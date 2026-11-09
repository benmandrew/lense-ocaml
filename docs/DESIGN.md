# An OCaml layout printer: design note

lense prints the memory layout of C and C++ records from clang's own layout engine. An OCaml version has to show something different. In C++ the questions are about bytes: *padding*, alignment, virtual table pointers and base placement. OCaml has a *uniform representation*, so those questions mostly disappear. The interesting part is how each type maps onto immediates, blocks and tags.

## The runtime model

Every OCaml value is one machine word. An *immediate* has its low bit set and carries a 63-bit integer on 64-bit targets. Anything else is a pointer to a *block* on the heap. Each block starts with a header word holding three fields: the size in words (*wosize*), two bits of garbage collector (GC) colour, and an 8-bit *tag*. The tag says how the GC and the runtime read the fields that follow. Sizes in this note and in the tool's output leave out the header word, which is the count `Obj.size` reports.

So a record of five fields is a header plus five words, whatever the field types are. A byte map in the style of lense would show the same picture for every record. The tool earns its place by answering other questions. Which constructors become immediates? Which tag does each block get? When does the compiler drop the block altogether?

## What the tool shows

**Variants.** Constant constructors become immediates numbered 0, 1, 2… in declaration order. Non-constant constructors become blocks with tags 0, 1, 2…, counted separately. In `type t = A | B of int | C | D of string`, `A` is immediate 0, `C` is immediate 1, `B` is a block with tag 0 and `D` is a block with tag 1. The two counters are independent, and readers often expect one shared counter. OCaml 5.5 accepts at most 244 non-constant constructors per type, with tags 0 to 243. OCaml 5 added `Forcing_tag` at 244 and `Cont_tag` at 245, below `Lazy_tag` at 246, so the tags from 244 up belong to the runtime.

**GADTs.** A *generalised algebraic data type* (GADT) uses the same representation as an ordinary variant. Type indices and type equalities are erased at compile time, and *existential* fields are plain uniform values. The tool numbers GADT constructors as an ordinary variant and marks each existential field, so constructors that the type checker keeps apart can be seen to share a runtime shape.

**Records.** A record is a block with tag 0 and its fields in declaration order. There are three special cases. A record whose fields are all `float` is stored flat, with unboxed doubles and `Double_array_tag` (254). A record or single-constructor type marked `[@@unboxed]` has no block at all. An *inline record* (`C of { x : int; y : float }`) puts its fields directly in the constructor's block, with the constructor's tag. Inline records never get the flat-float case, so `y` stays a pointer to a boxed float.

**Polymorphic variants.** A constant polymorphic variant is the immediate hash of its label. A non-constant one is a two-field block `[hash; argument]`, and a multi-argument payload becomes one pointer to a tuple. Two labels can hash to the same value, and the compiler rejects that. The tool reports collisions across every file it is given.

**Exceptions and extensible variants.** A constant extension constructor is its own *slot*: a block with `Object_tag` (248) holding the name and a unique identifier. A non-constant one is a tag-0 block whose first field points to that slot, followed by the arguments.

**Modules.** At runtime a structure is a block holding its value-bearing items in order: values, submodules, exceptions and classes. Types and module types take no slot. A functor is a closure. Signature ascription can insert a *coercion*, which copies the structure into a new block with fewer fields or a different order. The tool shows that copy field by field, with the size of the new block; existing tooling leaves it invisible.

**Closures, objects and lazy values.** Closures use `Closure_tag` (247), with a code pointer, a *closinfo* word (arity and the start of the environment) and then the environment. Objects use `Object_tag` with a method table. Lazy values use `Lazy_tag` and `Forward_tag`. These come last, because flambda changes closure shapes, so their layout depends on the compiler configuration as well as the type.

## Where the information comes from

The compiler's own libraries, `compiler-libs`, play the role of clang LibTooling. The tool can type-check source directly or read `.cmt` and `.cmti` files produced with `-bin-annot`. From the typed declarations it reads `record_representation` (regular, float, unboxed, inlined or extension) and the constructor tags that `Datarepr` assigns. For modules it reads the coercions that `Includemod` computes. This follows the existing lense rule of reading layouts from the compiler's data structures instead of parsing its debug output.

| lense (C++) | OCaml equivalent |
|---|---|
| clang LibTooling, `ASTRecordLayout` | `compiler-libs`: `Types.type_declaration`, `record_representation`, `Datarepr` constructor tags, `Includemod` coercions |
| Pinned to LLVM 23 | Pinned to OCaml 5.5, because `compiler-libs` changes between releases |
| Cross-check with `-fdump-record-layouts` | Cross-check with `-dlambda`, which prints `makeblock <tag>` and constant numbering |
| Fuzz oracle: clang 23 | Runtime introspection with `Obj.is_int`, `Obj.tag` and `Obj.size` |
| Emscripten build of clang for the web | `js_of_ocaml` or `wasm_of_ocaml` compiling `compiler-libs` |

The fuzz oracle is simpler than in the C++ version. A generator writes random type declarations and constructs values of them. The test program then inspects each value with the `Obj` module and compares the result with the tool's prediction. It is compiled with both `ocamlopt` and `ocamlc`, so each prediction is checked on both backends. The ground truth comes from the running program, so no second compiler is needed.

