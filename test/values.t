With --values, lense also prints the closures, lazy values and objects a unit
allocates. Closures differ between ocamlopt and ocamlc, so each backend has
its own section.

  $ lense-ocaml --values cases/values.ml
  type counter  block, tag 0, size 2
      0  next : unit -> int    pointer to closure, Closure_tag 247
      1  reset : unit -> unit  pointer to closure, Closure_tag 247
  
  closures in native code (Closure, without flambda)
    succ  line 3  Closure_tag 247, size 2, arity 1, no environment
    add  line 4  Closure_tag 247, size 3, arity 2, no environment
    add_pair  line 5  Closure_tag 247, size 3, arity 2 (tupled), no environment
    adder  line 6  Closure_tag 247, size 3, arity 2, no environment
    adder.(fun)  line 6  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  a : int  immediate (int)
        3  b : int  immediate (int)
    scaler  line 7  Closure_tag 247, size 2, arity 1, no environment
    scaler.(fun)  line 7  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  a : int  immediate (int)
    parity  line 9  Closure_tag 247, size 2, arity 1, no environment
    parity.even, parity.odd  line 10  one Closure_tag 247 block for 2 functions, size 6
        0  parity.even: code pointer
        1  parity.even: closinfo: arity 1, environment from field 5
        2  parity.odd: Infix_tag 249 header: a pointer to parity.odd points to the next field
        3  parity.odd: code pointer
        4  parity.odd: closinfo: arity 1, environment from field 5
        5  n : int  immediate (int)
    bump, bump_inner  line 13  one Closure_tag 247 block for 2 functions, size 7
        0  bump: code pointer: partial application
        1  bump: closinfo: arity 2, environment from field 7
        2  bump: code pointer: the function itself
        3  bump_inner: Infix_tag 249 header: a pointer to bump_inner points to the next field
        4  bump_inner: code pointer: partial application
        5  bump_inner: closinfo: arity 2, environment from field 7
        6  bump_inner: code pointer: the function itself
    counter  line 18  Closure_tag 247, size 2, arity 1, no environment
    counter.(fun)  line 22  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  n : int ref  pointer to record Stdlib.ref, tag 0
    counter.(fun)  line 25  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  start : int  immediate (int)
        3  n : int ref  pointer to record Stdlib.ref, tag 0
    lazies  line 28  Closure_tag 247, size 3, arity 2, no environment
    lazies  line 28  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  i : int  immediate (int)
    lazies.(fun)  line 28  Closure_tag 247, size 2, arity 1, no environment
    obj  line 51  Closure_tag 247, size 5
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  object_tables  immediate or pointer (a variable the compiler introduced)
        3  shared         immediate or pointer (a variable the compiler introduced)
        4  shared         immediate or pointer (a variable the compiler introduced)
    local  line 57  Closure_tag 247, size 6
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  shared    immediate or pointer (a variable the compiler introduced)
        3  shared    immediate or pointer (a variable the compiler introduced)
        4  shared    immediate or pointer (a variable the compiler introduced)
        5  c_tables  immediate or pointer (a variable the compiler introduced)
  
  closures in bytecode (ocamlc without -g)
    succ  line 3  Closure_tag 247, size 2, arity 1, no environment
    add  line 4  Closure_tag 247, size 2, arity 2, no environment
    add_pair  line 5  Closure_tag 247, size 2, arity 1, no environment
    adder  line 6  Closure_tag 247, size 2, arity 2, no environment
    adder.(fun)  line 6  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: environment from field 2
        2  a : int  immediate (int)
        3  b : int  immediate (int)
    scaler  line 7  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  scale : int  immediate (int)
    scaler.(fun)  line 7  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: environment from field 2
        2  scale : int  immediate (int)
        3  a : int      immediate (int)
    parity  line 9  Closure_tag 247, size 2, arity 1, no environment
    parity.even, parity.odd  line 10  one Closure_tag 247 block for 2 functions, size 6
        0  parity.even: code pointer
        1  parity.even: closinfo: environment from field 5
        2  parity.odd: Infix_tag 249 header: a pointer to parity.odd points to the next field
        3  parity.odd: code pointer
        4  parity.odd: closinfo: environment from field 5
        5  n : int  immediate (int)
    bump  line 13  Closure_tag 247, size 2, arity 2, no environment
    counter  line 18  Closure_tag 247, size 2, arity 1, no environment
    counter.(fun)  line 22  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  n : int ref  pointer to record Stdlib.ref, tag 0
    counter.(fun)  line 25  Closure_tag 247, size 4
        0  code pointer
        1  closinfo: environment from field 2
        2  start : int  immediate (int)
        3  n : int ref  pointer to record Stdlib.ref, tag 0
    lazies  line 28  Closure_tag 247, size 2, arity 2, no environment
    lazies  line 28  Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  i : int  immediate (int)
    lazies.(fun)  line 28  Closure_tag 247, size 2, arity 1, no environment
    obj  line 51  Closure_tag 247, size 5
        0  code pointer
        1  closinfo: environment from field 2
        2  object_tables  immediate or pointer (a variable the compiler introduced)
        3  shared         immediate or pointer (a variable the compiler introduced)
        4  shared         immediate or pointer (a variable the compiler introduced)
    local  line 57  Closure_tag 247, size 7
        0  code pointer
        1  closinfo: environment from field 2
        2  point     immediate or pointer (a variable the compiler introduced)
        3  shared    immediate or pointer (a variable the compiler introduced)
        4  shared    immediate or pointer (a variable the compiler introduced)
        5  shared    immediate or pointer (a variable the compiler introduced)
        6  c_tables  immediate or pointer (a variable the compiler introduced)
  
  lazy values
    lazy 3  line 28  no block: the value itself, immediate (int)
    lazy 2.5  line 28  Forward_tag 250 block, size 1, holding the value: pointer to boxed float, Double_tag 253
    lazy i  line 28  no block: the value itself, immediate (int)
    lazy v  line 28  Forward_tag 250 block, size 1, holding the value: immediate or pointer (type variable)
    lazy (i + 1)  line 28  Lazy_tag 246 block, size 1, holding a closure; forcing it makes it a Forward_tag 250 block holding the result
    lazy (fun x -> x)  line 28  no block: the value itself, pointer to closure, Closure_tag 247
  
  class point  line 30  Object_tag 248, size 4
      0  method table   pointer to the class's method table
      1  object id      immediate (int)
      2  x : int        immediate (int)
      3  name : string  pointer to string, String_tag 252
  
  class labelled  line 36  Object_tag 248, size 5
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  k : int       immediate (int)  (parameter)
      3  s : string    pointer to string, String_tag 252  (parameter)
      4  v : int       immediate (int)
  
  class point3  line 43  Object_tag 248, size 6
      0  method table   pointer to the class's method table
      1  object id      immediate (int)
      2  z : int        immediate (int)
      3  w : string     pointer to string, String_tag 252
      4  x : int        immediate (int)  (from point)
      5  name : string  pointer to string, String_tag 252  (from point)
  
  object  line 52  Object_tag 248, size 4
      0  method table  pointer to the class's method table
      1  object id     immediate (int)
      2  environment   pointer to a block of the local variables the class uses, tag 0
      3  a : int       immediate (int)
  
  class c  line 59  Object_tag 248, size 6
      0  method table   pointer to the class's method table
      1  object id      immediate (int)
      2  environment    pointer to a block of the local variables the class uses, tag 0
      3  a : int        immediate (int)
      4  x : int        immediate (int)  (from point)
      5  name : string  pointer to string, String_tag 252  (from point)
