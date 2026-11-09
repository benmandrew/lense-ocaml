With --values, lense also prints the closures, lazy values and objects a unit
allocates. Closures differ between ocamlopt and ocamlc, so each backend has
its own section.

  $ cat > v.ml <<'SRC'
  > let c3 = 3
  > let f1 x = x + 1
  > let f2 x y = x + y
  > let tup (a, b) = a + b
  > let mk b a = fun x -> x + a + b
  > let mku a = fun x -> x + a + c3
  > let mkrec n = let rec ev x = x = n || od (x - 1) and od x = x <> n && ev (x - 1) in (ev, od)
  > let opt ?(x = 1) y = x + y
  > let lz i fl s = (lazy 3, lazy "s", lazy 2.5, lazy i, lazy fl, lazy s, lazy (i + 1), lazy (fun x -> x))
  > class p = object val pa = 1 val pb = "pb" end
  > class kp (cx : int) (cy : string) = object val v = 3 method m = cx + v method n = cy end
  > class ch = object val c1 = 1 inherit p val c2 = "c2" val! pa = 5 end
  > let mko (k : string) = object val a = 1 method m = k end
  > let mkcp (k : string) = let module X = struct class c = object inherit p val a = 1 method m = k end end in new X.c
  > SRC
  $ lense-ocaml --values v.ml
  module V  structure block, tag 0, size 14
       0  val c3     immediate (int)
       1  val f1     pointer to closure, Closure_tag 247
       2  val f2     pointer to closure, Closure_tag 247
       3  val tup    pointer to closure, Closure_tag 247
       4  val mk     pointer to closure, Closure_tag 247
       5  val mku    pointer to closure, Closure_tag 247
       6  val mkrec  pointer to closure, Closure_tag 247
       7  val opt    pointer to closure, Closure_tag 247
       8  val lz     pointer to closure, Closure_tag 247
       9  class p    pointer to class, tag 0
      10  class kp   pointer to class, tag 0
      11  class ch   pointer to class, tag 0
      12  val mko    pointer to closure, Closure_tag 247
      13  val mkcp   pointer to closure, Closure_tag 247
  
  closures in native code (Closure, without flambda)
    f1  line 2  Closure_tag 247, size 2, arity 1, no environment
    f2  line 3  Closure_tag 247, size 3, arity 2, no environment
    tup  line 4  Closure_tag 247, size 3, arity 2 (tupled), no environment
    mk  line 5  Closure_tag 247, size 3, arity 2, no environment
    mk.(fun)  line 5  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  b : int  immediate (int)
        3  a : int  immediate (int)
    mku  line 6  Closure_tag 247, size 2, arity 1, no environment
    mku.(fun)  line 6  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  a : int  immediate (int)
    mkrec  line 7  Closure_tag 247, size 2, arity 1, no environment
    mkrec.ev, mkrec.od  line 7  one Closure_tag 247 block for 2 functions, size 6
        0  mkrec.ev: code pointer
        1  mkrec.ev: closinfo: arity 1, environment from field 5
        2  mkrec.od: Infix_tag 249 header: a pointer to mkrec.od points to the next field
        3  mkrec.od: code pointer
        4  mkrec.od: closinfo: arity 1, environment from field 5
        5  n : int  immediate (int)
    opt, opt_inner  line 8  one Closure_tag 247 block for 2 functions, size 7
        0  opt: code pointer: partial application
        1  opt: closinfo: arity 2, environment from field 7
        2  opt: code pointer: the function itself
        3  opt_inner: Infix_tag 249 header: a pointer to opt_inner points to the next field
        4  opt_inner: code pointer: partial application
        5  opt_inner: closinfo: arity 2, environment from field 7
        6  opt_inner: code pointer: the function itself
    lz  line 9  Closure_tag 247, size 3, arity 3, no environment
    lz  line 9  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  i : int  immediate (int)
    lz.(fun)  line 9  Closure_tag 247, size 2, arity 1, no environment
    mko  line 13  Closure_tag 247, size 5
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  object_tables  immediate or pointer (a variable the compiler introduced)
        3  shared         immediate or pointer (a variable the compiler introduced)
        4  shared         immediate or pointer (a variable the compiler introduced)
    mkcp  line 14  Closure_tag 247, size 6
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  shared    immediate or pointer (a variable the compiler introduced)
        3  shared    immediate or pointer (a variable the compiler introduced)
        4  shared    immediate or pointer (a variable the compiler introduced)
        5  c_tables  immediate or pointer (a variable the compiler introduced)
  
  closures in bytecode (ocamlc without -g)
    f1  line 2  Closure_tag 247, size 2, arity 1, no environment
    f2  line 3  Closure_tag 247, size 2, arity 2, no environment
    tup  line 4  Closure_tag 247, size 2, arity 1, no environment
    mk  line 5  Closure_tag 247, size 2, arity 2, no environment
    mk.(fun)  line 5  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: environment from field 2
        2  b : int  immediate (int)
        3  a : int  immediate (int)
    mku  line 6  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  c3 : int  immediate (int)
    mku.(fun)  line 6  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: environment from field 2
        2  c3 : int  immediate (int)
        3  a : int   immediate (int)
    mkrec  line 7  Closure_tag 247, size 2, arity 1, no environment
    mkrec.ev, mkrec.od  line 7  one Closure_tag 247 block for 2 functions, size 6
        0  mkrec.ev: code pointer
        1  mkrec.ev: closinfo: environment from field 5
        2  mkrec.od: Infix_tag 249 header: a pointer to mkrec.od points to the next field
        3  mkrec.od: code pointer
        4  mkrec.od: closinfo: environment from field 5
        5  n : int  immediate (int)
    opt  line 8  Closure_tag 247, size 2, arity 2, no environment
    lz  line 9  Closure_tag 247, size 2, arity 3, no environment
    lz  line 9  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  i : int  immediate (int)
    lz.(fun)  line 9  Closure_tag 247, size 2, arity 1, no environment
    mko  line 13  Closure_tag 247, size 5
        0  code pointer
        1  closinfo: environment from field 2
        2  object_tables  immediate or pointer (a variable the compiler introduced)
        3  shared         immediate or pointer (a variable the compiler introduced)
        4  shared         immediate or pointer (a variable the compiler introduced)
    mkcp  line 14  Closure_tag 247, size 7
        0  code pointer
        1  closinfo: environment from field 2
        2  p         immediate or pointer (a variable the compiler introduced)
        3  shared    immediate or pointer (a variable the compiler introduced)
        4  shared    immediate or pointer (a variable the compiler introduced)
        5  shared    immediate or pointer (a variable the compiler introduced)
        6  c_tables  immediate or pointer (a variable the compiler introduced)
  
  lazy values
    lazy 3  line 9  no block: the value itself, immediate (int)
    lazy "s"  line 9  no block: the value itself, pointer to string, String_tag 252
    lazy 2.5  line 9  Forward_tag 250 block, size 1, holding the value: pointer to boxed float, Double_tag 253
    lazy i  line 9  no block: the value itself, immediate (int)
    lazy fl  line 9  Forward_tag 250 block, size 1, holding the value: immediate or pointer (type variable)
    lazy s  line 9  Forward_tag 250 block, size 1, holding the value: immediate or pointer (type variable)
    lazy (i + 1)  line 9  Lazy_tag 246 block, size 1, holding a closure; forcing it makes it a Forward_tag 250 block holding the result
    lazy (fun x -> x)  line 9  no block: the value itself, pointer to closure, Closure_tag 247
  
  class p  line 10  Object_tag 248, size 4
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  pa : int      immediate (int)
      3  pb : string   pointer to string, String_tag 252
  
  class kp  line 11  Object_tag 248, size 5
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  cx : int      immediate (int)  (parameter)
      3  cy : string   pointer to string, String_tag 252  (parameter)
      4  v : int       immediate (int)
  
  class ch  line 12  Object_tag 248, size 6
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  c1 : int      immediate (int)
      3  c2 : string   pointer to string, String_tag 252
      4  pa : int      immediate (int)  (from p)
      5  pb : string   pointer to string, String_tag 252  (from p)
  
  object  line 13  Object_tag 248, size 4
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  environment   pointer to a block of the local variables the class uses, tag 0
      3  a : int       immediate (int)
  
  class c  line 14  Object_tag 248, size 6
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  environment   pointer to a block of the local variables the class uses, tag 0
      3  a : int       immediate (int)
      4  pa : int      immediate (int)  (from p)
      5  pb : string   pointer to string, String_tag 252  (from p)
