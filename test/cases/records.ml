type r = { a : int; b : float }
type point = { x : float; mutable y : float }
type fbox = { f : float } [@@unboxed]
type id = Id of int [@@unboxed]
type iu = IU of { iu : int } [@@unboxed]

(* A float behind an alias or [@@unboxed] still makes a flat record. A float
   behind an abstract type does not. *)
type metres = float

module Opaque : sig
  type t
end = struct
  type t = float
end

type seen = { m : metres; fb : fbox }
type hidden = { o : Opaque.t; h : float }

type inline =
  | I0
  | I1 of int
  | I2 of { ix : int; iy : float }
  | I3 of { f1 : float; f2 : float }

type uses = {
  t : inline;
  ids : id list;
  arr : float array;
  iarr : int array;
  opt : int option;
  big : int64;
  ch : char;
  lz : int Lazy.t;
  apply : 'a. 'a -> 'a;
}
