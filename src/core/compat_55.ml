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

(* The module type that a first-class module type packs. *)
let package_path ty =
  match get_desc ty with Tpackage p -> Some p.pack_path | _ -> None

(* OCaml 5.5 has no layouts besides value. *)
let flat_word (_ : Env.t) (_ : type_expr) : M.word option = None

(* Predefined types that only one compiler has. *)
let predef_word p : M.word option =
  if Path.same p Predef.path_continuation then
    Some (M.Pointer { tag = Some M.cont_tag; what = "continuation" })
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
  | Type_variant
      ( [ { cd_args = Cstr_record [ { ld_type = arg; _ } ]; _ } ],
        Variant_unboxed )
  | Type_record ([ { ld_type = arg; _ } ], Record_unboxed _) ->
      Unboxed_arg arg
  | Type_variant (cstrs, _) ->
      let consts =
        List.length (List.filter (fun c -> c.cd_args = Cstr_tuple []) cstrs)
      in
      Constructors (consts, List.length cstrs - consts)
  | Type_record (_, Record_float) -> Float_record
  | Type_record _ -> Record
  | Type_open -> Open
  | Type_abstract _ | Type_external _ -> (
      match decl.type_immediate with
      | Type_immediacy.Always -> Immediate "[@@immediate]"
      | Always_on_64bits when Lense_model.Model.word_size = 64 ->
          Immediate "[@@immediate64]"
      | _ -> Abstract)

(* The word of an abstract type declared in the file being read. *)
let abstract_word ~word:_ (_ : Env.t) (_ : Path.t) decl : M.word =
  match decl.type_immediate with
  | Type_immediacy.Always -> M.Immediate "[@@immediate]"
  | Always_on_64bits -> M.Immediate "[@@immediate64]"
  | Unknown -> M.Any "abstract type"

(* Typed trees *)

let ld_mutable (ld : T.label_declaration) = ld.ld_mutable = Mutable
let tuple_args = function T.Cstr_tuple cts -> cts | T.Cstr_record _ -> []

type cstr_desc = Data_types.constructor_description

let cstr_existentials (d : cstr_desc) = d.cstr_existentials

(* The shape of a record declaration, or None for other kinds. [field] turns
   one typed label into a model field. *)
let record_shape ~word:_ ~env:_ decl (kind : T.type_kind) ~field :
    M.shape option =
  match (decl.type_kind, kind) with
  | Type_record (_, repr), Ttype_record lds -> (
      let fields = List.map field lds in
      match repr with
      | Record_float ->
          Some
            (Flat_float
               (List.map
                  (fun (f : M.field) ->
                    { f with word = M.Double; owns = M.zero })
                  fields))
      | Record_unboxed _ ->
          Some
            (match fields with
            | [ f ] -> Unboxed f
            | _ -> Block { tag = 0; fields })
      | Record_regular | Record_inlined _ | Record_extension _ ->
          Some (Block { tag = 0; fields }))
  | _ -> None

let constructor_shape ~word:_ ~env:_ ~tys:_ ~slot (desc : cstr_desc) fields :
    M.shape =
  match desc.cstr_tag with
  | Cstr_constant n -> Constant n
  | Cstr_block tag -> Block { tag; fields }
  | Cstr_unboxed -> (
      match fields with [ f ] -> Unboxed f | _ -> Block { tag = 0; fields })
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

let type_interface ~source_file:_ (_ : Unit_info.t) env ast =
  Typemod.type_interface env ast

let type_structure env ast =
  let str, _, _, _, _ = Typemod.type_structure env ast in
  str

let reset_envaux () = Envaux.reset_cache ()
let cmt_modname (cmt : Cmt_format.cmt_infos) = cmt.cmt_modname

let read_cmi_signature file =
  Env.read_signature (Unit_info.Artifact.from_filename file)

(* Closures, from the Lambda code each backend compiles *)

(* The local variable an expression is, if it is one. *)
let expr_ident (e : T.expression) =
  match e.exp_desc with
  | T.Texp_ident (Path.Pident id, _, _) -> Some id
  | _ -> None

let bound_idents (p : _ T.general_pattern) =
  List.map (fun (id, _, ty, _) -> (id, ty)) (T.pat_bound_idents_full p)

type lfun = { lname : string; lloc : Location.t; nparams : int; ltupled : bool }

