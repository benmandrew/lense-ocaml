// Messages between the page and the worker that runs lense.

export type Compiler = '5.5' | 'ox';

export interface Options {
  compiler: Compiler;
  intf: boolean;
  values: boolean;
  labels: boolean;
}

/** Where something is written in the source. Lines count from 1, columns
 *  from 0 in UTF-8 bytes; the end is exclusive. */
export interface Range { line: number; column: number; end_line: number; end_column: number }

// Diagrams, as Diagram.json in src/model writes them. Each belongs to the
// card that holds the text line [key], with runs of spaces collapsed. Each
// cell carries the source ranges of what it stands for.

/** What a cell holds: imm, ptr, any and flat as in the text columns; meta
 *  for headers, code pointers and closinfo; pad for unused bytes. */
export type Kind = 'imm' | 'ptr' | 'any' | 'flat' | 'meta' | 'pad' | '';

export type Shape =
  | { type: 'bytes'; word: number;
      rows: { offset: number; cells: { label: string; kind: Kind; bytes: number; ranges: Range[] }[] }[] }
  | { type: 'column'; title: string;
      entries: { index: number; label: string; kind: Kind; desc: string; incoming: string | null; target: string | null;
                 ranges: Range[] }[] };

/** [replaces] lists the text rows the diagram shows in full, with runs of
 *  spaces collapsed; the page draws the diagram in their place. */
export interface Diagram { key: string; diagram: Shape; replaces: string[] }

/** [links] gives the source ranges of lines of [text], by line index from 0. */
export type Result = { text: string; links: [number, Range[]][]; diagrams: Diagram[] } | { error: string };

export type ToWorker =
  | { type: 'init'; url: string }
  | { type: 'analyze'; id: number; code: string; options: Options };

export type FromWorker =
  | { type: 'ready'; ms: number }
  | { type: 'fatal'; message: string }
  | { type: 'result'; id: number; result: Result; ms: number };
