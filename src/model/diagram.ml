(* Diagrams of the pointer structure, for the web page, which draws them.
   Every block of a declared type gets one, and so do some values:

   - a mixed block, as a byte map in the manner of lense: a row per word,
     each slot a cell spanning its bytes;
   - any other block, as a column of words with arrows to the blocks they
     point to;
   - a closure block with an environment or several functions, as such a
     column, with the pointers that enter it on the left.

   Each diagram carries the line of the text report it belongs to, with runs
   of spaces collapsed, so the page can put it in the right card. Diagrams
   come in the order of those lines in the report.

   A diagram that shows everything its rows say also lists those rows, so
   the page can draw it in their place. Notes stay as text. A byte map
   names fields only, so the rows of a mixed block stay too. *)

open Model

(* What a cell holds, as the page colours it: "imm", "ptr", "any" and "flat"
   as in the text columns, "meta" for header words, code pointers and
   closinfo, and "pad" for unused bytes. *)
type kind = string

(* Each cell carries the source ranges of what it stands for, so the page
   can link it to the source and to the text rows. *)
type piece = {
  plabel : string;
  pkind : kind;
  bytes : int;
  pranges : range list;
}

type entry = {
  index : int;
  elabel : string;
  ekind : kind;
  desc : string;
      (** The text row, for screen readers: the fill and arrows say the rest. *)
  incoming : string option;  (** A pointer that enters the block here. *)
  target : string option;  (** The block this word points to. *)
  ranges : range list;
}

type shape =
  | Bytes of { word : int; rows : (int * piece list) list }
      (** Byte offset of each row, and its cells. *)
  | Column of { title : string; entries : entry list }

type t = { key : string; shape : shape; replaces : string list }

(* Runs of spaces collapsed to one, ends trimmed. *)
let squeeze s =
  let b = Buffer.create (String.length s) in
  let space = ref false in
  String.iter
    (fun c ->
      if c = ' ' then space := true
      else (
        if !space && Buffer.length b > 0 then Buffer.add_char b ' ';
        space := false;
        Buffer.add_char b c))
    s;
  Buffer.contents b

let printed f =
  let b = Buffer.create 256 in
  f b;
  String.split_on_char '\n' (Buffer.contents b) |> List.map squeeze

(* The first line Text writes for [f]. *)
let head_line f = match printed f with l :: _ -> l | [] -> ""

(* The lines Text writes for [f] below the first, but for notes. *)
let rows_of f =
  match printed f with
  | _ :: rest ->
      List.filter
        (fun l -> l <> "" && not (String.starts_with ~prefix:"note:" l))
        rest
  | [] -> []

let some = List.filter_map Fun.id

let word_kind = function
  | Immediate _ -> "imm"
  | Pointer _ -> "ptr"
  | Any _ -> "any"
  | Double | Flat _ -> "flat"

let target_of = function
  | Pointer { what; tag = Some t } -> Some (what ^ ", " ^ Text.tag_name t)
  | Pointer { what; tag = None } -> Some what
  | _ -> None

(* A word the column shows in full: the fill gives its kind, the target box
   the block it points to, and the label why an immediate is one when the
   type does not. An "immediate or pointer" word and flat data have more to
   say than a fill. *)
let drawn = function
  | Immediate _ | Pointer _ | Double -> true
  | Any _ | Flat _ -> false

let cell_label label ty = function
  | Immediate why when why <> ty -> label ^ " (" ^ why ^ ")"
  | _ -> label

(* --- Mixed blocks ------------------------------------------------------- *)

(* Slots start on word boundaries; one of several words continues on the
   next rows. Cells name the field only: the rows above give the types. *)
