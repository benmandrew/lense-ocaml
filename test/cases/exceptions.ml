exception Empty
exception Error of int * string
exception Detail of { code : int; msg : string }
exception Again = Empty

type ext = ..
type ext += X1 | X2 of int

(* Effects are extension constructors of the extensible GADT Effect.t. *)
type _ Effect.t += Ask : int Effect.t | Tell : string -> unit Effect.t
