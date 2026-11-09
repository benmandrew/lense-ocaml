let answer = 42
let greet name = "hello " ^ name
external identity : 'a -> 'a = "%identity"
type t = int
exception Stop

module Inner = struct
  type point = { x : float; y : float }
  let origin = { x = 0.; y = 0. }
  let norm p = sqrt ((p.x *. p.x) +. (p.y *. p.y))
end

module type S = sig
  val greet : string -> string
  val answer : int
end

module Reordered : S = struct
  let answer = 1
  let unused = "dropped"
  let greet s = s
end

module Same : sig val a : int val b : int end = struct
  let a = 1
  let b = 2
end

module type ORD = sig type t val compare : t -> t -> int end

module Make (O : ORD) = struct
  let max a b = if O.compare a b >= 0 then a else b
  let min a b = if O.compare a b <= 0 then a else b
end

module IntOrd = struct
  type t = int
  let compare = Int.compare
  let extra = ()
end

module M = Make (IntOrd)

module Prim : sig val id : 'a -> 'a end = struct
  external id : 'a -> 'a = "%identity"
end

class counter = object
  val mutable n = 0
  method incr = n <- n + 1
end
