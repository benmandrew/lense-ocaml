Every case file, as text with its source.

  $ for f in cases/*.ml; do echo "### $f"; lense-ocaml --source $f; done
  ### cases/exceptions.ml
  exception Empty
  exception Empty  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  exception Error of int * string
  exception Error  block, tag 0, size 3
      0  slot    pointer to extension slot, Object_tag 248
      1  int     immediate (int)
      2  string  pointer to string, String_tag 252
  
  exception Detail of { code : int; msg : string }
  exception Detail  block, tag 0, size 3
      0  slot          pointer to extension slot, Object_tag 248
      1  code : int    immediate (int)
      2  msg : string  pointer to string, String_tag 252
  
  exception Again = Empty
  exception Again  the same value as Empty (rebinding)
  
  type ext = ..
  type ext  extensible: each constructor is an extension, listed separately
  
  X1
  extension X1  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  | X2 of int
  extension X2  block, tag 0, size 2
      0  slot  pointer to extension slot, Object_tag 248
      1  int   immediate (int)
  
  | X3 of float
  extension X3  block, tag 0, size 2
      0  slot   pointer to extension slot, Object_tag 248
      1  float  pointer to boxed float, Double_tag 253
  
  X4 of { r : float }
  extension X4  block, tag 0, size 2
      0  slot       pointer to extension slot, Object_tag 248
      1  r : float  pointer to boxed float, Double_tag 253
      note: inline record: all fields are float, but inline records are never stored flat
  
  type 'a res = ..
  type 'a res  extensible: each constructor is an extension, listed separately
  
  Ok_ of 'a
  extension Ok_  block, tag 0, size 2
      0  slot  pointer to extension slot, Object_tag 248
      1  'a    immediate or pointer (type variable 'a)
  
  module Exceptions  structure block, tag 0, size 9
      0  exception Empty   pointer to extension slot, Object_tag 248
      1  exception Error   pointer to extension slot, Object_tag 248
      2  exception Detail  pointer to extension slot, Object_tag 248
      3  exception Again   pointer to extension slot, Object_tag 248
      4  extension X1      pointer to extension slot, Object_tag 248
      5  extension X2      pointer to extension slot, Object_tag 248
      6  extension X3      pointer to extension slot, Object_tag 248
      7  extension X4      pointer to extension slot, Object_tag 248
      8  extension Ok_     pointer to extension slot, Object_tag 248
    no field: type ext, type res
  ### cases/modules.ml
  type t = int
  type t  abbreviation: immediate (int)
  
  exception Stop
  exception Stop  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  type point = { x : float; y : float }
  type Inner.point  flat float block, Double_array_tag 254, size 2
      0  x : float  unboxed double
      1  y : float  unboxed double
  
  type t = int
  type IntOrd.t  abbreviation: immediate (int)
  
  module Modules  structure block, tag 0, size 11
       0  val answer        immediate (int)
       1  val greet         pointer to closure, Closure_tag 247
       2  exception Stop    pointer to extension slot, Object_tag 248
       3  module Inner      pointer to structure, tag 0
       4  module Reordered  pointer to structure, tag 0
       5  module Same       pointer to structure, tag 0
       6  functor Make      pointer to closure, Closure_tag 247
       7  module IntOrd     pointer to structure, tag 0
       8  module M          pointer to structure, tag 0
       9  module Prim       pointer to structure, tag 0
      10  class counter     pointer to class, tag 0
    no field: external identity, type t, module type S, module type ORD
  
  module Inner  structure block, tag 0, size 2
      0  val origin  pointer to float record point, Double_array_tag 254
      1  val norm    pointer to closure, Closure_tag 247
    no field: type point
  
  module Reordered  structure block, tag 0, size 3
      0  val answer  immediate (int)
      1  val unused  pointer to string, String_tag 252
      2  val greet   pointer to closure, Closure_tag 247
  
  module Same  structure block, tag 0, size 2
      0  val a  immediate (int)
      1  val b  immediate (int)
  
  module Make(O)  functor body: each application builds a block, tag 0, size 2
      0  val max  pointer to closure, Closure_tag 247
      1  val min  pointer to closure, Closure_tag 247
  
  module IntOrd  structure block, tag 0, size 2
      0  val compare  pointer to closure, Closure_tag 247
      1  val extra    immediate (unit)
    no field: type t
  
  module Prim  structure block, size 0: no item takes a field
  
  module Reordered : S  copies 2 of 3 fields into a new block, size 2
      0 <- 2  greet
      1 <- 0  answer
  
  module Same : sig val a : int val b : int end  no copy: the block is used as it is
  
  argument of Make at line 42  copies 1 of 2 fields into a new block, size 1
      0 <- 0  compare
  
  module Prim : sig val id : 'a -> 'a end  copies 0 of 0 fields into a new block, size 1
      0 <- -  id  (external wrapped in a closure)
  ### cases/polyvariants.ml
  type colour = [ `Red | `Green | `Blue ]
  type colour  polymorphic variant
    `Red    immediate 4100401
    `Blue   immediate 737308346
    `Green  immediate 756711075
  
  type event = [ `Key of char | `Click of int * int | `Quit ]
  type event  polymorphic variant
    `Click  block, tag 0, size 2
              0  hash -611587032  immediate (label hash)
              1  int * int        pointer to tuple, tag 0
    `Key    block, tag 0, size 2
              0  hash 3752319  immediate (label hash)
              1  char          immediate (char)
    `Quit   immediate 904096751
  
  type 'a opened = 'a constraint 'a = [> `A | `B of int ]
  type 'a opened  polymorphic variant, open: other tags may appear
    `A  immediate 65
    `B  block, tag 0, size 2
          0  hash 66  immediate (label hash)
          1  int      immediate (int)
  
  type 'a sub = 'a constraint 'a = [< `A | `B of int ]
  type 'a sub  polymorphic variant
    `A  immediate 65
    `B  block, tag 0, size 2
          0  hash 66  immediate (label hash)
          1  int      immediate (int)
  
  type both = [ colour | event ]
  type both  polymorphic variant
    `Click  block, tag 0, size 2
              0  hash -611587032  immediate (label hash)
              1  int * int        pointer to tuple, tag 0
    `Key    block, tag 0, size 2
              0  hash 3752319  immediate (label hash)
              1  char          immediate (char)
    `Red    immediate 4100401
    `Blue   immediate 737308346
    `Green  immediate 756711075
    `Quit   immediate 904096751
  
  type nested = { c : colour; e : event }
  type nested  block, tag 0, size 2
      0  c : colour  immediate (constant polymorphic variant)
      1  e : event   immediate or pointer (polymorphic variant)
  
  module Polyvariants  structure block, tag 0, size 1
      0  val f  pointer to closure, Closure_tag 247
    no field: type colour, type event, type opened, type sub, type both, type nested
  ### cases/records.ml
  type r = { a : int; b : float }
  type r  block, tag 0, size 2
      0  a : int    immediate (int)
      1  b : float  pointer to boxed float, Double_tag 253
  
  type point = { x : float; y : float }
  type point  flat float block, Double_array_tag 254, size 2
      0  x : float  unboxed double
      1  y : float  unboxed double
  
  type mpoint = { mutable mx : float; my : float }
  type mpoint  flat float block, Double_array_tag 254, size 2
      0  mutable mx : float  unboxed double
      1  my : float          unboxed double
  
  type single_float = { f : float }
  type single_float  flat float block, Double_array_tag 254, size 1
      0  f : float  unboxed double
  
  type wrapped = { u : string } [@@unboxed]
  type wrapped  no block: [@@unboxed], the value is its field
      u : string  pointer to string, String_tag 252
  
  type id = Id of int [@@unboxed]
  type id  variant, unboxed
    Id  no block: [@@unboxed], the value is its field
          int  immediate (int)
  
  type fbox = { uf : float } [@@unboxed]
  type fbox  no block: [@@unboxed], the value is its field
      uf : float  pointer to boxed float, Double_tag 253
  
  type poly = { apply : 'a. 'a -> 'a; n : int }
  type poly  block, tag 0, size 2
      0  apply : 'a. 'a -> 'a  pointer to closure, Closure_tag 247
      1  n : int               immediate (int)
  
  type 'a cell = { mutable contents : 'a; [@atomic] count : int }
  type 'a cell  block, tag 0, size 2
      0  mutable contents : 'a  immediate or pointer (type variable 'a)
      1  count : int            immediate (int)
  
  type inline = | I0 | I1 of int | I2 of { ix : int; iy : float } | I3 of { f1 : float; f2 : float }
  type inline  variant: 1 immediate 0, 3 block tags 0-2
    I0  immediate 0
    I1  block, tag 0, size 1
          0  int  immediate (int)
    I2  block, tag 1, size 2
          0  ix : int    immediate (int)
          1  iy : float  pointer to boxed float, Double_tag 253
    I3  block, tag 2, size 2
          0  f1 : float  pointer to boxed float, Double_tag 253
          1  f2 : float  pointer to boxed float, Double_tag 253
          note: inline record: all fields are float, but inline records are never stored flat
  
  type iu = IU of { iu : int } [@@unboxed]
  type iu  variant, unboxed
    IU  no block: [@@unboxed], the value is its field
          iu : int  immediate (int)
  
  type uses = { t : inline; ids : id list; arr : float array; iarr : int array; opt : int option; big : int64; ch : char; lz : int Lazy.t; }
  type uses  block, tag 0, size 8
      0  t : inline         immediate or pointer (inline)
      1  ids : id list      immediate or pointer (list)
      2  arr : float array  pointer to float array (Double_array_tag 254 unless empty)
      3  iarr : int array   pointer to array, tag 0
      4  opt : int option   immediate or pointer (option)
      5  big : int64        pointer to custom block, Custom_tag 255
      6  ch : char          immediate (char)
      7  lz : int Lazy.t    immediate or pointer (lazy value)
  
  module Records  structure block, size 0: no item takes a field
  ### cases/variants.ml
  type t = A | B of int | C | D of string
  type t  variant: 2 immediates 0-1, 2 block tags 0-1
    A  immediate 0
    B  block, tag 0, size 1
         0  int  immediate (int)
    C  immediate 1
    D  block, tag 1, size 1
         0  string  pointer to string, String_tag 252
  
  type shape = Circle of float | Rect of float * float | Point
  type shape  variant: 1 immediate 0, 2 block tags 0-1
    Circle  block, tag 0, size 1
              0  float  pointer to boxed float, Double_tag 253
    Rect    block, tag 1, size 2
              0  float  pointer to boxed float, Double_tag 253
              1  float  pointer to boxed float, Double_tag 253
    Point   immediate 0
  
  type nested = T of (int * int) | T2 of int * int
  type nested  variant: 2 block tags 0-1
    T   block, tag 0, size 1
          0  int * int  pointer to tuple, tag 0
    T2  block, tag 1, size 2
          0  int  immediate (int)
          1  int  immediate (int)
  
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
  type 'a tree  variant: 1 immediate 0, 1 block tag 0
    Leaf  immediate 0
    Node  block, tag 0, size 3
            0  'a tree  immediate or pointer (tree)
            1  'a       immediate or pointer (type variable 'a)
            2  'a tree  immediate or pointer (tree)
  
  type empty = |
  type empty  variant with no constructors: it has no values
  
  type _ expr = | Int : int -> int expr | Bool : bool -> bool expr | Pair : 'a expr * 'b expr -> ('a * 'b) expr | Hide : 'a * ('a -> string) -> string expr | Unit : unit expr
  type _ expr  variant: 1 immediate 0, 4 block tags 0-3
    Int   block, tag 0, size 1
            0  int  immediate (int)
    Bool  block, tag 1, size 1
            0  bool  immediate (bool)
    Pair  block, tag 2, size 2
            0  'a expr  immediate or pointer (expr)
            1  'b expr  immediate or pointer (expr)
    Hide  block, tag 3, size 2
            0  'a            immediate or pointer (type variable 'a)
            1  'a -> string  pointer to closure, Closure_tag 247
            note: existential 'a: stored as uniform values
    Unit  immediate 0
    note: GADT: type indices are erased, so the constructors are numbered as in an ordinary variant
  
  module Variants  structure block, size 0: no item takes a field

Polymorphic variant labels and their hashes.

  $ lense-ocaml --labels cases/polyvariants.ml
  `A               65  cases/polyvariants.ml:3
  `B               66  cases/polyvariants.ml:3
  `Bar        3303859  cases/polyvariants.ml:8
  `Blue     737308346  cases/polyvariants.ml:1
  `Click   -611587032  cases/polyvariants.ml:2
  `Foo        3505894  cases/polyvariants.ml:8
  `Green    756711075  cases/polyvariants.ml:1
  `Key        3752319  cases/polyvariants.ml:2
  `Quit     904096751  cases/polyvariants.ml:2
  `Red        4100401  cases/polyvariants.ml:1

A name filter matches the last component.

  $ lense-ocaml --type point cases/records.ml cases/modules.ml
  == cases/records.ml
  
  type point  flat float block, Double_array_tag 254, size 2
      0  x : float  unboxed double
      1  y : float  unboxed double
  
  == cases/modules.ml
  
  type Inner.point  flat float block, Double_array_tag 254, size 2
      0  x : float  unboxed double
      1  y : float  unboxed double
