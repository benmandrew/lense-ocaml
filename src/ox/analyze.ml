(* Typed trees to the model. Representations come from the compiler's own
   data: [record_representation] on each declaration, the constructor tags
   that Datarepr assigns, and the module coercions that Includemod computes.
   Nothing here re-derives a layout rule the compiler already decided. *)

open Types
module M = Lense_model.Model
module T = Typedtree

(* Environments read from a .cmt hold only summaries; Load replaces this
   with a function that rebuilds them. *)
let rebuild_env : (Env.t -> Env.t) ref = ref Fun.id

type ctx = {
  src : string option;  (** Source text, for spelling types as written. *)
  prefix : string;  (** "A.B." inside module B of module A. *)
}

let squash s =
  let b = Buffer.create (String.length s) in
  let space = ref false in
  String.iter
    (fun c ->
      match c with
      | ' ' | '\n' | '\t' | '\r' -> space := true
      | c ->
          if !space && Buffer.length b > 0 then Buffer.add_char b ' ';
          space := false;
          Buffer.add_char b c)
    s;
  Buffer.contents b

let slice ctx (loc : Location.t) =
  match ctx.src with
  | Some s when not loc.loc_ghost ->
      let a = loc.loc_start.pos_cnum and b = loc.loc_end.pos_cnum in
      if a >= 0 && b <= String.length s && a < b then Some (String.sub s a (b - a))
      else None
  | _ -> None

let print_type ty = squash (Format.asprintf "%a" Printtyp.type_expr ty)

let spell ctx (ct : T.core_type) =
  match slice ctx ct.ctyp_loc with
  | Some s -> squash s
  | None -> print_type ct.ctyp_type

let line (loc : Location.t) = loc.loc_start.pos_lnum

let field ?(fkind = M.Arg) ?(mutable_ = false) ~env ctx (ct : T.core_type) : M.field =
  { fkind; ty = spell ctx ct; mutable_; word = Word.word env ct.ctyp_type }

let label_field ~env ctx (ld : T.label_declaration) =
  field ~fkind:(M.Label ld.ld_name.txt) ~mutable_:(ld.ld_mutable <> Immutable) ~env ctx
    ld.ld_type

let arg_fields ~env ctx = function
  | T.Cstr_tuple cas -> List.map (fun (ca : T.constructor_argument) -> field ~env ctx ca.ca_type) cas
  | T.Cstr_record lds -> List.map (label_field ~env ctx) lds

(* Field types are wrapped in Tpoly, because fields can be polymorphic. *)
let rec is_float env ty =
  match get_desc (Word.expand env ty) with
  | Tconstr (p, _, _) -> Path.same p Predef.path_float
  | Tpoly (t, []) -> is_float env t
  | _ -> false

(* Notes on a constructor that the tag alone does not show. *)
let constructor_notes env (desc : Types.constructor_description)
    (args : T.constructor_arguments) =
  let ex =
    match desc.cstr_existentials with
    | [] -> []
    | tys ->
        [
          "existential "
          ^ String.concat ", " (List.map print_type tys)
          ^ ": stored as uniform values";
        ]
  in
  let inline_floats =
    match args with
    | T.Cstr_record lds
      when lds <> [] && List.for_all (fun ld -> is_float env ld.T.ld_type.ctyp_type) lds ->
        [ "inline record: all fields are float, but inline records are never stored flat" ]
    | _ -> []
  in
  ex @ inline_floats

let slot_field name =
  { M.fkind = M.Slot name; ty = "extension slot"; mutable_ = false;
    word = M.Pointer { tag = Some M.object_tag; what = "extension slot" } }

(* OxCaml mixed blocks. The compiler's own Mixed_block_shape puts the
   elements in memory order: values first, then flat data, each in
   declaration order, with unboxed products split into their parts. *)
let element_data (e : unit Lambda.mixed_block_element) =
  match e with
  | Value _ | Float_boxed _ | Float64 | Bits64 | Word | Untagged_immediate -> ("", 8, 1)
  | Float32 -> ("float32", 4, 1)
  | Bits32 -> ("bits32", 4, 1)
  | Bits16 -> ("bits16", 2, 1)
  | Bits8 -> ("bits8", 1, 1)
  | Vec128 -> ("vec128", 16, 2)
  | Vec256 -> ("vec256", 32, 4)
  | Vec512 -> ("vec512", 64, 8)
  | Product _ -> ("product", 0, 0)

