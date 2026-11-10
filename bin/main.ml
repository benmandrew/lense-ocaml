(* lense-ocaml: print how each declared OCaml type is represented at runtime. *)

module M = Lense_model.Model

let usage =
  "lense-ocaml [options] <file.ml | file.mli | file.cmt | file.cmti | -> ...\n\n\
   Prints which constructors become immediates, which tag each block gets,\n\
   when the compiler drops the block, and how first-class modules are laid out.\n\
   Sizes are in words, without the header word.\n\n\
   Options:"

(* Which compiler's type checker reads the input. *)
type compiler = C55 | Ox

let compiler_of_string = function
  | "5.5" -> C55
  | "ox" | "oxcaml" -> Ox
  | s -> raise (Arg.Bad ("unknown compiler " ^ s ^ ": use 5.5 or ox"))

(* A .cmt, .cmti or .cmi file names its compiler in its magic number. *)
let detect file =
  match Filename.extension file with
  | ".cmt" | ".cmti" | ".cmi" -> (
      try
        let ic = open_in_bin file in
        let magic =
          Fun.protect
            ~finally:(fun () -> close_in ic)
            (fun () -> really_input_string ic 12)
        in
        let ox =
          Oxfront.Config.(magic = cmt_magic_number || magic = cmi_magic_number)
        in
        if ox then Some Ox else None
      with _ -> None)
  | _ -> None

(* The OxCaml stdlib .cmi files: --ox-stdlib or LENSE_OX_STDLIB if given,
   else the installed share directory, else the build tree when this runs
   as _build/default/bin/main.exe. *)
let find_ox_stdlib given =
  let here = Filename.dirname Sys.executable_name in
  let candidates =
    match given with
    | Some d -> [ d ]
    | None ->
        [
          Filename.concat here "../share/lense-ocaml/oxcaml-stdlib";
          Filename.concat here "../vendor/oxcaml/stdlib/cmi";
        ]
  in
  match
    List.find_opt
      (fun d -> Sys.file_exists (Filename.concat d "stdlib.cmi"))
      candidates
  with
  | Some d -> d
  | None ->
      raise
        (Lense_core_ox.Load.Failed
           ("lense-ocaml: no OxCaml stdlib.cmi in "
           ^ String.concat " or " candidates
           ^ "; pass --ox-stdlib DIR"))

(* The backend whose closures --values prints, or None for both. *)
let backend_of_string = function
  | "native" -> Some "native code"
  | "bytecode" -> Some "bytecode"
  | "both" -> None
  | s ->
      raise
        (Arg.Bad ("unknown backend " ^ s ^ ": use native, bytecode or both"))

let () =
  let values = ref false and backend = ref (Some "native code") in
  let compiler = ref None
  and ox_stdlib = ref (Sys.getenv_opt "LENSE_OX_STDLIB") in
  let json = ref false and source = ref false and labels = ref false in
  let only = ref []
  and includes = ref []
  and files = ref []
  and intf = ref false in
  let spec =
    Arg.align
      [
        ("--json", Arg.Set json, " Print JSON instead of text");
        ( "--type",
          Arg.String (fun s -> only := s :: !only),
          "NAME Show only the named types (repeatable)" );
        ( "--source",
          Arg.Set source,
          " Print each declaration above its representation" );
        ( "--values",
          Arg.Set values,
          " Also show closures, lazy values and objects" );
        ( "--backend",
          Arg.String (fun s -> backend := backend_of_string s),
          "native|bytecode|both Whose closures --values shows (default: native)"
        );
        ( "--labels",
          Arg.Set labels,
          " List every polymorphic variant label with its hash" );
        ("--intf", Arg.Set intf, " Read standard input as an interface (.mli)");
        ( "-",
          Arg.Unit (fun () -> files := "-" :: !files),
          " Read source from standard input" );
        ( "--compiler",
          Arg.String (fun s -> compiler := Some (compiler_of_string s)),
          "5.5|ox Type-check with OCaml 5.5 or OxCaml (default: from a .cmt \
           file's magic number, else 5.5)" );
        ( "--ox-stdlib",
          Arg.String (fun d -> ox_stdlib := Some d),
          "DIR Where the OxCaml stdlib .cmi files are" );
        ( "-I",
          Arg.String (fun d -> includes := d :: !includes),
          "DIR Add DIR to the load path for .cmi files" );
      ]
  in
  Arg.parse spec (fun f -> files := f :: !files) usage;
  let files = List.rev !files in
  if files = [] then (
    Arg.usage spec usage;
    exit 2);
  let failed = ref false in
  let units =
    List.filter_map
      (fun f ->
        let c =
          match !compiler with
          | Some c -> c
          | None -> Option.value (detect f) ~default:C55
        in
        let include_dirs = List.rev !includes in
        try
          Some
            (match c with
            | C55 ->
                Lense_core_55.Load.run ~values:!values ~include_dirs ~intf:!intf
                  f
            | Ox ->
                Lense_core_ox.Load.stdlib_dir :=
                  Some (find_ox_stdlib !ox_stdlib);
                Lense_core_ox.Load.run ~values:!values ~include_dirs ~intf:!intf
                  f)
        with
        | Lense_core_55.Load.Failed msg | Lense_core_ox.Load.Failed msg ->
            if msg <> "" then prerr_string msg;
            if msg <> "" && msg.[String.length msg - 1] <> '\n' then
              prerr_newline ();
            failed := true;
            None
        | Sys_error msg ->
            prerr_endline msg;
            failed := true;
            None)
      files
  in
  let units =
    match !backend with
    | Some b -> List.map (M.only_backend b) units
    | None -> units
  in
  if !json then print_string (Lense_model.Json.render units)
  else if !labels then (
    let b = Buffer.create 1024 in
    Lense_model.Text.labels b units;
    Lense_model.Text.collisions b units;
    print_string (Buffer.contents b))
  else
    print_string
      (Lense_model.Text.render
         { source = !source; only = List.rev !only }
         units);
  exit (if !failed then 1 else 0)
