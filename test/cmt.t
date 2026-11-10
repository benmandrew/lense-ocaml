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
  
  type t  variant
    W  no block: [@@unboxed], the value is its field
         A.pair  pointer to float record A.pair, Double_array_tag 254
  $ lense-ocaml -I . b.ml
  type uses  block, tag 0, size 3
      0  f : A.flag         immediate (constant constructors of A.flag)
      1  p : A.pair         pointer to float record A.pair, Double_array_tag 254
      2  o : A.flag option  immediate or pointer (option)
  
  type t  variant
    W  no block: [@@unboxed], the value is its field
         A.pair  pointer to float record A.pair, Double_array_tag 254
  $ cp b.ml b.mli; ocamlc -bin-annot -c b.mli
  $ lense-ocaml b.cmti
  type uses  block, tag 0, size 3
      0  f : A.flag         immediate (constant constructors of A.flag)
      1  p : A.pair         pointer to float record A.pair, Double_array_tag 254
      2  o : A.flag option  immediate or pointer (option)
  
  type t  variant
    W  no block: [@@unboxed], the value is its field
         A.pair  pointer to float record A.pair, Double_array_tag 254
