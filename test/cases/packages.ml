module type ORDERED = sig
  type t

  val name : string
  val compare : t -> t -> int
  external id : 'a -> 'a = "%identity"

  module Sub : sig
    val depth : int
  end

  exception Unordered
end

type entry = { key : int; ops : (module ORDERED with type t = int) }

(* Ints has more items than ORDERED, in another order. Packing it copies the
   items of ORDERED into a new block, in the order of ORDERED. *)
module Ints = struct
  exception Unordered

  type t = int

  let extra = 0.5
  let compare = Int.compare

  module Sub = struct
    let depth = 1
    let more = 2
  end

  external id : 'a -> 'a = "%identity"

  let name = "ints"
end

let entry = { key = 1; ops = (module Ints) }

module Shapes = struct
  module type SHAPE = sig
    val area : float

    class drawing : object
      method draw : unit
    end

    module Scale (_ : sig
      val k : float
    end) : sig
      val area : float
    end
  end
end

let unit_square =
  (module struct
    let area = 1.0

    class drawing =
      object
        method draw = ()
      end

    module Scale (X : sig
      val k : float
    end) =
    struct
      let area = X.k *. X.k
    end
  end : Shapes.SHAPE)

module type EMPTY = sig
  type t
end

let empty =
  (module struct
    type t = int
  end : EMPTY)

(* A function after the first of a recursive set is an Infix_tag pointer
   into the closure of the set, so odd is not a Closure_tag block. *)
module type PARITY = sig
  val even : int -> bool
  val odd : int -> bool
end

let parity =
  (module struct
    let rec even n = n = 0 || odd (n - 1)
    and odd n = n <> 0 && even (n - 1)
  end : PARITY)
