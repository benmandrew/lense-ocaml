// Messages between the page and the worker that runs lense.

export type Compiler = '5.5' | 'ox';

export interface Options {
  compiler: Compiler;
  intf: boolean;
  values: boolean;
  source: boolean;
  labels: boolean;
}

// Diagrams, as Diagram.json in src/model writes them. Each belongs to the
// card that holds the text line [key], with runs of spaces collapsed.

/** What a cell holds: imm, ptr, any and flat as in the text columns; meta
 *  for headers, code pointers and closinfo; pad for unused bytes. */
export type Kind = 'imm' | 'ptr' | 'any' | 'flat' | 'meta' | 'pad' | '';

export type Shape =
  | { type: 'bytes'; word: number; rows: { offset: number; cells: { label: string; kind: Kind; bytes: number }[] }[] }
  | { type: 'column'; title: string;
      entries: { index: number; label: string; kind: Kind; desc: string; incoming: string | null; target: string | null }[] };

/** [replaces] lists the text rows the diagram shows in full, with runs of
 *  spaces collapsed; the page draws the diagram in their place. */
export interface Diagram { key: string; diagram: Shape; replaces: string[] }

export type Result = { text: string; diagrams: Diagram[] } | { error: string };

export type ToWorker =
  | { type: 'init'; url: string }
  | { type: 'analyze'; id: number; code: string; options: Options };

export type FromWorker =
  | { type: 'ready'; ms: number }
  | { type: 'fatal'; message: string }
  | { type: 'result'; id: number; result: Result; ms: number };