(* The name and type of a part of an unboxed product field, from its path. *)
let rec part_of env ty path =
  match path with
  | [] -> ("", Some ty)
  | j :: rest -> (
      let ty = Word.expand env ty in
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
          | { type_kind = Type_record_unboxed_product (lds, _, _); _ } as decl when j < List.length lds ->
              let ld = List.nth lds j in
              down (Ident.name ld.ld_id) (Word.instantiate env decl args ld.ld_type)
          | _ -> ("." ^ string_of_int j, None)
          | exception Not_found -> ("." ^ string_of_int j, None))
      | _ -> ("." ^ string_of_int j, None))

let element_word ~env (fields : M.field array) field part_ty (e : unit Lambda.mixed_block_element) : M.word =
  match e with
  | Value _ when part_ty = None -> fields.(field).word
  | Value _ -> Word.word env (Option.get part_ty)
  | Float_boxed _ -> M.Flat { layout = "float64, boxed again when read"; bytes = 8 }
  | Float64 -> M.Flat { layout = "float64"; bytes = 8 }
  | Bits64 -> M.Flat { layout = "bits64"; bytes = 8 }
  | Word -> M.Flat { layout = "word"; bytes = 8 }
  | Untagged_immediate -> M.Flat { layout = "untagged immediate"; bytes = 8 }
  | e ->
      let layout, bytes, _ = element_data e in
      M.Flat { layout; bytes }

let mixed ~env ~tys ~tag (shape : Types.mixed_product_shape) (fields : M.field list) : M.shape =
  let tys = Array.of_list tys in
  let lshape = Lambda.transl_mixed_product_shape shape in
  let t = Mixed_block_shape.of_mixed_block_elements ~print_locality:(fun _ () -> ()) lshape in
  let order = Mixed_block_shape.flattened_reordered_shape t in
  let farr = Array.of_list fields in
  let slots =
    Array.to_list
      (Array.mapi
         (fun i (e : unit Mixed_block_shape.Singleton_mixed_block_element.t) ->
           let path = Mixed_block_shape.new_index_to_old_path t i in
           let field, rest = match path with f :: r -> (f, r) | [] -> (0, []) in
           let part, part_ty =
             if rest = [] || field >= Array.length tys then ("", None)
             else
               let n, t = part_of env tys.(field) rest in
               (n, t)
           in
           let pty = match part_ty with Some t -> print_type t | None -> "" in
           let le : unit Lambda.mixed_block_element =
             match e with
             | Value v -> Value v | Float_boxed () -> Float_boxed () | Float64 -> Float64
             | Float32 -> Float32 | Bits8 -> Bits8 | Bits16 -> Bits16 | Bits32 -> Bits32
             | Bits64 -> Bits64 | Vec128 -> Vec128 | Vec256 -> Vec256 | Vec512 -> Vec512
             | Word -> Word | Untagged_immediate -> Untagged_immediate
           in
           let _, data, words = element_data le in
           { M.field; part; pty; mword = element_word ~env farr field (if part = "" then None else part_ty) le; words; data })
         order)
  in
  Mixed { tag; fields; scanned = Mixed_block_shape.value_prefix_len t; slots }

let block_or_mixed ~env ~tys ~tag (cshape : Types.constructor_representation) fields : M.shape =
  match cshape with
  | Constructor_uniform_value -> Block { tag; fields }
  | Constructor_mixed shape -> mixed ~env ~tys ~tag shape fields

let arg_types = function
  | T.Cstr_tuple cas -> List.map (fun (ca : T.constructor_argument) -> ca.ca_type.ctyp_type) cas
  | T.Cstr_record lds -> List.map (fun (ld : T.label_declaration) -> ld.ld_type.ctyp_type) lds

