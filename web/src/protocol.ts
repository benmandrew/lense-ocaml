// Messages between the page and the worker that runs lense.

export type Compiler = '5.5' | 'ox';

export interface Options {
  compiler: Compiler;
  intf: boolean;
  values: boolean;
  source: boolean;
  nomodules: boolean;
  labels: boolean;
}

export type Result = { text: string } | { error: string };

export type ToWorker =
  | { type: 'init'; url: string }
  | { type: 'analyze'; id: number; code: string; options: Options };

export type FromWorker =
  | { type: 'ready'; ms: number }
  | { type: 'fatal'; message: string }
  | { type: 'result'; id: number; result: Result; ms: number };
