Stage 0: the representation rules that lense-ocaml relies on, checked
against the pinned compiler. The first part inspects real values with Obj;
the second reads the compiler's own -dlambda output.

  $ ../test/stage0/runtime.exe
  A                            imm 0
  B                            block tag 0 size 1 [imm 1]
  C                            imm 1
  D                            block tag 1 size 1 [blk tag 252 size 1]
  G1                           block tag 0 size 1 [imm 1]
  G2                           block tag 1 size 2 [imm 1] [closure]
  G3                           imm 0
  r                            block tag 0 size 2 [imm 1] [blk tag 253 size 1]
  fr                           block tag 254 size 2
  mfr                          block tag 254 size 2
  u                            block tag 252 size 1
  u2                           imm 5
  u3                           block tag 253 size 1
  I2                           block tag 1 size 2 [imm 1] [blk tag 253 size 1]
  I3                           block tag 2 size 2 [blk tag 253 size 1] [blk tag 253 size 1]
  IU                           imm 3
  `Foo                         imm 3505894
  `Bar 1                       block tag 0 size 2 [imm 3303859] [imm 1]
  `Baz (1,2)                   block tag 0 size 2 [imm 3303867] [blk tag 0 size 2]
  `Q ((1,2))                   block tag 0 size 2 [imm 81] [blk tag 0 size 2]
  E1                           block tag 248 size 2 [blk tag 252 size 3] [imm 6]
  E2                           block tag 0 size 3 [blk tag 248 size 2] [imm 1] [blk tag 252 size 1]
  X1                           block tag 248 size 2 [blk tag 252 size 3] [imm 8]
  X2                           block tag 0 size 2 [blk tag 248 size 2] [imm 1]
  E2 field0 tag 248
  T                            block tag 0 size 1 [blk tag 0 size 2]
  T2                           block tag 1 size 2 [imm 1] [imm 2]
  float                        block tag 253 size 1
  [|1.;2.|]                    block tag 254 size 2
  int32                        block tag 255 size 2
  lazy                         block tag 246 size 1 [closure]
  unit                         imm 0
  true                         imm 1
  []                           imm 0
  [1]                          block tag 0 size 2 [imm 1] [imm 0]
  None                         imm 0
  Some 1                       block tag 0 size 1 [imm 1]
  'a'                          imm 97
  E1 slot: name "Dune__exe__Runtime.E1", id is an immediate: true
  closure                      closure, tag 247
  module Mod                   block tag 0 size 5 [imm 1] [closure] [blk tag 248 size 2] [blk tag 0 size 1] [blk tag 0 size 3]
  Mod.c (a class)              block tag 0 size 3 [closure] [closure] [imm 0]

Constant and non-constant constructors are numbered separately, flat float
records are float arrays, an exception is a block of tag 248 made once.

  $ ocamlc -dlambda -c -w -a stage0/lambda.ml 2>&1 | grep -E 'makeblock|makearray|= [0-9]|f/'
      (a/287 = 0
       c/288 = 1
       b/289 = (function n/291[int] (makeblock 0 (int) n/291))
       d/292 = (function s/294 (makeblock 1 s/294))
       f/295 =
           (makearray_imm[float] x/297 y/298))
       i/299 = (function n/301[int] (makeblock 1 (int,float) n/301 1.))
       p/302 = (function n/304 (makeblock 0 3303859 n/304))
       E/305 = (makeblock 248 "Lambda.E" (caml_fresh_oo_id 0))
       e/306 = (function n/308[int] (makeblock 0 (*,int) E/305 n/308)))
      (makeblock 0 a/287 c/288 b/289 d/292 f/295 i/299 p/302 E/305 e/306)))

OCaml 5.5 allows 244 non-constant constructors per type (tags 0 to 243).
Tags from 244 are reserved for the runtime: Forcing_tag 244, Cont_tag 245.

  $ gen () { printf 'type t ='; for i in $(seq 1 $1); do printf ' | C%d of int' $i; done; echo; }
  $ gen 244 > ok.ml && ocamlc -c ok.ml && echo accepted
  accepted
  $ gen 245 > over.ml && ocamlc -c over.ml 2>&1 | tail -2
  Error: Too many non-constant constructors
         -- maximum is 244 non-constant constructors
