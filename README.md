# lense-ocaml

`lense-ocaml` prints how each type declared in an OCaml file is represented at runtime: which constructors become *immediates*, which *tag* each heap *block* gets, when the compiler drops the block, and how module structures and signature *coercions* lay out their fields. It reads the representations from the compiler's own libraries (*compiler-libs*) for OCaml 5.5, and never parses `-dlambda` text. It is the OCaml counterpart of `lense`, the C and C++ record layout printer, and its design is in [docs/DESIGN.md](docs/DESIGN.md).

```console
$ printf 'type t = A | B of int | C | D of string\n' | lense-ocaml --no-modules -
type t  variant: 2 immediates 0-1, 2 block tags 0-1
  A  immediate 0
  B  block, tag 0, size 1
       0  int  immediate (int)
  C  immediate 1
  D  block, tag 1, size 1
       0  string  pointer to string, String_tag 252
```

## Building

```sh
dune build
dune test      # cram goldens, Stage 0 checks and a 20-round fuzz run
```

It needs OCaml 5.5 with compiler-libs, and dune. There are no other dependencies. The tool is pinned to OCaml 5.5 because compiler-libs changes between releases.

### Nix

```sh
nix build            # the tool, after the cram goldens and the 20-round fuzz run pass
nix build .#web      # the web front end as static files
nix develop          # OCaml 5.5, dune, js_of_ocaml, ocamlfind, ocaml-lsp and Node
```

The flake uses `ocamlPackages_5_5` from nixpkgs. Its `js_of_ocaml` 6.5.0 builds `web/jsoo` on OCaml 5.5.1, so the Nix build needs no pin from master. The `.#web-js` script is 6.7 MB with the OxCaml frontend, against 2.6 MB without it.

### OxCaml

The same OCaml 5.5 build also reads OxCaml, Jane Street's branch of OCaml with unboxed layouts. `vendor/oxcaml` holds the *frontend* of OxCaml 5.2.0+ox (parser, type checker and Lambda) as the wrapped dune library `oxfront`, which OCaml 5.5 compiles. The sources in `src/core` are built twice, as `lense_core_55` against compiler-libs and `lense_core_ox` against `oxfront`, and both link into one executable. The parts that differ live in `compat_55.ml` and `compat_ox.ml`. Building needs no OxCaml switch, and `scripts/vendor-oxcaml.sh OXCAML_SRC` regenerates the vendored tree from an OxCaml source tree. The native binary is 26.0 MB with the OxCaml frontend, against 11.8 MB without it.

`--compiler ox` selects OxCaml, and `--compiler 5.5` selects OCaml 5.5. Without the option, the tool reads the magic number of a `.cmt`, `.cmti` or `.cmi` file, and falls back to 5.5. A `.ml` or `.mli` file with OxCaml syntax therefore needs `--compiler ox`. The 74 `.cmi` files of the OxCaml standard library are compiled from the vendored sources by `oxc.exe`, OxCaml's `ocamlc` driver built by OCaml 5.5. They are installed to `share/lense-ocaml/oxcaml-stdlib`. The tool reads them from `--ox-stdlib DIR`, or else from `LENSE_OX_STDLIB`. With neither, it looks in the installed directory and then in `vendor/oxcaml/stdlib/cmi` in the build tree.

```sh
lense-ocaml --compiler ox --no-modules test/ox/mixed.ml
OXCAML_BIN=$(opam var --switch=5.2.0+ox bin) dune build @test/ox/runtest-ox
dune build test/fuzz/fuzz.exe
PATH=$(opam var --switch=5.2.0+ox bin):$PATH ./_build/default/test/fuzz/fuzz.exe -rounds 200 -ox-stdlib _build/default/vendor/oxcaml/stdlib/cmi
```

`test/ox/mixed.t` holds the OxCaml goldens and runs in plain `dune test`. `test/ox/mixed_oracle.t` compiles OxCaml programs and runs them, so it needs the OxCaml compiler and runs only under the `runtest-ox` alias. It takes the compiler from `$OXCAML_BIN`, or else from `opam var --switch=5.2.0+ox bin`. The fuzz oracle checks OxCaml when the `ocamlfind` on `PATH` is OxCaml's, and `-ox-stdlib DIR` tells it where the OxCaml standard library is. Run the built executable rather than `dune exec`, because dune would build with the OxCaml compiler if it came first on `PATH`.

