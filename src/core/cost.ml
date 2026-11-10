(* The words of the blocks a value of a given type owns, beyond the word that
   holds it: see Model.cost. Read from the same type declarations as Word.
   [group] is the recursive group of the type being described: a field of one
   of those types is a further node, counted on its own. Another recursive
   type, such as a list, is not counted, and gets the words of each of its
   nodes instead. *)

open Types
module M = Lense_model.Model

let custom_block bytes =
  M.fixed (2 + ((bytes + M.word_bytes - 1) / M.word_bytes))

let boxed_float = M.fixed (1 + (8 / M.word_bytes))

(* The type constructors in a declaration's own fields and manifest. *)
let decl_paths env p decl =
  let tys =
    (match Compat.layout env p decl.type_params decl with
      | No_block tys -> tys
      | Blocks cs -> List.concat_map (Option.value ~default:[]) cs
      | Flat _ | Not_counted _ -> [])
    @ Option.to_list decl.type_manifest
  in
  let seen = ref Btype.TypeSet.empty and paths = ref [] in
  let rec walk ty =
    if not (Btype.TypeSet.mem ty !seen) then begin
      seen := Btype.TypeSet.add ty !seen;
      (match get_desc ty with
      | Tconstr (q, _, _) -> paths := q :: !paths
      | _ -> ());
      Btype.iter_type_expr walk ty
    end
  in
  List.iter walk tys;
  !paths

(* Whether [p]'s declaration reaches [p] again. *)
let recursive env p =
  let visited = ref [] in
  let rec reaches q =
    if List.exists (Path.same q) !visited then false
    else begin
      visited := q :: !visited;
      match Env.find_type q env with
      | decl ->
          List.exists
            (fun r -> Path.same r p || reaches r)
            (decl_paths env q decl)
      | exception Not_found -> false
    end
  in
  reaches p

let in_group group p = List.exists (Path.same p) group

(* Whether [ty] names a type of the group. A type declared outside the group
   reaches the group only through its arguments. *)
let mentions ~group ty =
  let seen = ref Btype.TypeSet.empty in
  let rec walk ty =
    if Btype.TypeSet.mem ty !seen then false
    else begin
      seen := Btype.TypeSet.add ty !seen;
      (match get_desc ty with
        | Tconstr (p, _, _) -> in_group group p
        | _ -> false)
      ||
      let found = ref false in
      Btype.iter_type_expr (fun t -> if walk t then found := true) ty;
      !found
    end
  in
  walk ty

(* A member of the group, unless it only abbreviates another type: then its
   expansion is counted. *)
let node_of ~group env ty =
  match get_desc ty with
  | Tconstr (p, _, _) when in_group group p -> (
      match Env.find_type p env with
      | { type_kind = Type_abstract _; type_manifest = Some m; _ } -> (
          (* A polymorphic variant or tuple has no node type but this one. *)
          match get_desc m with
          | Tconstr _ -> false
          | _ -> true)
      | _ -> true
      | exception Not_found -> true)
  | _ -> false

let print_type ty =
  String.concat " "
    (List.filter (( <> ) "")
       (String.split_on_char ' '
          (String.map
             (function '\n' | '\t' | '\r' -> ' ' | c -> c)
             (Format.asprintf "%a" Printtyp.type_expr ty))))

let var_name = function Some v -> "'" ^ v | None -> "a type variable"

let rec owns ?(depth = 0) ~group env ty : M.cost =
  if depth > 64 then M.uncounted "a type too deep to count"
  else if node_of ~group env ty then M.node
  else
    let ty = Word.expand env ty in
    let down = owns ~depth:(depth + 1) ~group env in
    if node_of ~group env ty then M.node
    else
      match Compat.view ty with
      | Poly t -> down t
      | _ when Compat.flat_scalar env ty -> M.zero
      | Var v -> M.uncounted (var_name v)
      | Arrow -> M.uncounted "closure"
      | Tuple ->
          let tys = Compat.tuple_types ty in
          M.add (M.fixed (1 + List.length tys)) (M.sum (List.map down tys))
      | Unboxed_tuple -> M.sum (List.map down (Compat.unboxed_tuple_types ty))
      | Object -> M.uncounted "object"
      | Package -> M.uncounted "first-class module"
      | Variant row -> poly ~down row
      | Constr (p, args) -> constr ~depth ~group env ty p args
      | Other -> M.uncounted "a type of unknown representation"

(* A polymorphic variant: an immediate, or a block of the hash and the
   argument. *)
and poly ~down row =
  if Word.row_counts row = None then M.uncounted "open polymorphic variant"
  else
    let block ty = M.add (M.fixed 3) (down ty) in
    M.alt
      (List.concat_map
         (fun (_, f) ->
           match row_field_repr f with
           | Rpresent None | Reither (true, [], _) -> [ M.zero ]
           | Rpresent (Some ty) | Reither (false, ty :: _, _) -> [ block ty ]
           | Reither (true, ty :: _, _) -> [ M.zero; block ty ]
           | Reither (false, [], _) | Rabsent -> [])
         (row_fields row))

and constr ~depth ~group env ty p args =
  let is = Path.same p in
  if
    is Predef.path_int || is Predef.path_char || is Predef.path_bool
    || is Predef.path_unit
  then M.zero
  else if is Predef.path_float then boxed_float
  else if is Predef.path_string then M.uncounted "string"
  else if is Predef.path_bytes then M.uncounted "bytes"
  else if is Predef.path_int32 then custom_block 4
  else if is Predef.path_int64 then custom_block 8
  else if is Predef.path_nativeint then custom_block M.word_bytes
  else if
    is Predef.path_array || is Predef.path_iarray || is Predef.path_floatarray
  then M.uncounted "array"
  else if is Predef.path_lazy_t then M.uncounted "lazy value"
  else if is Predef.path_exn then M.uncounted "exception"
  else if is Predef.path_extension_constructor then M.uncounted "extension slot"
  else if Compat.or_null p then
    match args with
    | [ a ] -> M.alt [ M.zero; owns ~depth:(depth + 1) ~group env a ]
    | _ -> M.uncounted "or_null"
  else
    match Compat.predef_cost p with
    | Some c -> c
    | None -> (
        match Env.find_type p env with
        | exception Not_found -> M.uncounted (Path.name p)
        | decl ->
            if recursive env p then
              let what = print_type ty in
              match
                values ~depth ~group:(p :: group) env p args decl
                  ~nodes_only:true
              with
              | Some c ->
                  {
                    (M.uncounted ~per_node:c what) with
                    nodes = List.exists (mentions ~group) args;
                  }
              | None -> M.uncounted what
            else
              Option.value
                (values ~depth ~group env p args decl ~nodes_only:false)
                ~default:(M.uncounted (Path.name p)))

(* The words of a value of [p args], over its constructors. With
   [nodes_only], over the constructors that are blocks: the nodes of a
   recursive type. None when the declaration does not let them be counted. *)
and values ~depth ~group env p args decl ~nodes_only =
  let down ty =
    owns ~depth:(depth + 1) ~group env (Word.instantiate env decl args ty)
  in
  match Compat.layout env p args decl with
  | No_block tys -> Some (M.sum (List.map down tys))
  | Flat n -> Some (M.fixed (1 + n))
  | Blocks cs -> (
      let cs =
        List.filter_map
          (function
            | None -> if nodes_only then None else Some M.zero
            | Some tys ->
                Some
                  (M.add
                     (M.fixed (1 + List.length tys))
                     (M.sum (List.map down tys))))
          cs
      in
      match cs with [] -> None | cs -> Some (M.alt cs))
  | Not_counted what -> Some (M.uncounted what)
