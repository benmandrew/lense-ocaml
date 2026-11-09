(* The runtime-representation model: a plain description of how values of
   each declared type look in memory. Lense_core fills it from compiler-libs;
   Text and Json print it. Nothing here depends on the compiler. *)

(* Tags from runtime/caml/mlvalues.h, OCaml 5.5. *)
let forcing_tag = 244
let cont_tag = 245
let lazy_tag = 246
let closure_tag = 247
let object_tag = 248
let infix_tag = 249
let forward_tag = 250
let abstract_tag = 251
let string_tag = 252
let double_tag = 253
let double_array_tag = 254
let custom_tag = 255

(* What one word holds: a field of a block, or a whole value. *)
type word =
  | Immediate of string  (** Always an immediate; says why. *)
  | Pointer of { tag : int option; what : string }
      (** Always a pointer to a block. [tag] is [None] when it varies. *)
  | Any of string  (** Could be either; says why. *)
  | Double  (** An unboxed double inside a flat float block. *)
  | Flat of { layout : string; bytes : int }
      (** OxCaml: an unboxed value of a non-value layout, such as [float64],
          with [bytes] of data. [bytes] is 0 when it is not one fixed size. *)

type field_kind =
  | Label of string  (** A record or inline-record field. *)
  | Arg  (** A constructor or polymorphic-variant argument. *)
  | Slot of string  (** The extension slot at the front of an extension block. *)
  | Hash of int  (** The label hash at the front of a polymorphic variant. *)