let lfun ?id (f : Lambda.lfunction) =
  let lname, lloc =
    match f.loc with
    | Loc_known { loc; scopes } ->
        (Debuginfo.Scoped_location.string_of_scopes scopes, loc)
    | Loc_unknown -> ("", Location.none)
  in
  (* A function split off by the compiler shares its scope name. *)
  let lname =
    match id with
    | Some id
      when lname <> "" && not (String.ends_with ~suffix:(Ident.name id) lname)
      ->
        let prefix =
          match String.rindex_opt lname '.' with
          | Some i -> String.sub lname 0 (i + 1)
          | None -> ""
        in
        prefix ^ Ident.name id
    | _ -> lname
  in
  { lname; lloc; nparams = List.length f.params; ltupled = f.kind = Tupled }

(* Closure splits a function with optional arguments and default values into
   a wrapper and an inner function, which then share a block (Closure's
   close_functions). Bytecode does not. *)
let split ~native (bs : Lambda.rec_binding list) =
  match bs with
  | _ when not native -> bs
  | [ { def = { attr = { inline = Always_inline; _ }; _ }; _ } ] -> bs
  | _ ->
      List.concat_map
        (fun ({ id; def = { kind; params; return; body; attr; loc } } :
               Lambda.rec_binding) ->
          Simplif.split_default_wrapper ~id ~kind ~params ~return ~body ~attr
            ~loc)
        bs

(* Every closure the code allocates per call of a function: one function,
   or a recursive set that shares one block, with the variables it captures
   in Ident order. A closure outside every function body is allocated once,
   when the unit initialises, and is left out. In native code, [allocated]
   says whether Closure allocates the set's block at all: it compiles a
   block whose environment it does not need as a constant. *)
let closure_sets ~native ?(allocated = fun _ -> true) (lam : Lambda.lambda) =
  let acc = ref [] in
  let add ~depth bs =
    let bs = split ~native bs in
    let fv = Lambda.free_variables (Lletrec (bs, Lambda.lambda_unit)) in
    let fns =
      List.map (fun (b : Lambda.rec_binding) -> lfun ~id:b.id b.def) bs
    in
    if depth > 0 && List.exists allocated fns then
      acc := (fns, Ident.Set.elements fv) :: !acc
  in
  let rec walk ~depth (lam : Lambda.lambda) =
    match lam with
    | Lfunction f ->
        (* Named after its scope, so a split-off inner function reads as "f_inner". *)
        let scope = (lfun f).lname in
        let last =
          match String.rindex_opt scope '.' with
          | Some i -> String.sub scope (i + 1) (String.length scope - i - 1)
          | None -> scope
        in
        add ~depth
          [
            {
              id = Ident.create_local (if last = "" then "fun" else last);
              def = f;
            };
          ];
        walk ~depth:(depth + 1) f.body
    | Lletrec (bs, body) ->
        add ~depth bs;
        List.iter
          (fun (b : Lambda.rec_binding) -> walk ~depth:(depth + 1) b.def.body)
          bs;
        walk ~depth body
    | _ -> Lambda.shallow_iter ~tail:(walk ~depth) ~non_tail:(walk ~depth) lam
  in
  walk ~depth:0 lam;
  List.rev !acc

(* The Lambda code that ocamlopt (without flambda) or ocamlc compiles, built
   as the drivers build it. *)
let lambda ~native ~modname (str : T.structure) =
  Misc.protect_refs
    [ Misc.R (Clflags.native_code, native) ]
    (fun () ->
      let p =
        (if native then Translmod.transl_store_implementation
         else Translmod.transl_implementation)
          modname (str, T.Tcoerce_none)
      in
      { p with code = Simplif.simplify_lambda p.code })

(* The backend that ocamlopt gives Closure (Optmaindriver.Backend). *)
module Backend = struct
  let symbol_for_global' = Compilenv.symbol_for_global'
  let closure_symbol = Compilenv.closure_symbol
  let really_import_approx = Import_approx.really_import_approx
  let import_symbol = Import_approx.import_symbol
  let size_int = Arch.size_int
  let big_endian = Arch.big_endian
  let max_sensible_number_of_arguments = Proc.max_arguments_for_tailcalls - 1
end

(* Where the functions are whose blocks Closure allocates at run time, by
   line and column: those of a Uclosure with an environment. Cmmgen makes a
   Uclosure without one a constant. Closure runs as Optcompile.clambda runs
   it; a missing .cmx only costs it approximations, so its warning is off. *)
