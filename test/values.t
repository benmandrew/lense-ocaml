The report shows the closures, lazy values and objects a unit allocates,
in source order with the types. Each one starts with the line that
allocates it. A closure made outside every function, such as succ, is one
block for the whole program and is not shown. Closures differ between
ocamlopt and ocamlc: --backend picks which one to show, native code by
default, and the first paragraph says how that backend was built.

  $ lense-ocaml cases/values.ml
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
  
  type counter  block, tag 0, size 2
      0  next : unit -> int    pointer to closure, Closure_tag 247 or Infix_tag 249
      1  reset : unit -> unit  pointer to closure, Closure_tag 247 or Infix_tag 249
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
  
  lazy (fun x -> x)  line 44  no block: the value itself, pointer to closure, Closure_tag 247 or Infix_tag 249
  
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

--backend bytecode shows the closures ocamlc allocates instead.

  $ lense-ocaml --backend bytecode cases/values.ml | sed -n '/^closures in/p;/^fun /,/^$/p'
  closures in bytecode: ocamlc without -g
  fun arities.inc  line 8  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  k : int  immediate (int)
  
  fun arities.add  line 9  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  k : int  immediate (int)
  
  fun arities.add_pair  line 10  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  k : int  immediate (int)
  
  fun adder.(fun)  line 13  Closure_tag 247, size 4
      0  code pointer
      1  closinfo: environment from field 2
      2  a : int  immediate (int)
      3  b : int  immediate (int)
  
  fun scaler.(fun)  line 14  Closure_tag 247, size 4
      0  code pointer
      1  closinfo: environment from field 2
      2  scale : int  immediate (int)
      3  a : int      immediate (int)
  
  fun parity.even, parity.odd  line 17  one Closure_tag 247 block for 2 functions, size 6
      0  parity.even: code pointer
      1  parity.even: closinfo: environment from field 5
      2  parity.odd: Infix_tag 249 header: a pointer to parity.odd points to the next field
      3  parity.odd: code pointer
      4  parity.odd: closinfo: environment from field 5
      5  n : int  immediate (int)
  
  fun bumper.bump  line 21  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  k : int  immediate (int)
  
  fun known.g  line 27  Closure_tag 247, size 2, arity 1, no environment
  
  fun known.(fun)  line 28  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  k : int  immediate (int)
  
  fun known.(fun)  line 28  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  g : int -> int  pointer to closure, Closure_tag 247 or Infix_tag 249
  
  fun counter.(fun)  line 37  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  n : int ref  pointer to record Stdlib.ref, tag 0
  
  fun counter.(fun)  line 40  Closure_tag 247, size 4
      0  code pointer
      1  closinfo: environment from field 2
      2  start : int  immediate (int)
      3  n : int ref  pointer to record Stdlib.ref, tag 0
  
  fun lazies  line 44  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: environment from field 2
      2  i : int  immediate (int)
  
  fun lazies.(fun)  line 44  Closure_tag 247, size 2, arity 1, no environment
  

