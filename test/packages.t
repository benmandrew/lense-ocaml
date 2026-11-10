A value of type (module S) is a structure block laid out by S alone. Packing
coerces the module to S, so the block holds S's value-bearing items in S's
order, whatever the module looked like. Named modules are one block per
program, so they are left out.

  $ cat > p.ml <<'SRC'
  > module type S = sig
  >   type t
  >   val name : string
  >   val compare : t -> t -> int
  >   module Sub : sig val depth : int end
  >   exception E
  > end
  > type entry = { key : int; ops : (module S with type t = int) }
  > module Ints = struct
  >   exception E
  >   let extra = 0.5
  >   type t = int
  >   let compare = Int.compare
  >   module Sub = struct let more = 2 let depth = 1 end
  >   let name = "ints"
  > end
  > let entry = { key = 1; ops = (module Ints) }
  > SRC
  $ lense-ocaml p.ml
  (module S)  structure block, tag 0, size 4
      0  val name     pointer to string, String_tag 252
      1  val compare  pointer to closure, Closure_tag 247
      2  module Sub   pointer to structure, tag 0
      3  exception E  pointer to extension slot, Object_tag 248
    no field: type t
  
  type entry  block, tag 0, size 2
      0  key : int                           immediate (int)
      1  ops : (module S with type t = int)  pointer to first-class module
      cost: 3 words per value, with headers
      not counted: ops (first-class module)
  
  exception Ints.E  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  type Ints.t  abbreviation: immediate (int)

The running program agrees, on both backends. Ints has its items in another
order and two more of them; the packed block has S's four.

  $ cat > check.ml <<'SRC'
  > let () =
  >   let r = Obj.repr P.entry.ops in
  >   let tag i = Obj.tag (Obj.field r i) in
  >   Printf.printf "tag %d, size %d\n" (Obj.tag r) (Obj.size r);
  >   Printf.printf "0 string %b, 1 closure %b, 3 extension slot %b\n"
  >     (tag 0 = Obj.string_tag) (tag 1 = Obj.closure_tag) (tag 3 = Obj.object_tag);
  >   Printf.printf "2 Sub: tag %d, size %d\n" (tag 2) (Obj.size (Obj.field r 2))
  > SRC
  $ ocamlopt p.ml check.ml -o native.exe 2>/dev/null && ./native.exe
  tag 0, size 4
  0 string true, 1 closure true, 3 extension slot true
  2 Sub: tag 0, size 1
  $ ocamlc p.ml check.ml -o byte.exe && ./byte.exe
  tag 0, size 4
  0 string true, 1 closure true, 3 extension slot true
  2 Sub: tag 0, size 1
