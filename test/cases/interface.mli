(* An interface: an abstract type shows only what its declaration promises. *)
type t
type small [@@immediate]
type id = private int
type pos = private { x : float; y : float }
type pair = { a : t; b : small }

module type CODEC = sig
  type v
  val encode : v -> string
  val default : v
end

val codec : (module CODEC with type v = pos)
