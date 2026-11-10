# lense-ocaml

Prints how OCaml types are represented at runtime (immediates, block tags, unboxing, first-class module fields), read from compiler-libs. The OCaml counterpart of `../lense`. Design and Stage 0 results: @docs/DESIGN.md. Plan: @PLAN.md.

## Build and test

```
eval $(opam env --switch=default --set-switch)   # OCaml 5.5 with dune
dune build
dune test            # cram goldens (incl. test/ox/mixed.t), Stage 0 checks, 20 fuzz rounds
dune promote         # accept golden changes, after reading the diff
dune fmt             # ocamlformat 0.29.0 (.ocamlformat); skips vendor/ and test/ox/mixed.ml
dune exec test/fuzz/fuzz.exe -- -rounds 500 [-seed N] [-keep DIR]

dune build web/jsoo/lense_web.bc.js              # lense_core for the browser (js_of_ocaml, pinned to master)
cd web && npm install && npm run dev             # the page; npm run build writes web/dist
nix build [.#web]                                # flake: tool and tests, or the static site

dune build @test/ox/runtest-ox                   # OxCaml runtime oracle; needs the 5.2.0+ox switch or $OXCAML_BIN
PATH=$(opam var --switch=5.2.0+ox bin):$PATH ./_build/default/test/fuzz/fuzz.exe -rounds 200 -ox-stdlib _build/default/vendor/oxcaml/stdlib/cmi
scripts/vendor-oxcaml.sh OXCAML_SRC              # regenerate vendor/oxcaml after an OxCaml upgrade
```

One OCaml 5.5 build serves both compilers: `lense-ocaml --compiler 5.5|ox`. The fuzz executable compiles its checkers with the `ocamlfind` on PATH and tests OxCaml when that is OxCaml's. Never put the OxCaml switch first on PATH for `dune` itself: dune would build with it.

## Constraints

- Pinned to OCaml 5.5, plus OxCaml 5.2.0+ox through `vendor/oxcaml` (its frontend as the wrapped library `oxfront`, built by 5.5). compiler-libs changes every release. Do not edit `vendor/oxcaml` by hand except its `dune` files and `config.overrides`; `scripts/vendor-oxcaml.sh` regenerates the rest.
- Read representations from the compiler's data: `record_representation`, `Datarepr` constructor tags, `Types.bound_value_identifiers` order. Never parse `-dlambda` text, but compare against it when in doubt.
- `src/model` (Model, Text, Json) has no compiler-libs dependency. The web page (`web/`) shows `Text` output from `lense_core` compiled by js_of_ocaml, with the stdlib `.cmi` files embedded at `/static/stdlib`. Everything touching compiler-libs lives in `src/core`, built twice: `src/core55` (`lense_core_55`, compiler-libs) and `src/coreox` (`lense_core_ox`, `-open Oxfront`). What differs between OCaml 5.5 and OxCaml goes in `compat_55.ml` and `compat_ox.ml`, which must define the same names; each library copies its own to `compat.ml`. The OxCaml stdlib `.cmi` files are embedded at `/static/oxstdlib`.
- Sizes are in words without the header, matching `Obj.size`.
- The fuzz oracle (`test/fuzz`) is the ground truth: a prediction is wrong if the running program disagrees, on either ocamlopt or ocamlc.
- Show only what costs memory per value. Named modules, including the unit itself, are one block per program and are not shown.
- Goldens avoid host-dependent output: no closure sizes or code pointers, no absolute paths.
- Environments from `.cmt` files hold only summaries; go through `Analyze.rebuild_env` before reading types from them.
- Field types in compiler-libs are wrapped in `Tpoly`; unwrap before matching on them.
- Closures are read from the Lambda each backend compiles (`Compat.closure_backends`), built as the drivers build it. Object slot order has no compiler data; `Values.class_vars` follows Translclass, and the fuzz oracle checks it.