let bytes (fields : field list) (slots : mixed_slot list) =
  let fields = Array.of_list fields in
  let ranges (s : mixed_slot) = some [ fields.(s.field).frange ] in
  let label (s : mixed_slot) =
    let f = fields.(s.field) in
    match f.fkind with
    | Label l -> l ^ s.part
    | _ when s.part = "" -> f.ty
    | _ -> "arg " ^ string_of_int s.field ^ s.part
  in
  let rows =
    List.concat
      (List.map2
         (fun (s : mixed_slot) o ->
           let size = s.words * word_bytes in
           let data = if s.data > 0 && s.data < size then s.data else size in
           List.init s.words (fun w ->
               let lo = w * word_bytes in
               let used = max 0 (min word_bytes (data - lo)) in
               ( o + lo,
                 (if used > 0 then
                    [
                      {
                        plabel = label s;
                        pkind = word_kind s.mword;
                        bytes = used;
                        pranges = ranges s;
                      };
                    ]
                  else [])
                 @
                 if used < word_bytes then
                   [
                     {
                       plabel = "unused";
                       pkind = "pad";
                       bytes = word_bytes - used;
                       pranges = [];
                     };
                   ]
                 else [] )))
         slots (mixed_offsets slots))
  in
  Bytes
    {
      word = word_bytes;
      rows =
        ( 0,
          [
            {
              plabel = "header";
              pkind = "meta";
              bytes = word_bytes;
              pranges = [];
            };
          ] )
        :: rows;
    }

(* An ordinary block, a word per field. *)
let block ~title (fields : field list) =
  let entries =
    List.mapi
      (fun index (f : field) ->
        let label = Text.field_label f in
        {
          index;
          elabel = cell_label label f.ty f.word;
          ekind = word_kind f.word;
          desc = label ^ ", " ^ Text.word f.word;
          incoming = None;
          target = target_of f.word;
          ranges = some [ f.frange ];
        })
      fields
  in
  Column { title; entries }

let decl (d : decl) =
  let one key print = function
    | Mixed { fields; slots; _ } ->
        [ { key; shape = bytes fields slots; replaces = [] } ]
    | (Block { fields; _ } | Flat_float fields) as s ->
        let tag =
          match s with Block { tag; _ } -> tag | _ -> double_array_tag
        in
        let title =
          Printf.sprintf "%s, size %d" (Text.tag_name tag) (List.length fields)
        in
        let all = List.for_all (fun (f : field) -> drawn f.word) fields in
        [
          {
            key;
            shape = block ~title fields;
            replaces = (if all then rows_of print else []);
          };
        ]
    | Constant _ | Unboxed _ | Ext_slot | Rebind _ | Product _ -> []
  in
  let whole b = Text.decl b { d with source = None } in
  match d.kind with
  | Record shape -> one (head_line whole) whole shape
  | Extension c -> one (head_line whole) whole c.shape
  | Variant cs | Polyvariant { cases = cs; _ } ->
      List.concat_map
        (fun (c : case) ->
          let print b = Text.cases b [ c ] in
          one (head_line print) print c.shape)
        cs
  | Alias _ | Abstract _ | Open -> []

(* --- Closures ----------------------------------------------------------- *)

(* Labels as in Text.closure_rows, but for the function's name: the pointer
   coming in names it. *)
