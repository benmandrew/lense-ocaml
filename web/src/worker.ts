/// <reference lib="webworker" />
// Runs lense_web.js (lense_core and compiler-libs, compiled by js_of_ocaml)
// off the main thread. The script is a classic script that sets
// globalThis.lense_analyze, so it is fetched and run with an indirect eval.
import type { FromWorker, Options, Result, ToWorker } from './protocol';

// lense_analyze returns the diagrams as a JSON string.
type Analyze = (code: string, options: Options) => { text: string; diagrams: string } | { error: string };

let url = '';
let loaded: Promise<Analyze> | null = null;

const post = (m: FromWorker) => postMessage(m);

function load(): Promise<Analyze> {
  loaded ??= fetch(url)
    .then((r) => {
      if (!r.ok) throw new Error(`${url}: ${r.status} ${r.statusText}`);
      return r.text();
    })
    .then((text) => {
      (0, eval)(text);
      return (globalThis as unknown as { lense_analyze: Analyze }).lense_analyze;
    });
  return loaded;
}

onmessage = async (e: MessageEvent<ToWorker>) => {
  const msg = e.data;
  const start = performance.now();
  if (msg.type === 'init') {
    url = msg.url;
    try {
      await load();
      post({ type: 'ready', ms: performance.now() - start });
    } catch (err) {
      loaded = null;
      post({ type: 'fatal', message: String(err) });
    }
    return;
  }
  let result: Result;
  try {
    const analyze = await load();
    const r = analyze(msg.code, msg.options);
    result = 'text' in r
      ? { text: String(r.text), diagrams: JSON.parse(String(r.diagrams ?? '[]')) }
      : { error: String(r.error) };
  } catch (err) {
    result = { error: `lense stopped: ${err}` };
  }
  post({ type: 'result', id: msg.id, result, ms: performance.now() - start });
};
