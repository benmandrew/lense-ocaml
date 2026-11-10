// lense_web.js comes from `dune build web/jsoo/lense_web.bc.js`. Set
// LENSE_JS to use a build other than ../_build/default.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { defineConfig, type Plugin } from 'vite';

const js = resolve(import.meta.dirname, process.env.LENSE_JS ?? '../_build/default/web/jsoo/lense_web.bc.js');

function read(): Buffer {
  if (!existsSync(js)) throw new Error(`${js} is missing: run dune build web/jsoo/lense_web.bc.js or set LENSE_JS`);
  return readFileSync(js);
}

// Serves the script at lense/lense_web.js in development and copies it into
// the build. Vite must not bundle it: it is a classic script, 54 MB from a
// dev build of lense_web and 6.1 MB from --profile release.
function lenseScript(): Plugin {
  return {
    name: 'lense-script',
    configureServer(server) {
      server.middlewares.use('/lense/lense_web.js', (_req, res) => {
        res.setHeader('Content-Type', 'text/javascript');
        res.end(read());
      });
    },
    generateBundle() {
      this.emitFile({ type: 'asset', fileName: 'lense/lense_web.js', source: read() });
    },
  };
}

// The golden-test inputs, offered in the page's Example menu: cases/ for
// OCaml 5.5 and ox/ for OxCaml. Set LENSE_EXAMPLES_DIR to read them from a
// test directory elsewhere.
const examplesDir = resolve(import.meta.dirname, process.env.LENSE_EXAMPLES_DIR ?? '../test');
const exampleDirs = [{ dir: 'cases', ox: false }, { dir: 'ox', ox: true }];
// Examples that need a checkbox on to show what they are about.
const exampleOptions: Record<string, { values?: boolean; labels?: boolean }> = {
  'values.ml': { values: true },
  'polyvariants.ml': { labels: true },
};

function examples(): Plugin {
  const id = 'virtual:examples';
  return {
    name: 'lense-examples',
    resolveId: (source) => (source === id ? `\0${id}` : undefined),
    load(resolved) {
      if (resolved !== `\0${id}`) return;
      const list = exampleDirs.flatMap(({ dir, ox }) => readdirSync(resolve(examplesDir, dir)).filter((f) => /\.mli?$/.test(f)).sort().map((f) => {
        const path = resolve(examplesDir, dir, f);
        this.addWatchFile(path);
        const { values = false, labels = false } = exampleOptions[f] ?? {};
        return { name: f, intf: f.endsWith('.mli'), ox, values, labels, code: readFileSync(path, 'utf8') };
      }));
      return `export default ${JSON.stringify(list)};`;
    },
  };
}

export default defineConfig({
  base: './',
  plugins: [lenseScript(), examples()],
  worker: { format: 'es' },
  build: { target: 'es2022', chunkSizeWarningLimit: 700 },
});
