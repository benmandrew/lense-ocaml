#!/bin/sh
# Regenerate vendor/oxcaml from an OxCaml source tree, so that OCaml 5.5
# builds the OxCaml frontend as the library oxfront. Usage:
#   scripts/vendor-oxcaml.sh OXCAML_SRC
# Needs cc, ocamllex, ocamlfind, menhir and dune from the OCaml 5.5 switch.
# The module lists in vendor/oxcaml/*/dune and config.overrides are kept;
# every source file and generated file is replaced.
set -eu
src=$(cd "$1" && pwd)
root=$(cd "$(dirname "$0")/.." && pwd)
V=$root/vendor/oxcaml
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The (modules ...) list of a dune file, which may span lines.
modules() { perl -0ne 'print $1 if /\(modules\s+([^)]*)\)/s' "$1" | tr -s ' \n' ' '; }

# --- Frontend: utils, parsing, typing, lambda and the parts of driver it uses.
F=$V/frontend
find "$F" -type f ! -name dune -delete
for m in $(modules "$F/dune"); do
  for d in utils parsing typing lambda file_formats bytecomp driver; do
    for e in ml mli mll; do [ -f "$src/$d/$m.$e" ] && cp "$src/$d/$m.$e" "$F/"; done
  done
done
cp "$src"/stdlib/camlinternalQuote.ml "$src"/stdlib/camlinternalQuote.mli "$F/"
cp "$(ocamlfind query menhirLib)/menhirLib.ml" "$F/camlinternalMenhirLib.ml"