let allocated_functions ~modname (p : Lambda.program) =
  let found = Hashtbl.create 16 in
  let rec walk (u : Clambda.ulambda) =
    match u with
    | Uclosure (fs, env) ->
        List.iter
          (fun (f : Clambda.ufunction) ->
            (match f.dbg with
            | d :: _ when env <> [] ->
                Hashtbl.replace found (d.dinfo_line, d.dinfo_char_start) ()
            | _ -> ());
            walk f.body)
          fs;
        List.iter walk env
    | Uvar _ | Uconst _ | Uunreachable -> ()
    | Udirect_apply (_, us, _) | Uprim (_, us, _) | Ustaticfail (_, us) ->
        List.iter walk us
    | Ugeneric_apply (u, us, _) ->
        walk u;
        List.iter walk us
    | Uoffset (u, _) | Uphantom_let (_, _, u) | Uassign (_, u) -> walk u
    | Ulet (_, _, _, a, b)
    | Ucatch (_, _, a, b)
    | Utrywith (a, _, b)
    | Usequence (a, b)
    | Uwhile (a, b) ->
        walk a;
        walk b
    | Uifthenelse (a, b, c) | Ufor (_, a, b, _, c) ->
        walk a;
        walk b;
        walk c
    | Uswitch (u, sw, _) ->
        walk u;
        Array.iter walk sw.us_actions_consts;
        Array.iter walk sw.us_actions_blocks
    | Ustringswitch (u, cases, default) ->
        walk u;
        List.iter (fun (_, u) -> walk u) cases;
        Option.iter walk default
    | Usend (_, a, b, us, _) ->
        walk a;
        walk b;
        List.iter walk us
  in
  Misc.protect_refs
    [ Misc.R (Clflags.native_code, true) ]
    (fun () ->
      Clflags.use_inlining_arguments_set Clflags.classic_arguments;
      Compilenv.reset modname;
      Warnings.without_warnings (fun () ->
          walk
            (Closure.intro
               ~backend:(module Backend : Backend_intf.S)
               ~size:p.main_module_block_size p.code));
      Compilenv.clear_structured_constants ());
  fun (f : lfun) ->
    let s = f.lloc.loc_start in
    Hashtbl.mem found (s.pos_lnum, s.pos_cnum - s.pos_bol)

(* For each backend: its name, its configuration, and the closures, or None
   when the layout is not predicted. *)
let closure_backends ~modname str =
  let sets native =
    try
      let p = lambda ~native ~modname str in
      let allocated =
        if native then Some (allocated_functions ~modname p) else None
      in
      Some (closure_sets ~native ?allocated p.code)
    with _ -> None
  in
  [
    ( "native code",
      (if Config.flambda then "flambda, which chooses closure layouts itself"
       else "Closure, without flambda"),
      if Config.flambda then None else sets true );
    ("bytecode", "ocamlc without -g", sets false);
  ]

(* Counting words *)

let tuple_types ty =
  match get_desc ty with Ttuple l -> List.map snd l | _ -> []

let unboxed_tuple_types (_ : type_expr) : type_expr list = []

(* The words of a value of a predefined type that only one compiler has. *)
let predef_cost p : M.cost option =
  if Path.same p Predef.path_continuation then Some (M.uncounted "continuation")
  else None

(* How a declaration lays out its values, for counting the words one takes.
   Field types are as declared, before applying the type's arguments. *)
type layout =
  | No_block of type_expr list
      (** The value is these, with no block: [@@unboxed]. *)
  | Blocks of type_expr list option list
      (** One per constructor: None when constant, or the fields of its block. A
          record is one constructor. *)
  | Flat of int  (** A flat float block of this many fields. *)
  | Not_counted of string

let layout env p args decl =
  match decl.type_kind with
  | Type_variant ([ { cd_args = Cstr_tuple [ arg ]; _ } ], Variant_unboxed)
  | Type_variant
      ( [ { cd_args = Cstr_record [ { ld_type = arg; _ } ]; _ } ],
        Variant_unboxed )
  | Type_record ([ { ld_type = arg; _ } ], Record_unboxed _) ->
      No_block [ arg ]
  | Type_variant (cds, _) ->
      Blocks
        (List.map
           (fun cd ->
             match cd.cd_args with
             | Cstr_tuple [] -> None
             | Cstr_tuple tys -> Some tys
             | Cstr_record lds -> Some (List.map (fun ld -> ld.ld_type) lds))
           cds)
  | Type_record (lds, Record_float) -> Flat (List.length lds)
  | Type_record (lds, _) ->
      Blocks [ Some (List.map (fun ld -> ld.ld_type) lds) ]
  | Type_open -> Not_counted ("extensible variant " ^ Path.name p)
  | Type_abstract _ | Type_external _ -> (
      match decl_view env p args decl with
      | Immediate _ -> Blocks [ None ]
      | _ -> Not_counted ("abstract type " ^ Path.name p))

(* A flat scalar, which owns no block. OCaml 5.5 has none. *)
let flat_scalar (_ : Env.t) (_ : type_expr) = false
