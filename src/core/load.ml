(* Inputs to typed trees: type-check a .ml or .mli with compiler-libs, or
   read the typed tree a build already saved in a .cmt or .cmti. *)

module M = Lense_model.Model

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let read_stdin () =
  let b = Buffer.create 4096 in
  (try
     while true do
       Buffer.add_channel b stdin 1
     done
   with End_of_file -> ());
  Buffer.contents b

exception Failed of string

(* The directory of the stdlib .cmi files, when it is not the compiler's own. *)
let stdlib_dir = ref None

let standard_library () =
  Option.value ~default:Config.standard_library !stdlib_dir

let report exn =
  match Location.error_of_exn exn with
  | Some (`Ok err) -> Failed (Format.asprintf "%a" Location.print_report err)
  | Some `Already_displayed -> Failed ""
  | None -> raise exn

let unit_name_of file =
  if file = "-" then "Stdin"
  else
    String.capitalize_ascii (Filename.remove_extension (Filename.basename file))

(* Type-check source text. [intf] chooses .mli syntax. *)
let typecheck ~include_dirs ~file ~intf src =
  Analyze.rebuild_env := Fun.id;
  Clflags.include_dirs := include_dirs @ Option.to_list !stdlib_dir;
  Clflags.no_std_include := !stdlib_dir <> None;
  Clflags.color := Some Misc.Color.Never;
  ignore (Warnings.parse_options false "-a");
  let unit_name = unit_name_of file in
  let source_file =
    if file = "-" then "stdin" ^ if intf then ".mli" else ".ml" else file
  in
  try
    Compmisc.init_path ();
    let ui = Compat.init_unit ~source_file ~intf in
    let env = Compmisc.initial_env () in
    let lexbuf = Lexing.from_string src in
    Location.init lexbuf source_file;
    Location.input_name := source_file;
    let input =
      if intf then
        Analyze.Intf
          (Compat.type_interface ~source_file ui env (Parse.interface lexbuf))
      else
        Analyze.Impl (Compat.type_structure env (Parse.implementation lexbuf))
    in
    (unit_name, input)
  with exn -> raise (report exn)

(* A typed tree from a build. Its environments hold only summaries, so they
   are rebuilt from the .cmi files on the load path recorded with it. *)
let read_cmt ~include_dirs file =
  let cmt = try Cmt_format.read_cmt file with exn -> raise (report exn) in
  (* The recorded build directory can be rewritten by BUILD_PATH_PREFIX_MAP,
     as dune does. Then look for it among the .cmt file's ancestors. *)
  let builddir =
    let relative = List.filter Filename.is_relative cmt.cmt_loadpath.visible in
    let fits d =
      Sys.file_exists d
      && List.for_all (fun r -> Sys.file_exists (Filename.concat d r)) relative
    in
    let rec ancestors d =
      let p = Filename.dirname d in
      d :: (if p = d then [] else ancestors p)
    in
    let here =
      Filename.dirname
        (if Filename.is_relative file then Filename.concat (Sys.getcwd ()) file
         else file)
    in
    match List.find_opt fits (cmt.cmt_builddir :: ancestors here) with
    | Some d -> d
    | None -> cmt.cmt_builddir
  in
  let rel d =
    if Filename.is_relative d then Filename.concat builddir d else d
  in
  let visible =
    List.map rel cmt.cmt_loadpath.visible
    @ include_dirs
    @ [ Filename.dirname file; standard_library () ]
  in
  Load_path.init ~auto_include:Load_path.no_auto_include ~visible
    ~hidden:(List.map rel cmt.cmt_loadpath.hidden);
  Compat.reset_envaux ();
  (Analyze.rebuild_env :=
     fun e -> try Envaux.env_of_only_summary e with _ -> e);
  let input =
    match cmt.cmt_annots with
    | Implementation str -> Analyze.Impl str
    | Interface sg -> Analyze.Intf sg
    | _ ->
        raise
          (Failed
             (file ^ ": the typed tree is partial; the build had type errors"))
  in
  let src =
    match cmt.cmt_sourcefile with
    | Some f -> (
        let path =
          if Filename.is_relative f then Filename.concat builddir f else f
        in
        try
          let s = read_file path in
          (* Only trust the text if it is what the build compiled. *)
          match cmt.cmt_source_digest with
          | Some d when Compat.source_digest s = d -> Some s
          | Some _ -> None
          | None -> Some s
        with Sys_error _ -> None)
    | None -> None
  in
  (Compat.cmt_modname cmt, input, src)

(* Closures, lazy values and objects, from an implementation. Run it before
   anything else is typechecked: the Lambda translation reads global state
   that typechecking sets. *)
let values_of ~values ~unit_name ~src (input : Analyze.input) =
  match input with
  | Impl str when values -> (
      try Some (Values.values ~modname:unit_name ~src str)
      with exn -> raise (report exn))
  | _ -> None

(* The Lambda translation looks names up in the typed tree's environments,
   which a .cmt holds only as summaries. Rebuild every one of them first. *)
let with_envs (input : Analyze.input) =
  match input with
  | Impl str ->
      let env _ e = !Analyze.rebuild_env e in
      let m = { Tast_mapper.default with env } in
      Analyze.Impl (m.structure m str)
  | Intf _ -> input

let compunit ?(values = false) ~include_dirs file : M.compunit =
  let ext = Filename.extension file in
  if ext = ".cmi" then
    raise
      (Failed
         (Printf.sprintf
            "lense-ocaml: %s holds no typed tree; pass the .cmt or .cmti that \
             the build writes beside it with -bin-annot"
            file));
  if ext = ".cmt" || ext = ".cmti" then
    let unit_name, input, src = read_cmt ~include_dirs file in
    let vals =
      values_of ~values ~unit_name ~src
        (if values then with_envs input else input)
    in
    { (Analyze.analyze ~file ~unit_name ~src input) with values = vals }
  else
    let src = if file = "-" then read_stdin () else read_file file in
    let intf = ext = ".mli" in
    let unit_name, input = typecheck ~include_dirs ~file ~intf src in
    let vals = values_of ~values ~unit_name ~src:(Some src) input in
    {
      (Analyze.analyze ~file ~unit_name ~src:(Some src) input) with
      values = vals;
    }

(* One input file, or standard input when [file] is "-". *)
let run ~values ~include_dirs ~intf file : M.compunit =
  if file = "-" && intf then
    let src = read_stdin () in
    let unit_name, input = typecheck ~include_dirs ~file ~intf:true src in
    Analyze.analyze ~file ~unit_name ~src:(Some src) input
  else compunit ~values ~include_dirs file