let shape_of_cstr ~env ~tys name (desc : Types.constructor_description) fields : M.shape =
  match (desc.cstr_repr, desc.cstr_tag) with
  | Variant_unboxed, _ -> ( match fields with [ f ] -> Unboxed f | _ -> Block { tag = 0; fields })
  | _, Null -> Constant 0
  | _, Ordinary { runtime_tag; _ } when desc.cstr_constant -> Constant runtime_tag
  | _, Ordinary { runtime_tag; _ } -> block_or_mixed ~env ~tys ~tag:runtime_tag desc.cstr_shape fields
  | _, Extension _ when desc.cstr_constant -> Ext_slot
  | _, Extension _ -> (
      (* The extension slot comes first, as an extra value field. *)
      match desc.cstr_shape with
      | Constructor_uniform_value -> Block { tag = 0; fields = slot_field name :: fields }
      | Constructor_mixed shape ->
          mixed ~env ~tys:(Predef.type_int :: tys) ~tag:0 (Array.append [| Types.Value |] shape) (slot_field name :: fields))

let poly_cases env row : M.case list =
  List.filter_map
    (fun (label, f) ->
      let hash = Btype.hash_variant label in
      let name = "`" ^ label in
      let block ty =
        let arg = { M.fkind = Arg; ty = print_type ty; mutable_ = false; word = Word.word env ty } in
        let h =
          { M.fkind = Hash hash; ty = "int"; mutable_ = false; word = M.Immediate "label hash" }
        in
        M.Block { tag = 0; fields = [ h; arg ] }
      in
      match row_field_repr f with
      | Rpresent None | Reither (true, [], _) -> Some { M.name; shape = Constant hash; notes = [] }
      | Rpresent (Some ty) | Reither (false, [ ty ], _) ->
          Some { M.name; shape = block ty; notes = [] }
      | Reither (_, ty :: _, _) ->
          Some
            { M.name; shape = block ty;
              notes = [ "conjunctive type: the value may be constant or carry an argument" ] }
      | Reither (false, [], _) | Rabsent -> None)
    (List.sort (fun (a, _) (b, _) -> compare (Btype.hash_variant a) (Btype.hash_variant b)) (row_fields row))

let params ctx (td : T.type_declaration) =
  match td.typ_params with
  | [] -> ""
  | [ (ct, _) ] -> spell ctx ct
  | ps -> "(" ^ String.concat ", " (List.map (fun (ct, _) -> spell ctx ct) ps) ^ ")"

let type_decl ~env ctx (td : T.type_declaration) : M.decl =
  let decl = td.typ_type in
  let path = Path.Pident td.typ_id in
  let kind : M.kind =
    match (decl.type_kind, td.typ_kind) with
    | Type_record (_, repr, _), Ttype_record lds -> (
        let fields = List.map (label_field ~env ctx) lds in
        match repr with
        | Record_float | Record_ufloat ->
            Record (Flat_float (List.map (fun (f : M.field) -> { f with word = M.Double }) fields))
        | Record_unboxed -> Record (match fields with [ f ] -> Unboxed f | _ -> Block { tag = 0; fields })
        | Record_mixed shape ->
            let tys = List.map (fun (ld : T.label_declaration) -> ld.ld_type.ctyp_type) lds in
            Record (mixed ~env ~tys ~tag:0 shape fields)
        | Record_boxed _ | Record_inlined _ -> Record (Block { tag = 0; fields }))
    | Type_record_unboxed_product _, Ttype_record_unboxed_product lds ->
        Record (Product (List.map (label_field ~env ctx) lds))
    | Type_variant _, Ttype_variant cds ->
        let descs = Datarepr.constructors_of_type ~current_unit:None path decl in
        Variant
          (List.map2
             (fun (cd : T.constructor_declaration) (_, (desc : Types.constructor_description)) ->
               let fields = arg_fields ~env ctx cd.cd_args in
               { M.name = cd.cd_name.txt;
                 shape = shape_of_cstr ~env ~tys:(arg_types cd.cd_args) cd.cd_name.txt desc fields;
                 notes = constructor_notes env desc cd.cd_args })
             cds descs)
    | Type_open, _ -> Open
    | _, _ -> (
        match decl.type_manifest with
        | Some ty -> (
            match get_desc (Word.expand env ty) with
            | Tvariant row ->
                Polyvariant { cases = poly_cases env row; closed = Word.row_counts row <> None }
            | _ -> Alias (Word.word env ty))
        | None -> Abstract (Word.word env (Btype.newgenty (Tconstr (path, decl.type_params, ref Mnil)))))
  in
  let notes =
    match td.typ_kind with
    | Ttype_variant cds when List.exists (fun (cd : T.constructor_declaration) -> cd.cd_res <> None) cds ->
        [ "GADT: type indices are erased, so the constructors are numbered as in an ordinary variant" ]
    | _ -> []
  in
  { M.name = ctx.prefix ^ td.typ_name.txt; params = params ctx td; keyword = "type";
    line = line td.typ_loc; source = Option.map squash (slice ctx td.typ_loc); kind; notes }

