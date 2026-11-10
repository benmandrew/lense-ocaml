A type error is reported and the exit code is 1.

  $ printf 'type t = A of undefined\n' | lense-ocaml -
  File "stdin.ml", line 1, characters 14-23:
  Error: Unbound type constructor undefined
  [1]

Standard input can also be an interface.

  $ printf 'type t = A | B of int\nval x : t\n' | lense-ocaml --intf -
  type t  variant
    A  immediate 0
    B  block, tag 0, size 1
         0  int  immediate (int)
         cost: 2 words per value, with headers

A .cmi holds no typed tree, so lense asks for the .cmt or .cmti instead.

  $ printf 'type t = A\n' > c.ml && ocamlc -c c.ml && lense-ocaml c.cmi
  lense-ocaml: c.cmi holds no typed tree; pass the .cmt or .cmti that the build writes beside it with -bin-annot
  [1]
