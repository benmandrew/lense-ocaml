# lense-ocaml

Prints how OCaml types are represented at runtime (immediates, block tags, unboxing, structure fields, coercions), read from compiler-libs. The OCaml counterpart of `../lense`. Design and Stage 0 results: @docs/DESIGN.md. Plan: @PLAN.md.

## Build and test

```
eval $(opam env --switch=default --set-switch)   # OCaml 5.5 with dune
dune build
dune test            # cram goldens, Stage 0 checks, 20 fuzz rounds
dune promote         # accept golden changes, after reading the diff
dune exec test/fuzz/fuzz.exe -- -rounds 500 [-seed N] [-keep DIR]

dune build web/jsoo/lense_web.bc.js              # lense_core for the browser (js_of_ocaml, pinned to master)
cd web && npm install && npm run dev             # the page; npm run build writes web/dist
nix build [.#web]                                # flake: tool and tests, or the static site

eval $(opam env --switch=5.2.0+ox --set-switch)  # OxCaml: separate build dir
dune test --build-dir _build-ox                  # test/ox goldens, fuzz with mixed blocks
```

Run the fuzz executable with the matching switch's `opam env` in the shell: it compiles its checkers with the `ocamlfind` on PATH.

## Constraints

- Pinned to OCaml 5.5, plus OxCaml 5.2.0+ox. compiler-libs changes every release. The OxCaml code is selected by `enabled_if` on `%{ocaml_version}`.
- Read representations from the compiler's data: `record_representation`, `Datarepr` constructor tags, `Types.bound_value_identifiers` order, `Typedtree.module_coercion`. Never parse `-dlambda` text, but compare against it when in doubt.
- `src/model` (Model, Text, Json) has no compiler-libs dependency. The web page (`web/`) shows `Text` output from `lense_core` compiled by js_of_ocaml, with the stdlib `.cmi` files embedded at `/static/stdlib`. Everything touching compiler-libs lives in `src/core`. What differs between OCaml 5.5 and OxCaml goes in `compat_55.ml` and `compat_ox.ml`, which must define the same names; a dune rule copies one to `compat.ml`.
- Sizes are in words without the header, matching `Obj.size`.
- The fuzz oracle (`test/fuzz`) is the ground truth: a prediction is wrong if the running program disagrees, on either ocamlopt or ocamlc.
- Goldens avoid host-dependent output: no closure sizes or code pointers, no absolute paths.
- Environments from `.cmt` files hold only summaries; go through `Analyze.rebuild_env` before reading types from them.
- Field types in compiler-libs are wrapped in `Tpoly`; unwrap before matching on them.
- Closures are read from the Lambda each backend compiles (`Compat.closure_backends`), built as the drivers build it. Object slot order has no compiler data; `Values.class_vars` follows Translclass, and the fuzz oracle checks it.
