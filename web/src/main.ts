import { HighlightStyle, StreamLanguage, syntaxHighlighting } from '@codemirror/language';
import { oCaml } from '@codemirror/legacy-modes/mode/mllike';
import { type Diagnostic, lintGutter, setDiagnostics } from '@codemirror/lint';
import { tags as t } from '@lezer/highlight';
import { basicSetup, EditorView } from 'codemirror';
import EXAMPLES from 'virtual:examples';
import type { Compiler, Diagram, FromWorker, Kind, Options, Shape, ToWorker } from './protocol';
import './style.css';

const SAMPLE = `(* Edit the code: the representations update as you type. *)
type shape =
  | Point
  | Circle of float
  | Rect of { w : float; h : float }

type colour = Red | Green | Blue

type vec = { x : float; y : float; z : float }

type id = Id of int [@@unboxed]

module Counter = struct
  let count = ref 0
  let next () = incr count; !count
end

let area = function
  | Point -> 0.
  | Circle r -> 3.14159 *. r *. r
  | Rect { w; h } -> w *. h
`;

interface Saved {
  code: string;
  compiler: Compiler;
  intf: boolean;
  values: boolean;
  source: boolean;
  labels: boolean;
}

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const exampleBox = $<HTMLSelectElement>('example');
const kindBox = $<HTMLSelectElement>('kind');
const compilerBox = $<HTMLSelectElement>('compiler');
const valuesBox = $<HTMLInputElement>('values');
const sourceBox = $<HTMLInputElement>('source');
const labelsBox = $<HTMLInputElement>('labels');
const statusBox = $<HTMLSpanElement>('status');
const output = $<HTMLElement>('output');

function el<K extends keyof HTMLElementTagNameMap>(tag: K, cls = '', text = '') {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text) e.textContent = text;
  return e;
}

// --- Saving the state in the URL -------------------------------------------

function toB64(b: Uint8Array): string {
  let s = '';
  for (const c of b) s += String.fromCharCode(c);
  return btoa(s).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
const fromB64 = (s: string) =>
  Uint8Array.from(atob(s.replaceAll('-', '+').replaceAll('_', '/')), (c) => c.charCodeAt(0));

const through = (data: BlobPart, stream: CompressionStream | DecompressionStream) =>
  new Response(new Blob([data]).stream().pipeThrough(stream));

async function pack(s: Saved): Promise<string> {
  const deflated = through(JSON.stringify(s), new CompressionStream('deflate-raw'));
  return toB64(new Uint8Array(await deflated.arrayBuffer()));
}

async function unpack(hash: string): Promise<Saved | null> {
  try {
    return JSON.parse(await through(fromB64(hash), new DecompressionStream('deflate-raw')).text());
  } catch {
    return null;
  }
}

function current(): Saved {
  return {
    code: view.state.doc.toString(),
    compiler: compilerBox.value === 'ox' ? 'ox' : '5.5',
    intf: kindBox.value === 'mli',
    values: valuesBox.checked,
    source: sourceBox.checked,
    labels: labelsBox.checked,
  };
}

const options = (s: Saved): Options => ({
  compiler: s.compiler, intf: s.intf, values: s.values, source: s.source, labels: s.labels,
});

// --- Diagnostics ----------------------------------------------------------

// The compiler's report: File "example.ml", line 3, characters 4-9:
// or lines 3-5, characters 4-2: then the message.
const LOC = /^File "[^"]*", lines? (\d+)(?:-(\d+))?, characters (\d+)-(\d+):\n?/;

function diagnostic(error: string): { diag: Diagnostic | null; line: number } {
  const m = LOC.exec(error);
  if (!m) return { diag: null, line: 0 };
  const doc = view.state.doc;
  const clampLine = (n: number) => doc.line(Math.min(Math.max(n, 1), doc.lines));
  const first = clampLine(Number(m[1]));
  const last = clampLine(Number(m[2] ?? m[1]));
  const from = Math.min(first.from + Number(m[3]), first.to);
  const to = Math.max(Math.min(last.from + Number(m[4]), last.to), from);
  const message = error.slice(m[0].length).replace(/^Error: /, '').trim();
  return { diag: { from, to: to > from ? to : Math.min(from + 1, doc.length), severity: 'error', message, source: 'ocaml' }, line: first.number };
}

// --- Output ---------------------------------------------------------------

// The text report separates its columns with two or more spaces. Each column
// is coloured by what it says: an index, a label, or a representation.

/** The class for a column that describes a representation, or null. */
function kind(s: string): string | null {
  if (/^immediate or pointer/.test(s)) return 'k-any';
  if (/^immediate\b/.test(s)) return 'k-imm';
  if (/^(unboxed|no block|no copy)\b/.test(s)) return 'k-flat';
  if (/^(pointer|block|flat float block|mixed block|structure block|extension slot)\b/.test(s)
      || /^[A-Z][a-z_]*_tag \d+/.test(s) || /^one [A-Z][a-z_]*_tag \d+ block/.test(s)) return 'k-ptr';
  return null;
}

