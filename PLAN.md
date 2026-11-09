# Plan

Stages follow docs/DESIGN.md.

- [x] Stage 0: check the note's rules on OCaml 5.5 (`test/stage0.t`). One correction: 244 non-constant constructors, not 246.
- [x] Stage 1: variants, records, inline records, `[@@unboxed]`, polymorphic variants, GADTs, exceptions and extension constructors; `Obj` fuzz oracle on both backends.
- [x] Stage 2: structure blocks (field order, items without fields, functors) and signature coercions inside a file, including functor arguments.
- [x] Coercion of a compilation unit to its `.mli` (`Includemod.compunit`; `test/unit.t`).
- [x] Stage 3: OxCaml unboxed layouts and mixed blocks, with a byte map (`src/core/compat_ox.ml`, `test/ox/mixed.t`, mixed-block fuzzing).
- [x] Share `src/core` between the two compilers; only `compat_55.ml` and `compat_ox.ml` differ.
- [x] Stage 4: closures, objects and lazy values per backend, behind `--values` (`src/core/values.ml`, `test/values.t`, fuzzed on both switches). Native closures under flambda are reported as not predicted.
- [x] Web front end through js_of_ocaml, reusing `src/model` (`web/`, `web/jsoo/lense_web.ml`). Needs js_of_ocaml from master: 6.5.0 does not support OCaml 5.5.
- [x] Nix flake, as in `../lense`: `nix build` (tool and tests), `.#web-js`, `.#web`, and a dev shell.
