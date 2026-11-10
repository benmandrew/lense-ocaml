(* The parts of compiler-libs that differ between OCaml 5.5 and OxCaml, for
   OxCaml. src/core/dune copies this file or compat_55.ml to compat.ml,
   chosen by %{ocaml_version}; the two must define the same names. *)

open Types
module M = Lense_model.Model
module T = Typedtree

let expand env ty = try Ctype.expand_head_opt env ty with _ -> ty

let instantiate env decl args ty =
  try Ctype.apply env decl.type_params ty args with _ -> ty

let print_type ty =
  let s = Format.asprintf "%a" Printtyp.type_expr ty in
  String.concat " "
    (List.filter (( <> ) "")
       (String.split_on_char ' '
          (String.map (function '\n' | '\t' | '\r' -> ' ' | c -> c) s)))

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
  | Tvar { name; _ } | Tunivar { name; _ } -> Var name
  | Tpoly (t, _) -> Poly t
  | Tarrow _ -> Arrow
  | Ttuple _ -> Tuple
  | Tunboxed_tuple _ -> Unboxed_tuple
  | Tobject _ -> Object
  | Tpackage _ -> Package
  | Tvariant row -> Variant row
  | Tconstr (p, args, _) -> Constr (p, args)
  | Tlink _ | Tsubst _ | Tfield _ | Tnil | Tquote _ | Tsplice _ | Tof_kind _ ->
      Other

(* The module type that a first-class module type packs. *)
let package_path ty =
  match get_desc ty with Tpackage (p, _) -> Some p | _ -> None

(* Bytes of data in one element of a layout; 0 when it has no single size. *)
let layout_bytes = function
  | "float64" | "bits64" | "word" | "untagged_immediate" -> 8
  | "float32" | "bits32" -> 4
  | "bits16" -> 2
  | "bits8" -> 1
  | "vec128" -> 16
  | "vec256" -> 32
  | "vec512" -> 64
  | _ -> 0

(* A type of a layout other than value is flat data. *)
let flat_word env ty : M.word option =
  match Jkind.get_layout (Ctype.type_jkind env ty) with
  | Some l -> (
      match Jkind.Layout.Const.to_string l with
      | "value" | "value_or_null" | "immediate" | "immediate64" | "any" -> None
      | layout -> Some (M.Flat { layout; bytes = layout_bytes layout }))
  | None -> None
  | exception _ -> None

(* Predefined types that only one compiler has. *)
let predef_word p : M.word option =
  if Path.same p Predef.path_int8 || Path.same p Predef.path_int16 then
    Some (M.Immediate (Path.name p))
  else if Path.same p Predef.path_float32 then
    Some (M.Pointer { tag = Some M.custom_tag; what = "custom block" })
  else None

let or_null p = Path.same p Predef.path_or_null

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

let decl_view env p args decl =
  match decl.type_kind with
  | Type_variant
      ( [ { cd_args = Cstr_tuple [ { ca_type = arg; _ } ]; _ } ],
        Variant_unboxed,
        _ )
  | Type_variant
      ( [ { cd_args = Cstr_record [ { ld_type = arg; _ } ]; _ } ],
        Variant_unboxed,
        _ )
  | Type_record ([ { ld_type = arg; _ } ], Record_unboxed, _) ->
      Unboxed_arg arg
  | Type_variant (cstrs, _, _) ->
      let consts =
        List.length (List.filter (fun c -> c.cd_args = Cstr_tuple []) cstrs)
      in
      Constructors (consts, List.length cstrs - consts)
  | Type_record (_, (Record_float | Record_ufloat), _) -> Float_record
  | Type_record _ -> Record
  | Type_record_unboxed_product ([ { ld_type = arg; _ } ], _, _) ->
      (* A single-field unboxed record is its field. *)
      Unboxed_arg arg
  | Type_record_unboxed_product _ -> Unboxed_record
  | Type_open -> Open
  | Type_abstract _ ->
      let ty = Btype.newgenty (Tconstr (p, args, ref Mnil)) in
      if try Ctype.is_always_gc_ignorable env ty with _ -> false then
        Immediate ": immediate"
      else if
        (* The compiler counts immediate64 as immediate only when it
           compiles native code; it is immediate on any 64-bit target. *)
        M.word_size = 64
        &&
          try
            Ctype.check_type_externality env ty
              Jkind_axis.Externality.External64
          with _ -> false
      then Immediate ": immediate64"
      else Abstract

