Every case file, as text with its source.

  $ for f in cases/*.ml cases/*.mli; do echo "### $f"; lense-ocaml --source $f; done
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
  
  Ask : int Effect.t
  extension Ask  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  | Tell : string -> unit Effect.t
  extension Tell  block, tag 0, size 2
      0  slot    pointer to extension slot, Object_tag 248
      1  string  pointer to string, String_tag 252
  ### cases/packages.ml
  (module ORDERED)  structure block, tag 0, size 4
      0  val name             pointer to string, String_tag 252
      1  val compare          pointer to closure, Closure_tag 247
      2  module Sub           pointer to structure, tag 0
      3  exception Unordered  pointer to extension slot, Object_tag 248
    no field: type t, external id
  
  type entry = { key : int; ops : (module ORDERED with type t = int) }
  type entry  block, tag 0, size 2
      0  key : int                                 immediate (int)
      1  ops : (module ORDERED with type t = int)  pointer to first-class module
  
  exception Unordered
  exception Ints.Unordered  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  type t = int
  type Ints.t  abbreviation: immediate (int)
  
  (module Shapes.SHAPE)  structure block, tag 0, size 3
      0  val area       pointer to boxed float, Double_tag 253
      1  class drawing  pointer to class, tag 0
      2  functor Scale  pointer to closure, Closure_tag 247
  
  (module EMPTY)  structure block, size 0: no item takes a field
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
  
  type nested = { c : colour; e : event }
  type nested  block, tag 0, size 2
      0  c : colour  immediate (constant polymorphic variant)
      1  e : event   immediate or pointer (polymorphic variant)
  
  type one = [ `Eric_Cooper ]
  type one  polymorphic variant
    `Eric_Cooper  immediate -332323982
  
  type other = [ `azdwbie of int ]
  type other  polymorphic variant
    `azdwbie  block, tag 0, size 2
                0  hash -332323982  immediate (label hash)
                1  int              immediate (int)
  
  hash collision: `Eric_Cooper (cases/polyvariants.ml:7), `azdwbie (cases/polyvariants.ml:8) all hash to -332323982
  ### cases/records.ml
  type r = { a : int; b : float }
  type r  block, tag 0, size 2
      0  a : int    immediate (int)
      1  b : float  pointer to boxed float, Double_tag 253
  
  type point = { x : float; mutable y : float }
  type point  flat float block, Double_array_tag 254, size 2
      0  x : float          unboxed double
      1  mutable y : float  unboxed double
  
  type fbox = { f : float } [@@unboxed]
  type fbox  no block: [@@unboxed], the value is its field
      f : float  pointer to boxed float, Double_tag 253
  
  type id = Id of int [@@unboxed]
  type id  variant
    Id  no block: [@@unboxed], the value is its field
          int  immediate (int)
  
  type iu = IU of { iu : int } [@@unboxed]
  type iu  variant
    IU  no block: [@@unboxed], the value is its field
          iu : int  immediate (int)
  
  type metres = float
  type metres  abbreviation: pointer to boxed float, Double_tag 253
  
  type t = float
  type Opaque.t  abbreviation: pointer to boxed float, Double_tag 253
  
  type seen = { m : metres; fb : fbox }
  type seen  flat float block, Double_array_tag 254, size 2
      0  m : metres  unboxed double
      1  fb : fbox   unboxed double
  
  type hidden = { o : Opaque.t; h : float }
  type hidden  block, tag 0, size 2
      0  o : Opaque.t  immediate or pointer (abstract type Opaque.t)
      1  h : float     pointer to boxed float, Double_tag 253
  
  type inline = | I0 | I1 of int | I2 of { ix : int; iy : float } | I3 of { f1 : float; f2 : float }
  type inline  variant
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
  
  type uses = { t : inline; ids : id list; arr : float array; iarr : int array; opt : int option; big : int64; ch : char; lz : int Lazy.t; apply : 'a. 'a -> 'a; }
  type uses  block, tag 0, size 9
      0  t : inline            immediate or pointer (inline)
      1  ids : id list         immediate or pointer (list)
      2  arr : float array     pointer to float array (Double_array_tag 254 unless empty)
      3  iarr : int array      pointer to array, tag 0
      4  opt : int option      immediate or pointer (option)
      5  big : int64           pointer to custom block, Custom_tag 255
      6  ch : char             immediate (char)
      7  lz : int Lazy.t       immediate or pointer (lazy value)
      8  apply : 'a. 'a -> 'a  pointer to closure, Closure_tag 247
  ### cases/sample.ml
  type shape = Point | Circle of float | Rect of { w : float; h : float }
  type shape  variant
    Point   immediate 0
    Circle  block, tag 0, size 1
              0  float  pointer to boxed float, Double_tag 253
    Rect    block, tag 1, size 2
              0  w : float  pointer to boxed float, Double_tag 253
              1  h : float  pointer to boxed float, Double_tag 253
              note: inline record: all fields are float, but inline records are never stored flat
  
  type colour = Red | Green | Blue
  type colour  variant
    Red    immediate 0
    Green  immediate 1
    Blue   immediate 2
  
  type vec = { x : float; y : float; z : float }
  type vec  flat float block, Double_array_tag 254, size 3
      0  x : float  unboxed double
      1  y : float  unboxed double
      2  z : float  unboxed double
  
  type id = Id of int [@@unboxed]
  type id  variant
    Id  no block: [@@unboxed], the value is its field
          int  immediate (int)
  ### cases/values.ml
  type counter = { next : unit -> int; reset : unit -> unit }
  type counter  block, tag 0, size 2
      0  next : unit -> int    pointer to closure, Closure_tag 247
      1  reset : unit -> unit  pointer to closure, Closure_tag 247
  ### cases/variants.ml
  type t = A | B of int | C | D of string
  type t  variant
    A  immediate 0
    B  block, tag 0, size 1
         0  int  immediate (int)
    C  immediate 1
    D  block, tag 1, size 1
         0  string  pointer to string, String_tag 252
  
  type nested = T of (int * int) | T2 of int * int
  type nested  variant
    T   block, tag 0, size 1
          0  int * int  pointer to tuple, tag 0
    T2  block, tag 1, size 2
          0  int  immediate (int)
          1  int  immediate (int)
  
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
  type 'a tree  variant
    Leaf  immediate 0
    Node  block, tag 0, size 3
            0  'a tree  immediate or pointer (tree)
            1  'a       immediate or pointer (type variable 'a)
            2  'a tree  immediate or pointer (tree)
  
  type empty = |
  type empty  variant with no constructors: it has no values
  
  type _ expr = | Int : int -> int expr | Bool : bool -> bool expr | Hide : 'a * ('a -> string) -> string expr | Unit : unit expr
  type _ expr  variant
    Int   block, tag 0, size 1
            0  int  immediate (int)
    Bool  block, tag 1, size 1
            0  bool  immediate (bool)
    Hide  block, tag 2, size 2
            0  'a            immediate or pointer (type variable 'a)
            1  'a -> string  pointer to closure, Closure_tag 247
            note: existential 'a: stored as uniform values
    Unit  immediate 0
    note: GADT: type indices are erased, so the constructors are numbered as in an ordinary variant
  ### cases/interface.mli
  type t
  type t  abstract: immediate or pointer (abstract type)
  
  type small [@@immediate]
  type small  abstract: immediate ([@@immediate])
  
  type id = private int
  type id  abbreviation: immediate (int)
  
  type pos = private { x : float; y : float }
  type pos  flat float block, Double_array_tag 254, size 2
      0  x : float  unboxed double
      1  y : float  unboxed double
  
  type pair = { a : t; b : small }
  type pair  block, tag 0, size 2
      0  a : t      immediate or pointer (abstract type t)
      1  b : small  immediate (small [@@immediate])
  
  (module CODEC)  structure block, tag 0, size 2
      0  val encode   pointer to closure, Closure_tag 247
      1  val default  immediate or pointer (abstract type v)
    no field: type v

Polymorphic variant labels and their hashes.

  $ lense-ocaml --labels cases/polyvariants.ml
  `A                     65  cases/polyvariants.ml:3
  `B                     66  cases/polyvariants.ml:3
  `Bar              3303859  cases/polyvariants.ml:10
  `Blue           737308346  cases/polyvariants.ml:1
  `Click         -611587032  cases/polyvariants.ml:2
  `Eric_Cooper   -332323982  cases/polyvariants.ml:7
  `Foo              3505894  cases/polyvariants.ml:10
  `Green          756711075  cases/polyvariants.ml:1
  `Key              3752319  cases/polyvariants.ml:2
  `Quit           904096751  cases/polyvariants.ml:2
  `Red              4100401  cases/polyvariants.ml:1
  `azdwbie       -332323982  cases/polyvariants.ml:8
  hash collision: `Eric_Cooper (cases/polyvariants.ml:7), `azdwbie (cases/polyvariants.ml:8) all hash to -332323982

A name filter matches the last component.

  $ lense-ocaml --type point --type SHAPE cases/records.ml cases/packages.ml
  == cases/records.ml
  
  type point  flat float block, Double_array_tag 254, size 2
      0  x : float          unboxed double
      1  mutable y : float  unboxed double
  
  == cases/packages.ml
  
  (module Shapes.SHAPE)  structure block, tag 0, size 3
      0  val area       pointer to boxed float, Double_tag 253
      1  class drawing  pointer to class, tag 0
      2  functor Scale  pointer to closure, Closure_tag 247