let ext_decl ~env ctx ~keyword (ec : T.extension_constructor) : M.decl =
  let name = ec.ext_name.txt in
  let case : M.case =
    match ec.ext_kind with
    | Text_rebind (p, _) -> { name; shape = Rebind (Path.name p); notes = [] }
    | Text_decl (_, args, _) ->
        let desc =
          Datarepr.extension_descr ~current_unit:None (Path.Pident ec.ext_id) ec.ext_type
        in
        let fields = arg_fields ~env ctx args in
        { name; shape = shape_of_cstr ~env ~tys:(arg_types args) name desc fields;
          notes = constructor_notes env desc args }
  in
  { M.name = ctx.prefix ^ name; params = ""; keyword; line = line ec.ext_loc;
    source = Option.map squash (slice ctx ec.ext_loc); kind = Extension case; notes = [] }

(* Module structures (stage 2). *)

let rec is_functor env mty =
  match Mtype.scrape env mty with
  | Mty_functor _ -> true
  | Mty_alias p -> (
      match Env.find_module p env with
      | md -> is_functor env md.md_type
      | exception Not_found -> false)
  | _ -> false
  | exception _ -> false

(* Mirrors Types.bound_value_identifiers, which decides the field order of a
   structure block, and keeps the kind and word of each item. *)
let slots env (sg : signature) =
  let n = ref 0 in
  let slots = ref [] and none = ref [] in
  let add item id word =
    slots := { M.index = !n; item; name = Ident.name id; word } :: !slots;
    incr n
  in
  (* A class also declares a class type and an object type of its name. *)
  let classes =
    List.filter_map (function Sig_class (id, _, _, _) -> Some (Ident.name id) | _ -> None) sg
  in
  let hidden id =
    let s = Ident.name id in
    (String.length s > 0 && s.[0] = '#') || List.mem s classes
  in
  List.iter
    (function
      | Sig_value (id, { val_kind = Val_reg; val_type; _ }, _) ->
          add M.Value id (Word.word env val_type)
      | Sig_value (id, _, _) -> none := ("external " ^ Ident.name id) :: !none
      | Sig_typext (id, ext, _, _) ->
          let item = if Path.same ext.ext_type_path Predef.path_exn then M.Exception else M.Extension in
          add item id (M.Pointer { tag = Some M.object_tag; what = "extension slot" })
      | Sig_module (id, Mp_present, md, _, _) ->
          if is_functor env md.md_type then
            add M.Functor id (M.Pointer { tag = Some M.closure_tag; what = "closure" })
          else add M.Module id (M.Pointer { tag = Some 0; what = "structure" })
      | Sig_module (id, Mp_absent, _, _, _) -> none := ("module alias " ^ Ident.name id) :: !none
      | Sig_class (id, _, _, _) -> add M.Class id (M.Pointer { tag = Some 0; what = "class" })
      | Sig_type (id, _, _, _) when not (hidden id) -> none := ("type " ^ Ident.name id) :: !none
      | Sig_modtype (id, _, _) -> none := ("module type " ^ Ident.name id) :: !none
      | Sig_class_type (id, _, _, _) when not (hidden id) ->
          none := ("class type " ^ Ident.name id) :: !none
      | Sig_type _ | Sig_class_type _ -> ())
    sg;
  (List.rev !slots, List.rev !none)

let slot_names env mty =
  match Mtype.scrape env mty with
  | Mty_signature sg -> Array.of_list (Types.bound_value_identifiers sg |> List.map Ident.name)
  | _ -> [||]
  | exception _ -> [||]

