// Renders public/og.png, the 1800x945 link-preview image, from the page itself.
//
//   npm run thumbnail
//
// Needs the js_of_ocaml build (see vite.config.ts) and Google Chrome; set
// LENSE_CHROME to the path of another Chromium-based browser.
//
// A shrunk screenshot is unreadable, so the page is rendered in an 800x420
// window at 2.25x. The report lines are wider than lense's byte map, so the
// window is wider than lense's 600x315, and the example has two types to fill
// its height. The top bar and gutters are hidden to leave the source next to
// the representations.
import { deflateRawSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';
import { createServer } from 'vite';

const root = fileURLToPath(new URL('..', import.meta.url));
const out = fileURLToPath(new URL('../public/og.png', import.meta.url));

const code = `type id =
  | Id of int [@@unboxed]

type shape =
  | Empty
  | Circle of float
  | Rect of float * float
  | Label of string * shape
  | Point`;

// The page state, encoded as main.ts encodes shared links.
const state = {
  code, compiler: '5.5', intf: false, values: false, source: false, modules: false, labels: false,
};
const hash = deflateRawSync(JSON.stringify(state)).toString('base64url');

// !important throughout: the page's own rules and CodeMirror's theme use
// selectors at least as specific, and the narrow-window layout below 860px
// must be undone.
const css = `
  html, body { height: 100% !important; }
  body { display: flex !important; flex-direction: column !important; }
  .bar { display: none !important; }
  main { flex: 1 !important; grid-template-columns: 280px minmax(0, 1fr) !important; }
  #editor { height: auto !important; border-bottom: none !important; border-right: 1px solid var(--border) !important; }
  .cm-editor .cm-gutters .cm-foldGutter, .cm-editor .cm-gutters .cm-gutter-lint { display: none !important; }
  .cm-editor .cm-lineNumbers .cm-gutterElement { padding: 0 8px 0 6px !important; }
  .cm-activeLine, .cm-activeLineGutter { background: transparent !important; }
  #output { overflow: hidden !important; padding: 12px !important;
            display: flex !important; flex-direction: column !important; justify-content: center !important;
            gap: 12px !important; }
  .card { margin: 0 !important; padding: 12px 14px !important; }
`;

const server = await createServer({ root, logLevel: 'warn', server: { port: 0 } });
await server.listen();
const browser = await chromium.launch(
  process.env.LENSE_CHROME ? { executablePath: process.env.LENSE_CHROME } : { channel: 'chrome' });
try {
  const page = await browser.newPage({
    viewport: { width: 800, height: 420 }, deviceScaleFactor: 2.25, colorScheme: 'dark',
  });
  page.on('pageerror', (e) => console.error(e.message));
  await page.goto(`${server.resolvedUrls.local[0]}#${hash}`);
  await page.locator('#output .card').first().waitFor({ timeout: 60_000 });
  await page.addStyleTag({ content: css });
  await page.evaluate(() => document.fonts.ready);
  // Let CodeMirror remeasure after the layout change.
  await page.waitForTimeout(400);
  await page.screenshot({ path: out });
  console.log(out);
} finally {
  await browser.close();
  await server.close();
}