const KEYWORD = /^(mutable|val|module|functor|exception|extension|class|external|type)\b\s*/;
const TAG = /\b(?:[A-Z][a-z_]*_tag \d+|tags? \d+(?:-\d+)?)/g;

/** Text with each block tag in it set in bold. */
function tagged(s: string, cls: string): HTMLElement {
  const span = el('span', cls);
  let last = 0;
  for (const m of s.matchAll(TAG)) {
    span.append(s.slice(last, m.index), el('b', '', m[0]));
    last = m.index + m[0].length;
  }
  span.append(s.slice(last));
  return span;
}

/** A label column: an optional keyword, a name, then ": type". */
function label(s: string, first: boolean): (Node | string)[] {
  const out: Node[] = [];
  const kw = KEYWORD.exec(s);
  if (kw) {
    out.push(el('span', 'k-kw', kw[0]));
    s = s.slice(kw[0].length);
  }
  const colon = s.indexOf(' : ');
  const name = colon < 0 ? s : s.slice(0, colon);
  out.push(el('span', first && !kw ? 'k-ctor' : 'k-name', name));
  if (colon >= 0) out.push(el('span', 'k-type', s.slice(colon)));
  return out;
}

function line(text: string): (Node | string)[] {
  const lead = text.length - text.trimStart().length;
  const rest = text.slice(lead);
  if (/^(note|no field|then)\b/.test(rest)) return [text.slice(0, lead), el('span', 'k-note', rest)];
  const out: (Node | string)[] = [text.slice(0, lead)];
  // A label that starts its row, with no index before it, names a constructor.
  let first = true;
  for (const part of rest.split(/(\s{2,})/)) {
    if (/^\s*$/.test(part)) {
      out.push(part);
      continue;
    }
    const k = kind(part);
    if (/^(\d+(-\d+)?|-|\d+ <- (\d+|-)|line \d+|header)$/.test(part)) out.push(el('span', 'k-index', part));
    else if (k) out.push(tagged(part, k));
    else if (/^\(.*\)$/.test(part)) out.push(el('span', 'k-note', part));
    else out.push(...label(part, first));
    first = false;
  }
  return out;
}

function legend(): HTMLElement {
  const p = el('p', 'legend');
  for (const [cls, name, what] of [
    ['k-imm', 'immediate', 'the value is in the word itself, with no allocation'],
    ['k-ptr', 'block or pointer', 'the word points to a block on the heap'],
    ['k-flat', 'unboxed', 'the value is stored in place, with no pointer'],
    ['k-any', 'immediate or pointer', 'it depends on the value'],
  ]) {
    const s = el('span', cls, `■ ${name}`);
    s.title = what;
    p.append(s);
  }
  return p;
}

const squeeze = (s: string) => s.trim().replace(/ +/g, ' ');

/** Diagrams by the text line they belong to, each list in report order. */
function byKey(diagrams: Diagram[]): Map<string, Diagram[]> {
  const m = new Map<string, Diagram[]>();
  for (const d of diagrams) m.set(d.key, [...(m.get(d.key) ?? []), d]);
  return m;
}

// --- Diagrams --------------------------------------------------------------

// Cells are filled as in lense's byte map: green, orange and blue for
// immediates, pointers and unboxed data, with dark text on them.

/** A cell. With [desc], a screen reader hears that in place of the label:
 *  the text row the cell stands for, which says what the fill shows. */
function seg(label: string, kind: Kind, desc = ''): HTMLElement {
  const s = el('span', `seg d-${kind || 'plain'}`);
  s.title = desc || label;
  if (!desc) s.textContent = label;
  else {
    const shown = el('span', '', label);
    shown.setAttribute('aria-hidden', 'true');
    s.append(shown, el('span', 'sr', desc));
  }
  return s;
}

const hidden = <E extends Element>(e: E): E => (e.setAttribute('aria-hidden', 'true'), e);

/** A mixed block, a row per word, as lense draws a struct. */
function byteMap(d: Extract<Shape, { type: 'bytes' }>): HTMLElement {
  // The text rows stay beside a byte map, so screen readers skip it.
  const map = hidden(el('div', 'bytemap'));
  map.style.setProperty('--bytes', String(d.word));
  const marks = el('div', 'marks');
  for (let b = 0; b < d.word; b++) marks.append(el('span', '', `+${b}`));
  const ruler = el('div', 'row');
  ruler.append(el('span', 'off'), marks);
  map.append(ruler);
  for (const r of d.rows) {
    const row = el('div', 'row');
    const cells = el('div', 'cells');
    for (const c of r.cells) {
      const s = seg(c.label, c.kind);
      s.style.gridColumn = `span ${c.bytes}`;
      cells.append(s);
    }
    row.append(el('span', 'off', String(r.offset)), cells);
    map.append(row);
  }
  return map;
}

