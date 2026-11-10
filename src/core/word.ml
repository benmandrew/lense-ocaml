(* What one word of a given type holds: an immediate, a pointer to a block
   with a known tag, or either. Read from the type declarations in the
   environment, the same ones the compiler uses to choose a representation.
   What differs between OCaml 5.5 and OxCaml goes through Compat. *)

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
    match Compat.view ty with
    | Poly t -> word ~depth:(depth + 1) env t
    | _ when Option.is_some (Compat.flat_word env ty) ->
        Option.get (Compat.flat_word env ty)
    | Var None -> M.Any "type variable"
    | Var (Some v) -> M.Any ("type variable '" ^ v)
    (* A function after the first of a recursive set is an Infix_tag pointer
       into the set's closure, so the tag varies. *)
    | Arrow ->
        ptr
          (Printf.sprintf "closure, Closure_tag %d or Infix_tag %d"
             M.closure_tag M.infix_tag)
    | Tuple -> ptr ~tag:0 "tuple"
    | Unboxed_tuple -> M.Any "unboxed tuple"
    | Object -> ptr ~tag:M.object_tag "object"
    | Package -> ptr "first-class module"
    | Variant row -> (
        match row_counts row with
        | None -> M.Any "open polymorphic variant"
        | Some (_, 0) -> M.Immediate "constant polymorphic variant"
        | Some (0, _) -> ptr ~tag:0 "polymorphic variant"
        | Some _ -> M.Any "polymorphic variant")
    | Constr (p, args) -> constr ~depth env p args
    | Other -> M.Any "unknown type"

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
    path_is p Predef.path_int32
    || path_is p Predef.path_int64
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
    | `Maybe when Config.flat_float_array ->
        ptr "array (flat if its elements are floats)"
    | `Maybe -> ptr ~tag:0 "array"
  else if path_is p Predef.path_lazy_t then
    (* A forced or eagerly built lazy value can be the result itself. *)
    M.Any "lazy value"
  else if path_is p Predef.path_exn then ptr "exception"
  else if path_is p Predef.path_extension_constructor then
    ptr ~tag:M.object_tag "extension slot"
  else if Compat.or_null p then
    match args with
    | [ a ] -> (
        match word ~depth:(depth + 1) env a with
        | M.Immediate why -> M.Any ("null or " ^ why)
        | M.Pointer { what; _ } -> M.Any ("null or pointer to " ^ what)
        | w -> w)
    | _ -> M.Any "or_null"
  else
    match Compat.predef_word p with
    | Some w -> w
    | None -> (
        match Env.find_type p env with
        | exception Not_found -> M.Any "unknown type"
        | decl -> (
            let name = Path.name p in
            match Compat.decl_view env p args decl with
            | Unboxed_arg arg ->
                word ~depth:(depth + 1) env (instantiate env decl args arg)
            | Constructors (consts, blocks) -> (
                match (consts, blocks) with
                | _, 0 -> M.Immediate ("constant constructors of " ^ name)
                | 0, 1 -> ptr ~tag:0 name
                | 0, _ -> ptr name
                | _ -> M.Any name)
            | Float_record ->
                ptr ~tag:M.double_array_tag ("float record " ^ name)
            | Record -> ptr ~tag:0 ("record " ^ name)
            | Unboxed_record -> M.Any ("unboxed record " ^ name)
            | Open -> ptr ("extensible variant " ^ name)
            | Immediate why -> M.Immediate (name ^ " " ^ why)
            | Abstract -> M.Any ("abstract type " ^ name)))
