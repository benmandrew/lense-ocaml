(* What one word of a given type holds: an immediate, a pointer to a block
   with a known tag, or either. Read from the type declarations in the
   environment, the same ones the compiler uses to choose a representation. *)

open Types
module M = Lense_model.Model

let ptr ?tag what = M.Pointer { tag; what }

let path_is p q = Path.same p q

(* Apply a declaration's parameters to [args] in [ty]. Falls back to the
   unsubstituted type, which only loses precision on type variables. *)
let instantiate env decl args ty =
  try Ctype.apply env decl.type_params ty args with _ -> ty

let expand env ty = try Ctype.expand_head_opt env ty with _ -> ty

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
    | Tvar None | Tunivar None -> M.Any "type variable"
    | Tvar (Some v) | Tunivar (Some v) -> M.Any ("type variable '" ^ v)
    | Tpoly (t, _) -> word ~depth:(depth + 1) env t
    | Tarrow _ | Tfunctor _ -> ptr ~tag:M.closure_tag "closure"
    | Ttuple _ -> ptr ~tag:0 "tuple"
    | Tobject _ -> ptr ~tag:M.object_tag "object"
    | Tpackage _ -> ptr "first-class module"
    | Tvariant row -> (
        match row_counts row with
        | None -> M.Any "open polymorphic variant"
        | Some (_, 0) -> M.Immediate "constant polymorphic variant"
        | Some (0, _) -> ptr ~tag:0 "polymorphic variant"
        | Some _ -> M.Any "polymorphic variant")
    | Tconstr (p, args, _) -> constr ~depth env p args
    | Tlink _ | Tsubst _ | Tfield _ | Tnil -> M.Any "unknown type"

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
  else if path_is p Predef.path_char then M.Immediate "char"
  else if path_is p Predef.path_bool then M.Immediate "bool"
  else if path_is p Predef.path_unit then M.Immediate "unit"
  else if path_is p Predef.path_float then ptr ~tag:M.double_tag "boxed float"
  else if path_is p Predef.path_string || path_is p Predef.path_bytes then
    ptr ~tag:M.string_tag "string"
  else if
    path_is p Predef.path_int32 || path_is p Predef.path_int64
    || path_is p Predef.path_nativeint
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
  else if path_is p Predef.path_continuation then ptr ~tag:M.cont_tag "continuation"
  else
    match Env.find_type p env with
    | exception Not_found -> M.Any "unknown type"
    | decl -> (
        let name = Path.name p in
        match decl.type_kind with
        | Type_variant ([ { cd_args = Cstr_tuple [ arg ]; _ } ], Variant_unboxed)
        | Type_variant
            ( [ { cd_args = Cstr_record [ { ld_type = arg; _ } ]; _ } ],
              Variant_unboxed )
        | Type_record ([ { ld_type = arg; _ } ], Record_unboxed _) ->
            word ~depth:(depth + 1) env (instantiate env decl args arg)
        | Type_variant (cstrs, _) -> (
            let consts =
              List.length (List.filter (fun c -> c.cd_args = Cstr_tuple []) cstrs)
            in
            match (consts, List.length cstrs - consts) with
            | _, 0 -> M.Immediate ("constant constructors of " ^ name)
            | 0, 1 -> ptr ~tag:0 name
            | 0, _ -> ptr name
            | _ -> M.Any name)
        | Type_record (_, Record_float) -> ptr ~tag:M.double_array_tag ("float record " ^ name)
        | Type_record _ -> ptr ~tag:0 ("record " ^ name)
        | Type_open -> ptr ("extensible variant " ^ name)
        | Type_abstract _ | Type_external _ -> (
            match decl.type_immediate with
            | Type_immediacy.Always -> M.Immediate (name ^ " [@@immediate]")
            | Always_on_64bits when Sys.word_size = 64 ->
                M.Immediate (name ^ " [@@immediate64]")
            | _ -> M.Any ("abstract type " ^ name)))
