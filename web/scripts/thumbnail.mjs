// Renders public/og.png, the README screenshot and link-preview image, from the
// page itself.
//
//   npm run thumbnail
//
// Needs the js_of_ocaml build (see vite.config.ts) and Google Chrome; set
// LENSE_CHROME to the path of another Chromium-based browser.
//
// The page is rendered at 2.25x, then the window is cropped to the source and
// the card: the source column is as wide as its longest line, and the window
// as tall as the taller of the two. The top bar, gutters and colour key are
// hidden to leave the source next to the representations.
import { deflateRawSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';
import { createServer } from 'vite';

const root = fileURLToPath(new URL('..', import.meta.url));
const out = fileURLToPath(new URL('../public/og.png', import.meta.url));

const code = `type shape =
  | Empty
  | Circle of float
  | Rect of float * float`;

// The page state, encoded as main.ts encodes shared links.
const state = {
  code, compiler: '5.5', intf: false, values: false, backend: 'native', labels: false,
};
const hash = deflateRawSync(JSON.stringify(state)).toString('base64url');

// !important throughout: the page's own rules and CodeMirror's theme use
// selectors at least as specific, and the narrow-window layout below 860px
// must be undone.
const css = `
  html, body { height: 100% !important; }
  body { display: flex !important; flex-direction: column !important; }
  .bar { display: none !important; }
  main { flex: 1 !important; grid-template-columns: var(--src, 280px) max-content !important; }
  #editor { height: auto !important; border-bottom: none !important; border-right: 1px solid var(--border) !important; }
  .cm-editor .cm-gutters .cm-foldGutter, .cm-editor .cm-gutters .cm-gutter-lint { display: none !important; }
  .cm-editor .cm-lineNumbers .cm-gutterElement { padding: 0 8px 0 6px !important; }
  .cm-activeLine, .cm-activeLineGutter { background: transparent !important; }
  #output { overflow: hidden !important; padding: 12px !important; }
  .card { margin: 0 !important; padding: 12px 14px !important; width: max-content !important; }
  .legend { display: none !important; }
`;

const server = await createServer({ root, logLevel: 'warn', server: { port: 0 } });
await server.listen();
const browser = await chromium.launch(
  process.env.LENSE_CHROME ? { executablePath: process.env.LENSE_CHROME } : { channel: 'chrome' });
try {
  const page = await browser.newPage({
    viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2.25, colorScheme: 'dark',
  });
  page.on('pageerror', (e) => console.error(e.message));
  await page.goto(`${server.resolvedUrls.local[0]}#${hash}`);
  await page.locator('#output .card').first().waitFor({ timeout: 60_000 });
  await page.addStyleTag({ content: css });
  await page.evaluate(() => document.fonts.ready);
  // Let CodeMirror remeasure after the layout change.
  await page.waitForTimeout(400);
  // Narrow the source column to its longest line, then crop the window to it
  // and the card.
  await page.evaluate(() => {
    const range = document.createRange();
    let right = 0;
    for (const line of document.querySelectorAll('.cm-line')) {
      range.selectNodeContents(line);
      right = Math.max(right, range.getBoundingClientRect().right);
    }
    document.documentElement.style.setProperty('--src', `${Math.ceil(right) + 16}px`);
  });
  await page.waitForTimeout(400);
  const size = await page.evaluate(() => {
    const card = document.querySelector('#output .card').getBoundingClientRect();
    const lines = [...document.querySelectorAll('.cm-line')].at(-1).getBoundingClientRect();
    return {
      width: Math.ceil(card.right) + 12,
      height: Math.ceil(Math.max(card.bottom, lines.bottom)) + 12,
    };
  });
  await page.setViewportSize(size);
  await page.waitForTimeout(400);
  await page.screenshot({ path: out });
  console.log(out);
} finally {
  await browser.close();
  await server.close();
}
