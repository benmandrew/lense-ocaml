OxCaml records and constructors with flat fields are mixed blocks: values
first, then flat data, one word per scalar in native code.

  $ lense-ocaml --compiler ox mixed.ml
  type m  mixed block, tag 0, size 5: 2 scanned fields, then 3 flat
         0-7    header
      0  8-15   a : int     immediate (int)
      1  16-23  c : string  pointer to string, String_tag 252
      2  24-31  b : float#  unboxed float64, 8 bytes
      3  32-35  d : int32#  unboxed bits32, 4 bytes, bytes 36-39 unused
      4  40     f : int8#   unboxed bits8, 1 byte, bytes 41-47 unused
      note: values first, then flat fields, each in declaration order
      note: native code; bytecode stores one boxed field per declared field, in declaration order
      cost: 6 words per value, with headers, in native code
      not counted: c (string)
  
  type u  flat float block, Double_array_tag 254, size 2
      0  x : float#  unboxed double
      1  y : float#  unboxed double
      cost: 3 words per value, with headers
  
  type fm  mixed block, tag 0, size 2: 0 scanned fields, then 2 flat
         0-7    header
      0  8-15   p : float   unboxed float64, boxed again when read, 8 bytes
      1  16-23  q : float#  unboxed float64, 8 bytes
      note: native code; bytecode stores one boxed field per declared field, in declaration order
      cost: 3 words per value, with headers, in native code
  
  type pr  no block: unboxed record, its fields are kept apart or stored in place
      px : int     immediate (int)
      py : float#  unboxed float64, 8 bytes
  
  type withp  mixed block, tag 0, size 6: 3 scanned fields, then 3 flat
         0-7    header
      0  8-15   w0 : string     pointer to string, String_tag 252
      1  16-23  w1.px : int     immediate (int)
      2  24-31  w3.1 : string   pointer to string, String_tag 252
      3  32-39  w1.py : float#  unboxed float64, 8 bytes
      4  40-47  w2 : int64#     unboxed bits64, 8 bytes
      5  48     w3.0 : int8#    unboxed bits8, 1 byte, bytes 49-55 unused
      note: values first, then flat fields, each in declaration order
      note: native code; bytecode stores one boxed field per declared field, in declaration order
      cost: 7 words per value, with headers, in native code
      not counted: w0 (string), w3 (string)
  
  type v  variant
    A  mixed block, tag 0, size 3: 2 scanned fields, then 1 flat
            0-7    header
         0  8-15   string            pointer to string, String_tag 252
         1  16-23  arg 1.1 : int     immediate (int)
         2  24-31  arg 1.0 : float#  unboxed float64, 8 bytes
         note: values first, then flat fields, each in declaration order
         note: native code; bytecode stores one boxed field per declared field, in declaration order
         cost: 4 words per value, with headers, in native code
         not counted: arg 0 (string)
    B  block, tag 1, size 1
         0  int  immediate (int)
         cost: 2 words per value, with headers
    C  mixed block, tag 2, size 3: 2 scanned fields, then 1 flat
            0-7    header
         0  8-15   s : string    pointer to string, String_tag 252
         1  16-23  n : int       immediate (int)
         2  24-27  t : float32#  unboxed float32, 4 bytes, bytes 28-31 unused
         note: values first, then flat fields, each in declaration order
         note: native code; bytecode stores one boxed field per declared field, in declaration order
         cost: 4 words per value, with headers, in native code
         not counted: s (string)
  
  type t  abstract: unboxed float64, 8 bytes
  
  type i  abstract: immediate (i : immediate)
  
  type al  abbreviation: unboxed bits32, 4 bytes
  
  type o  abbreviation: immediate or pointer (null or int)
  
  type one  no block: unboxed record, its fields are kept apart or stored in place
      one : #(float# * string)  unboxed float64 & value
  
  type sv  no block: unboxed record, its fields are kept apart or stored in place
      sv : string  pointer to string, String_tag 252
  
  type wone  mixed block, tag 0, size 5: 4 scanned fields, then 1 flat
         0-7    header
      0  8-15   o1.one.1 : string  pointer to string, String_tag 252
      1  16-23  o2.0 : int         immediate (int)
      2  24-31  o2.1.sv : string   pointer to string, String_tag 252
      3  32-39  o3 : sv            pointer to string, String_tag 252
      4  40-47  o1.one.0 : float#  unboxed float64, 8 bytes
      note: values first, then flat fields, each in declaration order
      note: native code; bytecode stores one boxed field per declared field, in declaration order
      cost: 6 words per value, with headers, in native code
      not counted: o1 (string), o2 (string), o3 (string)
