#!/usr/bin/env bash
# Plant known bugs in lense, one at a time, and check that the fuzz oracle
# catches each one. Runs in a copy of the working tree, so the checkout is
# never changed.
#
#   scripts/mutate.sh [-rounds N] [-seed N] [-ox] [-keep DIR]
#
# -ox also runs the OxCaml mutants, with the 5.2.0+ox switch's ocamlfind on
# PATH for the fuzz run only. Exits 1 if a mutant survives, or if a mutant
# no longer applies because the code it edits has changed.
set -euo pipefail

rounds=20 seed=1 ox=0 keep=""
while [ $# -gt 0 ]; do
  case "$1" in
    -rounds) rounds=$2; shift 2 ;;
    -seed) seed=$2; shift 2 ;;
    -ox) ox=1; shift ;;
    -keep) keep=$2; shift 2 ;;
    *) echo "usage: $0 [-rounds N] [-seed N] [-ox] [-keep DIR]" >&2; exit 2 ;;
  esac
done

root=$(cd "$(dirname "$0")/.." && pwd)
work=${keep:-$(mktemp -d "${TMPDIR:-/tmp}/lense-mutate.XXXXXX")}
mkdir -p "$work"
rsync -a --delete --exclude _build --exclude .git --exclude .claude \
  --exclude web/node_modules --exclude web/dist "$root/" "$work/"
cd "$work"

# The Nix dev shell's OCAMLPATH clashes with opam's stdlib.
unset OCAMLPATH
build() {
  dune build --root . ./test/fuzz/fuzz.exe @vendor/oxcaml/stdlib/cmi/all > build.log 2>&1 ||
    { grep -v "^ld: warning" build.log >&2; return 1; }
}
fuzz_55() { ./_build/default/test/fuzz/fuzz.exe -rounds "$rounds" -seed "$seed"; }
fuzz_ox() {
  PATH=$(opam var --switch=5.2.0+ox bin):$PATH ./_build/default/test/fuzz/fuzz.exe \
    -rounds "$rounds" -seed "$seed" -ox-stdlib _build/default/vendor/oxcaml/stdlib/cmi
}

echo "building in $work"
build
for run in fuzz_55 $([ $ox = 1 ] && echo fuzz_ox); do
  if ! $run > baseline.log; then
    echo "the unmutated fuzz run fails ($run); see $work/baseline.log" >&2
    exit 1
  fi
done

survived=0 stale=0

# mutant COMPILERS FILE DESCRIPTION FROM TO
# COMPILERS is 55, ox or both. FROM must occur exactly once in FILE.
mutant() {
  local compilers=$1 file=$2 desc=$3
  [ "$compilers" = ox ] && [ $ox = 0 ] && return
  cp "$file" "$file.orig"
  if ! FROM=$4 TO=$5 perl -0777 -i -pe \
    '$c += s/\Q$ENV{FROM}\E/$ENV{TO}/g; END { exit($c == 1 ? 0 : 3) }' "$file"; then
    mv "$file.orig" "$file"
    printf 'STALE     %s (%s no longer has the code it edits)\n' "$desc" "$file"
    stale=$((stale + 1))
    return
  fi
  if ! build; then
    mv "$file.orig" "$file"
    printf "STALE     %s (the mutant does not compile)\n" "$desc"
    stale=$((stale + 1))
    build
    return
  fi
  local runs=() caught=0 total=0
  case $compilers in
    55) runs=(fuzz_55) ;;
    ox) runs=(fuzz_ox) ;;
    both) runs=(fuzz_55 $([ $ox = 1 ] && echo fuzz_ox)) ;;
  esac
  for run in "${runs[@]}"; do
    local log="mutant-$total.log"
    if ! $run > "$log" 2>&1; then caught=$((caught + 1)); fi
    total=$((total + 1))
  done
  mv "$file.orig" "$file"
  if [ $caught -gt 0 ]; then
    printf 'killed    %s\n' "$desc"
  else
    printf 'SURVIVED  %s\n' "$desc"
    survived=$((survived + 1))
  fi
}

mutant both src/core/cost.ml "a boxed float costs 3 words" \
  'boxed_float = M.fixed (1 + (8 / M.word_bytes))' \
  'boxed_float = M.fixed (2 + (8 / M.word_bytes))'
mutant both src/core/cost.ml "a polymorphic variant block loses its header" \
  'let block ty = M.add (M.fixed 3) (down ty)' \
  'let block ty = M.add (M.fixed 2) (down ty)'
mutant both src/core/word.ml "a one-constructor variant gets tag 1" \
  '| 0, 1 -> ptr ~tag:0 name' \
  '| 0, 1 -> ptr ~tag:1 name'
mutant both src/core/word.ml "constant constructors become pointers" \
  '| _, 0 -> M.Immediate ("constant constructors of " ^ name)' \
  '| _, 0 -> ptr ("constant constructors of " ^ name)'
mutant 55 src/core/compat_55.ml "constructor fields are reversed" \
  '| Cstr_block tag -> Block { tag; fields }' \
  '| Cstr_block tag -> Block { tag; fields = List.rev fields }'
mutant both src/core/values.ml "the closure environment is reversed" \
  'env = List.map (capture ctx tbl) fv' \
  'env = List.rev (List.map (capture ctx tbl) fv)'
mutant both src/core/values.ml "objects never get an environment slot" \
  'let env_slot =
      (not top)' \
  'let env_slot =
      false && (not top)'
mutant both src/core/values.ml "a constant lazy value is suspended" \
  '| `Constant_or_function | `Identifier `Other -> Itself' \
  '| `Constant_or_function | `Identifier `Other -> Suspended'

echo "$survived survived, $stale stale, from $rounds rounds at seed $seed; logs in $work"
[ $survived = 0 ] && [ $stale = 0 ]
