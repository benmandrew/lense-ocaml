#!/bin/sh
# Compile the OxCaml stdlib interfaces with oxc, the OxCaml bytecode driver
# built from vendor/oxcaml. Usage: build.sh OXC SRCDIR
# StdlibModules gives link order, not interface order, so repeat passes
# until every module compiles or a pass makes no progress.
set -u
abs() { case $1 in /*) echo "$1";; *) echo "$(pwd)/$1";; esac; }
oxc=$(abs "$1"); src=$(abs "$2"); out=$(pwd); work=$(mktemp -d)
cp "$src"/*.ml "$src"/*.mli "$src"/expand_module_aliases.awk "$work"/
cd "$work"
flags="-strict-sequence -w -a -nostdlib -principal -no-alias-deps -I ."
todo="$(sed -n '/^STDLIB_MODULE_BASENAMES/,/^$/p' "$src"/StdlibModules | tr -d '\\' | tr -s ' \n' '\n' | grep -v -e STDLIB_MODULE_BASENAMES -e '^=*$') std_exit"
compile() {
  case $1 in
    stdlib) extra="-nopervasives -pp 'awk -f ./expand_module_aliases.awk'"; o="";;
    camlinternalFormatBasics|camlinternalAtomic) extra="-nopervasives"; o="";;
    camlinternal*|std_exit) extra=""; o="";;
    *) extra=""; o="-o stdlib__$(printf %s "$1" | cut -c1 | tr a-z A-Z)$(printf %s "$1" | cut -c2-)";;
  esac
  if [ -f "$1.mli" ]; then eval "$oxc" $flags $extra ${o:+$o.cmi} -c "$1.mli"
  else eval "$oxc" $flags $extra ${o:+$o.cmo} -c "$1.ml"; fi
}
while :; do
  left=""; progress=false
  for m in $todo; do if compile "$m" 2>"$m.err"; then progress=true; else left="$left $m"; fi; done
  todo=$left
  if [ -z "$todo" ] || ! $progress; then break; fi
done
for m in $todo; do echo "cannot compile $m:" >&2; cat "$m.err" >&2; done
cp ./*.cmi "$out"/; cd "$out"; rm -rf "$work"
[ -z "$todo" ]
