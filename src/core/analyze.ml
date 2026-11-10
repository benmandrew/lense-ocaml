(* Typed trees to the model. Representations come from the compiler's own
   data: [record_representation] on each declaration, the constructor tags
   that Datarepr assigns, and the field order of Types.bound_value_identifiers.
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
  own : string;  (** The file locations name for the unit's source. *)
  group : Path.t list;
      (** The recursive group of the types being read, whose values are counted
          node by node. *)
}

(* The file the unit's own locations name, read from its first item. *)
let own_file locs =
  match
    List.find_opt (fun (l : Location.t) -> l.loc_start.pos_fname <> "") locs
  with
  | Some l -> l.loc_start.pos_fname
  | None -> ""

let structure_file (str : T.structure) =
  own_file (List.map (fun (i : T.structure_item) -> i.str_loc) str.str_items)

let signature_file (sg : T.signature) =
  own_file (List.map (fun (i : T.signature_item) -> i.sig_loc) sg.sig_items)

(* A location in the unit's source as a range; none for one in another
   file, or one the compiler made up. *)
let range ctx (loc : Location.t) : M.range option =
  let a = loc.loc_start and b = loc.loc_end in
  if
    ctx.own = "" || a.pos_fname <> ctx.own || a.pos_cnum < 0
    || b.pos_cnum < a.pos_cnum
  then None
  else
    Some
      {
        first_line = a.pos_lnum;
        first_col = a.pos_cnum - a.pos_bol;
        last_line = b.pos_lnum;
        last_col = b.pos_cnum - b.pos_bol;
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
      if a >= 0 && b <= String.length s && a < b then
        Some (String.sub s a (b - a))
      else None
  | _ -> None

let print_type ty = squash (Format.asprintf "%a" Printtyp.type_expr ty)

let spell ctx (ct : T.core_type) =
  match slice ctx ct.ctyp_loc with
  | Some s -> squash s
  | None -> print_type ct.ctyp_type

let line (loc : Location.t) = loc.loc_start.pos_lnum
let word env ty = Word.word env ty

let field ?(fkind = M.Arg) ?(mutable_ = false) ?loc ~env ctx (ct : T.core_type)
    : M.field =
  {
    fkind;
    ty = spell ctx ct;
    mutable_;
    word = Word.word env ct.ctyp_type;
    owns = Cost.owns ~group:ctx.group env ct.ctyp_type;
    frange = range ctx (Option.value loc ~default:ct.ctyp_loc);
  }

let label_field ~env ctx (ld : T.label_declaration) =
  field ~fkind:(M.Label ld.ld_name.txt) ~mutable_:(Compat.ld_mutable ld)
    ~loc:ld.ld_loc ~env ctx ld.ld_type

let arg_fields ~env ctx = function
  | T.Cstr_record lds -> List.map (label_field ~env ctx) lds
  | args -> List.map (field ~env ctx) (Compat.tuple_args args)

let arg_types = function
  | T.Cstr_record lds ->
      List.map (fun (ld : T.label_declaration) -> ld.ld_type.ctyp_type) lds
  | args ->
      List.map (fun (ct : T.core_type) -> ct.ctyp_type) (Compat.tuple_args args)

(* Field types are wrapped in Tpoly, because fields can be polymorphic. *)
let rec is_float env ty =
  match get_desc (Word.expand env ty) with
  | Tconstr (p, _, _) -> Path.same p Predef.path_float
  | Tpoly (t, []) -> is_float env t
  | _ -> false

(* Notes on a constructor that the tag alone does not show. *)
let constructor_notes env (desc : Compat.cstr_desc)
    (args : T.constructor_arguments) =
  let ex =
    match Compat.cstr_existentials desc with
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
      when lds <> []
           && List.for_all (fun ld -> is_float env ld.T.ld_type.ctyp_type) lds
      ->
        [
          "inline record: all fields are float, but inline records are never \
           stored flat";
        ]
    | _ -> []
  in
  ex @ inline_floats

let slot_field name =
  {
    M.fkind = M.Slot name;
    ty = "extension slot";
    mutable_ = false;
    word = M.Pointer { tag = Some M.object_tag; what = "extension slot" };
    owns = M.zero;
    frange = None;
  }

let constructor_shape ~env ~args name desc fields =
  Compat.constructor_shape ~word ~env ~tys:(arg_types args)
    ~slot:(slot_field name) desc fields

let poly_cases ?(where = fun _ -> None) ?(group = []) env row : M.case list =
  List.filter_map
    (fun (label, f) ->
      let hash = Btype.hash_variant label in
      let name = "`" ^ label in
      let block ty =
        let arg =
          {
            M.fkind = Arg;
            ty = print_type ty;
            mutable_ = false;
            word = Word.word env ty;
            owns = Cost.owns ~group env ty;
            frange = None;
          }
        in
        let h =
          {
            M.fkind = Hash hash;
            ty = "int";
            mutable_ = false;
            word = M.Immediate "label hash";
            owns = M.zero;
            frange = None;
          }
        in
        M.Block { tag = 0; fields = [ h; arg ] }
      in
      let case_range = where label in
      match row_field_repr f with
      | Rpresent None | Reither (true, [], _) ->
          Some { M.name; shape = Constant hash; notes = []; case_range }
      | Rpresent (Some ty) | Reither (false, [ ty ], _) ->
          Some { M.name; shape = block ty; notes = []; case_range }
      | Reither (_, ty :: _, _) ->
          Some
            {
              M.name;
              shape = block ty;
              case_range;
              notes =
                [
                  "conjunctive type: the value may be constant or carry an \
                   argument";
                ];
            }
      | Reither (false, [], _) | Rabsent -> None)
    (List.sort
       (fun (a, _) (b, _) ->
         compare (Btype.hash_variant a) (Btype.hash_variant b))
       (row_fields row))

let params ctx (td : T.type_declaration) =
  match td.typ_params with
  | [] -> ""
  | [ (ct, _) ] -> spell ctx ct
  | ps ->
      "(" ^ String.concat ", " (List.map (fun (ct, _) -> spell ctx ct) ps) ^ ")"

let type_decl ~env ctx (td : T.type_declaration) : M.decl =
  let decl = td.typ_type in
  let path = Path.Pident td.typ_id in
  let kind : M.kind =
    match
      Compat.record_shape ~word ~env decl td.typ_kind
        ~field:(label_field ~env ctx)
    with
    | Some shape -> Record shape
    | None -> (
        match (decl.type_kind, td.typ_kind) with
        | Type_variant _, Ttype_variant cds ->
            let descs =
              Datarepr.constructors_of_type ~current_unit:None path decl
            in
            Variant
              (List.map2
                 (fun (cd : T.constructor_declaration)
                      (_, (desc : Compat.cstr_desc)) ->
                   let fields = arg_fields ~env ctx cd.cd_args in
                   {
                     M.name = cd.cd_name.txt;
                     shape =
                       constructor_shape ~env ~args:cd.cd_args cd.cd_name.txt
                         desc fields;
                     notes = constructor_notes env desc cd.cd_args;
                     case_range = range ctx cd.cd_loc;
                   })
                 cds descs)
        | Type_open, _ -> Open
        | _, _ -> (
            match decl.type_manifest with
            | Some ty -> (
                match get_desc (Word.expand env ty) with
                | Tvariant row ->
                    (* Tags written in this declaration, where they are. *)
                    let where l =
                      match td.typ_manifest with
                      | Some { ctyp_desc = Ttyp_variant (rfs, _, _); _ } ->
                          List.find_map
                            (fun (rf : T.row_field) ->
                              match rf.rf_desc with
                              | Ttag (t, _, _) when t.txt = l ->
                                  range ctx rf.rf_loc
                              | _ -> None)
                            rfs
                      | _ -> None
                    in
                    Polyvariant
                      {
                        cases = poly_cases ~where ~group:ctx.group env row;
                        closed = Word.row_counts row <> None;
                      }
                | _ -> Alias (Word.word env ty))
            | None -> Abstract (Compat.abstract_word ~word env path decl)))
  in
  let notes =
    match td.typ_kind with
    | Ttype_variant cds
      when List.exists
             (fun (cd : T.constructor_declaration) -> cd.cd_res <> None)
             cds ->
        [
          "GADT: type indices are erased, so the constructors are numbered as \
           in an ordinary variant";
        ]
    | _ -> []
  in
  {
    M.name = ctx.prefix ^ td.typ_name.txt;
    params = params ctx td;
    keyword = "type";
    line = line td.typ_loc;
    source = Option.map squash (slice ctx td.typ_loc);
    kind;
    notes;
    range = range ctx td.typ_loc;
  }

let ext_decl ~env ctx ~keyword (ec : T.extension_constructor) : M.decl =
  let name = ec.ext_name.txt in
  let case : M.case =
    match ec.ext_kind with
    | Text_rebind (p, _) ->
        {
          name;
          shape = Rebind (Path.name p);
          notes = [];
          case_range = range ctx ec.ext_loc;
        }
    | Text_decl (_, args, _) ->
        let desc =
          Datarepr.extension_descr ~current_unit:None (Path.Pident ec.ext_id)
            ec.ext_type
        in
        let fields = arg_fields ~env ctx args in
        {
          name;
          shape = constructor_shape ~env ~args name desc fields;
          notes = constructor_notes env desc args;
          case_range = range ctx ec.ext_loc;
        }
  in
  {
    M.name = ctx.prefix ^ name;
    params = "";
    keyword;
    line = line ec.ext_loc;
    source = Option.map squash (slice ctx ec.ext_loc);
    kind = Extension case;
    notes = [];
    range = range ctx ec.ext_loc;
  }

(* The fields of a structure block, for first-class modules. *)

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
let slots ctx env (sg : signature) =
  let n = ref 0 in
  let slots = ref [] and none = ref [] in
  let add ?loc item id word =
    slots :=
      {
        M.index = !n;
        item;
        name = Ident.name id;
        word;
        srange = Option.bind loc (range ctx);
      }
      :: !slots;
    incr n
  in
  (* A class also declares a class type and an object type of its name. *)
  let classes =
    List.filter_map
      (function Sig_class (id, _, _, _) -> Some (Ident.name id) | _ -> None)
      sg
  in
  let hidden id =
    let s = Ident.name id in
    (String.length s > 0 && s.[0] = '#') || List.mem s classes
  in
  List.iter
    (function
      | Sig_value (id, { val_kind = Val_reg; val_type; val_loc; _ }, _) ->
          add ~loc:val_loc M.Value id (Word.word env val_type)
      | Sig_value (id, _, _) -> none := ("external " ^ Ident.name id) :: !none
      | Sig_typext (id, ext, _, _) ->
          let item =
            if Path.same ext.ext_type_path Predef.path_exn then M.Exception
            else M.Extension
          in
          add ~loc:ext.ext_loc item id
            (M.Pointer { tag = Some M.object_tag; what = "extension slot" })
      | Sig_module (id, Mp_present, md, _, _) ->
          if is_functor env md.md_type then
            add ~loc:md.md_loc M.Functor id
              (M.Pointer { tag = Some M.closure_tag; what = "closure" })
          else
            add ~loc:md.md_loc M.Module id
              (M.Pointer { tag = Some 0; what = "structure" })
      | Sig_module (id, Mp_absent, _, _, _) ->
          none := ("module alias " ^ Ident.name id) :: !none
      | Sig_class (id, cd, _, _) ->
          add ~loc:cd.cty_loc M.Class id
            (M.Pointer { tag = Some 0; what = "class" })
      | Sig_type (id, _, _, _) when not (hidden id) ->
          none := ("type " ^ Ident.name id) :: !none
      | Sig_modtype (id, _, _) ->
          none := ("module type " ^ Ident.name id) :: !none
      | Sig_class_type (id, _, _, _) when not (hidden id) ->
          none := ("class type " ^ Ident.name id) :: !none
      | Sig_type _ | Sig_class_type _ -> ())
    sg;
  (List.rev !slots, List.rev !none)

type acc = { mutable decls : M.decl list }

let group tds =
  List.map (fun (td : T.type_declaration) -> Path.Pident td.typ_id) tds

(* Declarations inside modules are named by their path, such as [A.B.t]. *)
let rec structure acc ctx (str : T.structure) =
  let env = !rebuild_env str.str_final_env in
  List.iter (structure_item acc ctx ~env) str.str_items

and structure_item acc ctx ~env (item : T.structure_item) =
  match item.str_desc with
  | Tstr_type (_, tds) ->
      let ctx = { ctx with group = group tds } in
      List.iter (fun td -> acc.decls <- type_decl ~env ctx td :: acc.decls) tds
  | Tstr_typext te ->
      List.iter
        (fun ec ->
          acc.decls <- ext_decl ~env ctx ~keyword:"extension" ec :: acc.decls)
        te.tyext_constructors
  | Tstr_exception te ->
      acc.decls <-
        ext_decl ~env ctx ~keyword:"exception" te.tyexn_constructor :: acc.decls
  | Tstr_module mb -> module_binding acc ctx mb
  | Tstr_recmodule mbs -> List.iter (module_binding acc ctx) mbs
  | Tstr_include { incl_mod; _ } -> module_expr acc ctx incl_mod
  | _ -> ()

and module_binding acc ctx (mb : T.module_binding) =
  let name = Option.value mb.mb_name.txt ~default:"_" in
  module_expr acc { ctx with prefix = ctx.prefix ^ name ^ "." } mb.mb_expr

and module_expr acc ctx (me : T.module_expr) =
  match me.mod_desc with
  | Tmod_structure str -> structure acc ctx str
  | Tmod_functor (_, body) | Tmod_constraint (body, _, _, _) ->
      module_expr acc ctx body
  | Tmod_apply (_, arg, _) -> module_expr acc ctx arg
  | Tmod_ident _ | Tmod_apply_unit _ | Tmod_unpack _ -> ()

let rec signature acc ctx (sg : T.signature) =
  let env = !rebuild_env sg.sig_final_env in
  List.iter
    (fun (item : T.signature_item) ->
      match item.sig_desc with
      | Tsig_type (_, tds) ->
          let ctx = { ctx with group = group tds } in
          List.iter
            (fun td -> acc.decls <- type_decl ~env ctx td :: acc.decls)
            tds
      | Tsig_typext te ->
          List.iter
            (fun ec ->
              acc.decls <-
                ext_decl ~env ctx ~keyword:"extension" ec :: acc.decls)
            te.tyext_constructors
      | Tsig_exception te ->
          acc.decls <-
            ext_decl ~env ctx ~keyword:"exception" te.tyexn_constructor
            :: acc.decls
      | Tsig_module
          {
            md_name = { txt = Some n; _ };
            md_type = { mty_desc = Tmty_signature s; _ };
            _;
          } ->
          signature acc { ctx with prefix = ctx.prefix ^ n ^ "." } s
      | _ -> ())
    sg.sig_items

(* Every polymorphic-variant label written in types, expressions and patterns. *)
let labels ~file iter_with =
  let found = ref [] in
  let add label (loc : Location.t) =
    found :=
      { M.label; hash = Btype.hash_variant label; file; lline = line loc }
      :: !found
  in
  let open Tast_iterator in
  let typ it (ct : T.core_type) =
    (match ct.ctyp_desc with
    | Ttyp_variant (rfs, _, _) ->
        List.iter
          (fun (rf : T.row_field) ->
            match rf.rf_desc with
            | Ttag (l, _, _) -> add l.txt l.loc
            | Tinherit _ -> ())
          rfs
    | _ -> ());
    default_iterator.typ it ct
  in
  let expr it (e : T.expression) =
    (match e.exp_desc with Texp_variant (l, _) -> add l e.exp_loc | _ -> ());
    default_iterator.expr it e
  in
  let pat : type k. iterator -> k T.general_pattern -> unit =
   fun it p ->
    (match p.pat_desc with
    | Tpat_variant (l, _, _) -> add l p.pat_loc
    | _ -> ());
    default_iterator.pat it p
  in
  iter_with { default_iterator with typ; expr; pat };
  List.rev !found

(* First-class modules. A value of type [(module S)] is a structure block
   laid out by [S] alone: packing [(module M : S)] coerces [M] to [S], so
   whatever [M] looks like, the block holds S's value-bearing items in S's
   order. Constraints such as [with type t = int] add no field. Each module
   type named in a package type or a [(module M)] expression is shown once;
   [pline] is its first use. Its range is the module type's declaration, when that
   is in this file. *)
let packages ctx iter_with =
  let found = ref [] in
  let add env ty (loc : Location.t) =
    match Compat.package_path (Word.expand env ty) with
    | Some p
      when not (List.exists (fun (q, _, _) -> Path.name q = Path.name p) !found)
      ->
        found := (p, env, line loc) :: !found
    | _ -> ()
  in
  let open Tast_iterator in
  let typ it (ct : T.core_type) =
    (match ct.ctyp_desc with
    | Ttyp_package _ -> add ct.ctyp_env ct.ctyp_type ct.ctyp_loc
    | _ -> ());
    default_iterator.typ it ct
  in
  let expr it (e : T.expression) =
    (match e.exp_desc with
    | Texp_pack _ -> add e.exp_env e.exp_type e.exp_loc
    | _ -> ());
    default_iterator.expr it e
  in
  iter_with { default_iterator with typ; expr };
  List.rev !found
  |> List.filter_map (fun (p, env, l) ->
      let env = !rebuild_env env in
      match Mtype.scrape env (Env.find_modtype_expansion p env) with
      | Mty_signature sg ->
          let slots, no_slot = slots ctx (Env.add_signature sg env) sg in
          let prange =
            match Env.find_modtype p env with
            | mtd -> range ctx mtd.mtd_loc
            | exception Not_found -> None
          in
          Some { M.pname = Path.name p; pline = l; slots; no_slot; prange }
      | _ -> None
      | exception _ -> None)

type input = Impl of T.structure | Intf of T.signature

let analyze ~file ~unit_name ~src input : M.compunit =
  let acc = { decls = [] } in
  let own =
    match input with
    | Impl str -> structure_file str
    | Intf sg -> signature_file sg
  in
  let ctx = { src; prefix = ""; own; group = [] } in
  let iter_with =
    match input with
    | Impl str ->
        structure acc ctx str;
        fun (it : Tast_iterator.iterator) -> it.structure it str
    | Intf sg ->
        signature acc ctx sg;
        fun it -> it.signature it sg
  in
  {
    M.file;
    unit_name;
    decls = List.rev acc.decls;
    packages = packages ctx iter_with;
    labels = labels ~file iter_with;
    values = None;
  }
