# lense-ocaml

Prints how OCaml types are represented at runtime (immediates, block tags, unboxing, structure fields, coercions), read from compiler-libs. The OCaml counterpart of `../lense`. Design and Stage 0 results: @docs/DESIGN.md. Plan: @PLAN.md.

## Build and test

```
eval $(opam env --switch=default --set-switch)   # OCaml 5.5 with dune
dune build
dune test            # cram goldens, Stage 0 checks, 20 fuzz rounds
dune promote         # accept golden changes, after reading the diff
dune exec test/fuzz/fuzz.exe -- -rounds 500 [-seed N] [-keep DIR]
```

## Constraints

- Pinned to OCaml 5.5. compiler-libs changes every release; `dune-project` enforces the pin.
- Read representations from the compiler's data: `record_representation`, `Datarepr` constructor tags, `Types.bound_value_identifiers` order, `Typedtree.module_coercion`. Never parse `-dlambda` text, but compare against it when in doubt.
- `src/model` (Model, Text, Json) has no compiler-libs dependency, so a js_of_ocaml front end can reuse it. Everything touching compiler-libs lives in `src/core`.
- Sizes are in words without the header, matching `Obj.size`.
- The fuzz oracle (`test/fuzz`) is the ground truth: a prediction is wrong if the running program disagrees, on either ocamlopt or ocamlc.
- Goldens avoid host-dependent output: no closure sizes or code pointers, no absolute paths.
- Environments from `.cmt` files hold only summaries; go through `Analyze.rebuild_env` before reading types from them.
- Field types in compiler-libs are wrapped in `Tpoly`; unwrap before matching on them.
