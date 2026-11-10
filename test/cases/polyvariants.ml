type colour = [ `Red | `Green | `Blue ]
type event = [ `Key of char | `Click of int * int | `Quit ]
type 'a opened = 'a constraint 'a = [> `A | `B of int ]
type nested = { c : colour; e : event }

(* These two labels have the same hash, so no one type can hold both. *)
type one = [ `Eric_Cooper ]
type other = [ `azdwbie of int ]

let f = function `Foo -> 1 | `Bar n -> n
