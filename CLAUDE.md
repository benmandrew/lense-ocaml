# lense-ocaml

Prints how OCaml types are represented at runtime (immediates, block tags, unboxing, first-class module fields), read from compiler-libs. The OCaml counterpart of `../lense`. Read `docs/DESIGN.md` (rules, data sources, stage results) and `PLAN.md` (progress) when a task touches a representation rule or a new stage.

## Build and test

```
eval $(opam env --switch=default --set-switch)   # OCaml 5.5 with dune
dune build
dune test            # cram goldens (incl. test/ox/mixed.t), Stage 0 checks, 20 fuzz rounds
dune promote         # accept golden changes, after reading the diff
dune fmt             # ocamlformat 0.29.0; skips vendor/ and test/ox/mixed.ml
dune exec test/fuzz/fuzz.exe -- -rounds 500 [-seed N] [-keep DIR]

dune build web/jsoo/lense_web.bc.js              # lense_core for the browser (js_of_ocaml master)
cd web && npm install && npm run dev             # the page; npm run build writes web/dist
nix build [.#web]                                # tool and tests, or the static site

dune build @test/ox/runtest-ox                   # OxCaml runtime oracle; needs the 5.2.0+ox switch or $OXCAML_BIN
PATH=$(opam var --switch=5.2.0+ox bin):$PATH ./_build/default/test/fuzz/fuzz.exe -rounds 200 -ox-stdlib _build/default/vendor/oxcaml/stdlib/cmi
scripts/vendor-oxcaml.sh OXCAML_SRC              # regenerate vendor/oxcaml after an OxCaml upgrade
```

One OCaml 5.5 build serves both compilers: `lense-ocaml --compiler 5.5|ox`. The fuzz executable tests OxCaml when the `ocamlfind` on PATH is OxCaml's. Never put the OxCaml switch first on PATH for `dune` itself: dune would build with it.

## Constraints

- Pinned to OCaml 5.5 and OxCaml 5.2.0+ox. `vendor/oxcaml` is OxCaml's frontend, built by 5.5 as the wrapped library `oxfront`. Edit only its `dune` files and `config.overrides`; `scripts/vendor-oxcaml.sh` regenerates the rest.
- Read representations from the compiler's data (`record_representation`, `Datarepr` tags, `Types.bound_value_identifiers` order). Never parse `-dlambda` text; compare against it when in doubt.
- `src/model` has no compiler-libs dependency. `src/core` is built twice: `lense_core_55` (`src/core55`) and `lense_core_ox` (`src/coreox`, `-open Oxfront`). Differences go in `compat_55.ml` and `compat_ox.ml`, which define the same names.
- Sizes are words without the header (`Obj.size`). Costs are words with every header (`Obj.reachable_words`).
- The fuzz oracle (`test/fuzz`) is the ground truth: a prediction is wrong if the running program disagrees, on ocamlopt or ocamlc.
- Show only what costs memory per value. Named modules, the unit included, are one block per program and are not shown.
- Goldens hold no closure sizes, code pointers or absolute paths.
- `.cmt` environments hold only summaries: go through `Analyze.rebuild_env` first. Field types are wrapped in `Tpoly`: unwrap before matching.