/** A block as a column of words: the pointers that enter it on the left,
 *  the blocks its words point to on the right. */
function column(d: Extract<Shape, { type: 'column' }>): HTMLElement {
  const g = el('div', 'column');
  const left = d.entries.some((e) => e.incoming);
  if (!left) g.classList.add('no-in');
  // The title sits over the words; empty cells fill the rest of its row.
  const blank = (n: number) => Array.from({ length: n }, () => el('span'));
  g.append(...blank(left ? 3 : 1), el('span', 'title', d.title), ...blank(2));
  for (const e of d.entries) {
    // The arrows and the boxes at their ends repeat what desc says.
    if (left) g.append(hidden(e.incoming ? el('span', 'incoming', e.incoming) : el('span')), hidden(el('span', e.incoming ? 'arrow' : '')));
    g.append(el('span', 'off', String(e.index)), seg(e.label, e.kind, e.desc),
             hidden(el('span', e.target ? 'arrow' : '')), hidden(e.target ? el('span', 'target', e.target) : el('span')));
  }
  return g;
}

function diagram(d: Shape): HTMLElement {
  const box = el('div', 'diagram');
  box.append(d.type === 'bytes' ? byteMap(d) : column(d));
  return box;
}

/** One card per paragraph of the text report. The first line is the
 *  heading: its name, then the description after two spaces. A diagram
 *  follows the text of the card that holds its line. */
function render(text: string, diagrams: Diagram[] = []) {
  const pending = byKey(diagrams);
  output.replaceChildren(legend());
  for (const para of text.split(/\n\s*\n/)) {
    const lines = para.replace(/\s+$/, '').split('\n');
    if (!lines[0]) continue;
    const card = el('article', 'card');
    const head = lines[0].trim();
    const cut = head.indexOf('  ');
    const h = el('h2');
    if (cut > 0) h.append(el('span', 'name', head.slice(0, cut)), el('span', 'desc', head.slice(cut).trimStart()));
    else h.append(el('span', 'name', head));
    card.append(h);
    // A diagram keyed by the heading belongs to the whole card, one keyed by
    // a body line to the rows below it: those up to the next line indented
    // no further. It takes the place of the rows it replaces, and otherwise
    // follows its rows.
    type Scope = { d: Diagram; depth: number; drop: Set<string>; placed: boolean };
    const open = (d: Diagram, depth: number): Scope => ({ d, depth, drop: new Set(d.replaces), placed: false });
    const take = (l: string) => pending.get(squeeze(l))?.shift();
    const first = take(lines[0]);
    const whole = first && open(first, -1);
    // Strip the indent the body shares, so it starts at the card's edge.
    const body = lines.slice(1);
    const indent = Math.min(...body.filter((l) => l.trim()).map((l) => l.length - l.trimStart().length));
    const depth = (l: string) => l.length - l.trimStart().length;
    let pre = el('pre');
    const flush = () => {
      if (pre.childNodes.length) card.append(pre);
      pre = el('pre');
    };
    const place = (sc: Scope) => {
      if (sc.placed) return;
      flush();
      card.append(diagram(sc.d.diagram));
      sc.placed = true;
    };
    let held: Scope | undefined;
    for (const l of body) {
      if (held && l.trim() && depth(l) <= held.depth) {
        place(held);
        held = undefined;
      }
      const k = squeeze(l);
      const owner = held?.drop.has(k) ? held : whole?.drop.has(k) ? whole : undefined;
      if (owner) {
        owner.drop.delete(k);
        place(owner);
        continue;
      }
      pre.append(...(pre.childNodes.length ? ['\n'] : []), ...line(l.slice(indent)));
      const d = take(l);
      if (d) held = open(d, depth(l));
    }
    flush();
    if (held) place(held);
    if (whole) place(whole);
    output.append(card);
  }
}

// --- Editor ---------------------------------------------------------------

const highlight = HighlightStyle.define([
  { tag: t.keyword, color: 'var(--syn-keyword)' },
  { tag: [t.typeName, t.className], color: 'var(--syn-type)' },
  { tag: t.string, color: 'var(--syn-string)' },
  { tag: [t.number, t.bool, t.atom], color: 'var(--syn-number)' },
  { tag: t.comment, color: 'var(--syn-comment)', fontStyle: 'italic' },
  { tag: [t.variableName, t.propertyName], color: 'var(--syn-variable)' },
  { tag: [t.operator, t.punctuation], color: 'var(--syn-operator)' },
]);

