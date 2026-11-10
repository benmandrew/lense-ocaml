A typed tree saved by the compiler gives the same answer as type-checking
the source, and resolves types from other units through their .cmi files.

  $ cat > a.ml <<'SRC'
  > type flag = On | Off
  > type pair = { x : float; y : float }
  > SRC
  $ cat > b.ml <<'SRC'
  > type uses = { f : A.flag; p : A.pair; o : A.flag option }
  > type t = W of A.pair [@@unboxed]
  > SRC
  $ ocamlc -bin-annot -c a.ml b.ml
  $ lense-ocaml b.cmt
  type uses  block, tag 0, size 3
      0  f : A.flag         immediate (constant constructors of A.flag)
      1  p : A.pair         pointer to float record A.pair, Double_array_tag 254
      2  o : A.flag option  immediate or pointer (option)
      cost: 7 or 9 words per value, with headers
  
  type t  variant
    W  no block: [@@unboxed], the value is its field
         A.pair  pointer to float record A.pair, Double_array_tag 254
         cost: 3 words per value, with headers
  $ lense-ocaml -I . b.ml
  type uses  block, tag 0, size 3
      0  f : A.flag         immediate (constant constructors of A.flag)
      1  p : A.pair         pointer to float record A.pair, Double_array_tag 254
      2  o : A.flag option  immediate or pointer (option)
      cost: 7 or 9 words per value, with headers
  
  type t  variant
    W  no block: [@@unboxed], the value is its field
         A.pair  pointer to float record A.pair, Double_array_tag 254
         cost: 3 words per value, with headers
  $ cp b.ml b.mli; ocamlc -bin-annot -c b.mli
  $ lense-ocaml b.cmti
  type uses  block, tag 0, size 3
      0  f : A.flag         immediate (constant constructors of A.flag)
      1  p : A.pair         pointer to float record A.pair, Double_array_tag 254
      2  o : A.flag option  immediate or pointer (option)
      cost: 7 or 9 words per value, with headers
  
  type t  variant
    W  no block: [@@unboxed], the value is its field
         A.pair  pointer to float record A.pair, Double_array_tag 254
         cost: 3 words per value, with headers

The closures and lazy values come from the saved typed tree
too. The Lambda translation looks names up in its environments, so they are
rebuilt from their summaries first. The source file the .cmt names is read
when its digest matches, so types are spelt and lazy values quoted as written.

  $ cat > c.ml <<'SRC'
  > type sw = { s : [ `On | `Off ] }
  > let adder a = fun b -> a + b
  > let l = lazy (String.make 1 'z')
  > SRC
  $ ocamlc -bin-annot -c c.ml
  $ lense-ocaml c.cmt
  closures in native code: Closure, without flambda
  
  type sw  block, tag 0, size 1
      0  s : [ `On | `Off ]  immediate (constant polymorphic variant)
      cost: 2 words per value, with headers
  
  fun adder.(fun)  line 2  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1, environment from field 2
      2  a : int  immediate (int)
  
  lazy (String.make 1 'z')  line 3  Lazy_tag 246 block, size 1, holding a closure; forcing it makes it a Forward_tag 250 block holding the result
