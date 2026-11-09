exception Empty
exception Error of int * string
exception Detail of { code : int; msg : string }
exception Again = Empty

type ext = ..
type ext += X1 | X2 of int | X3 of float
type ext += X4 of { r : float }

type 'a res = ..
type 'a res += Ok_ of 'a
