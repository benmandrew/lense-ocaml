# Plan

Stages follow docs/DESIGN.md.

- [x] Stage 0: check the note's rules on OCaml 5.5 (`test/stage0.t`). One correction: 244 non-constant constructors, not 246.
- [x] Stage 1: variants, records, inline records, `[@@unboxed]`, polymorphic variants, GADTs, exceptions and extension constructors; `Obj` fuzz oracle on both backends.
- [x] Stage 2: structure blocks (field order, items without fields, functors) and signature coercions inside a file, including functor arguments. Removed later: see the last item.
- [x] Coercion of a compilation unit to its `.mli` (`Includemod.compunit`; `test/unit.t`). Removed later, with `test/unit.t`.
- [x] Stage 3: OxCaml unboxed layouts and mixed blocks, with a byte map (`src/core/compat_ox.ml`, `test/ox/mixed.t`, mixed-block fuzzing).
- [x] Share `src/core` between the two compilers; only `compat_55.ml` and `compat_ox.ml` differ.
- [x] Stage 4: closures, objects and lazy values per backend, behind `--values` (`src/core/values.ml`, `test/values.t`, fuzzed on both switches). Native closures under flambda are reported as not predicted.
- [x] Web front end through js_of_ocaml, reusing `src/model` (`web/`, `web/jsoo/lense_web.ml`). Needs js_of_ocaml from master: 6.5.0 does not support OCaml 5.5.
- [x] Nix flake, as in `../lense`: `nix build` (tool and tests), `.#web-js`, `.#web`, and a dev shell.
- [x] One OCaml 5.5 build for both compilers: the OxCaml frontend vendored as `oxfront` (`vendor/oxcaml`), `src/core` built as `lense_core_55` and `lense_core_ox`, `--compiler 5.5|ox`, and a Compiler select on the page.
- [x] First-class module types: each module type named in `(module S ...)` or `(module M : S)` is shown as a structure block. Module structures and signature coercions are removed, with `--modules`, `test/unit.t`, `test/cases/modules.ml` and the page's "modules" checkbox, because a named module is one block per program. The tool no longer reads a `.mli` beside a `.ml` or a `.cmti` beside a `.cmt`. JSON has `packages` per unit (`test/cases/packages.ml`, `test/packages.t`). The fuzz oracle packs each generated module into a package type holding a random subset of its items in random order; 300 programs on OCaml 5.5 and 200 on OxCaml 5.2.0+ox passed with 0 failures.