(* The word of an abstract type declared in the file being read. *)
let abstract_word ~word env p decl : M.word =
  word env (Btype.newgenty (Tconstr (p, decl.type_params, ref Mnil)))

(* Typed trees *)

let ld_mutable (ld : T.label_declaration) = ld.ld_mutable <> Immutable

let tuple_args = function
  | T.Cstr_tuple cas ->
      List.map (fun (ca : T.constructor_argument) -> ca.ca_type) cas
  | T.Cstr_record _ -> []

type cstr_desc = Types.constructor_description

let cstr_existentials (d : cstr_desc) = d.cstr_existentials

(* Mixed blocks. The compiler's own Mixed_block_shape puts the elements in
   memory order: values first, then flat data, each in declaration order,
   with unboxed products split into their parts. *)

(* Layout name, bytes of data and words taken in native code. *)
let element_data (e : unit Lambda.mixed_block_element) =
  match e with
  | Value _ | Float_boxed _ | Float64 | Bits64 | Word | Untagged_immediate ->
      ("", 8, 1)
  | Float32 -> ("float32", 4, 1)
  | Bits32 -> ("bits32", 4, 1)
  | Bits16 -> ("bits16", 2, 1)
  | Bits8 -> ("bits8", 1, 1)
  | Vec128 -> ("vec128", 16, 2)
  | Vec256 -> ("vec256", 32, 4)
  | Vec512 -> ("vec512", 64, 8)
  | Product _ -> ("product", 0, 0)

