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
