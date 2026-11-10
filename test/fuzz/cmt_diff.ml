(* The .cmt path against the source path. lense reads a .cmt through
   Load.read_cmt, whose environments hold only summaries and are rebuilt
   by Analyze.rebuild_env. Each generated program is compiled with
   -bin-annot, the .cmt is read back, and its JSON must equal the JSON from
   type-checking the source, apart from the file name. *)

module M = Lense_model.Model

(* Compile [src] as [file] with -bin-annot, stopping after type-checking,
   and return the .cmt path. *)
let compile ~ocamlc ~file src =
  Out_channel.with_open_bin file (fun oc -> output_string oc src);
  let dir = Filename.dirname file in
  let log = Filename.remove_extension file ^ ".cmt.log" in
  let cmd =
    Printf.sprintf
      "cd %s && %s -bin-annot -stop-after typing -w -a -c %s > %s 2>&1"
      (Filename.quote dir) ocamlc
      (Filename.quote (Filename.basename file))
      (Filename.quote log)
  in
  if Sys.command cmd = 0 then Ok (Filename.remove_extension file ^ ".cmt")
  else
    Error
      ("ocamlc -bin-annot fails: "
      ^ In_channel.with_open_text log In_channel.input_all)

let load ~ox cmt =
  try
    Ok
      (if ox then Lense_core_ox.Load.compunit ~values:true ~include_dirs:[] cmt
       else Lense_core_55.Load.compunit ~values:true ~include_dirs:[] cmt)
  with
  | Lense_core_55.Load.Failed msg | Lense_core_ox.Load.Failed msg -> Error msg
  | exn -> Error ("lense stopped: " ^ Printexc.to_string exn)

(* The unit and its labels name the file lense read, the .ml or the .cmt.
   Nothing else may differ. *)
let json (u : M.compunit) =
  let labels =
    List.map (fun (l : M.label_use) -> { l with file = "" }) u.labels
  in
  Lense_model.Json.render [ { u with file = ""; labels } ]

(* The first lines of a unified diff of two texts. *)
let diff ~file a b =
  let base = Filename.remove_extension file in
  let fa = base ^ ".src.json" and fb = base ^ ".cmt.json" in
  Out_channel.with_open_bin fa (fun oc -> output_string oc a);
  Out_channel.with_open_bin fb (fun oc -> output_string oc b);
  let ic =
    Unix.open_process_in
      (Printf.sprintf "diff -u %s %s | head -40" (Filename.quote fa)
         (Filename.quote fb))
  in
  let d = In_channel.input_all ic in
  ignore (Unix.close_process_in ic);
  d

(* None when the .cmt gives the same model as the source [u] of [src]. *)
let check ~ox ~ocamlc ~file src (u : M.compunit) =
  match Result.bind (compile ~ocamlc ~file src) (load ~ox) with
  | Error msg -> Some ("the .cmt does not load: " ^ msg)
  | Ok c ->
      let a = json u and b = json c in
      if a = b then None
      else
        Some ("the .cmt gives another model than the source:\n" ^ diff ~file a b)
