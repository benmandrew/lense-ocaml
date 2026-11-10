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
      cost: 4 words per value, with headers
      not counted: field 2 (string)
  
  exception Detail of { code : int; msg : string }
  exception Detail  block, tag 0, size 3
      0  slot          pointer to extension slot, Object_tag 248
      1  code : int    immediate (int)
      2  msg : string  pointer to string, String_tag 252
      cost: 4 words per value, with headers
      not counted: msg (string)
  
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
      cost: 3 words per value, with headers
  
  Ask : int Effect.t
  extension Ask  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  | Tell : string -> unit Effect.t
  extension Tell  block, tag 0, size 2
      0  slot    pointer to extension slot, Object_tag 248
      1  string  pointer to string, String_tag 252
      cost: 3 words per value, with headers
      not counted: field 1 (string)
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
      cost: 3 words per value, with headers
      not counted: ops (first-class module)
  
  exception Unordered
  exception Ints.Unordered  extension slot: block, Object_tag 248, size 2 (name, unique id)
  
  type t = int
  type Ints.t  abbreviation: immediate (int)
  
  (module Shapes.SHAPE)  structure block, tag 0, size 3
      0  val area       pointer to boxed float, Double_tag 253
      1  class drawing  pointer to class, tag 0
      2  functor Scale  pointer to closure, Closure_tag 247
  
  class drawing  line 59  Object_tag 248, size 2
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
  
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
              cost: 6 words per value, with headers
    `Key    block, tag 0, size 2
              0  hash 3752319  immediate (label hash)
              1  char          immediate (char)
              cost: 3 words per value, with headers
    `Quit   immediate 904096751
  
  type 'a opened = 'a constraint 'a = [> `A | `B of int ]
  type 'a opened  polymorphic variant, open: other tags may appear
    `A  immediate 65
    `B  block, tag 0, size 2
          0  hash 66  immediate (label hash)
          1  int      immediate (int)
          cost: 3 words per value, with headers
  
  type nested = { c : colour; e : event }
  type nested  block, tag 0, size 2
      0  c : colour  immediate (constant polymorphic variant)
      1  e : event   immediate or pointer (polymorphic variant)
      cost: 3, 6 or 9 words per value, with headers
  
  type one = [ `Eric_Cooper ]
  type one  polymorphic variant
    `Eric_Cooper  immediate -332323982
  
  type other = [ `azdwbie of int ]
  type other  polymorphic variant
    `azdwbie  block, tag 0, size 2
                0  hash -332323982  immediate (label hash)
                1  int              immediate (int)
                cost: 3 words per value, with headers
  
  hash collision: `Eric_Cooper (cases/polyvariants.ml:7), `azdwbie (cases/polyvariants.ml:8) all hash to -332323982
  ### cases/records.ml
  type r = { a : int; b : float }
  type r  block, tag 0, size 2
      0  a : int    immediate (int)
      1  b : float  pointer to boxed float, Double_tag 253
      cost: 5 words per value, with headers
  
  type point = { x : float; mutable y : float }
  type point  flat float block, Double_array_tag 254, size 2
      0  x : float          unboxed double
      1  mutable y : float  unboxed double
      cost: 3 words per value, with headers
  
  type fbox = { f : float } [@@unboxed]
  type fbox  no block: [@@unboxed], the value is its field
      f : float  pointer to boxed float, Double_tag 253
      cost: 2 words per value, with headers
  
  type id = Id of int [@@unboxed]
  type id  variant
    Id  no block: [@@unboxed], the value is its field
          int  immediate (int)
          cost: 0 words, no blocks
  
  type iu = IU of { iu : int } [@@unboxed]
  type iu  variant
    IU  no block: [@@unboxed], the value is its field
          iu : int  immediate (int)
          cost: 0 words, no blocks
  
  type metres = float
  type metres  abbreviation: pointer to boxed float, Double_tag 253
  
  type t = float
  type Opaque.t  abbreviation: pointer to boxed float, Double_tag 253
  
  type seen = { m : metres; fb : fbox }
  type seen  flat float block, Double_array_tag 254, size 2
      0  m : metres  unboxed double
      1  fb : fbox   unboxed double
      cost: 3 words per value, with headers
  
  type hidden = { o : Opaque.t; h : float }
  type hidden  block, tag 0, size 2
      0  o : Opaque.t  immediate or pointer (abstract type Opaque.t)
      1  h : float     pointer to boxed float, Double_tag 253
      cost: 5 words per value, with headers
      not counted: o (abstract type Opaque.t)
  
  type inline = | I0 | I1 of int | I2 of { ix : int; iy : float } | I3 of { f1 : float; f2 : float }
  type inline  variant
    I0  immediate 0
    I1  block, tag 0, size 1
          0  int  immediate (int)
          cost: 2 words per value, with headers
    I2  block, tag 1, size 2
          0  ix : int    immediate (int)
          1  iy : float  pointer to boxed float, Double_tag 253
          cost: 5 words per value, with headers
    I3  block, tag 2, size 2
          0  f1 : float  pointer to boxed float, Double_tag 253
          1  f2 : float  pointer to boxed float, Double_tag 253
          cost: 7 words per value, with headers
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
      cost: 13, 15, 17, 18, 20 or 22 words per value, with headers
      not counted: ids (id list: 3 words per node), arr (array), iarr (array), lz (lazy value), apply (closure)
  ### cases/recursive.ml
  type node = { v : int; mutable next : node option }
  type node  block, tag 0, size 2
      0  v : int                     immediate (int)
      1  mutable next : node option  immediate or pointer (option)
      cost: 3 or 5 words per node, with headers
  
  type cell = Nil | Cons of { v : int; mutable next : cell }
  type cell  variant
    Nil   immediate 0
    Cons  block, tag 0, size 2
            0  v : int              immediate (int)
            1  mutable next : cell  immediate or pointer (cell)
            cost: 3 words per node, with headers
  
  type expr = Num of float | Add of expr * expr | Neg of expr
  type expr  variant
    Num  block, tag 0, size 1
           0  float  pointer to boxed float, Double_tag 253
           cost: 4 words per node, with headers
    Add  block, tag 1, size 2
           0  expr  pointer to expr
           1  expr  pointer to expr
           cost: 3 words per node, with headers
    Neg  block, tag 2, size 1
           0  expr  pointer to expr
           cost: 2 words per node, with headers
  
  type forest = Tree of int * forest list
  type forest  variant
    Tree  block, tag 0, size 2
            0  int          immediate (int)
            1  forest list  immediate or pointer (list)
            cost: 3 words per node, with headers
            not counted: field 1 (forest list: 3 words per node)
  
  type even = Zero | Succ of odd
  type even  variant
    Zero  immediate 0
    Succ  block, tag 0, size 1
            0  odd  pointer to record odd, tag 0
            cost: 2 words per node, with headers
  
  and odd = { pred : even }
  type odd  block, tag 0, size 1
      0  pred : even  immediate or pointer (even)
      cost: 2 words per node, with headers
  
  type 'a seq = Seq of ('a * 'a seq) option [@@unboxed]
  type 'a seq  variant
    Seq  no block: [@@unboxed], the value is its field
           ('a * 'a seq) option  immediate or pointer (option)
           cost: 0 or 5 words per node, with headers
           not counted: the field ('a)
  
  type json = [ `Null | `Num of float | `List of json list ]
  type json  polymorphic variant
    `Num   block, tag 0, size 2
             0  hash 3905062  immediate (label hash)
             1  float         pointer to boxed float, Double_tag 253
             cost: 5 words per node, with headers
    `List  block, tag 0, size 2
             0  hash 848054398  immediate (label hash)
             1  json list       immediate or pointer (list)
             cost: 3 words per node, with headers
             not counted: field 1 (json list: 3 words per node)
    `Null  immediate 870828711
  
  type owned = { xs : float list; pt : (float * float) option; big : int64; name : string; }
  type owned  block, tag 0, size 4
      0  xs : float list              immediate or pointer (list)
      1  pt : (float * float) option  immediate or pointer (option)
      2  big : int64                  pointer to custom block, Custom_tag 255
      3  name : string                pointer to string, String_tag 252
      cost: 8 or 17 words per value, with headers
      not counted: xs (float list: 5 words per node), name (string)
  ### cases/sample.ml
  type shape = Point | Circle of float | Rect of { w : float; h : float }
  type shape  variant
    Point   immediate 0
    Circle  block, tag 0, size 1
              0  float  pointer to boxed float, Double_tag 253
              cost: 4 words per value, with headers
    Rect    block, tag 1, size 2
              0  w : float  pointer to boxed float, Double_tag 253
              1  h : float  pointer to boxed float, Double_tag 253
              cost: 7 words per value, with headers
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
      cost: 4 words per value, with headers
  
  type id = Id of int [@@unboxed]
  type id  variant
    Id  no block: [@@unboxed], the value is its field
          int  immediate (int)
          cost: 0 words, no blocks
  ### cases/values.ml
  closures in native code: Closure, without flambda
  
  fun arities.inc  line 8  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1, environment from field 2
      2  k : int  immediate (int)
  
  fun arities.add  line 9  Closure_tag 247, size 4
      0  code pointer: partial application
      1  closinfo: arity 2, environment from field 3
      2  code pointer: the function itself
      3  k : int  immediate (int)
  
  fun arities.add_pair  line 10  Closure_tag 247, size 4
      0  code pointer: takes the tuple apart
      1  closinfo: arity -2, environment from field 3
      2  code pointer: the function itself
      3  k : int  immediate (int)
  
  fun adder.(fun)  line 13  Closure_tag 247, size 4
      0  code pointer
      1  closinfo: arity 1, environment from field 2
      2  a : int  immediate (int)
      3  b : int  immediate (int)
  
  fun scaler.(fun)  line 14  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1, environment from field 2
      2  a : int  immediate (int)
  
  fun parity.even, parity.odd  line 17  one Closure_tag 247 block for 2 functions, size 6
      0  parity.even: code pointer
      1  parity.even: closinfo: arity 1, environment from field 5
      2  parity.odd: Infix_tag 249 header: a pointer to parity.odd points to the next field
      3  parity.odd: code pointer
      4  parity.odd: closinfo: arity 1, environment from field 5
      5  n : int  immediate (int)
  
  fun bumper.bump, bumper.bump_inner  line 21  one Closure_tag 247 block for 2 functions, size 8
      0  bumper.bump: code pointer: partial application
      1  bumper.bump: closinfo: arity 2, environment from field 7
      2  bumper.bump: code pointer: the function itself
      3  bumper.bump_inner: Infix_tag 249 header: a pointer to bumper.bump_inner points to the next field
      4  bumper.bump_inner: code pointer: partial application
      5  bumper.bump_inner: closinfo: arity 2, environment from field 7
      6  bumper.bump_inner: code pointer: the function itself
      7  k : int  immediate (int)
  
  type counter = { next : unit -> int; reset : unit -> unit }
  type counter  block, tag 0, size 2
      0  next : unit -> int    pointer to closure, Closure_tag 247
      1  reset : unit -> unit  pointer to closure, Closure_tag 247
      cost: 3 words per value, with headers
      not counted: next (closure), reset (closure)
  
  fun counter.(fun)  line 37  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1, environment from field 2
      2  n : int ref  pointer to record Stdlib.ref, tag 0
  
  fun counter.(fun)  line 40  Closure_tag 247, size 4
      0  code pointer
      1  closinfo: arity 1, environment from field 2
      2  start : int  immediate (int)
      3  n : int ref  pointer to record Stdlib.ref, tag 0
  
  fun lazies  line 44  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1, environment from field 2
      2  i : int  immediate (int)
  
  lazy 3  line 44  no block: the value itself, immediate (int)
  
  lazy 2.5  line 44  Forward_tag 250 block, size 1, holding the value: pointer to boxed float, Double_tag 253
  
  lazy i  line 44  no block: the value itself, immediate (int)
  
  lazy v  line 44  Forward_tag 250 block, size 1, holding the value: immediate or pointer (type variable)
  
  lazy (i + 1)  line 44  Lazy_tag 246 block, size 1, holding a closure; forcing it makes it a Forward_tag 250 block holding the result
  
  lazy (fun x -> x)  line 44  no block: the value itself, pointer to closure, Closure_tag 247
  
  class point  line 46  Object_tag 248, size 4
      0  method table   pointer to the class's method table
      1  object id      immediate (int)
      2  x : int        immediate (int)
      3  name : string  pointer to string, String_tag 252
  
  class labelled  line 52  Object_tag 248, size 5
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  k : int       immediate (int)  (parameter)
      3  s : string    pointer to string, String_tag 252  (parameter)
      4  v : int       immediate (int)
  
  class point3  line 59  Object_tag 248, size 6
      0  method table   pointer to the class's method table
      1  object id      immediate (int)
      2  z : int        immediate (int)
      3  w : string     pointer to string, String_tag 252
      4  x : int        immediate (int)  (from point)
      5  name : string  pointer to string, String_tag 252  (from point)
  
  object  line 68  Object_tag 248, size 4
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  environment   pointer to a block of the local variables the class uses, tag 0
      3  a : int       immediate (int)
  
  class c  line 75  Object_tag 248, size 6
      0  method table   pointer to the class's method table
      1  object id      immediate (int)
      2  environment    pointer to a block of the local variables the class uses, tag 0
      3  a : int        immediate (int)
      4  x : int        immediate (int)  (from point)
      5  name : string  pointer to string, String_tag 252  (from point)
  ### cases/variants.ml
  type t = A | B of int | C | D of string
  type t  variant
    A  immediate 0
    B  block, tag 0, size 1
         0  int  immediate (int)
         cost: 2 words per value, with headers
    C  immediate 1
    D  block, tag 1, size 1
         0  string  pointer to string, String_tag 252
         cost: 2 words per value, with headers
         not counted: field 0 (string)
  
  type nested = T of (int * int) | T2 of int * int
  type nested  variant
    T   block, tag 0, size 1
          0  int * int  pointer to tuple, tag 0
          cost: 5 words per value, with headers
    T2  block, tag 1, size 2
          0  int  immediate (int)
          1  int  immediate (int)
          cost: 3 words per value, with headers
  
  type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
  type 'a tree  variant
    Leaf  immediate 0
    Node  block, tag 0, size 3
            0  'a tree  immediate or pointer (tree)
            1  'a       immediate or pointer (type variable 'a)
            2  'a tree  immediate or pointer (tree)
            cost: 4 words per node, with headers
            not counted: field 1 ('a)
  
  type empty = |
  type empty  variant with no constructors: it has no values
  
  type _ expr = | Int : int -> int expr | Bool : bool -> bool expr | Hide : 'a * ('a -> string) -> string expr | Unit : unit expr
  type _ expr  variant
    Int   block, tag 0, size 1
            0  int  immediate (int)
            cost: 2 words per value, with headers
    Bool  block, tag 1, size 1
            0  bool  immediate (bool)
            cost: 2 words per value, with headers
    Hide  block, tag 2, size 2
            0  'a            immediate or pointer (type variable 'a)
            1  'a -> string  pointer to closure, Closure_tag 247
            cost: 3 words per value, with headers
            not counted: field 0 ('a), field 1 (closure)
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
      cost: 3 words per value, with headers
  
  type pair = { a : t; b : small }
  type pair  block, tag 0, size 2
      0  a : t      immediate or pointer (abstract type t)
      1  b : small  immediate (small [@@immediate])
      cost: 3 words per value, with headers
      not counted: a (abstract type t)
  
  (module CODEC)  structure block, tag 0, size 2
      0  val encode   pointer to closure, Closure_tag 247
      1  val default  immediate or pointer (abstract type v)
    no field: type v

A name filter matches the last component.

  $ lense-ocaml --type point --type SHAPE cases/records.ml cases/packages.ml
  == cases/records.ml
  
  type point  flat float block, Double_array_tag 254, size 2
      0  x : float          unboxed double
      1  mutable y : float  unboxed double
      cost: 3 words per value, with headers
  
  == cases/packages.ml
  
  (module Shapes.SHAPE)  structure block, tag 0, size 3
      0  val area       pointer to boxed float, Double_tag 253
      1  class drawing  pointer to class, tag 0
      2  functor Scale  pointer to closure, Closure_tag 247
