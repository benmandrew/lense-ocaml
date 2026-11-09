OxCaml records and constructors with flat fields are mixed blocks: values
first, then flat data, one word per scalar in native code.

  $ lense-ocaml --no-modules mixed.ml
  type m  mixed block, tag 0, size 5: 2 scanned fields, then 3 flat
         0-7    header
      0  8-15   a : int     immediate (int)
      1  16-23  c : string  pointer to string, String_tag 252
      2  24-31  b : float#  unboxed float64, 8 bytes
      3  32-35  d : int32#  unboxed bits32, 4 bytes, bytes 36-39 unused
      4  40     f : int8#   unboxed bits8, 1 byte, bytes 41-47 unused
      note: values first, then flat fields, each in declaration order
      note: native code; bytecode stores one boxed field per declared field, in declaration order
  
  type u  flat float block, Double_array_tag 254, size 2
      0  x : float#  unboxed double
      1  y : float#  unboxed double
  
  type fm  mixed block, tag 0, size 2: 0 scanned fields, then 2 flat
         0-7    header
      0  8-15   p : float   unboxed float64, boxed again when read, 8 bytes
      1  16-23  q : float#  unboxed float64, 8 bytes
      note: native code; bytecode stores one boxed field per declared field, in declaration order
  
  type pr  no block: unboxed record, its fields are kept apart or stored in place
      px : int     immediate (int)
      py : float#  unboxed float64, 8 bytes
  
  type withp  mixed block, tag 0, size 6: 3 scanned fields, then 3 flat
         0-7    header
      0  8-15   w0 : string     pointer to string, String_tag 252
      1  16-23  w1.px : int     immediate (int)
      2  24-31  w3.1 : string   pointer to string, String_tag 252
      3  32-39  w1.py : float#  unboxed float64, 8 bytes
      4  40-47  w2 : int64#     unboxed bits64, 8 bytes
      5  48     w3.0 : int8#    unboxed bits8, 1 byte, bytes 49-55 unused
      note: values first, then flat fields, each in declaration order
      note: native code; bytecode stores one boxed field per declared field, in declaration order
  
  type v  variant: 3 block tags 0-2
    A  mixed block, tag 0, size 3: 2 scanned fields, then 1 flat
            0-7    header
         0  8-15   string            pointer to string, String_tag 252
         1  16-23  arg 1.1 : int     immediate (int)
         2  24-31  arg 1.0 : float#  unboxed float64, 8 bytes
         note: values first, then flat fields, each in declaration order
         note: native code; bytecode stores one boxed field per declared field, in declaration order
    B  block, tag 1, size 1
         0  int  immediate (int)
    C  mixed block, tag 2, size 3: 2 scanned fields, then 1 flat
            0-7    header
         0  8-15   s : string    pointer to string, String_tag 252
         1  16-23  n : int       immediate (int)
         2  24-27  t : float32#  unboxed float32, 4 bytes, bytes 28-31 unused
         note: values first, then flat fields, each in declaration order
         note: native code; bytecode stores one boxed field per declared field, in declaration order
  
  type t  abstract: unboxed float64, 8 bytes
  
  type i  abstract: immediate (i : immediate)
  
  type al  abbreviation: unboxed bits32, 4 bytes
  
  type o  abbreviation: immediate or pointer (null or int)

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
