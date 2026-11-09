type t = A | B of int | C | D of string

type shape = Circle of float | Rect of float * float | Point

type nested = T of (int * int) | T2 of int * int

type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

type empty = |

type _ expr =
  | Int : int -> int expr
  | Bool : bool -> bool expr
  | Pair : 'a expr * 'b expr -> ('a * 'b) expr
  | Hide : 'a * ('a -> string) -> string expr
  | Unit : unit expr