For a *mixed block*, the output lists the scanned fields first and then the flat ones, with each flat field's byte range and the unused bytes in its word. The compiler's own `Mixed_block_shape` module supplies the order. This excerpt is for `type m = { a : int; b : float#; c : string; d : int32#; f : int8# }` from `test/ox/mixed.ml`.

```
type m  mixed block, tag 0, size 5: 2 scanned fields, then 3 flat
       0-7    header
    0  8-15   a : int     immediate (int)
    1  16-23  c : string  pointer to string, String_tag 252
    2  24-31  b : float#  unboxed float64, 8 bytes
    3  32-35  d : int32#  unboxed bits32, 4 bytes, bytes 36-39 unused
    4  40     f : int8#   unboxed bits8, 1 byte, bytes 41-47 unused
    note: values first, then flat fields, each in declaration order
    note: native code; bytecode stores one boxed field per declared field, in declaration order
```

## Usage

```sh
lense-ocaml [options] <file.ml | file.mli | file.cmt | file.cmti | -> ...
```

| Option | Effect |
| --- | --- |
| `--json` | Print JSON instead of text |
| `--type NAME` | Show only the named types; repeatable, and matches the last component of a qualified name |
| `--source` | Print each declaration above its representation |
| `--no-modules` | Leave out module structures and coercions |
| `--labels` | List every polymorphic variant label with its hash, and report collisions |
| `--values` | Also show closures, lazy values and objects, per backend |
| `--intf` | Read standard input as an `.mli` |
| `-I DIR` | Add `DIR` to the load path for `.cmi` files |
| `--compiler 5.5\|ox` | Read the input as OCaml 5.5 or OxCaml; the default comes from the magic number of a `.cmt`, `.cmti` or `.cmi` file, else 5.5 |
| `--ox-stdlib DIR` | Load the OxCaml standard library `.cmi` files from `DIR`; `LENSE_OX_STDLIB` does the same |
| `-` | Read standard input |

Several files can be given in one run, and hash collisions between polymorphic variant labels are reported across all of them. In a dune project, pass the `.cmt` files from `_build`, which dune writes by default. The tool rebuilds each file's environment from the load path that the file records. Sizes are in words and leave out the header word, so they match `Obj.size`.

## What it shows

**Variants.** Constant and non-constant constructors are numbered by separate counters, so `A` and `C` above are immediates 0 and 1 while `B` and `D` are blocks with tags 0 and 1. A *generalised algebraic data type* (GADT) uses the same numbering, because its type indices are erased. OCaml 5.5 accepts at most 244 non-constant constructors per type.

**Records.** A record is a tag-0 block of its fields in declaration order. A record whose fields are all `float` is a flat block of unboxed doubles with `Double_array_tag` (254). A record marked `[@@unboxed]` has no block. An *inline record* takes its constructor's tag and is never stored flat.

**Polymorphic variants.** A constant label is the immediate hash of its name. A non-constant one is a block `[hash; argument]` of size 2. `--labels` lists every label with its hash and reports collisions.

**Exceptions and extensions.** A constant exception or extension constructor is an *extension slot*, an `Object_tag` (248) block of size 2 holding its name and a unique identifier. A non-constant one is a tag-0 block whose field 0 points to that slot, followed by its arguments. A rebinding such as `exception Again = Empty` is the same value as the original.

**Modules and coercions.** A structure is a tag-0 block of its value-bearing items in order. Types, module types and `external` declarations take no field. When a signature ascription inserts a coercion, the output shows which fields are copied into the new block, and from where. A `.ml` file with an `.mli` beside it, or a `.cmt` file with a `.cmti` beside it, also shows the coercion to that interface, which builds the block other units see. This excerpt is from `test/cases/modules.ml`.

```
module Reordered : S  copies 2 of 3 fields into a new block, size 2
    0 <- 2  greet
    1 <- 0  answer
```

