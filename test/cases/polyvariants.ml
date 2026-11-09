type colour = [ `Red | `Green | `Blue ]
type event = [ `Key of char | `Click of int * int | `Quit ]
type 'a opened = 'a constraint 'a = [> `A | `B of int ]
type 'a sub = 'a constraint 'a = [< `A | `B of int ]
type both = [ colour | event ]
type nested = { c : colour; e : event }

let f = function `Foo -> 1 | `Bar n -> n
