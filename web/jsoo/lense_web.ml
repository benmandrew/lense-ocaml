(* The browser entry point. It sets globalThis.lense_analyze, which the web
   worker calls with the source text and an options object, and which
   returns { text } or { error, line, start, stop }. *)

open Js_of_ocaml
module M = Lense_model.Model

let flag opts name = Js.Optdef.case (Js.Unsafe.get opts name) (fun () -> false) Js.to_bool

let analyze code opts =
  let src = Js.to_string code in
  let intf = flag opts "intf" in
  let file = if intf then "example.mli" else "example.ml" in
  Clflags.no_std_include := true;
  let result =
    try
      let unit_name, input = Lense_core.Load.typecheck ~include_dirs:[ "/static/stdlib" ] ~file ~intf src in
      let u = Lense_core.Analyze.analyze ~file ~unit_name ~src:(Some src) input in
      let values = flag opts "values" in
      let u = { u with values = Lense_core.Load.values_of ~values ~unit_name ~src:(Some src) input } in
      let text =
        if flag opts "labels" then (
          let b = Buffer.create 1024 in
          Lense_model.Text.labels b [ u ];
          Lense_model.Text.collisions b [ u ];
          Buffer.contents b)
        else Lense_model.Text.render { source = flag opts "source"; modules = not (flag opts "nomodules"); only = [] } [ u ]
      in
      Ok text
    with
    | Lense_core.Load.Failed msg -> Error msg
    | exn -> Error ("lense stopped: " ^ Printexc.to_string exn)
  in
  match result with
  | Ok text -> Js.Unsafe.obj [| ("text", Js.Unsafe.inject (Js.string text)) |]
  | Error msg -> Js.Unsafe.obj [| ("error", Js.Unsafe.inject (Js.string msg)) |]

let () = Js.Unsafe.set Js.Unsafe.global "lense_analyze" (Js.wrap_callback analyze)