const theme = EditorView.theme({
  '&': { height: '100%', backgroundColor: 'var(--code-bg)', color: 'var(--ink-2)' },
  '.cm-scroller': { fontFamily: 'var(--mono)', fontSize: '13.5px', lineHeight: '1.55' },
  '.cm-gutters': { backgroundColor: 'var(--code-bg)', color: 'var(--muted)', border: 'none' },
  '.cm-activeLine, .cm-activeLineGutter': { backgroundColor: 'var(--active-line)' },
  '.cm-cursor': { borderLeftColor: 'var(--ink)' },
  '&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection':
    { backgroundColor: 'var(--selection) !important' },
  '.cm-tooltip': { backgroundColor: 'var(--surface)', border: '1px solid var(--border)', color: 'var(--ink-2)' },
}, { dark: true });

let timer = 0;
const view = new EditorView({
  parent: $('editor'),
  extensions: [
    basicSetup, StreamLanguage.define(oCaml), syntaxHighlighting(highlight), theme, lintGutter(),
    EditorView.updateListener.of((u) => {
      if (!u.docChanged) return;
      clearTimeout(timer);
      timer = setTimeout(analyze, 250);
    }),
  ],
});

// --- Worker ---------------------------------------------------------------

const worker = new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' });
let ready = false, busy = false, seq = 0;
let queued: ToWorker | null = null;

/** Posts msg, or the one held back, once the worker is free. A newer
 *  message replaces a held one. */
function send(msg?: ToWorker) {
  if (msg) queued = msg;
  if (!ready || busy || !queued) return;
  busy = true;
  worker.postMessage(queued);
  queued = null;
}

const examples = [{ name: 'sample', intf: false, ox: false, code: SAMPLE }, ...EXAMPLES];

/** Selects the example the editor holds, or "edited" if it holds none. */
function syncExample(code: string) {
  exampleBox.value = examples.find((e) => e.code === code)?.name ?? '';
}

async function analyze() {
  const s = current();
  syncExample(s.code);
  send({ type: 'analyze', id: ++seq, code: s.code, options: options(s) });
  history.replaceState(null, '', `#${await pack(s)}`);
}

function status(text: string, error = false) {
  statusBox.textContent = text;
  statusBox.classList.toggle('error', error);
}

worker.onmessage = (ev: MessageEvent<FromWorker>) => {
  const m = ev.data;
  switch (m.type) {
    case 'ready':
      ready = true;
      status(`compiler-libs ready in ${Math.round(m.ms)} ms`);
      send();
      return;
    case 'fatal':
      status(`Could not load lense: ${m.message}`, true);
      return;
    case 'result': {
      busy = false;
      send();
      if (m.id !== seq) return;
      const r = m.result;
      if ('error' in r) {
        const { diag, line } = diagnostic(r.error);
        view.dispatch(setDiagnostics(view.state, diag ? [diag] : []));
        output.replaceChildren(el('p', 'failure', line ? `The compiler stopped at line ${line}.` : 'lense failed.'),
                               el('pre', 'report', r.error.trim()));
        status('error', true);
      } else {
        view.dispatch(setDiagnostics(view.state, []));
        render(r.text, r.diagrams);
        status(`${Math.round(m.ms)} ms`);
      }
    }
  }
};

// --- Start ----------------------------------------------------------------

/** Replaces the editor text without the typing delay; callers analyze at once. */
function setCode(code: string) {
  view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: code } });
  clearTimeout(timer);
}

async function start() {
  const saved = (location.hash.length > 1 && (await unpack(location.hash.slice(1)))) || null;
  const s: Saved = { code: SAMPLE, compiler: '5.5', intf: false, values: false, source: false, labels: false, ...saved };
  setCode(s.code);
  kindBox.value = s.intf ? 'mli' : 'ml';
  compilerBox.value = s.compiler;
  valuesBox.checked = s.values;
  sourceBox.checked = s.source;
  labelsBox.checked = s.labels;

  const edited = new Option('edited', '');
  edited.hidden = true;
  exampleBox.append(edited, ...examples.map((e) => new Option(e.name, e.name)));
  syncExample(s.code);
  exampleBox.onchange = () => {
    const e = examples.find((x) => x.name === exampleBox.value);
    if (!e) return;
    kindBox.value = e.intf ? 'mli' : 'ml';
    compilerBox.value = e.ox ? 'ox' : '5.5';
    setCode(e.code);
    analyze();
  };
  for (const box of [kindBox, compilerBox, valuesBox, sourceBox, labelsBox]) box.onchange = analyze;

  status('Loading compiler-libs');
  worker.postMessage({ type: 'init', url: new URL('lense/lense_web.js', document.baseURI).href } satisfies ToWorker);
  analyze();
}

start();