let coercion ~env ~context ~cline ~src_mty ~dst_mty (cc : T.module_coercion) : M.coercion option =
  let src_names = slot_names env src_mty and dst_names = slot_names env dst_mty in
  let name i names = if i >= 0 && i < Array.length names then names.(i) else "?" in
  match cc with
  | Tcoerce_none ->
      Some { context; cline; src_size = Array.length src_names; copy = None; functor_wrap = false }
  | Tcoerce_functor _ ->
      Some { context; cline; src_size = 0; copy = None; functor_wrap = true }
  | Tcoerce_structure (pos_cc, _) ->
      let moves =
        List.mapi
          (fun dst (src, cc) ->
            let how : M.move_kind =
              match (cc : T.module_coercion) with
              | Tcoerce_none -> Copy
              | Tcoerce_structure _ | Tcoerce_functor _ -> Coerced
              | Tcoerce_primitive _ -> Wrapped_primitive
              | Tcoerce_alias _ -> Realised_alias
            in
            { M.dst; src; name = name dst dst_names; how })
          pos_cc
      in
      Some { context; cline; src_size = Array.length src_names; copy = Some moves; functor_wrap = false }
  | Tcoerce_primitive _ | Tcoerce_alias _ -> None

type acc = {
  mutable decls : M.decl list;
  mutable modules : M.structure list;
  mutable coercions : M.coercion list;
}

let add_structure acc ~name ~line ~params ~env sg =
  let slots, no_slot = slots env sg in
  acc.modules <- { M.mname = name; mline = line; functor_params = params; slots; no_slot } :: acc.modules

let rec structure acc ctx ~name ~line ~params (str : T.structure) =
  let env = !rebuild_env str.str_final_env in
  add_structure acc ~name ~line ~params ~env str.str_type;
  List.iter (structure_item acc ctx ~env) str.str_items

and structure_item acc ctx ~env (item : T.structure_item) =
  match item.str_desc with
  | Tstr_type (_, tds) -> List.iter (fun td -> acc.decls <- type_decl ~env ctx td :: acc.decls) tds
  | Tstr_typext te ->
      List.iter
        (fun ec -> acc.decls <- ext_decl ~env ctx ~keyword:"extension" ec :: acc.decls)
        te.tyext_constructors
  | Tstr_exception te ->
      acc.decls <- ext_decl ~env ctx ~keyword:"exception" te.tyexn_constructor :: acc.decls
  | Tstr_module mb -> module_binding acc ctx ~env mb
  | Tstr_recmodule mbs -> List.iter (module_binding acc ctx ~env) mbs
  | Tstr_include { incl_mod; _ } -> module_expr acc ctx ~env ~name:None ~params:[] incl_mod
  | _ -> ()

and module_binding acc ctx ~env (mb : T.module_binding) =
  let name = Option.value mb.mb_name.txt ~default:"_" in
  module_expr acc ctx ~env ~name:(Some name) ~params:[] mb.mb_expr

(* Walk a module expression bound to [name] (None for an include, whose items
   join the enclosing structure). Records the structures it builds and the
   coercions it applies. *)
and module_expr acc ctx ~env ~name ~params (me : T.module_expr) =
  let qualified = Option.map (fun n -> ctx.prefix ^ n) name in
  let inner = match name with Some n -> { ctx with prefix = ctx.prefix ^ n ^ "." } | None -> ctx in
  match me.mod_desc with
  | Tmod_structure str -> (
      match qualified with
      | Some q -> structure acc inner ~name:q ~line:(line me.mod_loc) ~params str
      | None -> List.iter (structure_item acc inner ~env:(!rebuild_env str.str_final_env)) str.str_items)
  | Tmod_functor (param, body) ->
      let p =
        match param with
        | Unit -> "()"
        | Named (_, { txt; _ }, _) -> "(" ^ Option.value txt ~default:"_" ^ ")"
      in
      module_expr acc ctx ~env ~name ~params:(params @ [ p ]) body
  | Tmod_constraint (sub, mty, _, cc) ->
      let context =
        match qualified with
        | Some q -> "module " ^ q ^ String.concat "" params ^ " : " ^ squash (Format.asprintf "%a" Printtyp.modtype mty)
        | None -> "include at line " ^ string_of_int (line me.mod_loc)
      in
      (match coercion ~env:(!rebuild_env me.mod_env) ~context ~cline:(line me.mod_loc) ~src_mty:sub.mod_type ~dst_mty:mty cc with
      | Some c -> acc.coercions <- c :: acc.coercions
      | None -> ());
      module_expr acc ctx ~env ~name ~params sub
  | Tmod_apply (f, arg, cc) ->
      module_expr acc ctx ~env ~name:None ~params:[] arg;
      let fname =
        match f.mod_desc with
        | Tmod_ident (p, _) -> Path.name p
        | _ -> "a functor"
      in
      let param_mty =
        match Mtype.scrape env f.mod_type with
        | Mty_functor (Named (_, pmty), _) -> Some pmty
        | _ -> None
        | exception _ -> None
      in
      (match (cc, param_mty) with
      | T.Tcoerce_none, _ | _, None -> ()
      | cc, Some dst_mty -> (
          let context = "argument of " ^ fname ^ " at line " ^ string_of_int (line me.mod_loc) in
          match coercion ~env:(!rebuild_env me.mod_env) ~context ~cline:(line me.mod_loc) ~src_mty:arg.mod_type ~dst_mty cc with
          | Some c -> acc.coercions <- c :: acc.coercions
          | None -> ()))
  | Tmod_ident _ | Tmod_apply_unit _ | Tmod_unpack _ -> ()