--backend both shows each closure once. Where the two backends lay a block
out differently, it shows each layout under the backend's name.

  $ lense-ocaml --backend both cases/values.ml | sed -n '/^closures in/p;/^fun /,/^$/p'
  closures in native code: Closure, without flambda
  closures in bytecode: ocamlc without -g
  fun arities.inc  line 8  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1 in native code, 0 in bytecode, environment from field 2
      2  k : int  immediate (int)
  
  fun arities.add  line 9  Closure_tag 247, size 4 in native code, 3 in bytecode
      native code: Closure_tag 247, size 4
        0  code pointer: partial application
        1  closinfo: arity 2, environment from field 3
        2  code pointer: the function itself
        3  k : int  immediate (int)
      bytecode: Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  k : int  immediate (int)
  
  fun arities.add_pair  line 10  Closure_tag 247, size 4 in native code, 3 in bytecode
      native code: Closure_tag 247, size 4
        0  code pointer: takes the tuple apart
        1  closinfo: arity -2, environment from field 3
        2  code pointer: the function itself
        3  k : int  immediate (int)
      bytecode: Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  k : int  immediate (int)
  
  fun adder.(fun)  line 13  Closure_tag 247, size 4
      0  code pointer
      1  closinfo: arity 1 in native code, 0 in bytecode, environment from field 2
      2  a : int  immediate (int)
      3  b : int  immediate (int)
  
  fun scaler.(fun)  line 14  Closure_tag 247, size 3 in native code, 4 in bytecode
      native code: Closure_tag 247, size 3
        0  code pointer
        1  closinfo: arity 1, environment from field 2
        2  a : int  immediate (int)
      bytecode: Closure_tag 247, size 4
        0  code pointer
        1  closinfo: environment from field 2
        2  scale : int  immediate (int)
        3  a : int      immediate (int)
  
  fun parity.even, parity.odd  line 17  one Closure_tag 247 block for 2 functions, size 6
      0  parity.even: code pointer
      1  parity.even: closinfo: arity 1 in native code, 0 in bytecode, environment from field 5
      2  parity.odd: Infix_tag 249 header: a pointer to parity.odd points to the next field
      3  parity.odd: code pointer
      4  parity.odd: closinfo: arity 1 in native code, 0 in bytecode, environment from field 5
      5  n : int  immediate (int)
  
  fun bumper.bump, bumper.bump_inner  line 21  Closure_tag 247, size 8 in native code, 3 in bytecode
      native code: one Closure_tag 247 block for 2 functions, size 8
        0  bumper.bump: code pointer: partial application
        1  bumper.bump: closinfo: arity 2, environment from field 7
        2  bumper.bump: code pointer: the function itself
        3  bumper.bump_inner: Infix_tag 249 header: a pointer to bumper.bump_inner points to the next field
        4  bumper.bump_inner: code pointer: partial application
        5  bumper.bump_inner: closinfo: arity 2, environment from field 7
        6  bumper.bump_inner: code pointer: the function itself
        7  k : int  immediate (int)
      bytecode: Closure_tag 247, size 3
        0  code pointer
        1  closinfo: environment from field 2
        2  k : int  immediate (int)
  
  fun known.g  line 27  Closure_tag 247, size 2, arity 1, no environment  (bytecode only)
  
  fun known.(fun)  line 28  Closure_tag 247, size 3  (bytecode only)
      0  code pointer
      1  closinfo: environment from field 2
      2  k : int  immediate (int)
  
  fun known.(fun)  line 28  Closure_tag 247, size 3  (bytecode only)
      0  code pointer
      1  closinfo: environment from field 2
      2  g : int -> int  pointer to closure, Closure_tag 247 or Infix_tag 249
  
  fun counter.(fun)  line 37  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1 in native code, 0 in bytecode, environment from field 2
      2  n : int ref  pointer to record Stdlib.ref, tag 0
  
  fun counter.(fun)  line 40  Closure_tag 247, size 4
      0  code pointer
      1  closinfo: arity 1 in native code, 0 in bytecode, environment from field 2
      2  start : int  immediate (int)
      3  n : int ref  pointer to record Stdlib.ref, tag 0
  
  fun lazies  line 44  Closure_tag 247, size 3
      0  code pointer
      1  closinfo: arity 1 in native code, 0 in bytecode, environment from field 2
      2  i : int  immediate (int)
  
  fun lazies.(fun)  line 44  Closure_tag 247, size 2, arity 1, no environment  (bytecode only)
  

--no-values leaves them out.

  $ lense-ocaml --no-values cases/values.ml
  type counter  block, tag 0, size 2
      0  next : unit -> int    pointer to closure, Closure_tag 247 or Infix_tag 249
      1  reset : unit -> unit  pointer to closure, Closure_tag 247 or Infix_tag 249
      cost: 3 words per value, with headers
      not counted: next (closure), reset (closure)
