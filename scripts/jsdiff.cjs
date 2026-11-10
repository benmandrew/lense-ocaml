// Runs lense_core as the web page does, from web/jsoo/lense_web.bc.js, and
// compares its JSON and text with the native lense-ocaml on the same files.
// Usage:
//   node scripts/jsdiff.cjs BUNDLE CLI COMPILER FILE...
// COMPILER is 5.5 or ox. Each file goes through the backends native, bytecode
// and both, with values shown. The script prints each difference and exits 1
// if there is one.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { spawnSync } = require('child_process');

const [bundle, cli, compiler, ...files] = process.argv.slice(2);
if (!files.length) {
  console.error('usage: node jsdiff.cjs BUNDLE CLI COMPILER FILE...');
  process.exit(2);
}

// The bundle is a classic script that sets globalThis.lense_analyze; the
// worker runs it with an indirect eval. Under node its runtime wants require.
globalThis.require = require;
vm.runInThisContext(fs.readFileSync(bundle, 'utf8'), { filename: bundle });
const analyze = globalThis.lense_analyze;

// The native CLI, run in the file's directory on its base name, so that the
// file names in the JSON are the same as the ones given to the bundle.
function native(file, args) {
  const r = spawnSync(cli, [...args, '--compiler', compiler, path.basename(file)], {
    cwd: path.dirname(file),
    encoding: 'utf8',
    maxBuffer: 1 << 28,
  });
  return r.status === 0 ? { out: r.stdout } : { error: r.stderr };
}

// The first line where two texts differ, with a few lines around it.
function firstDiff(a, b) {
  const la = a.split('\n');
  const lb = b.split('\n');
  let i = 0;
  while (i < la.length && i < lb.length && la[i] === lb[i]) i++;
  const show = (l) => l.slice(Math.max(0, i - 3), i + 3).map((s) => '    ' + s).join('\n');
  return `  first difference at line ${i + 1}\n  native:\n${show(la)}\n  js_of_ocaml:\n${show(lb)}`;
}

let diffs = 0;
let compared = 0;
let rejected = 0;
for (const file of files) {
  const code = fs.readFileSync(file, 'utf8');
  const intf = file.endsWith('.mli');
  for (const backend of ['native', 'bytecode', 'both']) {
    const what = `${file} (${compiler}, ${backend})`;
    let js;
    try {
      js = analyze(code, { compiler, intf, values: true, backend, json: true, file: path.basename(file) });
    } catch (e) {
      js = { error: `lense stopped: ${e}` };
    }
    const nat = native(file, ['--json', '--backend', backend]);
    if ('error' in js || nat.error !== undefined) {
      if ('error' in js && nat.error !== undefined) {
        rejected++;
        continue;
      }
      diffs++;
      console.log(`DIFF ${what}: only one rejects the file`);
      console.log(`  native: ${nat.error ?? 'accepts'}\n  js_of_ocaml: ${js.error ?? 'accepts'}`);
      continue;
    }
    compared++;
    if (String(js.json) !== nat.out) {
      diffs++;
      console.log(`DIFF ${what}: JSON\n${firstDiff(nat.out, String(js.json))}`);
      continue;
    }
    const text = native(file, ['--backend', backend]);
    if (String(js.text) !== text.out) {
      diffs++;
      console.log(`DIFF ${what}: text\n${firstDiff(text.out ?? '', String(js.text))}`);
    }
  }
}
console.log(
  `${compiler}: ${files.length} files, ${compared} runs compared in JSON and text, ` +
    `${rejected} rejected by both, ${diffs} differences`,
);
process.exit(diffs > 0 ? 1 : 0);
