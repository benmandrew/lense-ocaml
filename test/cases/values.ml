(* Closures, lazy values and objects, shown with "closures, lazy values and objects". *)
let scale = 3
let succ x = x + 1
let add x y = x + y
let add_pair (x, y) = x + y
let adder a b = fun x -> x + a + b
let scaler a = fun x -> x * a * scale

let parity n =
  let rec even x = x = n || odd (x - 1) and odd x = x <> n && even (x - 1) in
  (even, odd)

let bump ?(by = 1) x = x + by

(* Two closures that capture the same variable each have their own environment. *)
type counter = { next : unit -> int; reset : unit -> unit }

let counter start =
  let n = ref start in
  {
    next =
      (fun () ->
        incr n;
        !n);
    reset = (fun () -> n := start);
  }

let lazies i v = (lazy 3, lazy 2.5, lazy i, lazy v, lazy (i + 1), lazy (fun x -> x))

class point =
  object
    val x = 1
    val name = "p"
  end

class labelled (k : int) (s : string) =
  object
    val v = 3
    method m = k + v
    method n = s
  end

class point3 =
  object
    val z = 1
    inherit point
    val w = "w"
    val! x = 5
  end

let obj (k : string) =
  object
    val a = 1
    method m = k
  end

let local (k : string) =
  let module X = struct
    class c =
      object
        inherit point
        val a = 1
        method m = k
      end
  end in
  new X.c
