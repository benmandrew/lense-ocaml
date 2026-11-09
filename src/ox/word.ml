(* What one word of a given type holds: an immediate, a pointer to a block
   with a known tag, or either. Read from the type declarations in the
   environment, the same ones the compiler uses to choose a representation.
   OxCaml version: a type of a non-value layout is flat data. *)

open Types
module M = Lense_model.Model

let ptr ?tag what = M.Pointer { tag; what }

let path_is p q = Path.same p q

(* Apply a declaration's parameters to [args] in [ty]. Falls back to the
   unsubstituted type, which only loses precision on type variables. *)
let instantiate env decl args ty =
  try Ctype.apply env decl.type_params ty args with _ -> ty

let expand env ty = try Ctype.expand_head_opt env ty with _ -> ty

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

(* The layout of [ty] when it is known and is not a kind of value. *)
let flat_layout env ty =
  match Jkind.get_layout (Ctype.type_jkind env ty) with
  | Some l -> (
      match Jkind.Layout.Const.to_string l with
      | "value" | "value_or_null" | "immediate" | "immediate64" | "any" -> None
      | l -> Some l)
  | None -> None
  | exception _ -> None

let flat layout = M.Flat { layout; bytes = layout_bytes layout }

(* The constant and non-constant counts of a polymorphic variant row, or
   None when the row is open and further tags may appear. *)
let row_counts row =
  let consts, blocks =
    List.fold_left
      (fun (c, b) (_, f) ->
        match row_field_repr f with
        | Rpresent None -> (c + 1, b)
        | Rpresent (Some _) -> (c, b + 1)
        | Reither (true, [], _) -> (c + 1, b)
        | Reither (true, _, _) -> (c + 1, b + 1)
        | Reither (false, _, _) -> (c, b + 1)
        | Rabsent -> (c, b))
      (0, 0) (row_fields row)
  in
  if row_closed row then Some (consts, blocks) else None

let rec word ?(depth = 0) env ty : M.word =
  if depth > 64 then M.Any "type too deep to classify"
  else
    let ty = expand env ty in
    match get_desc ty with
    | Tpoly (t, _) -> word ~depth:(depth + 1) env t
    | _ when Option.is_some (flat_layout env ty) -> flat (Option.get (flat_layout env ty))
    | Tvar { name = None; _ } | Tunivar { name = None; _ } -> M.Any "type variable"
    | Tvar { name = Some v; _ } | Tunivar { name = Some v; _ } -> M.Any ("type variable '" ^ v)
    | Tarrow _ -> ptr ~tag:M.closure_tag "closure"
    | Ttuple _ -> ptr ~tag:0 "tuple"
    | Tunboxed_tuple _ -> M.Any "unboxed tuple"
    | Tobject _ -> ptr ~tag:M.object_tag "object"
    | Tpackage _ -> ptr "first-class module"
    | Tvariant row -> (
        match row_counts row with
        | None -> M.Any "open polymorphic variant"
        | Some (_, 0) -> M.Immediate "constant polymorphic variant"
        | Some (0, _) -> ptr ~tag:0 "polymorphic variant"
        | Some _ -> M.Any "polymorphic variant")
    | Tconstr (p, args, _) -> constr ~depth env p args
    | Tlink _ | Tsubst _ | Tfield _ | Tnil | Tquote _ | Tsplice _ | Tof_kind _ ->
        M.Any "unknown type"