**Closures, lazy values and objects.** With `--values`, the output also lists the closures, lazy values and objects that a unit allocates. Closures get one section for native code and one for bytecode, because the backends build them differently. Each closure shows its code pointers, its *closinfo* word (arity and the start of the environment) and the captured variables. Each lazy value shows whether it has a block, and with which tag. Each object shows the slot of every instance variable. Native closures under flambda are reported as not predicted. This excerpt is the native closure returned by `let mk b a = fun x -> x + a + b`, from `test/values.t`.

```
mk.(fun)  line 5  Closure_tag 247, size 4
    0  code pointer
    1  closinfo: arity 1, environment from field 2
    2  b : int  immediate (int)
    3  a : int  immediate (int)
```

## Web front end

`web/` holds a page built with Vite. A *CodeMirror* editor sits on the left, and the representation sits on the right, as one card per paragraph of the text report. The page re-analyses the source 250 ms after each edit. Its options are the compiler (OCaml 5.5 or OxCaml), `.ml` or `.mli`, closures, lazy values and objects (`--values`), source, modules, and variant labels only. The hash part of the page address holds the whole state, so a link reproduces it. The Example menu offers the files in `test/cases/*.ml` and `test/ox/*.ml`, and an OxCaml example selects OxCaml in the Compiler menu.

A *web worker* runs `web/jsoo/lense_web.ml`, which is `lense_core_55` with compiler-libs and `lense_core_ox` with the vendored OxCaml frontend, compiled by `js_of_ocaml` as a whole program. The script is 37 MB in the dev profile and 6.1 MB under `--profile release` (1.68 MB gzipped). It type-checks the source in the browser, with the standard library `.cmi` files embedded in the js_of_ocaml *pseudo-filesystem* at `/static/stdlib`, and the OxCaml ones at `/static/oxstdlib`. It returns the same text as the command line, from `Text` in `src/model`, or the compiler's error, which the editor marks on its line. A typical analysis took 27 to 48 ms in Chrome.

`js_of_ocaml` 6.5.0 on opam requires OCaml below 5.5, so the build pins its three packages to commit `87ab6ef` of the ocsigen/js_of_ocaml master branch, which accepts versions below 5.7. Plain `dune build` skips the script, so it has its own target.

```sh
opam pin add js_of_ocaml-compiler git+https://github.com/ocsigen/js_of_ocaml#87ab6ef45c8019288c1988a27be5d64cd7424fe2
opam pin add js_of_ocaml git+https://github.com/ocsigen/js_of_ocaml#87ab6ef45c8019288c1988a27be5d64cd7424fe2
opam pin add js_of_ocaml-ppx git+https://github.com/ocsigen/js_of_ocaml#87ab6ef45c8019288c1988a27be5d64cd7424fe2
opam install js_of_ocaml-compiler js_of_ocaml ocaml.5.5.0
dune build web/jsoo/lense_web.bc.js
cd web && npm install && npm run dev   # or npm run build, which writes web/dist
```

`LENSE_JS` points the Vite configuration at another build of the script. The theme and fonts are those of `../lense/web`, the dark theme of benmandrew.com.

## Testing

`dune test` runs the cram goldens in `test/*.t` and the OxCaml goldens in `test/ox/mixed.t`, rechecks the representation rules against the compiler in `test/stage0.t`, and runs the fuzz oracle in `test/fuzz/fuzz.ml`; `dune promote` accepts a changed golden. Each fuzz round generates random variants, records, polymorphic variants, GADTs, exceptions, modules with a coerced view, closures, lazy values and classes, and predicts their representations with `lense-ocaml` in-process. It then compiles a checker with both `ocamlopt` and `ocamlc` that builds a value of every constructor and compares it with the prediction through `Obj.is_int`, `Obj.tag` and `Obj.size`. The 20-round run in `dune test` makes 1,316 checks per backend, and a planted off-by-one in constant numbering failed on the first round. A longer run is `dune exec test/fuzz/fuzz.exe -- -rounds 500`, with `-seed N` for the first seed and `-keep DIR` to keep the generated programs. The ground truth is the running program, so the oracle needs no second implementation of the representation rules to compare against.
