A unit with an .mli is coerced to it at the end of compilation. The block
other units see has the interface's fields, in the interface's order.

  $ cat > m.ml <<'SRC'
  > let a = 1
  > let b = "x"
  > let c () = 2
  > external id : 'a -> 'a = "%identity"
  > let d = 3.0
  > module N = struct let p = 1 end
  > SRC
  $ cat > m.mli <<'SRC'
  > val d : float
  > val c : unit -> int
  > val id : 'a -> 'a
  > module N : sig end
  > val a : int
  > SRC
  $ lense-ocaml m.ml
  module M  structure block, tag 0, size 5
      0  val a     immediate (int)
      1  val b     pointer to string, String_tag 252
      2  val c     pointer to closure, Closure_tag 247
      3  val d     pointer to boxed float, Double_tag 253
      4  module N  pointer to structure, tag 0
    no field: external id
  
  module N  structure block, tag 0, size 1
      0  val p  immediate (int)
  
  unit M : m.mli  copies 4 of 5 fields into a new block, size 5
      0 <- 3  d
      1 <- 2  c
      2 <- -  id  (external wrapped in a closure)
      3 <- 4  N  (coerced again)
      4 <- 0  a

The compiler builds the same block:

  $ ocamlc -c m.mli && ocamlc -dlambda -c m.ml 2>&1 | grep -A1 'makeblock 0 d' | sed 's|/[0-9]*||g'
      (makeblock 0 d c (function prim stub prim) (makeblock 0)
        a)))

A .cmt with a .cmti beside it gives the same coercion:

  $ ocamlc -bin-annot -c m.mli m.ml
  $ lense-ocaml m.cmt | tail -6
  unit M : m.mli  copies 4 of 5 fields into a new block, size 5
      0 <- 3  d
      1 <- 2  c
      2 <- -  id  (external wrapped in a closure)
      3 <- 4  N  (coerced again)
      4 <- 0  a

An implementation that does not match its interface is an error:

  $ printf 'let a = 1\n' > bad.ml
  $ printf 'val a : string\n' > bad.mli
  $ lense-ocaml bad.ml
  File "bad.mli", line 1:
  Error: The implementation bad.ml does not match the interface bad.mli: 
         Values do not match: val a : int is not included in val a : string
         The type int is not compatible with the type string
         File "bad.mli", line 1, characters 0-14: Expected declaration
         File "bad.ml", line 1, characters 4-5: Actual declaration
  [1]
