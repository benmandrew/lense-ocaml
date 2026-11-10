(* Prints the shape of each value as the runtime sees it. Closure sizes
   and code pointers depend on the backend, so closures print as tags only. *)
let show name v =
  let r = Obj.repr v in
  let one f =
    if Obj.is_int f then Printf.sprintf "[imm %d]" (Obj.obj f : int)
    else if Obj.tag f = Obj.closure_tag then "[closure]"
    else Printf.sprintf "[blk tag %d size %d]" (Obj.tag f) (Obj.size f)
  in
  if Obj.is_int r then Printf.printf "%-28s imm %d\n" name (Obj.obj r : int)
  else if Obj.tag r = Obj.closure_tag then
    Printf.printf "%-28s closure, tag %d\n" name (Obj.tag r)
  else begin
    Printf.printf "%-28s block tag %d size %d" name (Obj.tag r) (Obj.size r);
    if Obj.tag r < Obj.no_scan_tag then
      for i = 0 to Obj.size r - 1 do
        print_string (" " ^ one (Obj.field r i))
      done;
    print_newline ()
  end

type t = A | B of int | C | D of string

let () =
  show "A" A;
  show "B" (B 1);
  show "C" C;
  show "D" (D "x")

type g = G1 : int -> g | G2 : 'a * ('a -> int) -> g | G3 : g

let () =
  show "G1" (G1 1);
  show "G2" (G2 (1, fun x -> x));
  show "G3" G3

type r = { a : int; b : float }
type fr = { x : float; y : float }
type mfr = { mutable mx : float; my : float }

let () =
  show "r" { a = 1; b = 2. };
  show "fr" { x = 1.; y = 2. };
  show "mfr" { mx = 1.; my = 2. }

type u = { u : string } [@@unboxed]
type u2 = U of int [@@unboxed]
type u3 = { uf : float } [@@unboxed]

let () =
  show "u" { u = "s" };
  show "u2" (U 5);
  show "u3" { uf = 1.5 }

type ir =
  | I0
  | I1 of int
  | I2 of { ix : int; iy : float }
  | I3 of { f1 : float; f2 : float }

let () =
  show "I2" (I2 { ix = 1; iy = 2. });
  show "I3" (I3 { f1 = 1.; f2 = 2. })

type iu = IU of { iu : int } [@@unboxed]

let () = show "IU" (IU { iu = 3 })

let () =
  show "`Foo" `Foo;
  show "`Bar 1" (`Bar 1);
  show "`Baz (1,2)" (`Baz (1, 2));
  show "`Q ((1,2))" (`Q (1, 2))

exception E1
exception E2 of int * string

type ext = ..
type ext += X1 | X2 of int

let () =
  show "E1" E1;
  show "E2" (E2 (1, "a"));
  show "X1" X1;
  show "X2" (X2 1)

let () =
  let r = Obj.repr (E2 (1, "a")) in
  Printf.printf "E2 field0 tag %d\n" (Obj.tag (Obj.field r 0))

type tup = T of (int * int) | T2 of int * int

let () =
  show "T" (T (1, 2));
  show "T2" (T2 (1, 2))

let () =
  show "float" 1.5;
  show "[|1.;2.|]" [| 1.; 2. |];
  show "int32" 1l;
  show "lazy" (lazy (print_int 1))

let () =
  show "unit" ();
  show "true" true;
  show "[]" [];
  show "[1]" [ 1 ];
  show "None" None;
  show "Some 1" (Some 1);
  show "'a'" 'a'

let () =
  let r = Obj.repr E1 in
  Printf.printf "E1 slot: name %S, id is an immediate: %b\n"
    (Obj.obj (Obj.field r 0) : string)
    (Obj.is_int (Obj.field r 1))

let () = show "closure" (fun x -> x + 1)

class counter =
  object
    val mutable n = 0
    method incr = n <- n + 1
  end

module Mod = struct
  let a = 1
  let f x = x

  type t = int

  exception Q

  module N = struct
    let z = 2
  end

  class c = counter
end

module type MS = module type of Mod

let () =
  let m = Obj.repr (module Mod : MS) in
  show "module Mod" m;
  show "Mod.c (a class)" (Obj.field m 4)