# config.ml: the boot configuration, the real magic numbers, then overrides.
m4=$src/build-aux/ocaml_version.m4
prefix=$(sed -n 's/^m4_define(\[MAGIC_NUMBER__PREFIX\], \[\(.*\)\])$/\1/p' "$m4")
version=$(sed -n 's/^m4_define(\[MAGIC_NUMBER__VERSION\], \[\(.*\)\])$/\1/p' "$m4")
exec_kind=$(sed -n 's/^m4_define(EXEC__FORMAT, \[\(.*\)\])$/\1/p' "$m4")
subst="-e s/@configure_input@/generated_by_vendor-oxcaml.sh/"
for pair in $(sed -n 's/^DEFINE_MAGIC_NUMBER(\[\([A-Z_]*\)\], \[*\([A-Z_]*\)\]*)$/\1:\2/p' "$m4"); do
  name=${pair%%:*}; kind=${pair#*:}; [ "$kind" = EXEC__FORMAT ] && kind=$exec_kind
  subst="$subst -e s/@${name}_MAGIC_NUMBER@/$prefix$kind$version/"
done
sed $subst "$src/utils/config.common.ml.in" > "$work/common.ml"
cp "$src/utils/config.fixed.ml" "$work/fixed.ml"
grep '^let ' "$V/config.overrides" | while IFS= read -r line; do
  k=$(printf %s "$line" | sed 's/^let \([a-z_0-9]*\) .*/\1/')
  if grep -q "^let $k = " "$work/fixed.ml"; then
    LINE=$line perl -pi -e "s/^let $k = .*\$/\$ENV{LINE}/" "$work/fixed.ml"
  else
    printf '%s\n' "$line" >> "$work/fixed.ml"
  fi
done
VERSION=$(head -1 "$src/VERSION") perl -pi -e 's/^let version = .*$/let version = {|$ENV{VERSION}|}/' "$work/common.ml"
cat "$work/fixed.ml" "$work/common.ml" > "$F/config.ml"
grep -q '@' "$F/config.ml" && grep -n '@[A-Za-z_]*@' "$F/config.ml" && { echo "config.ml: unsubstituted values" >&2; exit 1; }

# domainstate: the C preprocessor over the runtime's table, 64-bit.
mkdir -p "$work/inc"
printf '#define ARCH_SIXTYFOUR\n#define SIZEOF_PTR 8\n#define SIZEOF_LONG 8\n' > "$work/inc/m.h"; : > "$work/inc/s.h"
for e in ml mli; do cc -E -P -I "$work/inc" -I "$src/runtime/caml" -x c "$src/utils/domainstate.$e.c" > "$F/domainstate.$e"; done

# runtimedef: builtin exceptions and primitives of the runtime.
sh "$src/runtime/gen_primitives.sh" "$work/primitives" "$src"/runtime/*.c
sh "$src/lambda/generate_runtimedef.sh" "$src/runtime/caml/fail.h" "$work/primitives" > "$F/runtimedef.ml"

# opcodes: the bytecode instruction numbers.
cp "$src"/tools/make_opcodes.mll "$work/"
(cd "$work" && ocamllex -q make_opcodes.mll && ocamlfind ocamlopt -package str -o make_opcodes make_opcodes.ml 2>/dev/null || ocamlopt -o make_opcodes make_opcodes.ml)
"$work/make_opcodes" -opcodes < "$src/runtime/caml/instruct.h" > "$F/opcodes.ml"

# misc.ml builds a Format record; OCaml 5.5 added the field out_width.
perl -0pi -e 's/out_spaces;\n    out_indent\}/out_spaces;\n    out_indent;\n    out_width = (fun _ ~pos:_ ~len -> len)}/ or die "misc.ml: Format record not found\n"' "$F/misc.ml"

# --- flambda2_floats: Float32 and its C stubs. The parser step below needs it.
cp "$src"/middle_end/flambda2/numbers/floats/float32.ml "$src"/middle_end/flambda2/numbers/floats/float32.mli \
   "$src"/middle_end/flambda2/numbers/floats/float32_stubs.c "$V/floats/"

# parser.ml: menhir's --infer needs the library's types. Inside a wrapped
# library dune's menhir stanza prints them as Oxfront.X, which the library
# cannot refer to, so generate the parser once and drop the prefix.
P=$work/parser
mkdir -p "$P/oxfront"
cp "$F"/* "$P/oxfront/"; cp "$src/parsing/parser.mly" "$P/oxfront/"; rm -f "$P/oxfront/parser.ml" "$P/oxfront/parser.mli"
cp -r "$V/floats" "$P/floats"
printf '(lang dune 3.17)\n(using menhir 3.0)\n' > "$P/dune-project"
{ printf '(menhir (modules parser) (flags --lalr --require-aliases --strict --unused-token COMMENT --unused-token DOCSTRING --unused-token EOL --unused-token GREATERRBRACKET --table --fixed-exception --strategy simplified --inspection))\n'
  cat "$F/dune"; } > "$P/oxfront/dune"
(cd "$P" && dune build --root . ./oxfront/parser.ml > "$work/parser.log" 2>&1) || true
if [ ! -f "$P/_build/default/oxfront/parser.ml" ]; then
  cat "$work/parser.log" >&2; echo "menhir did not produce parser.ml" >&2; exit 1
fi
sed 's/Oxfront\.//g' "$P/_build/default/oxfront/parser.ml" > "$F/parser.ml"

# --- The bytecode driver, oxc, which compiles the stdlib interfaces.
for m in $(modules "$V/bytecomp/dune"); do
  for d in bytecomp driver; do
    for e in ml mli; do [ -f "$src/$d/$m.$e" ] && cp "$src/$d/$m.$e" "$V/bytecomp/"; done
  done
done

# --- The stdlib sources, compiled to .cmi files by stdlib/cmi/dune.
find "$V/stdlib" -maxdepth 1 -type f -delete
cp "$src"/stdlib/*.ml "$src"/stdlib/*.mli "$src"/stdlib/StdlibModules "$src"/stdlib/expand_module_aliases.awk "$V/stdlib/"

cp "$src/LICENSE" "$V/LICENSE"
head -1 "$src/VERSION" > "$V/VERSION"
echo "vendor/oxcaml now holds OxCaml $(cat "$V/VERSION")"
