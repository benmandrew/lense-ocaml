module type ORDERED = sig
  type t
  val name : string
  val compare : t -> t -> int
  external id : 'a -> 'a = "%identity"
  module Sub : sig val depth : int end
  exception Unordered
end

type entry = { key : int; ops : (module ORDERED with type t = int) }

module Ints = struct
  exception Unordered
  type t = int
  let extra = 0.5
  let compare = Int.compare
  module Sub = struct let depth = 1 let more = 2 end
  external id : 'a -> 'a = "%identity"
  let name = "ints"
end

let entry = { key = 1; ops = (module Ints) }

module Shapes = struct
  module type SHAPE = sig
    val area : float
    module Scale (_ : sig val k : float end) : sig val area : float end
  end
end

let unit_square =
  (module struct
    let area = 1.0
    module Scale (X : sig val k : float end) = struct let area = X.k *. X.k end
  end : Shapes.SHAPE)

module type EMPTY = sig type t end

let empty = (module struct type t = int end : EMPTY)
