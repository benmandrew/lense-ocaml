type t = A | B of int | C | D of string
type fr = { x : float; y : float }
type ir = I1 of int | I2 of { ix : int; iy : float }
let a = A let c = C let b n = B n let d s = D s
let f x y = { x; y }
let i n = I2 { ix = n; iy = 1. }
let p n = `Bar n
exception E of int
let e n = E n
