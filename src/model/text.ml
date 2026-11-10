(* The model as text. Sizes are in words and leave out the header word, the
   same count that Obj.size reports. *)

open Model

let tag_name t =
  if t = closure_tag then "Closure_tag 247"
  else if t = object_tag then "Object_tag 248"
  else if t = string_tag then "String_tag 252"
  else if t = double_tag then "Double_tag 253"
  else if t = double_array_tag then "Double_array_tag 254"
  else if t = custom_tag then "Custom_tag 255"
  else if t = lazy_tag then "Lazy_tag 246"
  else if t = forward_tag then "Forward_tag 250"
  else if t = infix_tag then "Infix_tag 249"
  else if t = cont_tag then "Cont_tag 245"
  else if t = forcing_tag then "Forcing_tag 244"
  else "tag " ^ string_of_int t

(* The source ranges of the lines written, for render_linked: each mark is
   the buffer offset at which a line's text is written, and its ranges.
   Only the buffer being recorded gets marks. *)
let recording : (Buffer.t * (int * range list) list ref) option ref = ref None

let link b rs =
  match (!recording, List.filter_map Fun.id rs) with
  | Some (rb, marks), (_ :: _ as rs) when rb == b -> marks := (Buffer.length b, rs) :: !marks
  | _ -> ()

let plural n one many = string_of_int n ^ " " ^ if n = 1 then one else many

let word = function
  | Immediate why -> "immediate (" ^ why ^ ")"
  | Pointer { tag = Some t; what } -> "pointer to " ^ what ^ ", " ^ tag_name t
  | Pointer { tag = None; what } -> "pointer to " ^ what
  | Any why -> "immediate or pointer (" ^ why ^ ")"
  | Double -> "unboxed double"
  | Flat { layout; bytes = 0 } -> "unboxed " ^ layout
  | Flat { layout; bytes } -> Printf.sprintf "unboxed %s, %s" layout (plural bytes "byte" "bytes")

let field_label f =
  match f.fkind with
  | Label l -> (if f.mutable_ then "mutable " else "") ^ l ^ " : " ^ f.ty
  | Arg -> f.ty
  | Slot _ -> "slot"
  | Hash h -> "hash " ^ string_of_int h

let pad n s = s ^ String.make (max 0 (n - String.length s)) ' '
let lpad n s = String.make (max 0 (n - String.length s)) ' ' ^ s

(* Rows of "index  label  word", aligned. [indent] is the left margin. *)
let rows b ~indent ?(index = true) (fields : field list) =
  let labels = List.map field_label fields in
  let w = List.fold_left (fun w l -> max w (String.length l)) 0 labels in
  let iw = String.length (string_of_int (List.length fields - 1)) in
  List.iteri
    (fun i ((f : field), l) ->
      let idx = if index then lpad iw (string_of_int i) ^ "  " else "" in
      link b [ f.frange ];
      Printf.bprintf b "%s%s%s  %s\n" (String.make indent ' ') idx (pad w l) (word f.word))
    (List.combine fields labels)

let shape_summary = function
  | Constant n -> "immediate " ^ string_of_int n
  | Block { tag; fields } -> Printf.sprintf "block, %s, size %d" (tag_name tag) (List.length fields)
  | Flat_float fields -> Printf.sprintf "flat float block, %s, size %d" (tag_name double_array_tag) (List.length fields)
  | Unboxed _ -> "no block: [@@unboxed], the value is its field"
  | Ext_slot -> "extension slot: block, Object_tag 248, size 2 (name, unique id)"
  | Rebind p -> "the same value as " ^ p ^ " (rebinding)"
  | Product _ -> "no block: unboxed record, its fields are kept apart or stored in place"
  | Mixed { tag; scanned; slots; _ } ->
      let size = mixed_size slots in
      Printf.sprintf "mixed block, %s, size %d: %s, then %d flat" (tag_name tag) size
        (plural scanned "scanned field" "scanned fields")
        (size - scanned)