(* The field of a single-field unboxed record, which has the layout of that
   field: the compiler's paths pass it by. *)
let single_field env ty =
  match get_desc (expand env ty) with
  | Tconstr (p, args, _) -> (
      match Env.find_type p env with
      | { type_kind = Type_record_unboxed_product ([ ld ], _, _); _ } as decl ->
          Some (Ident.name ld.ld_id, instantiate env decl args ld.ld_type)
      | _ -> None
      | exception Not_found -> None)
  | _ -> None

(* The name and type of a part of an unboxed product field, from its path. *)
let rec part_of env ty path =
  match (get_desc ty, single_field env ty, path) with
  | Tpoly (t, []), _, _ -> part_of env t path
  | _, Some (name, t), _ ->
      let s, t' = part_of env t path in
      ("." ^ name ^ s, t')
  | _, None, [] -> ("", Some ty)
  | _, None, j :: rest -> (
      let ty = expand env ty in
      let down name t =
        let s, t' = part_of env t rest in
        ("." ^ name ^ s, t')
      in
      match get_desc ty with
      | Tpoly (t, []) -> part_of env t path
      | Tunboxed_tuple l when j < List.length l ->
          let lbl, t = List.nth l j in
          down (Option.value lbl ~default:(string_of_int j)) t
      | Tconstr (p, args, _) -> (
          match Env.find_type p env with
          | { type_kind = Type_record_unboxed_product (lds, _, _); _ } as decl
            when j < List.length lds ->
              let ld = List.nth lds j in
              down (Ident.name ld.ld_id) (instantiate env decl args ld.ld_type)
          | _ -> ("." ^ string_of_int j, None)
          | exception Not_found -> ("." ^ string_of_int j, None))
      | _ -> ("." ^ string_of_int j, None))

let element_word ~word ~env (fields : M.field array) field part_ty
    (e : unit Lambda.mixed_block_element) : M.word =
  match e with
  | Value _ -> (
      match part_ty with
      | Some t -> word env t
      | None -> (
          (* A value part of a product field is not the field's flat word. *)
          match fields.(field).word with
          | M.Flat _ -> M.Any "a value part of an unboxed product"
          | w -> w))
  | Float_boxed _ ->
      M.Flat { layout = "float64, boxed again when read"; bytes = 8 }
  | Float64 -> M.Flat { layout = "float64"; bytes = 8 }
  | Bits64 -> M.Flat { layout = "bits64"; bytes = 8 }
  | Word -> M.Flat { layout = "word"; bytes = 8 }
  | Untagged_immediate -> M.Flat { layout = "untagged immediate"; bytes = 8 }
  | e ->
      let layout, bytes, _ = element_data e in
      M.Flat { layout; bytes }

let singleton (e : unit Mixed_block_shape.Singleton_mixed_block_element.t) :
    unit Lambda.mixed_block_element =
  match e with
  | Value v -> Value v
  | Float_boxed () -> Float_boxed ()
  | Float64 -> Float64
  | Float32 -> Float32
  | Bits8 -> Bits8
  | Bits16 -> Bits16
  | Bits32 -> Bits32
  | Bits64 -> Bits64
  | Vec128 -> Vec128
  | Vec256 -> Vec256
  | Vec512 -> Vec512
  | Word -> Word
  | Untagged_immediate -> Untagged_immediate

let mixed ~word ~env ~tys ~tag (shape : Types.mixed_product_shape)
    (fields : M.field list) : M.shape =
  let tys = Array.of_list tys and farr = Array.of_list fields in
  let t =
    Mixed_block_shape.of_mixed_block_elements
      ~print_locality:(fun _ () -> ())
      (Lambda.transl_mixed_product_shape shape)
  in
  let slot i e =
    let field, rest =
      match Mixed_block_shape.new_index_to_old_path t i with
      | f :: r -> (f, r)
      | [] -> (0, [])
    in
    let part, part_ty =
      if rest = [] || field >= Array.length tys then ("", None)
      else part_of env tys.(field) rest
    in
    let pty = match part_ty with Some t -> print_type t | None -> "" in
    let e = singleton e in
    let _, data, words = element_data e in
    let part_ty = if part = "" then None else part_ty in
    {
      M.field;
      part;
      pty;
      mword = element_word ~word ~env farr field part_ty e;
      words;
      data;
    }
  in
  let slots =
    Array.to_list
      (Array.mapi slot (Mixed_block_shape.flattened_reordered_shape t))
  in
  (* A field stored only as flat data, such as a float in a record of floats
     and float#, owns no block in native code. *)
  let fields =
    List.mapi
      (fun i (f : M.field) ->
        if
          List.for_all
            (fun (s : M.mixed_slot) ->
              s.field <> i || match s.mword with M.Flat _ -> true | _ -> false)
            slots
        then { f with owns = M.zero }
        else f)
      fields
  in
  Mixed { tag; fields; scanned = Mixed_block_shape.value_prefix_len t; slots }

(* The shape of a record declaration, or None for other kinds. [field] turns
   one typed label into a model field. *)
let record_shape ~word ~env decl (kind : T.type_kind) ~field : M.shape option =
  match (decl.type_kind, kind) with
  | Type_record (_, repr, _), Ttype_record lds -> (
      let fields = List.map field lds in
      match repr with
      | Record_float | Record_ufloat ->
          Some
            (Flat_float
               (List.map
                  (fun (f : M.field) ->
                    { f with word = M.Double; owns = M.zero })
                  fields))
      | Record_unboxed ->
          Some
            (match fields with
            | [ f ] -> Unboxed f
            | _ -> Block { tag = 0; fields })
      | Record_mixed shape ->
          let tys =
            List.map
              (fun (ld : T.label_declaration) -> ld.ld_type.ctyp_type)
              lds
          in
          Some (mixed ~word ~env ~tys ~tag:0 shape fields)
      | Record_boxed _ | Record_inlined _ -> Some (Block { tag = 0; fields }))
  | Type_record_unboxed_product _, Ttype_record_unboxed_product lds ->
      Some (Product (List.map field lds))
  | _ -> None

let constructor_shape ~word ~env ~tys ~slot (desc : cstr_desc) fields : M.shape
    =
  let block_or_mixed ~tag ~tys fields : M.shape =
    match desc.cstr_shape with
    | Constructor_uniform_value -> Block { tag; fields }
    | Constructor_mixed shape -> mixed ~word ~env ~tys ~tag shape fields
  in
  match (desc.cstr_repr, desc.cstr_tag) with
  | Variant_unboxed, _ -> (
      match fields with [ f ] -> Unboxed f | _ -> Block { tag = 0; fields })
  | _, Null -> Constant 0
  | _, Ordinary { runtime_tag; _ } when desc.cstr_constant ->
      Constant runtime_tag
  | _, Ordinary { runtime_tag; _ } ->
      block_or_mixed ~tag:runtime_tag ~tys fields
  | _, Extension _ when desc.cstr_constant -> Ext_slot
  | _, Extension _ -> (
      (* The extension slot comes first, as an extra value field. *)
      match desc.cstr_shape with
      | Constructor_uniform_value -> Block { tag = 0; fields = slot :: fields }
      | Constructor_mixed shape ->
          mixed ~word ~env ~tys:(Predef.type_int :: tys) ~tag:0
            (Array.append [| Types.Value |] shape)
            (slot :: fields))

(* Loading *)

let init_unit ~source_file ~intf =
  let ui =
    Unit_info.make ~check_modname:false ~source_file
      ~for_pack_prefix:Compilation_unit.Prefix.empty
      (if intf then Unit_info.Intf else Unit_info.Impl)
      (Filename.remove_extension source_file)
  in
  Env.set_unit_name (Some ui);
  ui

let type_interface ~source_file ui env ast =
  Typemod.type_interface ~sourcefile:source_file (Unit_info.modname ui) env ast

let type_structure env ast =
  let str, _, _, _, _, _ = Typemod.type_structure env ast in
  str

let reset_envaux () = Envaux.reset_cache ~preserve_persistent_env:false

let cmt_modname (cmt : Cmt_format.cmt_infos) =
  Compilation_unit.name_as_string cmt.cmt_modname

(* Forget the names the type printer has given out, which it keeps from
   one unit to the next: a type of the same name in an earlier unit made
   it print rr7 as rr7/2. *)
let reset_printing () = Printtyp.reset ()

(* The digest a .cmt records of its source: MD5 in OxCaml. *)
let source_digest s = Digest.string s
let read_cmi_signature file = (Cmi_format.read_cmi file).cmi_sign

(* Stage 4 *)

(* The local variable an expression is, if it is one. *)
let expr_ident (e : T.expression) =
  match e.exp_desc with
  | T.Texp_ident (Path.Pident id, _, _, _, _) -> Some id
  | _ -> None

let bound_idents (p : _ T.general_pattern) =
  List.map (fun (id, _, ty, _, _) -> (id, ty)) (T.pat_bound_idents_full p)

type lfun = { lname : string; lloc : Location.t; nparams : int; ltupled : bool }

let lfun (f : Lambda.lfunction) =
  let lname, lloc =
    match f.loc with
    | Loc_known { loc; scopes } ->
        ( Debuginfo.Scoped_location.string_of_scopes ~include_zero_alloc:false
            scopes,
          loc )
    | Loc_unknown -> ("", Location.none)
  in
  { lname; lloc; nparams = List.length f.params; ltupled = f.kind = Tupled }

(* Every closure the bytecode allocates per call of a function: one
   function, or a recursive set that shares one block, with the variables
   it captures in Ident order. A closure outside every function body is
   allocated once, when the unit initialises, and is left out. OxCaml's
   ocamlc does not split default arguments. *)
let closure_sets (lam : Lambda.lambda) =
  let acc = ref [] in
  let add fs fv = acc := (List.map lfun fs, Ident.Set.elements fv) :: !acc in
  let rec walk ~inside (lam : Lambda.lambda) =
    match lam with
    | Lfunction f ->
        if inside then add [ f ] (Lambda.free_variables lam);
        walk ~inside:true f.body
    | Lletrec (bs, body) ->
        if inside then
          add
            (List.map (fun (b : Lambda.rec_binding) -> b.def) bs)
            (Lambda.free_variables (Lletrec (bs, Lambda.lambda_unit)));
        List.iter
          (fun (b : Lambda.rec_binding) -> walk ~inside:true b.def.body)
          bs;
        walk ~inside body
    | _ -> Lambda.shallow_iter ~tail:(walk ~inside) ~non_tail:(walk ~inside) lam
  in
  walk ~inside:false lam;
  List.rev !acc

(* The Lambda code that OxCaml's ocamlc compiles, built as its driver
   builds it. *)
let bytecode_lambda ~modname (str : T.structure) =
  Misc.protect_refs
    [ Misc.R (Clflags.native_code, false) ]
    (fun () ->
      let cu =
        Compilation_unit.create Compilation_unit.Prefix.empty
          (Compilation_unit.Name.of_string modname)
      in
      let p = Translmod.transl_implementation cu (str, T.Tcoerce_none, None) in
      Simplif.simplify_lambda_for_bytecode p.code)

let closure_backends ~modname str =
  [
    ("native code", "flambda 2, which chooses closure layouts itself", None);
    ( "bytecode",
      "ocamlc without -g",
      try Some (closure_sets (bytecode_lambda ~modname str)) with _ -> None );
  ]

(* Counting words *)

let tuple_types ty =
  match get_desc ty with Ttuple l -> List.map snd l | _ -> []

let unboxed_tuple_types ty =
  match get_desc ty with Tunboxed_tuple l -> List.map snd l | _ -> []

(* The words of a value of a predefined type that only one compiler has. *)
let predef_cost p : M.cost option =
  if Path.same p Predef.path_int8 || Path.same p Predef.path_int16 then
    Some M.zero
  else if Path.same p Predef.path_float32 then
    (* A custom block: the operations pointer and one word of data. *)
    Some (M.fixed 3)
  else None

(* How a declaration lays out its values, for counting the words one takes.
   Field types are as declared, before applying the type's arguments. *)
type layout =
  | No_block of type_expr list
      (** The value is these, with no block: [@@unboxed], or the fields of an
          unboxed record. *)
  | Blocks of type_expr list option list
      (** One per constructor: None when constant, or the fields of its block. A
          record is one constructor. *)
  | Flat of int  (** A flat float block of this many fields. *)
  | Not_counted of string

let layout env p args decl =
  let fields lds = List.map (fun (ld : label_declaration) -> ld.ld_type) lds in
  match decl.type_kind with
  | Type_variant
      ( [ { cd_args = Cstr_tuple [ { ca_type = arg; _ } ]; _ } ],
        Variant_unboxed,
        _ )
  | Type_variant
      ( [ { cd_args = Cstr_record [ { ld_type = arg; _ } ]; _ } ],
        Variant_unboxed,
        _ )
  | Type_record ([ { ld_type = arg; _ } ], Record_unboxed, _) ->
      No_block [ arg ]
  | Type_variant (_, Variant_boxed reprs, _)
    when Array.exists
           (function Constructor_mixed _, _ -> true | _ -> false)
           reprs ->
      Not_counted ("mixed block " ^ Path.name p)
  | Type_variant (cds, _, _) ->
      Blocks
        (List.map
           (fun cd ->
             match cd.cd_args with
             | Cstr_tuple [] -> None
             | Cstr_tuple cas ->
                 Some
                   (List.map
                      (fun (ca : constructor_argument) -> ca.ca_type)
                      cas)
             | Cstr_record lds -> Some (fields lds))
           cds)
  | Type_record (lds, (Record_float | Record_ufloat), _) ->
      Flat (List.length lds)
  | Type_record (_, Record_mixed _, _) ->
      Not_counted ("mixed block " ^ Path.name p)
  | Type_record (lds, _, _) -> Blocks [ Some (fields lds) ]
  | Type_record_unboxed_product (lds, _, _) -> No_block (fields lds)
  | Type_open -> Not_counted ("extensible variant " ^ Path.name p)
  | Type_abstract _ -> (
      match decl_view env p args decl with
      | Immediate _ -> Blocks [ None ]
      | _ -> Not_counted ("abstract type " ^ Path.name p))

(* A flat scalar, which owns no block: a layout other than value that is not
   a product. An unboxed product is counted by its parts. *)
let flat_scalar env ty =
  match Jkind.get_layout (Ctype.type_jkind env ty) with
  | Some (Product _) -> false
  | _ -> Option.is_some (flat_word env ty)
  | exception _ -> false
