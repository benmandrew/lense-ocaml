#!/bin/sh
# Compare lense_core compiled by js_of_ocaml, as the web page runs it, with
# the native lense-ocaml. The inputs are every file in test/cases and
# test/ox and ROUNDS fuzz programs (default 200) from SEED (default 1), for
# OCaml 5.5 and for OxCaml. Each runs with values shown, for each backend, and
# the JSON and the text must be the same. Usage:
#   scripts/jsdiff.sh [ROUNDS [SEED]]
# Needs node and the opam switch dune builds with. The OxCaml fuzz programs
# need the 5.2.0+ox switch, or OXCAML_BIN set to its bin directory; without
# it they are skipped.
set -eu
rounds=${1:-200}
seed=${2:-1}
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The Nix dev shell's OCAMLPATH clashes with opam's stdlib.
env -u OCAMLPATH dune build --root . bin/main.exe test/fuzz/fuzz.exe \
  web/jsoo/lense_web.bc.js 2>&1 | grep -v 'ld: warning' || true
B=$root/_build/default
for f in bin/main.exe test/fuzz/fuzz.exe web/jsoo/lense_web.bc.js; do
  [ -e "$B/$f" ] || { echo "jsdiff: $B/$f did not build" >&2; exit 2; }
done

# The fuzz generator writes OxCaml programs when the ocamlfind on PATH is
# OxCaml's. Only the generator runs under that PATH, never dune.
"$B/test/fuzz/fuzz.exe" -gen "$work/55" -rounds "$rounds" -seed "$seed"
ox_bin=${OXCAML_BIN:-$(opam var --switch=5.2.0+ox bin 2>/dev/null || true)}
mkdir -p "$work/ox"
if [ -n "$ox_bin" ] && [ -x "$ox_bin/ocamlfind" ]; then
  PATH=$ox_bin:$PATH "$B/test/fuzz/fuzz.exe" -gen "$work/ox" \
    -rounds "$rounds" -seed "$seed"
else
  echo "jsdiff: no OxCaml switch; skipping the OxCaml fuzz programs" >&2
fi

status=0
node scripts/jsdiff.cjs "$B/web/jsoo/lense_web.bc.js" "$B/bin/main.exe" 5.5 \
  "$root"/test/cases/* "$work"/55/*.ml || status=1
# shellcheck disable=SC2046
node scripts/jsdiff.cjs "$B/web/jsoo/lense_web.bc.js" "$B/bin/main.exe" ox \
  "$root"/test/cases/* "$root"/test/ox/*.ml $(ls "$work"/ox/*.ml 2>/dev/null) \
  || status=1
exit $status