The web front end, not yet built, is also simpler. The [OCaml playground](https://ocaml.org/play) already runs the compiler in the browser through `js_of_ocaml`. The same route avoids the custom WebAssembly build of clang that lense needs.

## OxCaml

Jane Street's OxCaml branch adds *unboxed layouts* such as `float#` and `int32#`, and *mixed blocks* that store flat, unscanned fields after the scanned ones. Mixed blocks have real byte-level layout. With them, a byte map of the lense kind becomes useful again.

## Stage 0 results

The tag numbers and representation rules in this note were first written from memory. Stage 0 checked each one on OCaml 5.5.0 and 5.5.1, by inspecting real values with the `Obj` module and reading the compiler's `-dlambda` output. `test/stage0.t` repeats both checks on every `dune test`, so a compiler change that breaks a rule fails the tests.

**Confirmed.** Constant and non-constant constructors use separate counters, and GADTs use the ordinary numbering. All-float records are `Double_array_tag` (254) blocks, whether their fields are mutable or not. Records and constructors marked `[@@unboxed]` have no block. Inline records take the constructor's tag and never get the flat-float case, even when every field is a `float`. A constant polymorphic variant is the immediate hash of its label. A non-constant one is a block `[hash; argument]` of size 2, and a multi-argument payload is one pointer to a tuple. A constant exception is an `Object_tag` (248) block of size 2, holding its name as a string and an immediate identifier. A non-constant exception is a tag-0 block whose field 0 is that slot. A structure is a tag-0 block of its value-bearing items in order. Closures use `Closure_tag` (247), and lazy values use `Lazy_tag` (246) before they are forced.

**Wrong.** The note said a type could have 246 non-constant constructors, because tag 246 is `Lazy_tag`. OCaml 5.5 accepts at most 244, with tags 0 to 243. A type with 245 fails with "Too many non-constant constructors -- maximum is 244 non-constant constructors". OCaml 5 added `Forcing_tag` at 244 (a lazy value being forced) and `Cont_tag` at 245 (an effect continuation), and the note did not account for either.

**Not in the note.** Building the tool found six more rules. An empty float array `[||]` is a shared tag-0 *atom*, so a `float array` field has tag 254 only when the array is not empty. A lazy value built from a constant, or already forced, can be the value itself, so a `Lazy.t` field can be an immediate. A class in a structure takes one field, a tag-0 block of size 3. An `external` takes no field in its structure, and coercing it to a `val` wraps it in a new closure. The last two concern the tooling. Record field types in `compiler-libs` are wrapped in `Tpoly` nodes. Dune's `BUILD_PATH_PREFIX_MAP` rewrites the build directory that a `.cmt` file records, so the tool looks for that directory among the `.cmt` file's ancestors.

## Stage 3 results

The tool builds against OxCaml's `compiler-libs` from the same tree, checked on the 5.2.0+ox switch. `src/core` is shared between the two compilers. The parts of `compiler-libs` that differ are in `compat_55.ml` and `compat_ox.ml`, and a dune rule copies one of them to `compat.ml`, chosen by `%{ocaml_version}`. The mixed-block code is only in `compat_ox.ml`. The 5.5 goldens are disabled on OxCaml, and `test/ox/mixed.t` holds the OxCaml goldens. The field order of a mixed block comes from the compiler's own `Mixed_block_shape` module (`lambda/mixed_block_shape.ml`, part of `compiler-libs`), and the tool does not derive it again.

**Native code.** Values come first, then flat fields, each group in declaration order. Each flat scalar takes a whole word, even `int8#`, `int16#`, `int32#` and `float32#`; the compiler's comment says they "aren't packed tightly". An `int32#` is written with a 32-bit store, an `int16#` with a 16-bit store and an `int8#` with an 8-bit store, so the rest of the word is unused. A `vec128` takes two words. The header records the length of the scanned prefix, and `Obj.Uniform_or_mixed` reads it back. Unboxed products (unboxed records `#{...}` and unboxed tuples `#(...)`) inside a block are split. Their value parts join the scanned prefix and their flat parts join the flat suffix, and an unboxed record type has no block of its own. A record of only `float` and `float#` fields is stored entirely flat, and its `float` fields are boxed again when read. A record of only `float#` fields is a `Double_array_tag` block, like an all-`float` record. Extension constructors and exceptions cannot have unboxed fields, because the compiler rejects them.

**Bytecode.** The compiler's own runtime header calls these *faux mixed blocks*. Bytecode keeps declaration order, with one scanned field per declared field. Flat fields are boxed: `float#` as a `Double_tag` block, `int32#`, `int64#` and `nativeint#` as custom blocks, `int8#`, `int16#` and `int#` as immediates, and unboxed products as tag-0 blocks. The block sizes differ between the backends whenever products are present. The fuzz oracle generates mixed records and constructors on OxCaml, with scalar flat fields of eight kinds, unboxed tuples and all-float records. It checks native code through `Obj.raw_field` bits and the scanned prefix length, and bytecode through the boxed values. A planted bug that reversed the slot order gave 7 mismatches in 6 rounds. `dune test --build-dir _build-ox` runs 20 rounds.

## Plan

**Stage 0.** Done. Every rule in this note was checked against the pinned OCaml release, with the results above.

**Stage 1.** Done. Variants, records, polymorphic variants and `[@@unboxed]`, read from typed `compiler-libs` output, with the `Obj` fuzz oracle from the start.

**Stage 2.** Done. Module structures and signature coercions. A unit with an interface also shows its coercion to the `.mli`, computed with `Includemod.compunit` as the compiler does; `test/unit.t` compares it with `-dlambda`.

**Stage 3.** Done. OxCaml mixed blocks and the byte map, built against OxCaml's own `compiler-libs` through `src/core/compat_ox.ml`. The fuzz oracle checks native code through `Obj.raw_field` and bytecode through the boxed values.

**Stage 4.** Open. Closures, objects and lazy values, per compiler configuration.

Two pieces sit outside the stages and are also open: the `js_of_ocaml` web front end, and checking the predictions under flambda.

The C++ tool is mostly about the compiler's freedom to place fields. The OCaml tool is mostly about the compiler's freedom to choose a representation, and that choice is where OCaml programmers usually have the least visibility.
