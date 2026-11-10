type node = { v : int; mutable next : node option }
type cell = Nil | Cons of { v : int; mutable next : cell }
type expr = Num of float | Add of expr * expr | Neg of expr
type forest = Tree of int * forest list

type even = Zero | Succ of odd
and odd = { pred : even }

type 'a seq = Seq of ('a * 'a seq) option [@@unboxed]
type json = [ `Null | `Num of float | `List of json list ]

type owned = {
  xs : float list;
  pt : (float * float) option;
  big : int64;
  name : string;
}
