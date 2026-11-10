(* Edit the code: the representations update as you type. *)
type shape = Point | Circle of float | Rect of { w : float; h : float }
type colour = Red | Green | Blue
type vec = { x : float; y : float; z : float }
type id = Id of int [@@unboxed]

let area = function
  | Point -> 0.
  | Circle r -> 3.14159 *. r *. r
  | Rect { w; h } -> w *. h