(* A mixed block: its slots in memory order, with the bytes each takes in
   native code. *)
let mixed b ~indent (fields : field list) (slots : mixed_slot list) =
  let fields = Array.of_list fields in
  let margin = String.make indent ' ' in
  let label s =
    let f = fields.(s.field) in
    if s.part = "" then field_label f
    else
      (match f.fkind with Label l -> l ^ s.part | _ -> "arg " ^ string_of_int s.field ^ s.part)
      ^ if s.pty = "" then "" else " : " ^ s.pty
  in
  let offs = mixed_offsets slots in
  let range o n = if n = 1 then string_of_int o else Printf.sprintf "%d-%d" o (o + n - 1) in
  let rows =
    List.map2
      (fun s o ->
        let size = s.words * word_bytes in
        let data = if s.data > 0 && s.data < size then s.data else size in
        let unused = if data < size then Printf.sprintf ", bytes %s unused" (range (o + data) (size - data)) else "" in
        (range o data, label s, word s.mword ^ unused))
      slots offs
  in
  let rw = List.fold_left (fun w (r, _, _) -> max w (String.length r)) 3 rows in
  let lw = List.fold_left (fun w (_, l, _) -> max w (String.length l)) 0 rows in
  let iw = String.length (string_of_int (List.length slots - 1)) in
  Printf.bprintf b "%s%s  %s  header\n" margin (String.make iw ' ') (pad rw (range 0 word_bytes));
  List.iteri
    (fun i ((r, l, w), s) ->
      link b [ fields.(s.field).frange ];
      Printf.bprintf b "%s%s  %s  %s  %s\n" margin (lpad iw (string_of_int i)) (pad rw r) (pad lw l) w)
    (List.combine rows slots);
  let reordered = List.exists (fun (i, s) -> s.field <> i || s.part <> "") (List.mapi (fun i s -> (i, s)) slots) in
  if reordered then Printf.bprintf b "%snote: values first, then flat fields, each in declaration order\n" margin;
  Printf.bprintf b "%snote: native code; bytecode stores one boxed field per declared field, in declaration order\n"
    margin

let shape_rows b ~indent = function
  | Block { fields; _ } | Flat_float fields -> rows b ~indent fields
  | Unboxed f -> rows b ~indent ~index:false [ f ]
  | Product fields -> rows b ~indent ~index:false fields
  | Mixed { fields; slots; _ } -> mixed b ~indent fields slots
  | Constant _ | Ext_slot | Rebind _ -> ()

let notes b ~indent ns = List.iter (fun n -> Printf.bprintf b "%snote: %s\n" (String.make indent ' ') n) ns

let cases b (cases : case list) =
  let w = List.fold_left (fun w (c : case) -> max w (String.length c.name)) 0 cases in
  List.iter
    (fun (c : case) ->
      link b [ c.case_range ];
      Printf.bprintf b "  %s  %s\n" (pad w c.name) (shape_summary c.shape);
      shape_rows b ~indent:(w + 6) c.shape;
      notes b ~indent:(w + 6) c.notes)
    cases

(* Each case below the heading gives its own representation, so the heading
   names only the kind of type. *)
let variant_summary (cs : case list) = if cs = [] then "variant with no constructors: it has no values" else "variant"
let decl_head (d : decl) = d.keyword ^ " " ^ (if d.params = "" then "" else d.params ^ " ") ^ d.name

let decl ?(source = false) b (d : decl) =
  if source then Option.iter (fun s -> Printf.bprintf b "%s\n" s) d.source;
  let head = decl_head d in
  link b [ d.range ];
  (match d.kind with
  | Record shape ->
      Printf.bprintf b "%s  %s\n" head (shape_summary shape);
      shape_rows b ~indent:4 shape
  | Variant cs ->
      Printf.bprintf b "%s  %s\n" head (variant_summary cs);
      cases b cs
  | Polyvariant { cases = cs; closed } ->
      Printf.bprintf b "%s  polymorphic variant%s\n" head (if closed then "" else ", open: other tags may appear");
      cases b cs
  | Extension c ->
      Printf.bprintf b "%s  %s\n" head (shape_summary c.shape);
      shape_rows b ~indent:4 c.shape;
      notes b ~indent:4 c.notes
  | Alias w -> Printf.bprintf b "%s  abbreviation: %s\n" head (word w)
  | Abstract w -> Printf.bprintf b "%s  abstract: %s\n" head (word w)
  | Open -> Printf.bprintf b "%s  extensible: each constructor is an extension, listed separately\n" head);
  notes b ~indent:2 d.notes

