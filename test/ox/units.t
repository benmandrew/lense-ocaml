Each unit's types print with fresh names. The type printer remembers the
names it has given out; after the first file, which translates a class for
bytecode, the second file's rr7 printed as rr7/2.

  $ cat > a.ml <<'SRC'
  > class c (p : int list) = object method m = 0 end
  > type rr7 = { f8 : exn; mutable next9 : rr7 option }
  > type r = { f : rr7 }
  > let o () = object inherit c [] val v = 1 method n = 0 end
  > SRC
  $ cat > b.ml <<'SRC'
  > type rr7 = { f8 : int; mutable next9 : rr7 option }
  > let mk (c : rr7) = fun (x : int) -> ignore (Sys.opaque_identity c); x
  > SRC
  $ lense-ocaml --compiler ox --backend bytecode a.ml b.ml | grep 'c :'
      2  c : rr7  pointer to record rr7, tag 0