let closure ~native (c : closure) =
  if List.length c.fns = 1 && c.env = [] then []
  else
    let print b = Text.closure b ~native c in
    let rows = rows_of print in
    let offs, envstart = closure_offsets ~native c in
    let entry (f : fn) off =
      let meta ?incoming index elabel =
        {
          index;
          elabel;
          ekind = "meta";
          desc = "";
          incoming;
          target = None;
          ranges = some [ f.fn_range ];
        }
      in
      let ptr = Text.fn_name f in
      let infix =
        if off = 0 then []
        else [ meta (off - 1) (Text.tag_name infix_tag ^ " header") ]
      in
      let arity = if f.tupled then -f.arity else f.arity in
      let info =
        if native then
          Printf.sprintf "closinfo: arity %d, environment from field %d" arity
            envstart
        else Printf.sprintf "closinfo: environment from field %d" envstart
      in
      let code =
        if code_words ~native f = 3 then
          [
            meta ~incoming:ptr off
              (if f.tupled then "code pointer: takes the tuple apart"
               else "code pointer: partial application");
            meta (off + 1) info;
            meta (off + 2) "code pointer: the function itself";
          ]
        else [ meta ~incoming:ptr off "code pointer"; meta (off + 1) info ]
      in
      infix @ code
    in
    let env =
      List.mapi
        (fun i (cv : capture) ->
          let label =
            if cv.cty = "" then cv.cvar else cv.cvar ^ " : " ^ cv.cty
          in
          {
            index = envstart + i;
            elabel = cell_label label cv.cty cv.cword;
            ekind = word_kind cv.cword;
            desc = "";
            incoming = None;
            target = target_of cv.cword;
            ranges = some [ cv.cv_range ];
          })
        c.env
    in
    let entries = List.concat (List.map2 entry c.fns offs) @ env in
    (* Each word reads as its text row, without the index. *)
    let without_index row =
      match String.index_opt row ' ' with
      | Some i -> String.sub row (i + 1) (String.length row - i - 1)
      | None -> row
    in
    let entries =
      List.map2 (fun e row -> { e with desc = without_index row }) entries rows
    in
    let title =
      Printf.sprintf "%s, size %d"
        (Text.tag_name closure_tag)
        (closure_size ~native c)
    in
    let all = List.for_all (fun (cv : capture) -> drawn cv.cword) c.env in
    [
      {
        key = head_line print;
        shape = Column { title; entries };
        replaces = (if all then rows else []);
      };
    ]

let values (v : values) =
  List.concat_map
    (fun (bc : backend_closures) ->
      match bc.closures with
      | Some cs ->
          List.concat_map (closure ~native:(bc.backend = "native code")) cs
      | None -> [])
    v.backends

(* The diagrams for what Text.render prints with these options, in its order. *)
let compunit (opts : Text.options) (u : compunit) =
  List.concat_map
    (fun (d : decl) -> if Text.selected opts d.name then decl d else [])
    u.decls
  @ match u.values with Some v when opts.only = [] -> values v | _ -> []

(* --- JSON --------------------------------------------------------------- *)

let json (ds : t list) =
  let open Json in
  let opt = function None -> Null | Some s -> Str s in
  let ranges rs = List (List.map (fun r -> range (Some r)) rs) in
  let strs l = List (List.map (fun s -> Str s) l) in
  let shape = function
    | Bytes { word; rows } ->
        Obj
          [
            ("type", Str "bytes");
            ("word", Int word);
            ( "rows",
              List
                (List.map
                   (fun (o, ps) ->
                     Obj
                       [
                         ("offset", Int o);
                         ( "cells",
                           List
                             (List.map
                                (fun p ->
                                  Obj
                                    [
                                      ("label", Str p.plabel);
                                      ("kind", Str p.pkind);
                                      ("bytes", Int p.bytes);
                                      ("ranges", ranges p.pranges);
                                    ])
                                ps) );
                       ])
                   rows) );
          ]
    | Column { title; entries } ->
        Obj
          [
            ("type", Str "column");
            ("title", Str title);
            ( "entries",
              List
                (List.map
                   (fun e ->
                     Obj
                       [
                         ("index", Int e.index);
                         ("label", Str e.elabel);
                         ("kind", Str e.ekind);
                         ("desc", Str e.desc);
                         ("incoming", opt e.incoming);
                         ("target", opt e.target);
                         ("ranges", ranges e.ranges);
                       ])
                   entries) );
          ]
  in
  let b = Buffer.create 4096 in
  write b ~indent:0
    (List
       (List.map
          (fun d ->
            Obj
              [
                ("key", Str d.key);
                ("diagram", shape d.shape);
                ("replaces", strs d.replaces);
              ])
          ds));
  Buffer.contents b