let rec signature acc ctx (sg : T.signature) =
  let env = !rebuild_env sg.sig_final_env in
  List.iter
    (fun (item : T.signature_item) ->
      match item.sig_desc with
      | Tsig_type (_, tds) -> List.iter (fun td -> acc.decls <- type_decl ~env ctx td :: acc.decls) tds
      | Tsig_typext te ->
          List.iter
            (fun ec -> acc.decls <- ext_decl ~env ctx ~keyword:"extension" ec :: acc.decls)
            te.tyext_constructors
      | Tsig_exception te ->
          acc.decls <- ext_decl ~env ctx ~keyword:"exception" te.tyexn_constructor :: acc.decls
      | Tsig_module { md_name = { txt = Some n; _ }; md_type = { mty_desc = Tmty_signature s; _ }; _ } ->
          signature acc { ctx with prefix = ctx.prefix ^ n ^ "." } s
      | _ -> ())
    sg.sig_items

(* Every polymorphic-variant label written in types, expressions and patterns. *)
let labels ~file iter_with =
  let found = ref [] in
  let add label (loc : Location.t) =
    found := { M.label; hash = Btype.hash_variant label; file; lline = line loc } :: !found
  in
  let open Tast_iterator in
  let typ it (ct : T.core_type) =
    (match ct.ctyp_desc with
    | Ttyp_variant (rfs, _, _) ->
        List.iter (fun (rf : T.row_field) ->
            match rf.rf_desc with Ttag (l, _, _) -> add l.txt l.loc | Tinherit _ -> ()) rfs
    | _ -> ());
    default_iterator.typ it ct
  in
  let expr it (e : T.expression) =
    (match e.exp_desc with Texp_variant (l, _) -> add l e.exp_loc | _ -> ());
    default_iterator.expr it e
  in
  let pat : type k. iterator -> k T.general_pattern -> unit =
   fun it p ->
    (match p.pat_desc with Tpat_variant (l, _, _) -> add l p.pat_loc | _ -> ());
    default_iterator.pat it p
  in
  iter_with { default_iterator with typ; expr; pat };
  List.rev !found

type input = Impl of T.structure | Intf of T.signature

(* The coercion that turns a unit's own structure into the block its
   interface describes: [interface] is (env, interface file, its signature,
   the coercion Includemod.compunit computed). *)
let unit_coercion acc ~unit_name (str : T.structure) (env, intf_file, intf_sg, cc) =
  let context = "unit " ^ unit_name ^ " : " ^ Filename.basename intf_file in
  match coercion ~env ~context ~cline:1 ~src_mty:(Mty_signature str.str_type) ~dst_mty:(Mty_signature intf_sg) cc with
  | Some c -> acc.coercions <- c :: acc.coercions
  | None -> ()

let analyze ?interface ~file ~unit_name ~src input : M.compunit =
  let acc = { decls = []; modules = []; coercions = [] } in
  let ctx = { src; prefix = "" } in
  let labels =
    match input with
    | Impl str ->
        structure acc ctx ~name:unit_name ~line:1 ~params:[] str;
        Option.iter (unit_coercion acc ~unit_name str) interface;
        labels ~file (fun it -> it.structure it str)
    | Intf sg ->
        signature acc ctx sg;
        labels ~file (fun it -> it.signature it sg)
  in
  { M.file; unit_name; decls = List.rev acc.decls; modules = List.rev acc.modules;
    coercions = List.rev acc.coercions; labels }
