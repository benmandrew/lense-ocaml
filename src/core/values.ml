(* Stage 4: closures, lazy values and objects.

   Closures come from the Lambda code each backend compiles, built as the
   drivers build it: the arity and tupling of each function, which functions
   share a block, and the variables the block captures. Lazy values come from
   Typeopt.classify_lazy_argument, which Translcore uses to choose between
   the value itself, a Forward block and a Lazy block. Objects follow the
   order in which Translclass allocates instance-variable slots at class
   initialisation: there is no compiler data that records it. *)

module M = Lense_model.Model
module T = Typedtree

(* Types of the variables bound anywhere in the structure. *)
let ident_types (str : T.structure) =
  let tbl = Hashtbl.create 64 in
  let pat : 'k. Tast_iterator.iterator -> 'k T.general_pattern -> unit =
   fun sub p ->
    List.iter (fun (id, ty) -> Hashtbl.replace tbl id (ty, p.pat_env)) (Compat.bound_idents p);
    Tast_iterator.default_iterator.pat sub p
  in
  let it = { Tast_iterator.default_iterator with pat } in
  it.structure it str;
  tbl

(* Closures *)

let capture tbl id : M.capture =
  match Hashtbl.find_opt tbl id with
  | Some (ty, env) -> { cvar = Ident.name id; cty = Analyze.print_type ty; cword = Word.word env ty }
  | None -> { cvar = Ident.name id; cty = ""; cword = M.Any "a variable the compiler introduced" }

