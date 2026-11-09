# Plan

Stages follow docs/DESIGN.md.

- [x] Stage 0: check the note's rules on OCaml 5.5 (`test/stage0.t`). One correction: 244 non-constant constructors, not 246.
- [x] Stage 1: variants, records, inline records, `[@@unboxed]`, polymorphic variants, GADTs, exceptions and extension constructors; `Obj` fuzz oracle on both backends.
- [x] Stage 2: structure blocks (field order, items without fields, functors) and signature coercions inside a file, including functor arguments.
- [x] Coercion of a compilation unit to its `.mli` (`Includemod.compunit`; `test/unit.t`).
- [x] Stage 3: OxCaml unboxed layouts and mixed blocks, with a byte map (`src/ox`, `test/ox/mixed.t`, mixed-block fuzzing).
- [ ] Share the code of `src/core` and `src/ox`, keeping only the compiler-specific parts apart.
- [ ] Stage 4: closures, objects and lazy values per compiler configuration (flambda changes closure shapes).
- [ ] Web front end through js_of_ocaml, reusing `src/model`.
- [ ] Nix flake, as in `../lense`.
