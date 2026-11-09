The running program agrees with mixed.t. This test compiles OxCaml
programs, so it runs only under the runtest-ox alias. It takes the
compiler from $OXCAML_BIN, or else from the 5.2.0+ox opam switch.

  $ export PATH="${OXCAML_BIN:-$(opam var --switch=5.2.0+ox bin 2>/dev/null)}:$PATH"
  $ ocamlfind ocamlopt -version
  5.2.0+ox

The running program agrees. Native code reorders the fields and marks the
scanned prefix in the header; bytecode keeps declaration order and boxes
the flat fields.

  $ cat > probe.ml <<'SRC'
  > type m = { a : int; b : float#; c : string; d : int32#; f : int8# }
  > let () =
  >   let r = Obj.repr { a = Sys.opaque_identity 1; b = #2.0; c = "c"; d = -#3l; f = #5s } in
  >   let d f = if Obj.is_int f then Printf.sprintf "int %d" (Obj.obj f : int) else Printf.sprintf "tag %d" (Obj.tag f) in
  >   let prefix = match Obj.Uniform_or_mixed.(repr (of_block r)) with Uniform -> "uniform" | Mixed { scannable_prefix_len = n } -> string_of_int n ^ " scanned" in
  >   Printf.printf "size %d, %s\n" (Obj.size r) prefix;
  >   for i = 0 to Obj.size r - 1 do
  >     if Sys.backend_type = Sys.Native && i >= 2 then Printf.printf "  %d raw %nx\n" i (Obj.raw_field r i)
  >     else Printf.printf "  %d %s\n" i (d (Obj.field r i))
  >   done
  > SRC
  $ ocamlfind ocamlopt probe.ml -o probe.exe 2>/dev/null && ./probe.exe
  size 5, 2 scanned
    0 int 1
    1 tag 252
    2 raw 4000000000000000
    3 raw fffffffd
    4 raw 5
  $ ocamlfind ocamlc probe.ml -o probe.byte && ./probe.byte
  size 5, 5 scanned
    0 int 1
    1 tag 253
    2 tag 252
    3 tag 255
    4 int 5