and constr ~depth env p args =
  let elt_is_float () =
    match args with
    | [ a ] -> (
        match get_desc (expand env a) with
        | Tconstr (q, _, _) when path_is q Predef.path_float -> `Yes
        | Tvar _ | Tunivar _ -> `Maybe
        | Tconstr (q, _, _) -> (
            (* An abstract element type could still be float. *)
            match Env.find_type q env with
            | { type_kind = Type_abstract _; type_manifest = None; _ } -> `Maybe
            | _ -> `No
            | exception Not_found -> `Maybe)
        | _ -> `No)
    | _ -> `Maybe
  in
  if path_is p Predef.path_int then M.Immediate "int"
  else if path_is p Predef.path_int8 || path_is p Predef.path_int16 then M.Immediate (Path.name p)
  else if path_is p Predef.path_char then M.Immediate "char"
  else if path_is p Predef.path_bool then M.Immediate "bool"
  else if path_is p Predef.path_unit then M.Immediate "unit"
  else if path_is p Predef.path_float then ptr ~tag:M.double_tag "boxed float"
  else if path_is p Predef.path_string || path_is p Predef.path_bytes then
    ptr ~tag:M.string_tag "string"
  else if
    path_is p Predef.path_int32 || path_is p Predef.path_int64
    || path_is p Predef.path_nativeint || path_is p Predef.path_float32
  then ptr ~tag:M.custom_tag "custom block"
  else if path_is p Predef.path_floatarray then
    (* The empty array is a shared tag-0 atom. *)
    ptr "float array (Double_array_tag 254 unless empty)"
  else if path_is p Predef.path_array || path_is p Predef.path_iarray then
    match elt_is_float () with
    | `No -> ptr ~tag:0 "array"
    | `Yes when Config.flat_float_array ->
        ptr "float array (Double_array_tag 254 unless empty)"
    | `Yes -> ptr ~tag:0 "array"
    | `Maybe when Config.flat_float_array -> ptr "array (flat if its elements are floats)"
    | `Maybe -> ptr ~tag:0 "array"
  else if path_is p Predef.path_lazy_t then
    (* A forced or eagerly built lazy value can be the result itself. *)
    M.Any "lazy value"
  else if path_is p Predef.path_exn then ptr "exception"
  else if path_is p Predef.path_extension_constructor then
    ptr ~tag:M.object_tag "extension slot"
  else if path_is p Predef.path_or_null then
    match args with
    | [ a ] -> (
        match word ~depth:(depth + 1) env a with
        | M.Immediate why -> M.Any ("null or " ^ why)
        | M.Pointer { what; _ } -> M.Any ("null or pointer to " ^ what)
        | w -> w)
    | _ -> M.Any "or_null"
  else
    match Env.find_type p env with
    | exception Not_found -> M.Any "unknown type"
    | decl -> (
        let name = Path.name p in
        match decl.type_kind with
        | Type_variant ([ { cd_args = Cstr_tuple [ { ca_type = arg; _ } ]; _ } ], Variant_unboxed, _)
        | Type_variant
            ([ { cd_args = Cstr_record [ { ld_type = arg; _ } ]; _ } ], Variant_unboxed, _)
        | Type_record ([ { ld_type = arg; _ } ], Record_unboxed, _) ->
            word ~depth:(depth + 1) env (instantiate env decl args arg)
        | Type_variant (cstrs, _, _) -> (
            let consts =
              List.length (List.filter (fun c -> c.cd_args = Cstr_tuple []) cstrs)
            in
            match (consts, List.length cstrs - consts) with
            | _, 0 -> M.Immediate ("constant constructors of " ^ name)
            | 0, 1 -> ptr ~tag:0 name
            | 0, _ -> ptr name
            | _ -> M.Any name)
        | Type_record (_, (Record_float | Record_ufloat), _) ->
            ptr ~tag:M.double_array_tag ("float record " ^ name)
        | Type_record _ -> ptr ~tag:0 ("record " ^ name)
        | Type_record_unboxed_product _ -> M.Any ("unboxed record " ^ name)
        | Type_open -> ptr ("extensible variant " ^ name)
        | Type_abstract _ ->
            let ty = Btype.newgenty (Tconstr (p, args, ref Mnil)) in
            if (try Ctype.is_always_gc_ignorable env ty with _ -> false) then
              M.Immediate (name ^ " : immediate")
            else M.Any ("abstract type " ^ name))
