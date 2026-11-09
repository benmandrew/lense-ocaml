(* lense-ocaml: print how each declared OCaml type is represented at runtime. *)

module M = Lense_model.Model

let usage =
  "lense-ocaml [options] <file.ml | file.mli | file.cmt | file.cmti | -> ...\n\n\
   Prints which constructors become immediates, which tag each block gets,\n\
   when the compiler drops the block, and how module structures are laid out.\n\
   Sizes are in words, without the header word.\n\nOptions:"

let () =
  let json = ref false and source = ref false and modules = ref true and labels = ref false in
  let only = ref [] and includes = ref [] and files = ref [] and intf = ref false in
  let spec =
    Arg.align
      [
        ("--json", Arg.Set json, " Print JSON instead of text");
        ("--type", Arg.String (fun s -> only := s :: !only), "NAME Show only the named types (repeatable)");
        ("--source", Arg.Set source, " Print each declaration above its representation");
        ("--no-modules", Arg.Clear modules, " Leave out module structures and coercions");
        ("--labels", Arg.Set labels, " List every polymorphic variant label with its hash");
        ("--intf", Arg.Set intf, " Read standard input as an interface (.mli)");
        ("-", Arg.Unit (fun () -> files := "-" :: !files), " Read source from standard input");
        ("-I", Arg.String (fun d -> includes := d :: !includes), "DIR Add DIR to the load path for .cmi files");
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
        let f' = if f = "-" && !intf then "-" else f in
        try
          Some
            (if f = "-" && !intf then
               Lense_core.Load.(
                 let src = read_stdin () in
                 let unit_name, input = typecheck ~include_dirs:(List.rev !includes) ~file:f' ~intf:true src in
                 Lense_core.Analyze.analyze ~file:f ~unit_name ~src:(Some src) input)
             else Lense_core.Load.compunit ~include_dirs:(List.rev !includes) f)
        with
        | Lense_core.Load.Failed msg ->
            if msg <> "" then prerr_string msg;
            if msg <> "" && msg.[String.length msg - 1] <> '\n' then prerr_newline ();
            failed := true;
            None
        | Sys_error msg ->
            prerr_endline msg;
            failed := true;
            None)
      files
  in
  if !json then print_string (Lense_model.Json.render units)
  else if !labels then (
    let b = Buffer.create 1024 in
    Lense_model.Text.labels b units;
    Lense_model.Text.collisions b units;
    print_string (Buffer.contents b))
  else
    print_string
      (Lense_model.Text.render { source = !source; modules = !modules; only = List.rev !only } units);
  exit (if !failed then 1 else 0)
