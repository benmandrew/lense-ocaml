(* Inputs to typed trees: type-check a .ml or .mli with compiler-libs, or
   read the typed tree a build already saved in a .cmt or .cmti. *)

module M = Lense_model.Model

let read_file path =
  let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> really_input_string ic (in_channel_length ic))

let read_stdin () =
  let b = Buffer.create 4096 in
  (try
     while true do
       Buffer.add_channel b stdin 1
     done
   with End_of_file -> ());
  Buffer.contents b

exception Failed of string

let report exn =
  match Location.error_of_exn exn with
  | Some (`Ok err) -> Failed (Format.asprintf "%a" Location.print_report err)
  | Some `Already_displayed -> Failed ""
  | None -> raise exn

let unit_name_of file =
  if file = "-" then "Stdin"
  else String.capitalize_ascii (Filename.remove_extension (Filename.basename file))

(* Type-check source text. [intf] chooses .mli syntax. *)
let typecheck ~include_dirs ~file ~intf src =
  Analyze.rebuild_env := Fun.id;
  Clflags.include_dirs := include_dirs;
  Clflags.color := Some Misc.Color.Never;
  ignore (Warnings.parse_options false "-a");
  let unit_name = unit_name_of file in
  let source_file = if file = "-" then "stdin" ^ if intf then ".mli" else ".ml" else file in
  try
    Compmisc.init_path ();
    let ui =
      Unit_info.make ~check_modname:false ~source_file
        (if intf then Unit_info.Intf else Unit_info.Impl)
        (Filename.remove_extension source_file)
    in
    Env.set_current_unit ui;
    let env = Compmisc.initial_env () in
    let lexbuf = Lexing.from_string src in
    Location.init lexbuf source_file;
    Location.input_name := source_file;
    let input =
      if intf then Analyze.Intf (Typemod.type_interface env (Parse.interface lexbuf))
      else
        let str, _, _, _, _ = Typemod.type_structure env (Parse.implementation lexbuf) in
        Analyze.Impl str
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
    let fits d = Sys.file_exists d && List.for_all (fun r -> Sys.file_exists (Filename.concat d r)) relative in
    let rec ancestors d =
      let p = Filename.dirname d in
      d :: (if p = d then [] else ancestors p)
    in
    let here = Filename.dirname (if Filename.is_relative file then Filename.concat (Sys.getcwd ()) file else file) in
    match List.find_opt fits (cmt.cmt_builddir :: ancestors here) with
    | Some d -> d
    | None -> cmt.cmt_builddir
  in
  let rel d = if Filename.is_relative d then Filename.concat builddir d else d in
  let visible =
    List.map rel cmt.cmt_loadpath.visible @ include_dirs @ [ Filename.dirname file; Config.standard_library ]
  in
  Load_path.init ~auto_include:Load_path.no_auto_include ~visible
    ~hidden:(List.map rel cmt.cmt_loadpath.hidden);
  Envaux.reset_cache ();
  Analyze.rebuild_env := (fun e -> try Envaux.env_of_only_summary e with _ -> e);
  let input =
    match cmt.cmt_annots with
    | Implementation str -> Analyze.Impl str
    | Interface sg -> Analyze.Intf sg
    | _ -> raise (Failed (file ^ ": the typed tree is partial; the build had type errors"))
  in
  let src =
    match cmt.cmt_sourcefile with
    | Some f -> (
        let path = if Filename.is_relative f then Filename.concat builddir f else f in
        try
          let s = read_file path in
          (* Only trust the text if it is what the build compiled. *)
          match cmt.cmt_source_digest with
          | Some d when Digest.to_hex (Digest.string s) = d || Digest.string s = d -> Some s
          | Some _ -> None
          | None -> Some s
        with Sys_error _ -> None)
    | None -> None
  in
  (cmt.cmt_modname, input, src)

(* Coerce a unit's structure to its interface, as the compiler does at the
   end of compiling an implementation that has an .mli. *)
let coerce_to_interface ~impl_file ~intf_file intf_sg (input : Analyze.input) =
  match input with
  | Intf _ -> None
  | Impl str -> (
      try
        let env = Compmisc.initial_env () in
        let cc, _ = Includemod.compunit env ~mark:false impl_file str.str_type intf_file intf_sg Shape.dummy_mod in
        Some (env, intf_file, intf_sg, cc)
      with exn -> raise (report exn))

let compunit ~include_dirs file : M.compunit =
  let ext = Filename.extension file in
  if ext = ".cmt" || ext = ".cmti" then
    let unit_name, input, src = read_cmt ~include_dirs file in
    (* The interface the build compiled: a .cmti beside the .cmt marks one. *)
    let base = Filename.remove_extension file in
    let interface =
      if ext = ".cmt" && Sys.file_exists (base ^ ".cmti") && Sys.file_exists (base ^ ".cmi") then
        let sg =
          try Env.read_signature (Unit_info.Artifact.from_filename (base ^ ".cmi"))
          with exn -> raise (report exn)
        in
        let intf_file =
          match (Cmt_format.read_cmt (base ^ ".cmti")).cmt_sourcefile with
          | Some f -> f
          | None | (exception _) -> base ^ ".cmi"
        in
        coerce_to_interface ~impl_file:file ~intf_file sg input
      else None
    in
    Analyze.analyze ?interface ~file ~unit_name ~src input
  else
    let src = if file = "-" then read_stdin () else read_file file in
    let intf = ext = ".mli" in
    let unit_name, input = typecheck ~include_dirs ~file ~intf src in
    let mli = Filename.remove_extension file ^ ".mli" in
    let interface =
      if intf || file = "-" || not (Sys.file_exists mli) then None
      else
        match typecheck ~include_dirs ~file:mli ~intf:true (read_file mli) with
        | _, Intf tsg -> coerce_to_interface ~impl_file:file ~intf_file:mli tsg.sig_type input
        | _, Impl _ -> None
    in
    Analyze.analyze ?interface ~file ~unit_name ~src:(Some src) input