type field = {
  fkind : field_kind;
  ty : string;  (** Spelling of the field's type. *)
  mutable_ : bool;
  word : word;
}

(* OxCaml: one element of a mixed block, in memory order. *)
type mixed_slot = {
  field : int;  (** The declared field it comes from, counting from 0. *)
  part : string;  (** The path inside an unboxed product field, such as ".x", or "". *)
  pty : string;  (** The type of that part, or "". *)
  mword : word;
  words : int;  (** Words it takes in native code. *)
  data : int;  (** Bytes of data at the start of those words. *)
}

type shape =
  | Constant of int  (** An immediate with this value. *)
  | Block of { tag : int; fields : field list }
  | Flat_float of field list  (** Double_array_tag, fields stored as doubles. *)
  | Unboxed of field  (** No block: the value is this field. *)
  | Ext_slot  (** An Object_tag block holding the name and a unique id. *)
  | Rebind of string  (** The same value as another extension constructor. *)
  | Product of field list
      (** OxCaml: an unboxed record. No block: the fields are kept apart, in
          registers or stored in place inside an enclosing block. *)
  | Mixed of { tag : int; fields : field list; scanned : int; slots : mixed_slot list }
      (** OxCaml: a block whose first [scanned] words are values and whose
          other words are flat data. [fields] is in declaration order,
          [slots] in memory order. *)

let word_bytes = Sys.word_size / 8

(* The byte offset of each slot, counting the header word. *)
let mixed_offsets slots =
  let _, offs =
    List.fold_left (fun (o, acc) s -> (o + (s.words * word_bytes), o :: acc)) (word_bytes, []) slots
  in
  List.rev offs

let mixed_size slots = List.fold_left (fun n s -> n + s.words) 0 slots

type case = {
  name : string;  (** Constructor name, with a backquote for polymorphic tags. *)
  shape : shape;
  notes : string list;
}

type kind =
  | Record of shape
  | Variant of case list
  | Polyvariant of { cases : case list; closed : bool }
  | Extension of case  (** An exception or extension constructor. *)
  | Alias of word  (** An abbreviation; the word its expansion uses. *)
  | Abstract of word
  | Open  (** An extensible variant, [type t = ..]. *)

type decl = {
  name : string;  (** Qualified within the unit: [M.t]. *)
  params : string;  (** Type parameters as written, such as ['a] or [('a, 'b)]. *)
  keyword : string;  (** "type", "exception" or "extension". *)
  line : int;
  source : string option;  (** The declaration as written, when available. *)
  kind : kind;
  notes : string list;
}

type slot_kind = Value | Module | Functor | Exception | Extension | Class | Primitive

type slot = { index : int; item : slot_kind; name : string; word : word }

(* A structure: one block with tag 0, its fields the value-bearing items. *)
type structure = {
  mname : string;
  mline : int;
  functor_params : string list;  (** Non-empty for a functor's body. *)
  slots : slot list;
  no_slot : string list;  (** Items that take no field, such as types. *)
}

type move_kind =
  | Copy
  | Coerced  (** The field is itself coerced before the copy. *)
  | Wrapped_primitive  (** An external becomes a closure. *)
  | Realised_alias  (** A module alias becomes a real field. *)

type move = { dst : int; src : int; name : string; how : move_kind }

type coercion = {
  context : string;  (** What is coerced: "module M : S", "argument of F". *)
  cline : int;
  src_size : int;  (** Fields in the block being coerced. *)
  copy : move list option;  (** [None]: no copy, the block is reused. *)
  functor_wrap : bool;  (** A functor is wrapped in a new closure. *)
}

type label_use = { label : string; hash : int; file : string; lline : int }

(* Stage 4: values that are not of a declared type's shape. *)

(* A variable a closure captures. *)
type capture = { cvar : string; cty : string; cword : word }

type fn = {
  fname : string;  (** Scope name from the compiler, such as "mk.(fun)". *)
  fline : int;
  arity : int;
  tupled : bool;  (** Takes its arguments as one tuple, unpacked by the caller. *)
}

(* One closure block: a single function, or a set of mutually recursive ones
   that share an environment. *)
type closure = { fns : fn list; env : capture list }

(* The words a function's entry takes before the next entry or the
   environment: code pointer and closinfo, plus a second code pointer in
   native code when the function takes more than one argument. *)
let code_words ~native f = if native && (f.arity > 1 || f.tupled) then 3 else 2

(* Field index of each entry (after its Infix header, if any), and of the
   environment. *)
let closure_offsets ~native c =
  let _, offs =
    List.fold_left
      (fun (i, acc) f ->
        let i = if acc = [] then i else i + 1 in
        (i + code_words ~native f, i :: acc))
      (0, []) c.fns
  in
  let offs = List.rev offs in
  let last = List.nth c.fns (List.length c.fns - 1) and lo = List.nth offs (List.length offs - 1) in
  (offs, lo + code_words ~native last)

let closure_size ~native c = snd (closure_offsets ~native c) + List.length c.env

type backend_closures = {
  backend : string;  (** "native code" or "bytecode". *)
  config : string;  (** How the backend was built, such as "Closure, without flambda". *)
  closures : closure list option;  (** [None]: the layout is not predicted for this configuration. *)
}

type lazy_kind =
  | Itself  (** No block: the value is computed at once, and is its own lazy value. *)
  | Forward  (** A Forward_tag block holding the value. *)
  | Suspended  (** A Lazy_tag block holding a closure, until forced. *)

type lazy_value = { zline : int; zsource : string; zkind : lazy_kind; zword : word }

type ivar = {
  vname : string;
  vty : string;
  vmutable : bool;
  vparam : bool;  (** A class parameter or class-level let that a method uses. *)
  vword : word;
  vfrom : string;  (** The class that declares it. *)
}

type obj = {
  oname : string;  (** "class c", or "object" for an immediate object. *)
  oline : int;
  env_slot : bool;  (** Field 2 holds the local variables the class uses, before the instance variables. *)
  ivars : ivar list;  (** Instance variables in slot order. *)
  unknown : string list;  (** Inherited classes from other units, whose variables follow. *)
}

type values = { backends : backend_closures list; lazies : lazy_value list; objects : obj list }

type compunit = {
  file : string;
  unit_name : string;
  decls : decl list;
  modules : structure list;
  coercions : coercion list;
  labels : label_use list;
  values : values option;  (** Closures, lazy values and objects; only when asked for. *)
}

(* Polymorphic-variant labels that share a hash, across every unit. Each
   group lists the distinct labels with one use of each. *)
let collisions (units : compunit list) =
  let tbl = Hashtbl.create 64 in
  List.iter
    (fun u ->
      List.iter
        (fun l ->
          let prev = try Hashtbl.find tbl l.hash with Not_found -> [] in
          if not (List.exists (fun p -> p.label = l.label) prev) then
            Hashtbl.replace tbl l.hash (prev @ [ l ]))
        u.labels)
    units;
  Hashtbl.fold (fun h ls acc -> if List.length ls > 1 then (h, ls) :: acc else acc) tbl []
  |> List.sort compare
