(* OxCaml layouts: mixed blocks, all-flat records and unboxed products. *)
type m = { a : int; b : float#; c : string; d : int32#; f : int8# }
type u = { x : float#; y : float# }
type fm = { p : float; q : float# }
type pr = #{ px : int; py : float# }
type withp = { w0 : string; w1 : pr; w2 : int64#; w3 : #(int8# * string) }
type v = A of string * #(float# * int) | B of int | C of { s : string; t : float32#; n : int }
type t : float64
type i : immediate
type i64 : immediate64
type al = int32#
type o = int or_null
type one = #{ one : #(float# * string) }
type sv = #{ sv : string }
type wone = { o1 : one; o2 : #(int * sv); o3 : sv }
