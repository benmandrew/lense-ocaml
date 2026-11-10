(* The browser entry point. It sets globalThis.lense_analyze, which the web
   worker calls with the source text and an options object, and which
   returns { text, links, diagrams } or { error }. links is a JSON list of
   [line, ranges] pairs: the source ranges of each line of text, counting
   lines from 0. diagrams is Diagram.json's string. The option "compiler" is "5.5" (the default) or "ox"; each has
   its stdlib .cmi files embedded under /static. *)

open Js_of_ocaml
module M = Lense_model.Model

let flag opts name = Js.Optdef.case (Js.Unsafe.get opts name) (fun () -> false) Js.to_bool
let str opts name = Js.Optdef.case (Js.Unsafe.get opts name) (fun () -> "") Js.to_string

(* The same steps for either compiler: type-check, analyse, add values. *)
let unit_55 ~file ~intf ~values src =
  let open Lense_core_55 in
  Load.stdlib_dir := Some "/static/stdlib";
  match Load.typecheck ~include_dirs:[] ~file ~intf src with
  | exception Load.Failed msg -> Error msg
  | unit_name, input ->
      let u = Analyze.analyze ~file ~unit_name ~src:(Some src) input in
      Ok { u with values = Load.values_of ~values ~unit_name ~src:(Some src) input }

let unit_ox ~file ~intf ~values src =
  let open Lense_core_ox in
  Load.stdlib_dir := Some "/static/oxstdlib";
  match Load.typecheck ~include_dirs:[] ~file ~intf src with
  | exception Load.Failed msg -> Error msg
  | unit_name, input ->
      let u = Analyze.analyze ~file ~unit_name ~src:(Some src) input in
      Ok { u with values = Load.values_of ~values ~unit_name ~src:(Some src) input }

let analyze code opts =
  let src = Js.to_string code in
  let intf = flag opts "intf" in
  let file = if intf then "example.mli" else "example.ml" in
  let values = flag opts "values" in
  let result =
    try
      Result.map
        (fun u ->
          if flag opts "labels" then (
            let b = Buffer.create 1024 in
            Lense_model.Text.labels b [ u ];
            Lense_model.Text.collisions b [ u ];
            (Buffer.contents b, [], "[]"))
          else
            let topts : Lense_model.Text.options = { source = false; only = [] } in
            let text, links = Lense_model.Text.render_linked topts [ u ] in
            (text, links, Lense_model.Diagram.(json (compunit topts u))))
        ((if str opts "compiler" = "ox" then unit_ox else unit_55) ~file ~intf ~values src)
    with exn -> Error ("lense stopped: " ^ Printexc.to_string exn)
  in
  match result with
  | Ok (text, links, diagrams) ->
      let links =
        let open Lense_model.Json in
        let b = Buffer.create 1024 in
        write b ~indent:0 (List (List.map (fun (i, rs) -> List [ Int i; List (List.map (fun r -> range (Some r)) rs) ]) links));
        Buffer.contents b
      in
      Js.Unsafe.obj
        [| ("text", Js.Unsafe.inject (Js.string text)); ("links", Js.Unsafe.inject (Js.string links));
           ("diagrams", Js.Unsafe.inject (Js.string diagrams)) |]
  | Error msg -> Js.Unsafe.obj [| ("error", Js.Unsafe.inject (Js.string msg)) |]

let () = Js.Unsafe.set Js.Unsafe.global "lense_analyze" (Js.wrap_callback analyze)
