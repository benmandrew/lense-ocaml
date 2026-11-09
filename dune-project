(lang dune 3.17)
(name lense-ocaml)
(cram enable)
(generate_opam_files true)

(package
 (name lense-ocaml)
 (synopsis "Show how OCaml types are represented at runtime")
 (description
  "lense-ocaml reads type declarations through compiler-libs and prints which constructors become immediates, which tag each block gets, when the compiler drops the block, and how modules are laid out.")
 ; compiler-libs changes between releases; the tool is pinned to one.
 (depends
  (ocaml (and (>= 5.5.0) (< 5.6.0)))
  dune))