let item_name (s : slot) =
  (match s.item with
    | Value -> "val "
    | Module -> "module "
    | Functor -> "functor "
    | Exception -> "exception "
    | Extension -> "extension "
    | Class -> "class "
    | Primitive -> "external ")
  ^ s.name

let shorten s = if String.length s <= 72 then s else String.sub s 0 69 ^ "..."

(* The block of every value of type [(module S)]. *)
let package b (m : package) =
  let n = List.length m.slots in
  link b [ m.prange ];
  if n = 0 then Printf.bprintf b "(module %s)  structure block, size 0: no item takes a field\n" m.pname
  else Printf.bprintf b "(module %s)  structure block, tag 0, size %d\n" m.pname n;
  let names = List.map item_name m.slots in
  let w = List.fold_left (fun w l -> max w (String.length l)) 0 names in
  let iw = String.length (string_of_int (n - 1)) in
  List.iter2
    (fun s l ->
      link b [ s.srange ];
      Printf.bprintf b "    %s  %s  %s\n" (lpad iw (string_of_int s.index)) (pad w l) (word s.word))
    m.slots names;
  if m.no_slot <> [] && n > 0 then Printf.bprintf b "  no field: %s\n" (String.concat ", " m.no_slot)

let rows b ~indent ?links (rs : (string * string * string) list) =
  (* Rows with nothing in the last column do not widen the middle one. *)
  let w = List.fold_left (fun w (_, l, x) -> if x = "" then w else max w (String.length l)) 0 rs in
  let iw = List.fold_left (fun w (i, _, _) -> max w (String.length i)) 0 rs in
  let links = match links with Some ls -> ls | None -> List.map (fun _ -> None) rs in
  List.iter2
    (fun (i, l, x) r ->
      link b [ r ];
      let line = Printf.sprintf "%s%s  %s  %s" (String.make indent ' ') (lpad iw i) (pad w l) x in
      (* No trailing spaces when the last column is empty. *)
      let n = ref (String.length line) in
      while !n > 0 && line.[!n - 1] = ' ' do
        decr n
      done;
      Printf.bprintf b "%s\n" (String.sub line 0 !n))
    rs links

let fn_name f = if f.fname = "" then "(made by the compiler)" else f.fname

(* The rows of a closure block, and the range of each: the function a word
   belongs to, or where a captured variable is bound. *)
let closure_rows ~native c =
  let offs, envstart = closure_offsets ~native c in
  let many = List.length c.fns > 1 in
  let entry (f : fn) off =
    let who s = if many then fn_name f ^ ": " ^ s else s in
    let info =
      if native then
        let arity = if f.tupled then -f.arity else f.arity in
        Printf.sprintf "closinfo: arity %d, environment from field %d" arity envstart
      else Printf.sprintf "closinfo: environment from field %d" envstart
    in
    let infix =
      if off = 0 then []
      else
        [
          ( string_of_int (off - 1),
            who (tag_name infix_tag ^ " header: a pointer to " ^ fn_name f ^ " points to the next field"),
            "" );
        ]
    in
    let code =
      if code_words ~native f = 3 then
        [
          ( string_of_int off,
            who (if f.tupled then "code pointer: takes the tuple apart" else "code pointer: partial application"),
            "" );
          (string_of_int (off + 1), who info, "");
          (string_of_int (off + 2), who "code pointer: the function itself", "");
        ]
      else [ (string_of_int off, who "code pointer", ""); (string_of_int (off + 1), who info, "") ]
    in
    List.map (fun r -> (r, f.fn_range)) (infix @ code)
  in
  List.split
    (List.concat (List.map2 entry c.fns offs)
    @ List.mapi
        (fun i (cv : capture) ->
          ( (string_of_int (envstart + i), (if cv.cty = "" then cv.cvar else cv.cvar ^ " : " ^ cv.cty), word cv.cword),
            cv.cv_range ))
        c.env)

