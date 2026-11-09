type r = { a : int; b : float }
type point = { x : float; y : float }
type mpoint = { mutable mx : float; my : float }
type single_float = { f : float }
type wrapped = { u : string } [@@unboxed]
type id = Id of int [@@unboxed]
type fbox = { uf : float } [@@unboxed]
type poly = { apply : 'a. 'a -> 'a; n : int }
type 'a cell = { mutable contents : 'a; [@atomic] count : int }

type inline =
  | I0
  | I1 of int
  | I2 of { ix : int; iy : float }
  | I3 of { f1 : float; f2 : float }

type iu = IU of { iu : int } [@@unboxed]

type uses = {
  t : inline;
  ids : id list;
  arr : float array;
  iarr : int array;
  opt : int option;
  big : int64;
  ch : char;
  lz : int Lazy.t;
}
