(* The model as JSON. Hand-written so the model library has no dependencies. *)

open Model

type t =
  | Null
  | Bool of bool
  | Int of int
  | Str of string
  | List of t list
  | Obj of (string * t) list

let escape s =
  let b = Buffer.create (String.length s + 2) in
  String.iter
    (function
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | c when Char.code c < 0x20 -> Printf.bprintf b "\\u%04x" (Char.code c)
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let rec write b ~indent v =
  let nl n =
    Buffer.add_char b '\n';
    Buffer.add_string b (String.make n ' ')
  in
  match v with
  | Null -> Buffer.add_string b "null"
  | Bool x -> Buffer.add_string b (string_of_bool x)
  | Int n -> Buffer.add_string b (string_of_int n)
  | Str s -> Printf.bprintf b "\"%s\"" (escape s)
  | List [] -> Buffer.add_string b "[]"
  | Obj [] -> Buffer.add_string b "{}"
  (* An object of numbers, such as a range, on one line. *)
  | Obj kvs when List.for_all (function _, Int _ -> true | _ -> false) kvs ->
      Buffer.add_char b '{';
      List.iteri
        (fun i (k, x) ->
          if i > 0 then Buffer.add_string b ", ";
          Printf.bprintf b "\"%s\": " (escape k);
          write b ~indent x)
        kvs;
      Buffer.add_char b '}'
  (* A list of numbers on one line. *)
  | List xs when List.for_all (function Int _ -> true | _ -> false) xs ->
      Buffer.add_char b '[';
      List.iteri
        (fun i x ->
          if i > 0 then Buffer.add_string b ", ";
          write b ~indent x)
        xs;
      Buffer.add_char b ']'
  | List xs ->
      Buffer.add_char b '[';
      List.iteri
        (fun i x ->
          if i > 0 then Buffer.add_char b ',';
          nl (indent + 2);
          write b ~indent:(indent + 2) x)
        xs;
      nl indent;
      Buffer.add_char b ']'
  | Obj kvs ->
      Buffer.add_char b '{';
      List.iteri
        (fun i (k, x) ->
          if i > 0 then Buffer.add_char b ',';
          nl (indent + 2);
          Printf.bprintf b "\"%s\": " (escape k);
          write b ~indent:(indent + 2) x)
        kvs;
      nl indent;
      Buffer.add_char b '}'

let opt f = function None -> Null | Some x -> f x

(* Columns count bytes from 0; the end is exclusive. *)
let range =
  opt (fun r ->
      Obj
        [
          ("line", Int r.first_line);
          ("column", Int r.first_col);
          ("end_line", Int r.last_line);
          ("end_column", Int r.last_col);
        ])

let word = function
  | Immediate why -> Obj [ ("kind", Str "immediate"); ("why", Str why) ]
  | Pointer { tag; what } ->
      Obj
        [
          ("kind", Str "pointer");
          ("tag", opt (fun t -> Int t) tag);
          ("what", Str what);
        ]
  | Any why -> Obj [ ("kind", Str "any"); ("why", Str why) ]
  | Double -> Obj [ ("kind", Str "double") ]
  | Flat { layout; bytes } ->
      Obj [ ("kind", Str "flat"); ("layout", Str layout); ("bytes", Int bytes) ]

let rec cost (c : cost) =
  Obj
    [
      ("words", List (List.map (fun n -> Int n) c.words));
      ("range", Bool c.range);
      ( "not_counted",
        List
          (List.map
             (fun p ->
               Obj [ ("what", Str p.what); ("per_node", opt cost p.per_node) ])
             c.uncounted) );
      ("nodes", Bool c.nodes);
    ]

let field (f : field) =
  let kind =
    match f.fkind with
    | Label l -> [ ("kind", Str "label"); ("name", Str l) ]
    | Arg -> [ ("kind", Str "arg") ]
    | Slot c -> [ ("kind", Str "slot"); ("constructor", Str c) ]
    | Hash h -> [ ("kind", Str "hash"); ("hash", Int h) ]
  in
  Obj
    (kind
    @ [
        ("type", Str f.ty);
        ("mutable", Bool f.mutable_);
        ("word", word f.word);
        ("owns", cost f.owns);
        ("range", range f.frange);
      ])

let shape_kvs = function
  | Constant n -> Obj [ ("kind", Str "immediate"); ("value", Int n) ]
  | Block { tag; fields } ->
      Obj
        [
          ("kind", Str "block");
          ("tag", Int tag);
          ("size", Int (List.length fields));
          ("fields", List (List.map field fields));
        ]
  | Flat_float fields ->
      Obj
        [
          ("kind", Str "block");
          ("tag", Int double_array_tag);
          ("size", Int (List.length fields));
          ("flat_float", Bool true);
          ("fields", List (List.map field fields));
        ]
  | Unboxed f -> Obj [ ("kind", Str "unboxed"); ("field", field f) ]
  | Ext_slot ->
      Obj
        [
          ("kind", Str "block");
          ("tag", Int object_tag);
          ("size", Int 2);
          ("extension_slot", Bool true);
        ]
  | Rebind p -> Obj [ ("kind", Str "rebind"); ("of", Str p) ]
  | Product fs ->
      Obj
        [
          ("kind", Str "unboxed_product"); ("fields", List (List.map field fs));
        ]
  | Mixed { tag; fields; scanned; slots } ->
      let slot (s : mixed_slot) o =
        Obj
          [
            ("field", Int s.field);
            ("part", Str s.part);
            ("part_type", Str s.pty);
            ("word", word s.mword);
            ("words", Int s.words);
            ("data_bytes", Int s.data);
            ("offset", Int o);
          ]
      in
      Obj
        [
          ("kind", Str "mixed");
          ("tag", Int tag);
          ("size", Int (mixed_size slots));
          ("scanned", Int scanned);
          ("fields", List (List.map field fields));
          ("slots", List (List.map2 slot slots (mixed_offsets slots)));
        ]

(* Each shape with the words a value of it takes. *)
let shape s =
  match shape_kvs s with
  | Obj kvs -> Obj (kvs @ [ ("cost", opt cost (shape_cost s)) ])
  | j -> j

let strs l = List (List.map (fun s -> Str s) l)

let case (c : case) =
  Obj
    [
      ("name", Str c.name);
      ("shape", shape c.shape);
      ("notes", strs c.notes);
      ("range", range c.case_range);
    ]

let decl (d : decl) =
  let kind =
    match d.kind with
    | Record s -> [ ("kind", Str "record"); ("shape", shape s) ]
    | Variant cs ->
        [ ("kind", Str "variant"); ("cases", List (List.map case cs)) ]
    | Polyvariant { cases; closed } ->
        [
          ("kind", Str "polymorphic_variant");
          ("closed", Bool closed);
          ("cases", List (List.map case cases));
        ]
    | Extension c -> [ ("kind", Str "extension"); ("case", case c) ]
    | Alias w -> [ ("kind", Str "alias"); ("word", word w) ]
    | Abstract w -> [ ("kind", Str "abstract"); ("word", word w) ]
    | Open -> [ ("kind", Str "open") ]
  in
  Obj
    ([
       ("name", Str d.name);
       ("params", Str d.params);
       ("keyword", Str d.keyword);
       ("line", Int d.line);
     ]
    @ kind
    @ [ ("notes", strs d.notes); ("range", range d.range) ])

let slot_kind = function
  | Value -> "value"
  | Module -> "module"
  | Functor -> "functor"
  | Exception -> "exception"
  | Extension -> "extension"
  | Class -> "class"
  | Primitive -> "external"

let package (m : package) =
  Obj
    [
      ("name", Str m.pname);
      ("line", Int m.pline);
      ("size", Int (List.length m.slots));
      ( "fields",
        List
          (List.map
             (fun (s : slot) ->
               Obj
                 [
                   ("index", Int s.index);
                   ("item", Str (slot_kind s.item));
                   ("name", Str s.name);
                   ("word", word s.word);
                   ("range", range s.srange);
                 ])
             m.slots) );
      ("no_field", strs m.no_slot);
      ("range", range m.prange);
    ]

let label (l : label_use) =
  Obj
    [
      ("label", Str l.label);
      ("hash", Int l.hash);
      ("file", Str l.file);
      ("line", Int l.lline);
    ]

let closure ~native (c : closure) =
  let offs, envstart = closure_offsets ~native c in
  Obj
    [
      ("size", Int (closure_size ~native c));
      ("env_start", Int envstart);
      ( "functions",
        List
          (List.map2
             (fun (f : fn) off ->
               Obj
                 [
                   ("name", Str f.fname);
                   ("line", Int f.fline);
                   ("arity", Int f.arity);
                   ("tupled", Bool f.tupled);
                   ("offset", Int off);
                   ("code_words", Int (code_words ~native f));
                   ("range", range f.fn_range);
                 ])
             c.fns offs) );
      ( "env",
        List
          (List.map
             (fun (cv : capture) ->
               Obj
                 [
                   ("name", Str cv.cvar);
                   ("type", Str cv.cty);
                   ("word", word cv.cword);
                   ("bound_at", range cv.cv_range);
                 ])
             c.env) );
    ]

let backend (bc : backend_closures) =
  Obj
    [
      ("backend", Str bc.backend);
      ("config", Str bc.config);
      ( "closures",
        opt
          (fun cs ->
            List (List.map (closure ~native:(bc.backend = "native code")) cs))
          bc.closures );
    ]

let lazy_value (z : lazy_value) =
  let kind (backend, k) =
    Obj
      [
        ("backend", Str backend);
        ( "kind",
          Str
            (match k with
            | Itself -> "itself"
            | Forward -> "forward"
            | Suspended -> "lazy") );
      ]
  in
  Obj
    [
      ("line", Int z.zline);
      ("source", Str z.zsource);
      ("kinds", List (List.map kind z.zkinds));
      ("word", word z.zword);
      ("range", range z.zrange);
    ]

let obj (o : obj) =
  Obj
    [
      ("name", Str o.oname);
      ("line", Int o.oline);
      ("env_slot", Bool o.env_slot);
      ( "vars",
        List
          (List.map
             (fun (v : ivar) ->
               Obj
                 [
                   ("name", Str v.vname);
                   ("type", Str v.vty);
                   ("mutable", Bool v.vmutable);
                   ("parameter", Bool v.vparam);
                   ("from", Str v.vfrom);
                   ("word", word v.vword);
                   ("range", range v.vrange);
                 ])
             o.ivars) );
      ("unknown", strs o.unknown);
      ("range", range o.orange);
    ]

let values (v : values) =
  Obj
    [
      ("closures", List (List.map backend v.backends));
      ("lazy", List (List.map lazy_value v.lazies));
      ("objects", List (List.map obj v.objects));
    ]

let compunit (u : compunit) =
  Obj
    ([
       ("file", Str u.file);
       ("unit", Str u.unit_name);
       ("types", List (List.map decl u.decls));
       ("packages", List (List.map package u.packages));
       ("labels", List (List.map label u.labels));
     ]
    @ match u.values with Some v -> [ ("values", values v) ] | None -> [])

let render units =
  let collisions =
    List.map
      (fun (h, ls) ->
        Obj [ ("hash", Int h); ("labels", List (List.map label ls)) ])
      (Model.collisions units)
  in
  let b = Buffer.create 4096 in
  write b ~indent:0
    (Obj
       [
         ("word_size", Int Model.word_size);
         ("units", List (List.map compunit units));
         ("collisions", List collisions);
       ]);
  Buffer.add_char b '\n';
  Buffer.contents b