let closure b ~native c =
  let names = String.concat ", " (List.map fn_name c.fns) in
  let f = List.hd c.fns in
  let size = closure_size ~native c in
  link b (List.map (fun f -> f.fn_range) c.fns);
  if List.length c.fns = 1 && c.env = [] then
    Printf.bprintf b "  %s  line %d  %s, size %d, arity %d%s, no environment\n" names f.fline (tag_name closure_tag)
      size f.arity
      (if f.tupled then " (tupled)" else "")
  else begin
    if List.length c.fns = 1 then
      Printf.bprintf b "  %s  line %d  %s, size %d\n" names f.fline (tag_name closure_tag) size
    else
      Printf.bprintf b "  %s  line %d  one %s block for %d functions, size %d\n" names f.fline (tag_name closure_tag)
        (List.length c.fns) size;
    let rs, links = closure_rows ~native c in
    rows b ~indent:6 ~links rs
  end

let backend b (bc : backend_closures) =
  match bc.closures with
  | None -> Printf.bprintf b "closures in %s (%s): not predicted\n" bc.backend bc.config
  | Some [] -> Printf.bprintf b "closures in %s (%s): none\n" bc.backend bc.config
  | Some cs ->
      Printf.bprintf b "closures in %s (%s)\n" bc.backend bc.config;
      List.iter (closure b ~native:(bc.backend = "native code")) cs

let lazy_value b (z : lazy_value) =
  let what =
    match z.zkind with
    | Itself -> "no block: the value itself, " ^ word z.zword
    | Forward -> Printf.sprintf "%s block, size 1, holding the value: %s" (tag_name forward_tag) (word z.zword)
    | Suspended ->
        Printf.sprintf "%s block, size 1, holding a closure; forcing it makes it a %s block holding the result"
          (tag_name lazy_tag) (tag_name forward_tag)
  in
  link b [ z.zrange ];
  Printf.bprintf b "%s  line %d  %s\n" (shorten z.zsource) z.zline what

let obj b (o : obj) =
  let first = if o.env_slot then 3 else 2 in
  let size = first + List.length o.ivars in
  link b [ o.orange ];
  Printf.bprintf b "%s  line %d  %s, size %d%s\n" o.oname o.oline (tag_name object_tag) size
    (if o.unknown = [] then "" else " or more");
  let rs =
    [ ("0", "method table", "pointer to the class's method table"); ("1", "object id", "immediate (int)") ]
    @ (if o.env_slot then [ ("2", "environment", "pointer to a block of the local variables the class uses, tag 0") ]
       else [])
    @ List.mapi
        (fun i (v : ivar) ->
          let label = (if v.vmutable then "mutable " else "") ^ v.vname ^ " : " ^ v.vty in
          let from = if v.vparam then "  (parameter)" else "" in
          let from =
            if "class " ^ v.vfrom = o.oname || v.vfrom = o.oname then from else from ^ "  (from " ^ v.vfrom ^ ")"
          in
          (string_of_int (first + i), label, word v.vword ^ from))
        o.ivars
  in
  let links = List.init first (fun _ -> None) @ List.map (fun (v : ivar) -> v.vrange) o.ivars in
  rows b ~indent:4 ~links rs;
  List.iter
    (fun u -> Printf.bprintf b "    then the variables of %s, from another unit, in an order its class sets\n" u)
    o.unknown

