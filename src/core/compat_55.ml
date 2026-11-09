(* The parts of compiler-libs that differ between OCaml 5.5 and OxCaml, for
   OCaml 5.5. src/core/dune copies this file or compat_ox.ml to compat.ml,
   chosen by %{ocaml_version}; the two must define the same names. *)

open Types
module M = Lense_model.Model
module T = Typedtree

(* Types *)

type view =
  | Var of string option
  | Poly of type_expr
  | Arrow
  | Tuple
  | Unboxed_tuple
  | Object
  | Package
  | Variant of row_desc
  | Constr of Path.t * type_expr list
  | Other

let view ty =
  match get_desc ty with
  | Tvar v | Tunivar v -> Var v
  | Tpoly (t, _) -> Poly t
  | Tarrow _ | Tfunctor _ -> Arrow
  | Ttuple _ -> Tuple
  | Tobject _ -> Object
  | Tpackage _ -> Package
  | Tvariant row -> Variant row
  | Tconstr (p, args, _) -> Constr (p, args)
  | Tlink _ | Tsubst _ | Tfield _ | Tnil -> Other

(* OCaml 5.5 has no layouts besides value. *)
let flat_word (_ : Env.t) (_ : type_expr) : M.word option = None

(* Predefined types that only one compiler has. *)
let predef_word p : M.word option =
  if Path.same p Predef.path_continuation then Some (M.Pointer { tag = Some M.cont_tag; what = "continuation" })
  else None

let or_null (_ : Path.t) = false

(* A type declaration, as far as the word of one of its values goes. *)
type decl_view =
  | Unboxed_arg of type_expr  (** [@@unboxed]: the value is this argument. *)
  | Constructors of int * int  (** Constant and non-constant counts. *)
  | Float_record
  | Record
  | Unboxed_record
  | Open
  | Immediate of string  (** An abstract type known to be immediate, and why. *)
  | Abstract

let decl_view (_ : Env.t) (_ : Path.t) (_ : type_expr list) decl =
  match decl.type_kind with
  | Type_variant ([ { cd_args = Cstr_tuple [ arg ]; _ } ], Variant_unboxed)
  | Type_variant ([ { cd_args = Cstr_record [ { ld_type = arg; _ } ]; _ } ], Variant_unboxed)
  | Type_record ([ { ld_type = arg; _ } ], Record_unboxed _) ->
      Unboxed_arg arg
  | Type_variant (cstrs, _) ->
      let consts = List.length (List.filter (fun c -> c.cd_args = Cstr_tuple []) cstrs) in
      Constructors (consts, List.length cstrs - consts)
  | Type_record (_, Record_float) -> Float_record
  | Type_record _ -> Record
  | Type_open -> Open
  | Type_abstract _ | Type_external _ -> (
      match decl.type_immediate with
      | Type_immediacy.Always -> Immediate "[@@immediate]"
      | Always_on_64bits when Sys.word_size = 64 -> Immediate "[@@immediate64]"
      | _ -> Abstract)

(* The word of an abstract type declared in the file being read. *)
let abstract_word ~word:_ (_ : Env.t) (_ : Path.t) decl : M.word =
  match decl.type_immediate with
  | Type_immediacy.Always -> M.Immediate "[@@immediate]"
  | Always_on_64bits -> M.Immediate "[@@immediate64]"
  | Unknown -> M.Any "abstract type"

(* Typed trees *)

let ld_mutable (ld : T.label_declaration) = ld.ld_mutable = Mutable

let tuple_args = function
  | T.Cstr_tuple cts -> cts
  | T.Cstr_record _ -> []

type cstr_desc = Data_types.constructor_description

let cstr_existentials (d : cstr_desc) = d.cstr_existentials

(* The shape of a record declaration, or None for other kinds. [field] turns
   one typed label into a model field. *)
let record_shape ~word:_ ~env:_ decl (kind : T.type_kind) ~field : M.shape option =
  match (decl.type_kind, kind) with
  | Type_record (_, repr), Ttype_record lds -> (
      let fields = List.map field lds in
      match repr with
      | Record_float -> Some (Flat_float (List.map (fun (f : M.field) -> { f with word = M.Double }) fields))
      | Record_unboxed _ -> Some (match fields with [ f ] -> Unboxed f | _ -> Block { tag = 0; fields })
      | Record_regular | Record_inlined _ | Record_extension _ -> Some (Block { tag = 0; fields }))
  | _ -> None

let constructor_shape ~word:_ ~env:_ ~tys:_ ~slot (desc : cstr_desc) fields : M.shape =
  match desc.cstr_tag with
  | Cstr_constant n -> Constant n
  | Cstr_block tag -> Block { tag; fields }
  | Cstr_unboxed -> ( match fields with [ f ] -> Unboxed f | _ -> Block { tag = 0; fields })
  | Cstr_extension (_, true) -> Ext_slot
  | Cstr_extension (_, false) -> Block { tag = 0; fields = slot :: fields }

(* Loading *)

let init_unit ~source_file ~intf =
  let ui =
    Unit_info.make ~check_modname:false ~source_file
      (if intf then Unit_info.Intf else Unit_info.Impl)
      (Filename.remove_extension source_file)
  in
  Env.set_current_unit ui;
  ui

let type_interface ~source_file:_ (_ : Unit_info.t) env ast = Typemod.type_interface env ast

let type_structure env ast =
  let str, _, _, _, _ = Typemod.type_structure env ast in
  str

let reset_envaux () = Envaux.reset_cache ()
let cmt_modname (cmt : Cmt_format.cmt_infos) = cmt.cmt_modname
let read_cmi_signature file = Env.read_signature (Unit_info.Artifact.from_filename file)