(* Where classes and immediate objects are: the closures inside them are
   the object system's own code, and are left out. *)
let class_locs (str : T.structure) =
  let acc = ref [] in
  let class_expr sub (ce : T.class_expr) =
    acc := ce.cl_loc :: !acc;
    Tast_iterator.default_iterator.class_expr sub ce
  in
  let expr sub (e : T.expression) =
    (match e.exp_desc with Texp_object _ -> acc := e.exp_loc :: !acc | _ -> ());
    Tast_iterator.default_iterator.expr sub e
  in
  let it = { Tast_iterator.default_iterator with class_expr; expr } in
  it.structure it str;
  !acc

let inside (outer : Location.t) (l : Location.t) =
  outer.loc_start.pos_cnum <= l.loc_start.pos_cnum && l.loc_end.pos_cnum <= outer.loc_end.pos_cnum

let closures ~modname str : M.backend_closures list =
  let tbl = ident_types str and classes = class_locs str in
  let prefix = modname ^ "." in
  let name s = if String.starts_with ~prefix s then String.sub s (String.length prefix) (String.length s - String.length prefix) else s in
  let fn (f : Compat.lfun) =
    { M.fname = name f.lname; fline = f.lloc.loc_start.pos_lnum; arity = f.nparams; tupled = f.ltupled }
  in
  let shown ((fns : Compat.lfun list), _) =
    List.for_all (fun (f : Compat.lfun) -> f.lname <> "" && not (List.exists (fun c -> inside c f.lloc) classes)) fns
  in
  List.map
    (fun (backend, config, sets) ->
      let closure (fns, fv) = { M.fns = List.map fn fns; env = List.map (capture tbl) fv } in
      { M.backend; config; closures = Option.map (fun s -> List.map closure (List.filter shown s)) sets })
    (Compat.closure_backends ~modname str)

(* Lazy values *)

let lazies ctx (str : T.structure) =
  let acc = ref [] in
  let expr sub (e : T.expression) =
    (match e.exp_desc with
    | Texp_lazy a ->
        let zkind : M.lazy_kind =
          match Typeopt.classify_lazy_argument a with
          | `Constant_or_function | `Identifier `Other -> Itself
          | `Float_that_cannot_be_shortcut | `Identifier `Forward_value -> Forward
          | `Other -> Suspended
        in
        let zsource = match Analyze.slice ctx e.exp_loc with Some s -> Analyze.squash s | None -> "lazy" in
        acc := { M.zline = Analyze.line e.exp_loc; zsource; zkind; zword = Word.word a.exp_env a.exp_type } :: !acc
    | _ -> ());
    Tast_iterator.default_iterator.expr sub e
  in
  let it = { Tast_iterator.default_iterator with expr } in
  it.structure it str;
  List.rev !acc

(* Objects *)

(* The idents [f] reports for a class expression: bound inside it, or
   referred to from it. *)
let class_idents (ce : T.class_expr) =
  let bound = ref Ident.Set.empty and used = ref Ident.Set.empty in
  let pat : 'k. Tast_iterator.iterator -> 'k T.general_pattern -> unit =
   fun sub p ->
    List.iter (fun (id, _) -> bound := Ident.Set.add id !bound) (Compat.bound_idents p);
    Tast_iterator.default_iterator.pat sub p
  in
  let expr sub (e : T.expression) =
    (match (Compat.expr_ident e, e.exp_desc) with
    | Some id, _ | None, (Texp_instvar (_, Path.Pident id, _) | Texp_setinstvar (_, Path.Pident id, _, _)) ->
        used := Ident.Set.add id !used
    | _ -> ());
    Tast_iterator.default_iterator.expr sub e
  in
  let it = { Tast_iterator.default_iterator with pat; expr } in
  it.class_expr it ce;
  (!bound, !used)

(* The variables the methods of a class expression refer to directly. *)
let method_idents (ce : T.class_expr) =
  let used = ref Ident.Set.empty and depth = ref 0 in
  let expr sub (e : T.expression) =
    (match Compat.expr_ident e with Some id when !depth > 0 -> used := Ident.Set.add id !used | _ -> ());
    Tast_iterator.default_iterator.expr sub e
  in
  let class_field sub (f : T.class_field) =
    match f.cf_desc with
    | Tcf_method _ ->
        incr depth;
        Tast_iterator.default_iterator.class_field sub f;
        decr depth
    | _ -> Tast_iterator.default_iterator.class_field sub f
  in
  let it = { Tast_iterator.default_iterator with expr; class_field } in
  it.class_expr it ce;
  !used

let ivar ?(param = false) ~from name mutable_ ty env : M.ivar =
  { vname = name; vty = Analyze.print_type ty; vmutable = mutable_; vparam = param; vword = Word.word env ty; vfrom = from }

(* Instance variables in slot order. Each class level allocates, in this
   order: the parameters and class-level lets its methods use (always a new
   slot, unnamed), its own non-override vals in declaration order, then the slots of
   each inherited class in turn. A named variable that already has a slot
   keeps it. *)
let rec class_vars classes ~from (ce : T.class_expr) : M.ivar list * string list =
  match ce.cl_desc with
  | Tcl_fun (_, _, vals, cl, _) | Tcl_let (_, _, vals, cl) ->
      (* Translclass binds each one to a new slot with a StrictOpt let, and
         Simplif drops the let when no method refers to it. *)
      let _, used = class_idents cl in
      let params =
        List.filter_map
          (fun (id, (e : T.expression)) ->
            (* Methods reach a parameter through Texp_instvar on [id]. *)
            if Ident.Set.mem id used then Some (ivar ~param:true ~from (Ident.name id) false e.exp_type e.exp_env)
            else None)
          vals
      in
      let rest, unknown = class_vars classes ~from cl in
      (params @ rest, unknown)
  | Tcl_structure str ->
      let own =
        List.filter_map
          (fun (f : T.class_field) ->
            match f.cf_desc with
            | Tcf_val (name, mut, _, kind, false) ->
                let ty, env =
                  match kind with
                  | Tcfk_virtual ct -> (ct.ctyp_type, ct.ctyp_env)
                  | Tcfk_concrete (_, e) -> (e.exp_type, e.exp_env)
                in
                Some (ivar ~from name.txt (mut = Asttypes.Mutable) ty env)
            | _ -> None)
          str.cstr_fields
      in
      List.fold_left
        (fun (vars, unknown) (f : T.class_field) ->
          match f.cf_desc with
          | Tcf_inherit (_, cl, _, _, _) ->
              let pv, pu = class_vars classes ~from:(parent_name cl) cl in
              let taken (v : M.ivar) = (not v.vparam) && List.exists (fun (w : M.ivar) -> (not w.vparam) && w.vname = v.vname) vars in
              let fresh = List.filter (fun v -> not (taken v)) pv in
              (vars @ fresh, unknown @ pu)
          | _ -> (vars, unknown))
        (own, []) str.cstr_fields
  | Tcl_ident (p, _, _) -> (
      match Hashtbl.find_opt classes (Path.name p) with
      | Some ce -> class_vars classes ~from:(Path.name p) ce
      | None -> ([], [ Path.name p ]))
  | Tcl_apply (cl, _) | Tcl_constraint (cl, _, _, _, _) | Tcl_open (_, cl) -> class_vars classes ~from cl

and parent_name (ce : T.class_expr) =
  match ce.cl_desc with
  | Tcl_ident (p, _, _) -> Path.name p
  | Tcl_apply (cl, _) | Tcl_constraint (cl, _, _, _, _) | Tcl_open (_, cl) -> parent_name cl
  | _ -> "class"

(* A class at the top of the unit is built once, outside any function. A
   class or object inside an expression is built under Translobj.oo_wrap:
   it takes an extra slot, allocated by Translclass as [env2], when its
   methods use variables bound in the enclosing top-level item. *)
let objects (str : T.structure) : M.obj list =
  let classes = Hashtbl.create 8 in
  let acc = ref [] in
  let add ~top ~locals name line (ce : T.class_expr) =
    let ivars, unknown = class_vars classes ~from:name ce in
    let env_slot = (not top) && not (Ident.Set.is_empty (Ident.Set.inter (method_idents ce) locals)) in
    acc := { M.oname = name; oline = line; env_slot; ivars; unknown } :: !acc
  in
  let class_decls ~top ~locals l =
    List.iter
      (fun ((ci : T.class_declaration), _) ->
        Hashtbl.replace classes (Ident.name ci.ci_id_class) ci.ci_expr;
        add ~top ~locals ("class " ^ ci.ci_id_name.txt) (Analyze.line ci.ci_loc) ci.ci_expr)
      l
  in
  (* Classes and objects below a top-level item. *)
  let nested locals =
    let structure_item sub (si : T.structure_item) =
      (match si.str_desc with Tstr_class l -> class_decls ~top:false ~locals l | _ -> ());
      Tast_iterator.default_iterator.structure_item sub si
    in
    let expr sub (e : T.expression) =
      (match e.exp_desc with
      | Texp_object (cs, _) ->
          let ce = { T.cl_desc = Tcl_structure cs; cl_loc = e.exp_loc; cl_type = Cty_signature cs.cstr_type;
                     cl_env = e.exp_env; cl_attributes = [] } in
          add ~top:false ~locals "object" (Analyze.line e.exp_loc) ce
      | _ -> ());
      Tast_iterator.default_iterator.expr sub e
    in
    { Tast_iterator.default_iterator with structure_item; expr }
  in
  let rec top_structure (str : T.structure) =
    List.iter
      (fun (si : T.structure_item) ->
        match si.str_desc with
        | Tstr_class l -> class_decls ~top:true ~locals:Ident.Set.empty l
        | Tstr_module { mb_expr = { mod_desc = Tmod_structure s; _ }; _ } -> top_structure s
        | _ ->
            let locals = ref Ident.Set.empty in
            let pat : 'k. Tast_iterator.iterator -> 'k T.general_pattern -> unit =
             fun sub p ->
              List.iter (fun (id, _) -> locals := Ident.Set.add id !locals) (Compat.bound_idents p);
              Tast_iterator.default_iterator.pat sub p
            in
            let collect = { Tast_iterator.default_iterator with pat } in
            collect.structure_item collect si;
            (* The item's own top-level names are not local. *)
            let own = match si.str_desc with
              | Tstr_value (_, vbs) -> List.concat_map (fun (vb : T.value_binding) -> List.map fst (Compat.bound_idents vb.vb_pat)) vbs
              | _ -> []
            in
            let locals = List.fold_left (fun s id -> Ident.Set.remove id s) !locals own in
            let it = nested locals in
            it.structure_item it si)
      str.str_items
  in
  top_structure str;
  List.sort (fun (a : M.obj) b -> compare a.oline b.oline) (List.rev !acc)

let values ~modname ~src (str : T.structure) : M.values =
  let ctx = { Analyze.src; prefix = "" } in
  { backends = closures ~modname str; lazies = lazies ctx str; objects = objects str }