let values b (v : values) =
  let first = ref true in
  let sep () = if !first then first := false else Buffer.add_char b '\n' in
  List.iter
    (fun bc ->
      sep ();
      backend b bc)
    v.backends;
  if v.lazies <> [] then begin
    sep ();
    Buffer.add_string b "lazy values\n";
    List.iter
      (fun z ->
        Buffer.add_string b "  ";
        lazy_value b z)
      v.lazies
  end;
  List.iter
    (fun o ->
      sep ();
      obj b o)
    v.objects

type options = { source : bool; only : string list }

let selected opts name =
  opts.only = []
  || List.exists
       (fun o ->
         o = name
         ||
         let n = String.length name and k = String.length o in
         n > k && String.sub name (n - k - 1) (k + 1) = "." ^ o)
       opts.only

let compunit opts b (u : compunit) =
  let first = ref true in
  let sep () = if !first then first := false else Buffer.add_char b '\n' in
  (* Source order: a package sits at its module type's declaration when that
     is in this file, else at its first use. *)
  let decls = List.map (fun (d : decl) -> (d.line, `Decl d)) u.decls in
  let packages =
    List.map
      (fun (m : package) -> ((match m.prange with Some r -> r.first_line | None -> m.pline), `Package m))
      u.packages
  in
  List.stable_sort (fun (a, _) (c, _) -> compare a c) (decls @ packages)
  |> List.iter (function
    | _, `Decl (d : decl) ->
        if selected opts d.name then (
          sep ();
          decl ~source:opts.source b d)
    | _, `Package (m : package) ->
        if selected opts m.pname then (
          sep ();
          package b m));
  match u.values with
  | Some v when opts.only = [] ->
      sep ();
      values b v
  | _ -> ()

let collisions b units =
  List.iter
    (fun (h, ls) ->
      Printf.bprintf b "hash collision: %s all hash to %d\n"
        (String.concat ", " (List.map (fun l -> Printf.sprintf "`%s (%s:%d)" l.label l.file l.lline) ls))
        h)
    (Model.collisions units)

let labels b (units : compunit list) =
  let all = List.concat_map (fun u -> u.labels) units in
  let seen = Hashtbl.create 64 in
  let uniq =
    List.filter
      (fun l ->
        if Hashtbl.mem seen l.label then false
        else (
          Hashtbl.add seen l.label ();
          true))
      all
    |> List.sort (fun a b -> compare a.label b.label)
  in
  let w = List.fold_left (fun w l -> max w (String.length l.label + 1)) 0 uniq in
  List.iter (fun l -> Printf.bprintf b "%s  %11d  %s:%d\n" (pad w ("`" ^ l.label)) l.hash l.file l.lline) uniq

let render_into b opts units =
  let many = List.length units > 1 in
  List.iteri
    (fun i u ->
      if i > 0 then Buffer.add_char b '\n';
      if many then Printf.bprintf b "== %s\n\n" u.file;
      compunit opts b u)
    units;
  let c = Buffer.create 256 in
  collisions c units;
  if Buffer.length c > 0 then (
    Buffer.add_char b '\n';
    Buffer.add_buffer b c)

let render opts units =
  let b = Buffer.create 4096 in
  render_into b opts units;
  Buffer.contents b

(* The report, and the source ranges of its lines: each line's index,
   counting from 0, with its ranges. *)
let render_linked opts units =
  let b = Buffer.create 4096 and marks = ref [] in
  recording := Some (b, marks);
  Fun.protect ~finally:(fun () -> recording := None) (fun () -> render_into b opts units);
  let text = Buffer.contents b in
  let line = ref 0 and at = ref 0 in
  let lines =
    List.map
      (fun (off, rs) ->
        while !at < off do
          if text.[!at] = '\n' then incr line;
          incr at
        done;
        (!line, rs))
      (List.sort (fun (a, _) (b, _) -> compare a b) !marks)
  in
  (* A line written in pieces can have several marks. *)
  let rec merge = function
    | (i, a) :: (j, b) :: rest when i = j -> merge ((i, a @ b) :: rest)
    | x :: rest -> x :: merge rest
    | [] -> []
  in
  (text, merge lines)
