(* The Obj fuzz oracle. Each round writes a program of random declarations,
   predicts the shape of a value of every constructor with lense, then
   compiles a checker that builds those values and inspects them with Obj.
   The ground truth is the running program, so no second compiler is needed.
   Each round also reads the program back from a .cmt (cmt_diff.ml).

   fuzz.exe [-seed N] [-rounds N] [-keep DIR] [-no-cmt] [-gen DIR]
   The compilers come from LENSE_OCAMLOPT and LENSE_OCAMLC, or PATH. *)

module M = Lense_model.Model

let st = ref (Random.State.make [| 1 |])
let rand n = Random.State.int !st n
let chance p = Random.State.float !st 1.0 < p
let pick l = List.nth l (rand (List.length l))

(* A type spelling and an expression of that type. *)
type sample = { ty : string; expr : string }

let base =
  [
    ("int", "7");
    ("bool", "true");
    ("char", "'c'");
    ("unit", "()");
    ("float", "1.5");
    ("fl", "2.5");
    ("string", "\"s\"");
    ("bytes", "(Bytes.make 1 'b')");
    ("int32", "3l");
    ("int64", "4L");
    ("nativeint", "5n");
    ("int list", "[1]");
    ("int list", "[]");
    ("float list", "[1.5; 2.5]");
    ("(int * float) list", "[(1, 2.5)]");
    ("int option list", "[Some 1; None]");
    ("int option", "(Some 1)");
    ("int option", "None");
    ("int * string", "(1, \"a\")");
    ("float array", "[|1.5|]");
    ("float array", "[||]");
    ("int array", "[|1|]");
    ("int -> int", "(fun x -> x + 1)");
    ("int ref", "(ref 1)");
    ("exn", "Not_found");
    ("exn", "(Failure \"f\")");
    ("string Lazy.t", "(lazy (String.make 1 'z'))");
    ("[ `On | `Off ]", "`On");
    ("[ `N of int ]", "(`N 3)");
    ("fstr", "{ fa = 1.; fb = 2. }");
    ("< m : int >", "(object method m = 1 end)");
  ]
  |> List.map (fun (ty, expr) -> { ty; expr })

(* The nodes of each list sample, for checking the words per node. *)
let list_nodes =
  [
    ("[1]", 1);
    ("[]", 0);
    ("[1.5; 2.5]", 2);
    ("[(1, 2.5)]", 1);
    ("[Some 1; None]", 2);
  ]

let prelude =
  "type fl = float\ntype fstr = { fa : float; fb : float }\ntype ext = ..\n"

(* One value to check: its expression, the expressions of the fields it
   was built from in block order, and a way to rebuild it from other field
   expressions. [vsubs] are the further nodes of a recursive type that it
   holds, each with the index in [vfields] of the field that holds it. *)
type value = {
  vexpr : string;
  vfields : string list;
  vmake : string list -> string;
  vsubs : (int * string) list;
}

let value make fields =
  { vexpr = make fields; vfields = fields; vmake = make; vsubs = [] }

let constant e = value (fun _ -> e) []

(* OxCaml: a field of a mixed block, as a leaf or an unboxed tuple of
   leaves. [bits] is the native word expected for a flat leaf, compared
   under [mask]; [boxed] is what bytecode stores instead. *)
(* The compilers the oracle runs: those on PATH, unless the environment
   names others. The checkers use no library, so ocamlfind is not needed. *)
let tool var default = Option.value (Sys.getenv_opt var) ~default
let ocamlopt = tool "LENSE_OCAMLOPT" "ocamlopt"
let ocamlc = tool "LENSE_OCAMLC" "ocamlc"
let ocamlrun = tool "LENSE_OCAMLRUN" "ocamlrun"

(* Which compiler the oracle runs, read from [ocamlc]. lense type-checks
   with the matching half of its build. *)
let ox =
  let ic = Unix.open_process_in (ocamlc ^ " -version") in
  let v = try input_line ic with End_of_file -> "" in
  ignore (Unix.close_process_in ic);
  String.ends_with ~suffix:"+ox" v

(* Type-check and analyse a generated program, as lense-ocaml would. *)
let analyze ~file src =
  if ox then
    Lense_core_ox.(
      match Load.typecheck ~include_dirs:[] ~file ~intf:false src with
      | exception Load.Failed msg -> Error msg
      | unit_name, input ->
          let u = Analyze.analyze ~file ~unit_name ~src:(Some src) input in
          Ok
            {
              u with
              values =
                Load.values_of ~values:true ~unit_name ~src:(Some src) input;
            })
  else
    Lense_core_55.(
      match Load.typecheck ~include_dirs:[] ~file ~intf:false src with
      | exception Load.Failed msg -> Error msg
      | unit_name, input ->
          let u = Analyze.analyze ~file ~unit_name ~src:(Some src) input in
          Ok
            {
              u with
              values =
                Load.values_of ~values:true ~unit_name ~src:(Some src) input;
            })

type leaf = {
  lty : string;
  lexpr : string;
  bits : string option;
  mask : string;
  boxed : string;
}

(* [Rec] is an unboxed record type: its name and labelled fields. *)
type ftree =
  | Leaf of leaf
  | Prod of ftree list
  | Rec of string * (string * ftree) list

(* A first-class module to check: the expression, the package type whose
   prediction it must meet, and for each submodule slot whose signature is
   a named module type, that type, so the inner block is checked too. *)
type pack = {
  pexpr : string;
  ptype : string;
  psubs : (string * string) list;  (** slot name -> module type *)
}

let flat_leaves =
  [
    {
      lty = "float#";
      lexpr = "#2.5";
      bits = Some "(Int64.to_nativeint (Int64.bits_of_float 2.5))";
      mask = "(-1n)";
      boxed = "2.5";
    };
    {
      lty = "float32#";
      lexpr = "#2.5s";
      bits = Some "(Nativeint.of_int32 (Int32.bits_of_float 2.5))";
      mask = "0xffffffffn";
      boxed = "2.5s";
    };
    {
      lty = "int32#";
      lexpr = "(-#3l)";
      bits = Some "(-3n)";
      mask = "0xffffffffn";
      boxed = "(-3l)";
    };
    {
      lty = "int64#";
      lexpr = "#4L";
      bits = Some "4n";
      mask = "(-1n)";
      boxed = "4L";
    };
    {
      lty = "nativeint#";
      lexpr = "(-#5n)";
      bits = Some "(-5n)";
      mask = "(-1n)";
      boxed = "(-5n)";
    };
    {
      lty = "int8#";
      lexpr = "(-#6s)";
      bits = Some "(-6n)";
      mask = "0xffn";
      boxed = "(-6)";
    };
    {
      lty = "int16#";
      lexpr = "#300S";
      bits = Some "300n";
      mask = "0xffffn";
      boxed = "300";
    };
    {
      lty = "int#";
      lexpr = "#9m";
      bits = Some "9n";
      mask = "(-1n)";
      boxed = "9";
    };
  ]

let float_leaf =
  {
    lty = "float";
    lexpr = "1.5";
    bits = Some "(Int64.to_nativeint (Int64.bits_of_float 1.5))";
    mask = "(-1n)";
    boxed = "1.5";
  }

(* A vec128 of two equal words, read by [v128], which the checker defines.
   Bytecode aborts on SIMD, so a value holding one is checked in native code
   only. *)
let vec_leaf =
  {
    lty = "int64x2#";
    lexpr = "(v128 \"ABCDEFGHABCDEFGH\" 0)";
    bits = Some "0x4847464544434241n";
    mask = "(-1n)";
    boxed = "";
  }

let rec tree_ty = function
  | Leaf l -> if l.bits = None then "(" ^ l.lty ^ ")" else l.lty
  | Prod ts -> "#(" ^ String.concat " * " (List.map tree_ty ts) ^ ")"
  | Rec (name, _) -> name

(* Value leaves go through [cp], a copy that shares nothing: OxCaml cannot
   marshal a mixed block to undo the constants that native code shares. *)
let rec tree_expr = function
  | Leaf l when l.bits = None || l.lty = "float" -> "(cp " ^ l.lexpr ^ ")"
  | Leaf l -> l.lexpr
  | Prod ts -> "#(" ^ String.concat ", " (List.map tree_expr ts) ^ ")"
  | Rec (_, fs) ->
      "#{ "
      ^ String.concat "; " (List.map (fun (l, t) -> l ^ " = " ^ tree_expr t) fs)
      ^ " }"

let rec tree_leaves = function
  | Leaf l -> [ l ]
  | Prod ts -> List.concat_map tree_leaves ts
  | Rec (_, fs) -> List.concat_map (fun (_, t) -> tree_leaves t) fs

let has_vec trees =
  List.exists (fun l -> l == vec_leaf) (List.concat_map tree_leaves trees)

(* A field whose value is one value word: a single-field unboxed record is
   its field. *)
let rec value_tree = function
  | Leaf l -> l.bits = None
  | Rec (_, [ (_, t) ]) -> value_tree t
  | _ -> false

type state = {
  decls : Buffer.t;
  trees : (string * string, ftree list) Hashtbl.t;
      (** OxCaml: (type, case) -> fields *)
  mutable pool : sample list;
  values : (string * string, value) Hashtbl.t;  (** (type, case) -> value *)
  mutable modules : pack list;  (** First-class modules to check. *)
  mutable n : int;
  mutable vchecks : vcheck list;  (** Stage 4 values to check. *)
  mutable classes :
    (string * sample list * (string * bool * sample) list * string list) list;
      (** class, parameters, vals, virtual methods *)
}

(* A Stage 4 value, found in the prediction by the line its definition starts on. *)
and vcheck =
  | Vclosure of { values : (string * int) list; again : string }
      (** Each function of one block: the value, its line. [again] makes the
          first value again, with a second call. *)
  | Vlazy of { v : string; line : int; ident : string option; forced : bool }
  | Vobj of { v : string; line : int }

let line s =
  1
  + List.length (String.split_on_char '\n' (prelude ^ Buffer.contents s.decls))
  - 1

let fresh s prefix =
  s.n <- s.n + 1;
  prefix ^ string_of_int s.n

let contains s sub =
  let n = String.length sub in
  let rec go i =
    i + n <= String.length s && (String.sub s i n = sub || go (i + 1))
  in
  go 0

let field_sample s = pick (if s.pool <> [] && chance 0.3 then s.pool else base)

let float_sample () =
  pick [ { ty = "float"; expr = "0.25" }; { ty = "fl"; expr = "0.75" } ]

(* Arguments of a constructor: a tuple or an inline record. *)
let args s =
  if chance 0.25 then
    let fs =
      List.init
        (1 + rand 3)
        (fun _ ->
          (fresh s "l", if chance 0.3 then float_sample () else field_sample s))
    in
    let decl =
      "{ "
      ^ String.concat "; " (List.map (fun (l, x) -> l ^ " : " ^ x.ty) fs)
      ^ " }"
    in
    let make es =
      "{ "
      ^ String.concat "; " (List.map2 (fun (l, _) e -> l ^ " = " ^ e) fs es)
      ^ " }"
    in
    (decl, make, List.map (fun (_, x) -> x.expr) fs)
  else
    let xs = List.init (1 + rand 3) (fun _ -> field_sample s) in
    let paren t = "(" ^ t ^ ")" in
    ( String.concat " * " (List.map (fun x -> paren x.ty) xs),
      (fun es -> "(" ^ String.concat ", " es ^ ")"),
      List.map (fun x -> x.expr) xs )

let add_value s ty case v = Hashtbl.replace s.values (ty, case) v

let gen_variant s =
  let name = fresh s "t" in
  let n = 1 + rand 6 in
  let unboxed = n = 1 && chance 0.5 in
  let cases =
    List.init n (fun _ ->
        let c = fresh s "C" in
        if (not unboxed) && chance 0.3 then (c, None) else (c, Some (args s)))
  in
  (* [@@unboxed] needs exactly one argument. *)
  let cases =
    if unboxed then
      List.map
        (fun (c, a) ->
          match a with
          | Some (_, _, [ _ ]) -> (c, a)
          | _ ->
              let x = field_sample s in
              ( c,
                Some
                  ( "(" ^ x.ty ^ ")",
                    (fun es -> "(" ^ String.concat ", " es ^ ")"),
                    [ x.expr ] ) ))
        cases
    else cases
  in
  Printf.bprintf s.decls "type %s =%s%s\n" name
    (String.concat ""
       (List.map
          (fun (c, a) ->
            match a with
            | None -> " | " ^ c
            | Some (d, _, _) -> " | " ^ c ^ " of " ^ d)
          cases))
    (if unboxed then " [@@unboxed]" else "");
  List.iter
    (fun (c, a) ->
      let v =
        match a with
        | None -> constant c
        | Some (_, make, fs) -> value (fun es -> c ^ " " ^ make es) fs
      in
      add_value s name c v;
      s.pool <- { ty = name; expr = "(" ^ v.vexpr ^ ")" } :: s.pool)
    cases

let gen_record s =
  let name = fresh s "r" in
  let floats = chance 0.35 in
  let n = 1 + rand 5 in
  let unboxed = n = 1 && chance 0.4 in
  let fs =
    List.init n (fun _ ->
        ( fresh s "f",
          chance 0.3,
          if floats then float_sample () else field_sample s ))
  in
  Printf.bprintf s.decls "type %s = { %s }%s\n" name
    (String.concat "; "
       (List.map
          (fun (l, m, x) ->
            (if m && not unboxed then "mutable " else "") ^ l ^ " : " ^ x.ty)
          fs))
    (if unboxed then " [@@unboxed]" else "");
  let make es =
    "{ "
    ^ String.concat "; " (List.map2 (fun (l, _, _) e -> l ^ " = " ^ e) fs es)
    ^ " }"
  in
  let v = value make (List.map (fun (_, _, x) -> x.expr) fs) in
  add_value s name "" v;
  s.pool <- { ty = name; expr = "(" ^ v.vexpr ^ ")" } :: s.pool

let gen_poly s =
  let name = fresh s "p" in
  let labels = [ "A"; "B"; "Cc"; "Dd"; "Ee"; "Ff"; "Gg"; "Hh" ] in
  let tags =
    List.sort_uniq compare (List.init (1 + rand 5) (fun _ -> pick labels))
  in
  let tags =
    List.map (fun l -> (l, if chance 0.5 then Some (pick base) else None)) tags
  in
  Printf.bprintf s.decls "type %s = [ %s ]\n" name
    (String.concat " | "
       (List.map
          (function l, None -> "`" ^ l | l, Some x -> "`" ^ l ^ " of " ^ x.ty)
          tags));
  List.iter
    (fun (l, x) ->
      let v =
        match x with
        | None -> constant ("(`" ^ l ^ " : " ^ name ^ ")")
        | Some x ->
            value
              (fun es ->
                "(`" ^ l ^ " " ^ String.concat "" es ^ " : " ^ name ^ ")")
              [ x.expr ]
      in
      add_value s name ("`" ^ l) v;
      s.pool <- { ty = name; expr = v.vexpr } :: s.pool)
    tags

let gen_gadt s =
  let name = fresh s "g" in
  let cases =
    List.init
      (1 + rand 4)
      (fun _ ->
        let c = fresh s "G" in
        let idx = pick [ "int"; "string"; "bool" ] in
        let exist = chance 0.4 in
        let xs = List.init (rand 3) (fun _ -> pick base) in
        let xs = if exist then { ty = "'a"; expr = "42" } :: xs else xs in
        (c, idx, xs))
  in
  Printf.bprintf s.decls "type _ %s =%s\n" name
    (String.concat ""
       (List.map
          (fun (c, idx, xs) ->
            let args =
              String.concat " * " (List.map (fun x -> "(" ^ x.ty ^ ")") xs)
            in
            Printf.sprintf " | %s : %s%s %s" c
              (if xs = [] then "" else args ^ " -> ")
              idx name)
          cases));
  List.iter
    (fun (c, idx, xs) ->
      let make es =
        let e = if es = [] then c else c ^ " (" ^ String.concat ", " es ^ ")" in
        "(" ^ e ^ " : " ^ idx ^ " " ^ name ^ ")"
      in
      add_value s name c (value make (List.map (fun x -> x.expr) xs)))
    cases

let gen_exn s =
  let c = fresh s "E" in
  let ext = chance 0.4 in
  let rebind = (not ext) && chance 0.15 && Hashtbl.length s.values > 0 in
  let existing =
    Hashtbl.fold
      (fun (ty, case) v acc -> if ty = "exn" then (case, v) :: acc else acc)
      s.values []
  in
  if rebind && existing <> [] then (
    let target, tv = pick existing in
    Printf.bprintf s.decls "exception %s = %s\n" c target;
    (* The same arguments under the new name; vfields holds the original. *)
    let rename e =
      c
      ^ String.sub e (String.length target)
          (String.length e - String.length target)
    in
    add_value s "exn" c
      {
        vexpr = rename tv.vexpr;
        vfields = [ tv.vexpr ];
        vmake = (fun es -> rename (tv.vmake es));
        vsubs = [];
      })
  else
    let a = if chance 0.4 then None else Some (args s) in
    let decl = match a with None -> c | Some (d, _, _) -> c ^ " of " ^ d in
    if ext then Printf.bprintf s.decls "type ext += %s\n" decl
    else Printf.bprintf s.decls "exception %s\n" decl;
    let v =
      match a with
      | None -> constant c
      | Some (_, make, fs) -> value (fun es -> c ^ " " ^ make es) fs
    in
    add_value s (if ext then "ext" else "exn") c v

(* OxCaml: a record or variant whose fields mix values, flat scalars and
   unboxed tuples. A record of only float and float# fields is all flat. *)
(* The fields of a mixed type: leaves, unboxed tuples, unboxed records
   (declared here, and checked as values of their own) and [@@unboxed]
   wrappers of flat leaves. [rec_ok] leaves out the empty array, an atom
   that a value and its further nodes would both count. *)
let mixed_fields ?(rec_ok = false) ~floats_only s =
  let value_leaf () =
    let x =
      pick
        (List.filter
           (fun x ->
             x.ty <> "float" && x.ty <> "fl"
             && not (rec_ok && contains x.expr "[||]"))
           base)
    in
    { lty = x.ty; lexpr = x.expr; bits = None; mask = "0n"; boxed = x.expr }
  in
  let wrapper () =
    let l = pick flat_leaves in
    let w = fresh s "uw" in
    let c = String.capitalize_ascii w in
    if chance 0.5 then (
      Printf.bprintf s.decls "type %s = %s of %s [@@unboxed]\n" w c l.lty;
      { l with lty = w; lexpr = "(" ^ c ^ " " ^ l.lexpr ^ ")" })
    else (
      Printf.bprintf s.decls "type %s = { %s : %s } [@@unboxed]\n" w (w ^ "f")
        l.lty;
      { l with lty = w; lexpr = "{ " ^ w ^ "f = " ^ l.lexpr ^ " }" })
  in
  let rec tree depth =
    if floats_only then
      if depth = 0 && chance 0.15 then unboxed_record depth
      else Leaf (if chance 0.5 then float_leaf else List.hd flat_leaves)
    else
      match rand 13 with
      | 0 | 1 | 2 | 3 | 4 -> Leaf (pick flat_leaves)
      | 5 when depth < 2 -> Prod (List.init (2 + rand 2) (fun _ -> tree 2))
      | 6 -> Leaf float_leaf
      | (7 | 9) when depth < 2 -> unboxed_record depth
      | 8 -> Leaf (if chance 0.5 then vec_leaf else wrapper ())
      | _ -> Leaf (value_leaf ())
  and unboxed_record depth =
    let name = fresh s "ur" in
    let fs =
      List.init
        (if chance 0.4 then 1 else 2 + rand 2)
        (fun _ -> (fresh s "u", tree (depth + 1)))
    in
    Printf.bprintf s.decls "type %s = #{ %s }\n" name
      (String.concat "; " (List.map (fun (l, t) -> l ^ " : " ^ tree_ty t) fs));
    let t = Rec (name, fs) in
    add_value s name "" (constant (tree_expr t));
    Hashtbl.replace s.trees (name, "") (List.map snd fs);
    t
  in
  fun () -> List.init (1 + rand 4) (fun _ -> tree 0)

(* A value of a mixed type, reached through a field of an ordinary record:
   the mixed block is not counted, so the record's cost is a lower bound. *)
let gen_mixed_holder s ty (v : value) trees =
  if (not (has_vec trees)) && chance 0.3 then (
    let name = fresh s "hr" in
    let x = field_sample s in
    let a = fresh s "h" and b = fresh s "h" in
    Printf.bprintf s.decls "type %s = { %s : %s; %s : %s }\n" name a x.ty b ty;
    let make es =
      "{ " ^ a ^ " = " ^ List.nth es 0 ^ "; " ^ b ^ " = " ^ List.nth es 1 ^ " }"
    in
    add_value s name ""
      {
        vexpr = make [ "(cp " ^ x.expr ^ ")"; "(" ^ v.vexpr ^ ")" ];
        vfields = [ x.expr; v.vexpr ];
        vmake = make;
        vsubs = [];
      })

(* A recursive mixed type: a record linked through an option, or a list
   whose cells are mixed. Each value holds its further node in [vsubs]. *)
let gen_mixed_recursive s =
  let fields = mixed_fields ~rec_ok:true ~floats_only:false s in
  (* At least one flat field, so that the cells are mixed blocks. *)
  let ts = Leaf (pick flat_leaves) :: fields () in
  let link =
    Leaf { lty = ""; lexpr = ""; bits = None; mask = "0n"; boxed = "" }
  in
  let trees = ts @ [ link ] in
  let labelled () = List.map (fun t -> (fresh s "m", t)) ts in
  let record fs next =
    "{ "
    ^ String.concat "; "
        (List.map (fun (l, t) -> l ^ " = " ^ tree_expr t) fs
        @ [ fst next ^ " = " ^ snd next ])
    ^ " }"
  in
  match rand 3 with
  | 0 ->
      let name = fresh s "mrr" in
      let fs = labelled () and next = fresh s "next" in
      Printf.bprintf s.decls "type %s = { %s; mutable %s : %s option }\n" name
        (String.concat "; " (List.map (fun (l, t) -> l ^ " : " ^ tree_ty t) fs))
        next name;
      let leaf = "(" ^ record fs (next, "None") ^ ")" in
      let v =
        if chance 0.3 then constant leaf
        else
          {
            (constant (record fs (next, "(Some " ^ leaf ^ ")"))) with
            vsubs = [ (List.length fs, leaf) ];
          }
      in
      add_value s name "" v;
      Hashtbl.replace s.trees (name, "") trees;
      gen_mixed_holder s name v trees
  | k ->
      let name = fresh s "mrl" in
      let nil = fresh s "MNil" and cons = fresh s "MCons" in
      let fs = labelled () and tl = fresh s "tl" in
      let make =
        if k = 1 then (
          Printf.bprintf s.decls
            "type %s = %s | %s of { %s; mutable %s : %s }\n" name nil cons
            (String.concat "; "
               (List.map (fun (l, t) -> l ^ " : " ^ tree_ty t) fs))
            tl name;
          fun next -> cons ^ " " ^ record fs (tl, next))
        else (
          Printf.bprintf s.decls "type %s = %s | %s of %s * %s\n" name nil cons
            (String.concat " * " (List.map tree_ty ts))
            name;
          fun next ->
            cons ^ " ("
            ^ String.concat ", " (List.map tree_expr ts @ [ next ])
            ^ ")")
      in
      let sub = "(" ^ make nil ^ ")" in
      let v =
        { (constant (make sub)) with vsubs = [ (List.length ts, sub) ] }
      in
      add_value s name cons v;
      add_value s name nil (constant nil);
      Hashtbl.replace s.trees (name, cons) trees;
      gen_mixed_holder s name v trees

let gen_mixed s =
  let floats_only = chance 0.2 in
  let fields = mixed_fields ~floats_only s in
  if chance 0.25 then gen_mixed_recursive s
  else if chance 0.5 then (
    let name = fresh s "mr" in
    let fs = List.map (fun t -> (fresh s "m", chance 0.2, t)) (fields ()) in
    Printf.bprintf s.decls "type %s = { %s }\n" name
      (String.concat "; "
         (List.map
            (fun (l, m, t) ->
              (if m then "mutable " else "") ^ l ^ " : " ^ tree_ty t)
            fs));
    let make es =
      "{ "
      ^ String.concat "; " (List.map2 (fun (l, _, _) e -> l ^ " = " ^ e) fs es)
      ^ " }"
    in
    let v =
      {
        vexpr = make (List.map (fun (_, _, t) -> tree_expr t) fs);
        vfields =
          List.map
            (fun (_, _, t) ->
              let rec boxed = function
                | Leaf l -> l.boxed
                | Rec (_, [ (_, t) ]) -> boxed t
                | _ -> "()"
              in
              boxed t)
            fs;
        vmake = make;
        vsubs = [];
      }
    in
    let trees = List.map (fun (_, _, t) -> t) fs in
    add_value s name "" v;
    Hashtbl.replace s.trees (name, "") trees;
    gen_mixed_holder s name v trees)
  else
    let name = fresh s "mv" in
    let cases =
      List.init
        (1 + rand 4)
        (fun _ ->
          let c = fresh s "K" in
          if chance 0.2 then (c, `Const)
          else if chance 0.3 then
            (c, `Inline (List.map (fun t -> (fresh s "k", t)) (fields ())))
          else (c, `Tuple (fields ())))
    in
    Printf.bprintf s.decls "type %s =%s\n" name
      (String.concat ""
         (List.map
            (fun (c, a) ->
              match a with
              | `Const -> " | " ^ c
              | `Tuple ts ->
                  " | " ^ c ^ " of " ^ String.concat " * " (List.map tree_ty ts)
              | `Inline fs ->
                  " | " ^ c ^ " of { "
                  ^ String.concat "; "
                      (List.map (fun (l, t) -> l ^ " : " ^ tree_ty t) fs)
                  ^ " }")
            cases));
    List.iter
      (fun (c, a) ->
        match a with
        | `Const -> add_value s name c (constant c)
        | `Tuple ts ->
            add_value s name c
              {
                (constant
                   (c ^ " (" ^ String.concat ", " (List.map tree_expr ts) ^ ")"))
                with
                vfields = [];
              };
            Hashtbl.replace s.trees (name, c) ts
        | `Inline fs ->
            add_value s name c
              (constant
                 (c ^ " { "
                 ^ String.concat "; "
                     (List.map (fun (l, t) -> l ^ " = " ^ tree_expr t) fs)
                 ^ " }"));
            Hashtbl.replace s.trees (name, c) (List.map snd fs))
      cases;
    match List.filter (fun (_, a) -> a <> `Const) cases with
    | [] -> ()
    | cs ->
        let c, _ = pick cs in
        gen_mixed_holder s name
          (Hashtbl.find s.values (name, c))
          (Hashtbl.find s.trees (name, c))

(* A recursive type: a list, a record linked through an option, a binary
   tree, or two types that point to each other. Each value holds its further
   nodes in [vsubs], so the oracle can count each node on its own. *)
let gen_recursive s =
  (* The empty array is one shared atom, which reachable_words counts once in
     a value but once again in each node subtracted from it. *)
  let rec field_sample s =
    let x = pick (if s.pool <> [] && chance 0.3 then s.pool else base) in
    if contains x.expr "[||]" then field_sample s else x
  in
  let paren x = "(" ^ x.ty ^ ")" in
  let tuple es = "(" ^ String.concat ", " es ^ ")" in
  let samples () = List.init (1 + rand 2) (fun _ -> field_sample s) in
  let pool name v =
    s.pool <- { ty = name; expr = "(" ^ v.vexpr ^ ")" } :: s.pool
  in
  match rand 4 with
  | 0 ->
      let name = fresh s "rl" in
      let nil = fresh s "Nil" and cons = fresh s "Cons" in
      let xs = samples () in
      let n = List.length xs in
      let make =
        if chance 0.4 then (
          let ls = List.map (fun _ -> fresh s "l") xs in
          Printf.bprintf s.decls
            "type %s = %s | %s of { %s; mutable next : %s }\n" name nil cons
            (String.concat "; " (List.map2 (fun l x -> l ^ " : " ^ x.ty) ls xs))
            name;
          fun es ->
            cons ^ " { "
            ^ String.concat "; "
                (List.map2 (fun l e -> l ^ " = " ^ e) (ls @ [ "next" ]) es)
            ^ " }")
        else (
          Printf.bprintf s.decls "type %s = %s | %s of %s * %s\n" name nil cons
            (String.concat " * " (List.map paren xs))
            name;
          fun es -> cons ^ " " ^ tuple es)
      in
      let es = List.map (fun x -> x.expr) xs in
      let sub = "(" ^ make (es @ [ nil ]) ^ ")" in
      let v = { (value make (es @ [ sub ])) with vsubs = [ (n, sub) ] } in
      add_value s name cons v;
      add_value s name nil (constant nil);
      pool name v
  | 1 ->
      let name = fresh s "rr" in
      let fs = List.map (fun x -> (fresh s "f", x)) (samples ()) in
      let next = fresh s "next" in
      Printf.bprintf s.decls "type %s = { %s; mutable %s : %s option }\n" name
        (String.concat "; " (List.map (fun (l, x) -> l ^ " : " ^ x.ty) fs))
        next name;
      let make es =
        "{ "
        ^ String.concat "; "
            (List.map2
               (fun l e -> l ^ " = " ^ e)
               (List.map fst fs @ [ next ])
               es)
        ^ " }"
      in
      let es = List.map (fun (_, x) -> x.expr) fs in
      let leaf = "(" ^ make (es @ [ "None" ]) ^ ")" in
      let v =
        if chance 0.3 then value make (es @ [ "None" ])
        else
          {
            (value make (es @ [ "(Some " ^ leaf ^ ")" ])) with
            vsubs = [ (List.length fs, leaf) ];
          }
      in
      add_value s name "" v;
      pool name v
  | 2 ->
      let name = fresh s "rt" in
      let leaf = fresh s "Leaf" and node = fresh s "Node" in
      let x = field_sample s in
      Printf.bprintf s.decls "type %s = %s | %s of %s * %s * %s\n" name leaf
        node name (paren x) name;
      let make es = node ^ " " ^ tuple es in
      let small = "(" ^ make [ leaf; x.expr; leaf ] ^ ")" in
      let side () = if chance 0.5 then leaf else small in
      let l = side () and r = side () in
      let v =
        {
          (value make [ l; x.expr; r ]) with
          vsubs =
            List.filter_map
              (fun (i, e) -> if e = small then Some (i, e) else None)
              [ (0, l); (2, r) ];
        }
      in
      add_value s name node v;
      add_value s name leaf (constant leaf);
      pool name v
  | _ ->
      let a = fresh s "ra" and b = fresh s "rb" in
      let stop = fresh s "Stop" and go = fresh s "Go" in
      let x = field_sample s and y = field_sample s in
      let bv = fresh s "bv" and bn = fresh s "bn" in
      Printf.bprintf s.decls
        "type %s = %s | %s of %s * %s\nand %s = { %s : %s; %s : %s }\n" a stop
        go (paren x) b b bv y.ty bn a;
      let mk_go es = go ^ " " ^ tuple es in
      let mk_b es =
        "{ "
        ^ String.concat "; "
            (List.map2 (fun l e -> l ^ " = " ^ e) [ bv; bn ] es)
        ^ " }"
      in
      let inner = "(" ^ mk_b [ y.expr; stop ] ^ ")" in
      let gv =
        { (value mk_go [ x.expr; inner ]) with vsubs = [ (1, inner) ] }
      in
      add_value s a go gv;
      add_value s a stop (constant stop);
      let deeper = "(" ^ mk_go [ x.expr; inner ] ^ ")" in
      add_value s b ""
        (if chance 0.5 then value mk_b [ y.expr; stop ]
         else { (value mk_b [ y.expr; deeper ]) with vsubs = [ (1, deeper) ] });
      pool a gv

(* Random module items. A submodule holds items of its own, up to two
   levels down. *)
let rec gen_items s depth =
  List.init
    (1 + rand 6)
    (fun _ ->
      match rand 12 with
      | 0 -> `Ext (fresh s "e")
      | 1 -> `Exn (fresh s "X")
      | 2 -> `Type (fresh s "ty")
      | 3 when depth < 2 -> `Sub (fresh s "S", gen_items s (depth + 1))
      | 4 -> `Functor (fresh s "F")
      | 5 -> `Class (fresh s "cl")
      | 6 -> `Extn (fresh s "Xe", chance 0.5)
      | 7 -> `Fun (fresh s "f", rand 3)
      | 8 -> `Rec (fresh s "f", fresh s "g")
      | _ -> `Val (fresh s "v", pick base))

let rec item_src = function
  | `Val (v, x) -> Printf.sprintf "let %s : %s = %s" v x.ty x.expr
  | `Ext e -> Printf.sprintf "external %s : 'a -> 'a = \"%%identity\"" e
  | `Exn x -> "exception " ^ x
  | `Type t -> "type " ^ t ^ " = int"
  | `Sub (sm, items) ->
      "module " ^ sm ^ " = struct "
      ^ String.concat " " (List.map item_src items)
      ^ " end"
  | `Functor f ->
      Printf.sprintf
        "module %s (X : sig end) = struct let a = 1 let b = \"b\" end" f
  | `Class c -> Printf.sprintf "class %s = object method m = 0 end" c
  | `Extn (x, arg) ->
      Printf.sprintf "type ext += %s%s" x (if arg then " of int" else "")
  | `Fun (f, 0) -> Printf.sprintf "let %s (x : int) = x + 1" f
  | `Fun (f, 1) -> Printf.sprintf "let %s = ( + ) 1" f
  | `Fun (f, _) -> Printf.sprintf "let %s ?(o = 1) (x : int) = o + x" f
  | `Rec (f, g) ->
      Printf.sprintf
        "let rec %s (x : int) = if x = 0 then 0 else %s (x - 1) and %s (x : \
         int) = %s x"
        f g g f

(* The signature items of a package type for [items]: all of them in order
   when [exact], otherwise a random subset in a random order. A submodule
   gets a named module type, declared here, or an inline signature. Returns
   the items, the abstract types and the slot name -> module type pairs. *)
let rec sig_of s ~exact items =
  let subs = ref [] and abstract = ref [] in
  let keep () = exact || chance 0.7 in
  let item = function
    | `Val (v, x) -> [ Printf.sprintf "val %s : %s" v x.ty ]
    | `Ext e ->
        if exact || chance 0.3 then
          [ Printf.sprintf "external %s : 'a -> 'a = \"%%identity\"" e ]
        else if chance 0.5 then [ Printf.sprintf "val %s : 'a -> 'a" e ]
        else []
    | `Exn x -> [ "exception " ^ x ]
    | `Type t ->
        if exact || chance 0.3 then [ "type " ^ t ^ " = int" ]
        else if chance 0.6 then (
          abstract := t :: !abstract;
          [ "type " ^ t ])
        else []
    | `Sub (sm, items) ->
        let inner, _, isubs = sig_of s ~exact:(exact || chance 0.2) items in
        let body = "sig " ^ String.concat " " inner ^ " end" in
        if chance 0.3 then [ "module " ^ sm ^ " : " ^ body ]
        else
          let ms = fresh s "MS" in
          Printf.bprintf s.decls
            "module type %s = %s\ntype pk_%s = (module %s)\n" ms body ms ms;
          subs := ((sm, ms) :: isubs) @ !subs;
          [ "module " ^ sm ^ " : " ^ ms ]
    | `Functor f ->
        [
          (if exact then
             Printf.sprintf
               "module %s : functor (X : sig end) -> sig val a : int val b : \
                string end"
               f
           else
             pick
               [
                 Printf.sprintf "module %s (X : sig end) : sig val a : int end"
                   f;
                 Printf.sprintf
                   "module %s : functor (X : sig end) -> sig val b : string \
                    val a : int end"
                   f;
                 Printf.sprintf "module %s : functor (_ : sig end) -> sig end" f;
               ]);
        ]
    | `Class c -> [ Printf.sprintf "class %s : object method m : int end" c ]
    | `Extn (x, arg) ->
        [ Printf.sprintf "type ext += %s%s" x (if arg then " of int" else "") ]
    | `Fun (f, k) ->
        [
          Printf.sprintf "val %s : %s" f
            (if k < 2 then "int -> int" else "?o:int -> int -> int");
        ]
    | `Rec (f, g) ->
        List.filter
          (fun _ -> keep ())
          [
            Printf.sprintf "val %s : int -> int" f;
            Printf.sprintf "val %s : int -> int" g;
          ]
  in
  let chosen =
    List.concat_map (fun it -> if keep () then item it else []) items
  in
  let chosen =
    if exact then chosen
    else
      List.map snd
        (List.sort compare (List.map (fun x -> (rand 1000, x)) chosen))
  in
  (chosen, !abstract, !subs)

(* A module of random items, and a package type of a random subset of
   them in a random order, which the module is packed into. Sometimes the
   package type has every item in the module's order, so that packing
   copies nothing, and sometimes the package is unpacked and packed again. *)
let gen_module s =
  let m = fresh s "M" in
  let items = gen_items s 0 in
  Printf.bprintf s.decls "module %s = struct %s end\n" m
    (String.concat " " (List.map item_src items));
  let chosen, abstract, psubs = sig_of s ~exact:(chance 0.2) items in
  let p = m ^ "_P" in
  let withs =
    match List.filter (fun _ -> chance 0.6) abstract with
    | [] -> ""
    | ts ->
        " with "
        ^ String.concat " and " (List.map (fun t -> "type " ^ t ^ " = int") ts)
  in
  Printf.bprintf s.decls
    "module type %s = sig %s end\ntype pk_%s = (module %s%s)\n" p
    (String.concat " " chosen) m p withs;
  let pexpr = Printf.sprintf "(module %s : %s%s)" m p withs in
  s.modules <- { pexpr; ptype = p; psubs } :: s.modules;
  (* Unpack and pack again: into the same package type, or into one with
     fewer of its items in another order, which copies the block again. *)
  if chance 0.4 then
    let q =
      if chance 0.4 then p ^ withs
      else
        let q = m ^ "_Q" in
        let is_type t =
          String.starts_with ~prefix:"type " t && not (contains t "+=")
        in
        let rest =
          List.filter (fun t -> (not (is_type t)) && chance 0.7) chosen
        in
        let rest =
          List.map snd
            (List.sort compare (List.map (fun x -> (rand 1000, x)) rest))
        in
        Printf.bprintf s.decls
          "module type %s = sig %s end\ntype pk_%s = (module %s)\n" q
          (String.concat " " rest) q q;
        q
    in
    let ptype = List.hd (String.split_on_char ' ' q) in
    s.modules <-
      { pexpr = Printf.sprintf "(module (val %s) : %s)" pexpr q; ptype; psubs }
      :: s.modules

(* Stage 4: closures, lazy values and objects. Each definition the
   prediction is matched by starts its own line. *)

let gen_closure s =
  let f = fresh s "mk" in
  let caps = List.init (rand 4) (fun _ -> (fresh s "c", field_sample s)) in
  let local = if chance 0.3 then Some (fresh s "k", field_sample s) else None in
  let names = List.map fst caps @ Option.to_list (Option.map fst local) in
  let used = List.filter (fun _ -> chance 0.7) names in
  let use =
    if used = [] then ""
    else "ignore (Sys.opaque_identity (" ^ String.concat ", " used ^ ")); "
  in
  (* At least one parameter, so that the closure is made per call: a
     function at the top of the unit is one block for the program. *)
  let params =
    if caps = [] then "()"
    else
      String.concat " "
        (List.map (fun (c, x) -> "(" ^ c ^ " : " ^ x.ty ^ ")") caps)
  in
  Printf.bprintf s.decls "let %s %s =\n" f params;
  Option.iter
    (fun (k, x) ->
      Printf.bprintf s.decls "  let %s : %s = Sys.opaque_identity %s in\n" k
        x.ty x.expr)
    local;
  let v = fresh s "fv" in
  let args =
    if caps = [] then "()"
    else String.concat " " (List.map (fun (_, x) -> x.expr) caps)
  in
  match rand 4 with
  | 0 ->
      let l = line s in
      let n = 1 + rand 3 in
      Printf.bprintf s.decls "  fun %s -> %sx0\n"
        (String.concat " " (List.init n (Printf.sprintf "(x%d : int)")))
        use;
      Printf.bprintf s.decls "let %s = %s %s\n" v f args;
      s.vchecks <-
        Vclosure { values = [ (v, l) ]; again = f ^ " " ^ args } :: s.vchecks
  | 1 ->
      let l = line s in
      Printf.bprintf s.decls "  fun (x0, x1) -> %s(x0 : int) + x1\n" use;
      Printf.bprintf s.decls "let %s = %s %s\n" v f args;
      s.vchecks <-
        Vclosure { values = [ (v, l) ]; again = f ^ " " ^ args } :: s.vchecks
  | 2 ->
      let l = line s in
      Printf.bprintf s.decls "  fun ?(o = 1) (x0 : int) -> %so + x0\n" use;
      Printf.bprintf s.decls "let %s = %s %s\n" v f args;
      s.vchecks <-
        Vclosure { values = [ (v, l) ]; again = f ^ " " ^ args } :: s.vchecks
  | _ ->
      let arity2 = chance 0.5 in
      let l1 = line s in
      Printf.bprintf s.decls
        "  let rec g1 (x0 : int) = %sif x0 = 0 then 0 else g2 (x0 - 1)%s\n" use
        (if arity2 then " 0" else "");
      let l2 = line s in
      Printf.bprintf s.decls "  and g2 (x0 : int) %s= %sg1 x0 in (g1, g2)\n"
        (if arity2 then "(_ : int) " else "")
        use;
      let v2 = fresh s "fv" in
      Printf.bprintf s.decls "let (%s, %s) = %s %s\n" v v2 f args;
      s.vchecks <-
        Vclosure
          {
            values = [ (v, l1); (v2, l2) ];
            again = "fst (" ^ f ^ " " ^ args ^ ")";
          }
        :: s.vchecks

(* Closures in other places: nested in another closure, in a record or a
   tuple, in a module, with labelled arguments, capturing a local ref or a
   value of the unit. A partial application such as [f 1] is a block that
   lense does not predict, so it is left out. *)
let gen_closure_more s =
  let m = if chance 0.3 then Some (fresh s "CM") else None in
  Option.iter (fun m -> Printf.bprintf s.decls "module %s = struct\n" m) m;
  let qual x = match m with Some m -> m ^ "." ^ x | None -> x in
  (* A value of the unit or of the module: bytecode captures it, native code
     reads it from the module block. *)
  let glob = if chance 0.3 then Some (fresh s "gl", field_sample s) else None in
  Option.iter
    (fun (g, x) -> Printf.bprintf s.decls "let %s : %s = %s\n" g x.ty x.expr)
    glob;
  let f = fresh s "mk" in
  let caps =
    List.init (rand 3) (fun _ -> (fresh s "c", chance 0.3, field_sample s))
  in
  let refv =
    if chance 0.35 then Some (fresh s "rf", field_sample s) else None
  in
  (* Each name as a closure uses it: a ref is read or written. *)
  let names =
    List.map (fun (c, _, _) -> c) caps
    @ Option.to_list (Option.map fst glob)
    @ Option.to_list
        (Option.map
           (fun (r, x) ->
             if chance 0.5 then "!" ^ r else "(" ^ r ^ " := " ^ x.expr ^ ")")
           refv)
  in
  let use extra =
    let l = List.filter (fun _ -> chance 0.6) (names @ extra) in
    if l = [] then ""
    else "ignore (Sys.opaque_identity (" ^ String.concat ", " l ^ ")); "
  in
  let shape = rand 4 in
  let ty = fresh s "rc" and fa = fresh s "rf" and fb = fresh s "rg" in
  if shape = 1 then
    Printf.bprintf s.decls "type %s = { %s : int; %s : int -> int }\n" ty fa fb;
  Printf.bprintf s.decls "let %s %s =\n" f
    (if caps = [] then "()"
     else
       String.concat " "
         (List.map
            (fun (c, lab, x) ->
              Printf.sprintf "%s(%s : %s)" (if lab then "~" else "") c x.ty)
            caps));
  Option.iter
    (fun (r, x) ->
      Printf.bprintf s.decls
        "  let %s : (%s) ref = ref (Sys.opaque_identity %s) in\n" r x.ty x.expr)
    refv;
  let args =
    if caps = [] then "()"
    else
      String.concat " "
        (List.map
           (fun (c, lab, x) -> (if lab then "~" ^ c ^ ":" else "") ^ x.expr)
           caps)
  in
  (* [again] makes the value again with a second call of the maker. *)
  let one v l again =
    s.vchecks <- Vclosure { values = [ (v, l) ]; again } :: s.vchecks
  in
  let call = "(" ^ qual f ^ " " ^ args ^ ")" in
  let fin () = Option.iter (fun _ -> Buffer.add_string s.decls "end\n") m in
  match shape with
  | 0 ->
      (* A closure that returns a closure, which captures both levels. *)
      let j = if chance 0.5 then Some (fresh s "j", field_sample s) else None in
      let l1 = line s in
      Printf.bprintf s.decls "  fun (x0 : int) -> %s\n" (use []);
      Option.iter
        (fun (j, x) ->
          Printf.bprintf s.decls "    let %s : %s = Sys.opaque_identity %s in\n"
            j x.ty x.expr)
        j;
      let l2 = line s in
      Printf.bprintf s.decls "    fun (y0 : int) -> %sy0 + x0\n"
        (use (Option.to_list (Option.map fst j)));
      fin ();
      let v = fresh s "fv" and v2 = fresh s "fv" in
      Printf.bprintf s.decls "let %s = %s %s\nlet %s = %s 1\n" v (qual f) args
        v2 v;
      one v l1 call;
      one v2 l2 ("(" ^ v ^ " 1)")
  | 1 ->
      (* In a record field. *)
      Printf.bprintf s.decls "  { %s = 1;\n" fa;
      let l = line s in
      Printf.bprintf s.decls "    %s = (fun (x0 : int) -> %sx0) }\n" fb (use []);
      fin ();
      let v = fresh s "fv" in
      Printf.bprintf s.decls "let %s = (%s %s).%s\n" v (qual f) args (qual fb);
      one v l (call ^ "." ^ qual fb)
  | 2 ->
      (* Two closures in a tuple: each has its own block. *)
      let l1 = line s in
      Printf.bprintf s.decls "  ((fun (x0 : int) -> %sx0),\n" (use []);
      let l2 = line s in
      Printf.bprintf s.decls "   (fun (x0 : string) -> %sx0))\n" (use []);
      fin ();
      let v = fresh s "fv" and v2 = fresh s "fv" in
      Printf.bprintf s.decls "let (%s, %s) = %s %s\n" v v2 (qual f) args;
      one v l1 ("fst " ^ call);
      one v2 l2 ("snd " ^ call)
  | _ ->
      (* Labelled and optional arguments, without defaults. *)
      let ps =
        pick
          [
            ("~(x0 : int)", "x0");
            ("?(o : int option)", "0");
            ("~(x0 : int) ?(o : int option)", "x0");
            ("?(o : int option) ~(x0 : int)", "x0");
          ]
      in
      let l = line s in
      Printf.bprintf s.decls "  fun %s (x1 : int) -> %s%s + x1\n" (fst ps)
        (use (if contains (fst ps) "?" then [ "o" ] else []))
        (snd ps);
      fin ();
      let v = fresh s "fv" in
      Printf.bprintf s.decls "let %s = %s %s\n" v (qual f) args;
      one v l call

let gen_lazy s =
  let v = fresh s "lz" in
  let x = field_sample s in
  let id = fresh s "lv" in
  let e =
    pick
      [
        "3";
        "\"str\"";
        "2.5";
        "None";
        "(1, 2)";
        "(fun x -> x + 1)";
        id;
        id;
        "(Sys.opaque_identity 4 + 1)";
        "`A";
        "[1]";
        "'c'";
        (* A lazy of a lazy, of a float identifier, and of a lazy identifier. *)
        "(lazy (Sys.opaque_identity 5))";
        "(lazy 6)";
        "fid";
        "zid";
        "(Sys.opaque_identity 2.5 +. 1.)";
      ]
  in
  let ident =
    if e = id then (
      Printf.bprintf s.decls "let %s : %s = %s\n" id x.ty x.expr;
      Some id)
    else if e = "fid" then (
      let x = float_sample () in
      Printf.bprintf s.decls "let %s : %s = Sys.opaque_identity %s\n" id x.ty
        x.expr;
      Some id)
    else if e = "zid" then (
      Printf.bprintf s.decls "let %s = lazy (%s)\n" id
        (pick [ "Sys.opaque_identity 7"; "7"; "String.make 1 'q'" ]);
      Some id)
    else None
  in
  let l = line s in
  Printf.bprintf s.decls "let %s = lazy %s\n" v (if ident = None then e else id);
  (* Forced before the check: lense predicts the block that forcing makes. *)
  let forced = chance 0.3 in
  if forced then Printf.bprintf s.decls "let () = ignore (Lazy.force %s)\n" v;
  s.vchecks <- Vlazy { v; line = l; ident; forced } :: s.vchecks

(* A class at the top, which may be virtual; an immediate object in a
   function; or a class in a function, under [let module]. Its methods,
   initializer and private methods use some of the parameters, class-level
   lets and local variables, and may call each other through self. *)
let gen_class s =
  let c = fresh s "cl" in
  let form =
    match rand 10 with 0 | 1 | 2 -> `Object | 3 | 4 -> `Local | _ -> `Top
  in
  let virt = form = `Top && chance 0.15 in
  let typed ps =
    String.concat " " (List.map (fun (p, x) -> "(" ^ p ^ " : " ^ x.ty ^ ")") ps)
  in
  let params = List.init (rand 3) (fun _ -> (fresh s "p", field_sample s)) in
  (* Class parameters of a class in a function. *)
  let kparams =
    if form = `Local then
      List.init (rand 3) (fun _ -> (fresh s "p", field_sample s))
    else []
  in
  let class_params = if form = `Top then params else kparams in
  (* Class-level lets, perhaps of a parameter. *)
  let lets =
    if form <> `Object && chance 0.35 then
      List.init
        (1 + rand 2)
        (fun _ ->
          let k = fresh s "k" in
          match class_params with
          | (p, x) :: _ when chance 0.4 -> (k, x, "Sys.opaque_identity " ^ p)
          | _ ->
              let x = field_sample s in
              (k, x, x.expr))
    else []
  in
  (* Local variables of the function: a value and a ref. *)
  let locals =
    if form <> `Top && chance 0.4 then [ (fresh s "j", field_sample s) ] else []
  in
  let refv =
    if form <> `Top && chance 0.25 then Some (fresh s "rf", field_sample s)
    else None
  in
  let names =
    List.map fst params @ List.map fst kparams
    @ List.map (fun (k, _, _) -> k) lets
    @ List.map fst locals
    @ Option.to_list
        (Option.map
           (fun (r, x) ->
             if chance 0.5 then "!" ^ r else "(" ^ r ^ " := " ^ x.expr ^ ")")
           refv)
  in
  let some p = List.filter (fun _ -> chance p) names in
  let opaque = function
    | [] -> "0"
    | l -> "Sys.opaque_identity (" ^ String.concat ", " l ^ ")"
  in
  let vals = List.init (rand 4) (fun _ -> (fresh s "a", field_sample s)) in
  let vals = List.map (fun (a, x) -> (a, chance 0.3, x)) vals in
  let parent =
    if s.classes <> [] && chance 0.6 then Some (pick s.classes) else None
  in
  let val_src (a, m, x) =
    (* A val may start from a class parameter of its type. *)
    let e =
      match List.find_opt (fun (_, y) -> y.ty = x.ty) class_params with
      | Some (p, _) when chance 0.3 -> p
      | _ -> x.expr
    in
    Printf.sprintf "val %s%s : %s = %s" (if m then "mutable " else "") a x.ty e
  in
  let fields = List.map val_src vals in
  let fields =
    match parent with
    | None -> fields
    | Some (pc, pps, pvals, pvirt) ->
        let inh =
          "inherit " ^ pc
          ^ String.concat "" (List.map (fun x -> " " ^ x.expr) pps)
        in
        (* The same class twice: its slots are allocated again. *)
        let inh = if chance 0.2 then [ inh; inh ] else [ inh ] in
        let extra =
          (* Redefine an inherited val: with !, or as a new val of the same name. *)
          match pvals with
          | (a, m, x) :: _ when chance 0.4 ->
              [
                Printf.sprintf "val%s %s%s : %s = %s"
                  (if chance 0.5 then "!" else "")
                  (if m then "mutable " else "")
                  a x.ty x.expr;
              ]
          | _ -> []
        in
        let defs = List.map (fun v -> "method " ^ v ^ " = 1") pvirt in
        let i = rand (List.length fields + 1) in
        List.filteri (fun j _ -> j < i) fields
        @ inh @ extra
        @ List.filteri (fun j _ -> j >= i) fields
        @ defs
  in
  let self_ = chance 0.4 in
  let meth =
    "method m" ^ c ^ " = "
    ^
    if chance 0.2 then "let z = 1 in " ^ opaque ("z" :: some 0.6)
    else opaque (some 0.6)
  in
  let priv =
    if chance 0.3 then
      ("method private q" ^ c ^ " = " ^ opaque (some 0.4))
      :: (if self_ then [ "method t" ^ c ^ " = self#q" ^ c ] else [])
    else []
  in
  let selfm =
    if self_ then [ "method s" ^ c ^ " = Sys.opaque_identity self#m" ^ c ]
    else []
  in
  let init =
    if chance 0.35 then
      [
        "initializer ignore ("
        ^ opaque
            ((if self_ && chance 0.5 then [ "self#m" ^ c ] else []) @ some 0.5)
        ^ ")";
      ]
    else []
  in
  let virts = if virt then [ "v" ^ c ] else [] in
  let body =
    String.concat " "
      (fields @ [ meth ] @ priv @ selfm @ init
      @ List.map (fun v -> "method virtual " ^ v ^ " : int") virts)
  in
  let obj = if self_ then "object (self)" else "object" in
  let lets_src ind =
    String.concat ""
      (List.map
         (fun (k, x, e) ->
           Printf.sprintf "%slet %s : %s = %s in\n" ind k x.ty e)
         lets)
  in
  let o = fresh s "ob" in
  let args ps = String.concat "" (List.map (fun (_, x) -> " " ^ x.expr) ps) in
  match form with
  | `Top ->
      let l = line s in
      Printf.bprintf s.decls "class %s%s %s =\n%s  %s %s end\n"
        (if virt then "virtual " else "")
        c (typed params) (lets_src "  ") obj body;
      s.classes <- (c, List.map snd params, vals, virts) :: s.classes;
      if not virt then (
        Printf.bprintf s.decls "let %s = new %s%s\n" o c (args params);
        s.vchecks <- Vobj { v = o; line = l } :: s.vchecks)
  | (`Object | `Local) as form ->
      (* Its methods reach the function's variables through the environment slot. *)
      Printf.bprintf s.decls "let %s %s =\n" c
        (if params = [] then "()" else typed params);
      List.iter
        (fun (j, x) ->
          Printf.bprintf s.decls "  let %s : %s = Sys.opaque_identity %s in\n" j
            x.ty x.expr)
        locals;
      Option.iter
        (fun (r, x) ->
          Printf.bprintf s.decls
            "  let %s : (%s) ref = ref (Sys.opaque_identity %s) in\n" r x.ty
            x.expr)
        refv;
      let l =
        if form = `Object then (
          let l = line s in
          Printf.bprintf s.decls "  %s %s end\n" obj body;
          l)
        else (
          Printf.bprintf s.decls "  let module Q = struct\n";
          let l = line s in
          Printf.bprintf s.decls "    class k %s =\n%s    %s %s end\n"
            (typed kparams) (lets_src "    ") obj body;
          Printf.bprintf s.decls "  end in\n  new Q.k%s\n" (args kparams);
          l)
      in
      Printf.bprintf s.decls "let %s = %s%s\n" o c
        (if params = [] then " ()" else args params);
      s.vchecks <- Vobj { v = o; line = l } :: s.vchecks

let gen_values s =
  match rand 4 with
  | 0 -> gen_closure s
  | 1 -> gen_closure_more s
  | 2 -> gen_lazy s
  | _ -> gen_class s

(* Type parameters, abstract and private types, open rows, packages and
   more recursion. A type spelled as a polymorphic variant makes an
   abbreviation of it a polymorphic variant declaration, not an alias. *)

let is_poly ty =
  String.length ty > 1
  && (ty.[0] = '[' || (ty.[0] = 'p' && ty.[1] >= '0' && ty.[1] <= '9'))

let rec plain_sample s =
  let x = field_sample s in
  if is_poly x.ty then plain_sample s else x

let shuffle l =
  List.map snd (List.sort compare (List.map (fun x -> (rand 1000, x)) l))

let add_pool s ty expr = s.pool <- { ty; expr } :: s.pool

(* A record of [xs], checked as a value and added to the pool. *)
let emit_record s xs =
  let name = fresh s "hr" in
  let fs = List.map (fun x -> (fresh s "h", x)) xs in
  Printf.bprintf s.decls "type %s = { %s }\n" name
    (String.concat "; " (List.map (fun (l, x) -> l ^ " : " ^ x.ty) fs));
  let make es =
    "{ "
    ^ String.concat "; " (List.map2 (fun (l, _) e -> l ^ " = " ^ e) fs es)
    ^ " }"
  in
  let v = value make (List.map (fun (_, x) -> x.expr) fs) in
  add_value s name "" v;
  add_pool s name ("(" ^ v.vexpr ^ ")")

(* The parameters of a declaration, and an instance of it at [xs]. *)
let params_decl ps name =
  match ps with
  | [ p ] -> p ^ " " ^ name
  | _ -> "(" ^ String.concat ", " ps ^ ") " ^ name

let inst xs name =
  "("
  ^ String.concat ", " (List.map (fun x -> "(" ^ x.ty ^ ")") xs)
  ^ ") " ^ name

(* A field over a parameter, at the instance [xs], or a plain field. *)
let param_field s ps xs =
  let i = rand (List.length ps) in
  let p = List.nth ps i and x = List.nth xs i in
  match rand 5 with
  | 0 | 1 -> { ty = p; expr = x.expr }
  | 2 -> { ty = p ^ " option"; expr = "(Some " ^ x.expr ^ ")" }
  | 3 -> { ty = p ^ " * int"; expr = "(" ^ x.expr ^ ", 3)" }
  | _ -> field_sample s

(* A record or variant over 'a, or 'a and 'b, instantiated at concrete
   types. A record of floats keeps its parameter as a phantom. *)
let gen_param s =
  let ps = if chance 0.3 then [ "'a"; "'b" ] else [ "'a" ] in
  let xs = List.map (fun _ -> field_sample s) ps in
  let annot name e = "(" ^ e ^ " : " ^ inst xs name ^ ")" in
  if chance 0.5 then (
    let name = fresh s "pr" in
    let n = 1 + rand 4 in
    let unboxed = n = 1 && chance 0.4 in
    let floats = (not unboxed) && chance 0.25 in
    let fs =
      List.init n (fun _ ->
          ( fresh s "q",
            (not unboxed) && chance 0.3,
            if floats then float_sample () else param_field s ps xs ))
    in
    Printf.bprintf s.decls "type %s = { %s }%s\n" (params_decl ps name)
      (String.concat "; "
         (List.map
            (fun (l, m, x) -> (if m then "mutable " else "") ^ l ^ " : " ^ x.ty)
            fs))
      (if unboxed then " [@@unboxed]" else "");
    let make es =
      annot name
        ("{ "
        ^ String.concat "; "
            (List.map2 (fun (l, _, _) e -> l ^ " = " ^ e) fs es)
        ^ " }")
    in
    let v = value make (List.map (fun (_, _, x) -> x.expr) fs) in
    add_value s name "" v;
    add_pool s (inst xs name) v.vexpr)
  else
    let name = fresh s "pv" in
    let n = 1 + rand 4 in
    let unboxed = n = 1 && chance 0.4 in
    let cases =
      List.init n (fun _ ->
          let c = fresh s "P" in
          if (not unboxed) && chance 0.25 then (c, `Const)
          else if (not unboxed) && chance 0.25 then
            ( c,
              `Inline
                (List.init
                   (1 + rand 3)
                   (fun _ -> (fresh s "l", param_field s ps xs))) )
          else
            ( c,
              `Tuple
                (List.init
                   (if unboxed then 1 else 1 + rand 3)
                   (fun _ -> param_field s ps xs)) ))
    in
    Printf.bprintf s.decls "type %s =%s%s\n" (params_decl ps name)
      (String.concat ""
         (List.map
            (fun (c, a) ->
              match a with
              | `Const -> " | " ^ c
              | `Tuple xs ->
                  " | " ^ c ^ " of "
                  ^ String.concat " * "
                      (List.map (fun x -> "(" ^ x.ty ^ ")") xs)
              | `Inline fs ->
                  " | " ^ c ^ " of { "
                  ^ String.concat "; "
                      (List.map (fun (l, x) -> l ^ " : " ^ x.ty) fs)
                  ^ " }")
            cases))
      (if unboxed then " [@@unboxed]" else "");
    List.iter
      (fun (c, a) ->
        let v =
          match a with
          | `Const -> constant (annot name c)
          | `Tuple xs ->
              value
                (fun es -> annot name (c ^ " (" ^ String.concat ", " es ^ ")"))
                (List.map (fun x -> x.expr) xs)
          | `Inline fs ->
              value
                (fun es ->
                  annot name
                    (c ^ " { "
                    ^ String.concat "; "
                        (List.map2 (fun (l, _) e -> l ^ " = " ^ e) fs es)
                    ^ " }"))
                (List.map (fun (_, x) -> x.expr) fs)
        in
        add_value s name c v;
        add_pool s (inst xs name) v.vexpr)
      cases

(* Recursion the goldens cover: an abbreviation in a group, a recursive
   polymorphic variant, [@@unboxed] in a group, and parameterised
   recursive types. Each value holds its further nodes in [vsubs]. *)
let gen_recursive_more s =
  let rec rec_sample s =
    let x = field_sample s in
    if contains x.expr "[||]" then rec_sample s else x
  in
  let paren x = "(" ^ x.ty ^ ")" in
  let tuple es = "(" ^ String.concat ", " es ^ ")" in
  let x = rec_sample s in
  match rand 5 with
  | 0 ->
      let a = fresh s "ga" and u = fresh s "gu" in
      let stop = fresh s "Gs" and go = fresh s "Gg" in
      add_value s a stop (constant stop);
      if chance 0.5 then (
        (* The abbreviation expands to an option: its Some block counts. *)
        Printf.bprintf s.decls
          "type %s = %s | %s of %s * %s\nand %s = %s option\n" a stop go
          (paren x) u u a;
        let mk es = go ^ " " ^ tuple es in
        let inner = "(" ^ mk [ x.expr; "None" ] ^ ")" in
        let some = "(Some " ^ inner ^ ")" in
        let v = { (value mk [ x.expr; some ]) with vsubs = [ (1, inner) ] } in
        add_value s a go v;
        add_value s u "" (constant some);
        add_pool s a ("(" ^ v.vexpr ^ ")"))
      else (
        (* The abbreviation is a tuple: the node itself. *)
        Printf.bprintf s.decls "type %s = %s | %s of %s\nand %s = %s * %s\n" a
          stop go u u a (paren x);
        let t2 = tuple [ stop; x.expr ] in
        let t1 = tuple [ "(" ^ go ^ " " ^ t2 ^ ")"; x.expr ] in
        let mk es = go ^ " (" ^ String.concat ", " es ^ ")" in
        let v = { (value mk [ t1 ]) with vsubs = [ (0, t1) ] } in
        add_value s a go v;
        add_value s u "" (constant t1);
        add_pool s a ("(" ^ v.vexpr ^ ")"))
  | 1 ->
      let p = fresh s "p" in
      let one = chance 0.5 in
      Printf.bprintf s.decls "type %s = [ `End | `More of %s * %s%s ]\n" p
        (paren x) p
        (if one then " | `One of " ^ paren x else "");
      let tag l es = "(`" ^ l ^ " " ^ String.concat "" es ^ " : " ^ p ^ ")" in
      let inner = tag "More" [ tuple [ x.expr; "`End" ] ] in
      let arg = tuple [ x.expr; inner ] in
      let v = { (value (tag "More") [ arg ]) with vsubs = [ (0, inner) ] } in
      add_value s p "`End" (constant ("(`End : " ^ p ^ ")"));
      add_value s p "`More" v;
      if one then add_value s p "`One" (value (tag "One") [ x.expr ]);
      add_pool s p v.vexpr
  | 2 ->
      let a = fresh s "ua" and b = fresh s "ub" in
      let c = fresh s "U" in
      let l1 = fresh s "u" and l2 = fresh s "u" in
      let record es =
        "{ "
        ^ String.concat "; "
            (List.map2 (fun l e -> l ^ " = " ^ e) [ l1; l2 ] es)
        ^ " }"
      in
      let unboxed es = c ^ " " ^ String.concat "" es in
      if chance 0.5 then (
        (* The unboxed constructor is the record node. *)
        Printf.bprintf s.decls
          "type %s = %s of %s [@@unboxed]\n\
           and %s = { %s : %s; mutable %s : %s option }\n"
          a c b b l1 x.ty l2 a;
        let leaf = record [ x.expr; "None" ] in
        let inner = "(" ^ unboxed [ "(" ^ leaf ^ ")" ] ^ ")" in
        add_value s a c (value unboxed [ "(" ^ leaf ^ ")" ]);
        let v =
          {
            (value record [ x.expr; "(Some " ^ inner ^ ")" ]) with
            vsubs = [ (1, inner) ];
          }
        in
        add_value s b "" v;
        add_pool s b ("(" ^ v.vexpr ^ ")"))
      else (
        (* The unboxed constructor is an option of the record node. *)
        Printf.bprintf s.decls
          "type %s = { %s : %s; %s : %s }\n\
           and %s = %s of %s option [@@unboxed]\n"
          a l1 x.ty l2 b b c a;
        let leaf = "(" ^ record [ x.expr; c ^ " None" ] ^ ")" in
        let some = "(Some " ^ leaf ^ ")" in
        let bv = "(" ^ unboxed [ some ] ^ ")" in
        let v = { (value record [ x.expr; bv ]) with vsubs = [ (1, bv) ] } in
        add_value s a "" v;
        add_value s b c { (value unboxed [ some ]) with vsubs = [ (0, leaf) ] };
        add_pool s a ("(" ^ v.vexpr ^ ")"))
  | 3 ->
      (* A list of pairs, as an unboxed option of a tuple. *)
      let name = fresh s "sq" in
      let ty = inst [ x ] name in
      let case, wrap, decl =
        if chance 0.5 then
          let c = fresh s "Sq" in
          (c, (fun e -> c ^ " " ^ e), c ^ " of ('a * 'a " ^ name ^ ") option")
        else
          let l = fresh s "st" in
          ( "",
            (fun e -> "{ " ^ l ^ " = " ^ e ^ " }"),
            "{ " ^ l ^ " : ('a * 'a " ^ name ^ ") option }" )
      in
      Printf.bprintf s.decls "type 'a %s = %s [@@unboxed]\n" name decl;
      let mk es = "(" ^ wrap (String.concat "" es) ^ " : " ^ ty ^ ")" in
      let inner = mk [ "(Some " ^ tuple [ x.expr; mk [ "None" ] ] ^ ")" ] in
      let field = "(Some " ^ tuple [ x.expr; inner ] ^ ")" in
      let v = { (value mk [ field ]) with vsubs = [ (0, inner) ] } in
      add_value s name case v;
      add_pool s ty v.vexpr
  | _ ->
      let name = fresh s "pt" in
      let leaf = fresh s "Pl" and node = fresh s "Pn" in
      Printf.bprintf s.decls "type 'a %s = %s | %s of 'a %s * 'a * 'a %s\n" name
        leaf node name name;
      let ty = inst [ x ] name in
      let make es = "(" ^ node ^ " " ^ tuple es ^ " : " ^ ty ^ ")" in
      let small = make [ leaf; x.expr; leaf ] in
      let side () = if chance 0.5 then leaf else small in
      let l = side () and r = side () in
      let v =
        {
          (value make [ l; x.expr; r ]) with
          vsubs =
            List.filter_map
              (fun (i, e) -> if e = small then Some (i, e) else None)
              [ (0, l); (2, r) ];
        }
      in
      add_value s name node v;
      add_value s name leaf (constant ("(" ^ leaf ^ " : " ^ ty ^ ")"));
      add_pool s ty v.vexpr

(* A module that hides a type behind its signature: abstract, immediate or
   private. Its values are fields of a record, which is flat when they are
   private floats among floats. *)
let gen_hidden s =
  let m = fresh s "H" in
  let imm () =
    pick
      [
        { ty = "int"; expr = "7" };
        { ty = "bool"; expr = "false" };
        { ty = "char"; expr = "'d'" };
        { ty = "unit"; expr = "()" };
      ]
  in
  let maybe_float () = if chance 0.4 then float_sample () else plain_sample s in
  let x, sg =
    match rand 4 with
    | 0 -> (maybe_float (), "type t")
    | 1 -> (imm (), "type t [@@immediate]")
    | 2 -> (imm (), "type t [@@immediate64]")
    | _ ->
        let x = maybe_float () in
        (x, "type t = private " ^ x.ty)
  in
  Printf.bprintf s.decls
    "module %s : sig %s val v : t end = struct type t = %s let v : t = %s end\n"
    m sg x.ty x.expr;
  let h = { ty = m ^ ".t"; expr = m ^ ".v" } in
  add_value s h.ty "" (constant h.expr);
  add_pool s h.ty h.expr;
  let float = x.ty = "float" || x.ty = "fl" in
  if chance 0.7 then
    emit_record s
      (shuffle
         (h
         :: List.init (rand 3) (fun _ ->
             if float then float_sample () else field_sample s)))

(* An abbreviation, or an abstract type the program promises is
   immediate. *)
let gen_alias s =
  let name = fresh s "al" in
  match rand 3 with
  | 0 ->
      let x = field_sample s in
      let body, e =
        pick
          [
            ("'a * int", "(" ^ x.expr ^ ", 3)");
            ("'a option", "(Some " ^ x.expr ^ ")");
            ("'a ref", "(ref " ^ x.expr ^ ")");
            ("'a -> 'a", "(fun y -> y)");
            ("'a list", "[" ^ x.expr ^ "]");
          ]
      in
      Printf.bprintf s.decls "type 'a %s = %s\n" name body;
      let e = "(" ^ e ^ " : " ^ inst [ x ] name ^ ")" in
      add_value s name "" (constant e);
      add_pool s (inst [ x ] name) e
  | 1 ->
      let x = plain_sample s in
      Printf.bprintf s.decls "type %s = %s\n" name x.ty;
      let e = "(" ^ x.expr ^ " : " ^ name ^ ")" in
      add_value s name "" (constant e);
      add_pool s name e
  | _ ->
      Printf.bprintf s.decls "type %s [@@immediate%s]\n" name
        (if chance 0.5 then "64" else "");
      let e = Printf.sprintf "(Obj.magic %d : %s)" (rand 100) name in
      add_value s name "" (constant e);
      add_pool s name e

(* Fields of an open polymorphic variant, through a parameter or a
   polymorphic field, and of a package type. *)
let gen_open s =
  let extra () = List.init (rand 3) (fun _ -> field_sample s) in
  (* Modules packed directly, as "(module M : P ...)", have a type pk_M. *)
  let direct =
    List.filter_map
      (fun pk ->
        match String.index_opt pk.pexpr ':' with
        | Some i when not (String.starts_with ~prefix:"(module (val" pk.pexpr)
          ->
            Some (String.trim (String.sub pk.pexpr 8 (i - 8)), pk.pexpr)
        | _ -> None)
      s.modules
  in
  match (rand 5, direct) with
  | 0, (_ :: _ as ms) ->
      let m, e = pick ms in
      let x = { ty = "pk_" ^ m; expr = e } in
      add_value s x.ty "" (constant x.expr);
      add_pool s x.ty x.expr;
      emit_record s (shuffle (x :: extra ()))
  | k, _ ->
      let name = fresh s "op" and l = fresh s "o" in
      let param, fty, e =
        match k mod 4 with
        | 0 -> (true, "[> `A ] as 'a", "`A")
        | 1 -> (true, "([> `A ] as 'a) -> int", "(function `A -> 1 | `B -> 2)")
        | 2 -> (false, "'a. ([> `A ] as 'a) -> int", "(fun _ -> 1)")
        | _ -> (false, "'a. ([> `A ] as 'a)", "`A")
      in
      let fs =
        (l, { ty = fty; expr = e })
        :: List.map (fun x -> (fresh s "o", x)) (extra ())
      in
      let fs = shuffle fs in
      Printf.bprintf s.decls "type %s%s = { %s }\n"
        (if param then "'a " else "")
        name
        (String.concat "; " (List.map (fun (l, x) -> l ^ " : " ^ x.ty) fs));
      let ty = if param then "([ `A | `B ]) " ^ name else name in
      let make es =
        "({ "
        ^ String.concat "; " (List.map2 (fun (l, _) e -> l ^ " = " ^ e) fs es)
        ^ " } : " ^ ty ^ ")"
      in
      let v = value make (List.map (fun (_, x) -> x.expr) fs) in
      add_value s name "" v;
      add_pool s ty v.vexpr

let gen_more s =
  match rand 6 with
  | 0 | 1 -> gen_param s
  | 2 -> gen_recursive_more s
  | 3 -> gen_hidden s
  | 4 -> gen_alias s
  | _ -> gen_open s

let program () =
  let s =
    {
      decls = Buffer.create 2048;
      trees = Hashtbl.create 8;
      pool = [];
      values = Hashtbl.create 32;
      modules = [];
      n = 0;
      vchecks = [];
      classes = [];
    }
  in
  for _ = 1 to 4 + rand 8 do
    match rand 23 with
    | 17 | 18 | 19 | 20 | 21 | 22 -> gen_more s
    | 15 | 16 -> gen_recursive s
    | (10 | 11 | 12) when ox -> gen_mixed s
    | 10 | 11 | 12 | 13 | 14 -> gen_values s
    | 0 | 1 | 2 -> gen_variant s
    | 3 | 4 -> gen_record s
    | 5 -> gen_poly s
    | 6 -> gen_gadt s
    | 7 | 8 -> gen_exn s
    | _ -> gen_module s
  done;
  (prelude ^ Buffer.contents s.decls, s)

(* Checks, as OCaml source, from the model's predictions. *)

let word_check what r (w : M.word) =
  match w with
  | Immediate _ -> Printf.sprintf "imm %S %s;" what r
  | Pointer { tag = Some t; _ } ->
      Printf.sprintf "ptr %S %s (Some %d);" what r t
  | Pointer { tag = None; _ } -> Printf.sprintf "ptr %S %s None;" what r
  | Any _ | Double | Flat _ -> ""

(* The leaf at a slot's part path, such as ".1" or ".x". A single-field
   unboxed record is its field, so a path may pass it by. *)
let rec leaf_at t path =
  match (t, path) with
  | Leaf l, [] -> Some l
  | Prod ts, j :: rest -> (
      match int_of_string_opt j with
      | Some j when j < List.length ts -> leaf_at (List.nth ts j) rest
      | _ -> None)
  | Rec (_, fs), j :: rest when List.mem_assoc j fs ->
      leaf_at (List.assoc j fs) rest
  | Rec (_, [ (_, t) ]), path -> leaf_at t path
  | _ -> None

(* Bytecode boxes a flat leaf, keeps a single-field unboxed record as its
   field, and stores any other unboxed product as a tag-0 block. *)
let rec byte_tree b w fr = function
  | Leaf l when l.bits <> None ->
      Printf.bprintf b "    boxed %S %s (Obj.repr %s);\n" w fr l.boxed
  | Leaf _ -> ()
  | Rec (_, [ (_, t) ]) -> byte_tree b w fr t
  | (Prod _ | Rec _) as t ->
      let ts =
        match t with Rec (_, fs) -> List.map snd fs | Prod ts -> ts | _ -> []
      in
      let n = List.length ts in
      Printf.bprintf b
        "    block %S %s 0 %d;\n    if is_block %s 0 %d then begin\n" w fr n fr
        n;
      List.iteri
        (fun i t ->
          byte_tree b
            (Printf.sprintf "%s.%d" w i)
            (Printf.sprintf "(Obj.field %s %d)" fr i)
            t)
        ts;
      Printf.bprintf b "    end;\n"

let mixed_checks b ~what ~r ~trees ~tag ~(fields : M.field list) ~scanned
    ~(slots : M.mixed_slot list) =
  let trees = Array.of_list trees in
  Printf.bprintf b "  if native then begin\n    mixed %S %s %d %d %d;\n" what r
    tag (M.mixed_size slots) scanned;
  let o = ref 0 in
  List.iter
    (fun (sl : M.mixed_slot) ->
      let fr = Printf.sprintf "(Obj.field %s %d)" r !o in
      let w =
        Printf.sprintf "%s slot %d (field %d%s)" what !o sl.field sl.part
      in
      (match sl.mword with
      | Flat _ -> (
          let path =
            match String.split_on_char '.' sl.part with "" :: p -> p | p -> p
          in
          match
            if sl.field < Array.length trees then leaf_at trees.(sl.field) path
            else None
          with
          | Some { bits = Some bits; mask; _ } ->
              (* A vec128 takes two words, both holding [bits]. *)
              for k = 0 to sl.words - 1 do
                Printf.bprintf b "    flat %S %s %d %s %s;\n" w r (!o + k) bits
                  mask
              done
          | _ -> ())
      | word ->
          let c = word_check w fr word in
          if c <> "" then Printf.bprintf b "    %s\n" c);
      o := !o + sl.words)
    slots;
  Buffer.add_string b "  end else begin\n";
  (* Bytecode aborts on SIMD: a value with a vec128 is not built there. *)
  if not (has_vec (Array.to_list trees)) then begin
    Printf.bprintf b "    block %S %s %d %d;\n" what r tag (List.length fields);
    List.iteri
      (fun i (f : M.field) ->
        let fr = Printf.sprintf "(Obj.field %s %d)" r i in
        let w = Printf.sprintf "%s byte field %d (%s)" what i f.ty in
        let tree = if i < Array.length trees then Some trees.(i) else None in
        match tree with
        | Some t when not (value_tree t) -> byte_tree b w fr t
        | _ ->
            let c = word_check w fr f.word in
            if c <> "" then Printf.bprintf b "    %s\n" c)
      fields
  end;
  Buffer.add_string b "  end;\n"

(* A check of the words a value takes, by Obj.reachable_words, less those of
   [subs]: further nodes, or a shared extension slot. *)
let cost_call what r subs (c : M.cost) =
  Printf.sprintf "cost %S %s [%s] [%s] %b %b;" what r (String.concat "; " subs)
    (String.concat "; " (List.map string_of_int c.words))
    c.range (c.uncounted <> [])

(* The words of [n] nodes, each of cost [c]. *)
let nodes_cost (c : M.cost) n =
  M.sum (List.init n (fun _ -> { c with uncounted = []; nodes = false }))

let cost_checks b ~what ~v ~r (shape : M.shape) =
  let obj e = "(Obj.repr (" ^ e ^ "))" in
  match M.shape_cost shape with
  | None | Some { words = [ 0 ]; uncounted = []; _ } -> ()
  | Some c -> (
      let slot =
        match shape with
        | Block { fields = { fkind = Slot _; _ } :: _; _ }
        | Mixed { fields = { fkind = Slot _; _ } :: _; _ } ->
            [ Printf.sprintf "(Obj.field %s 0)" r ]
        | _ -> []
      in
      let subs = slot @ List.map (fun (_, e) -> obj e) v.vsubs in
      let native = match shape with Mixed _ -> "if native then " | _ -> "" in
      Printf.bprintf b "  %s%s\n" native (cost_call (what ^ " words") r subs c);
      match shape with
      | Block { fields; _ } ->
          (* Each field against the expression it was built from. *)
          let k = ref 0 in
          List.iteri
            (fun i (f : M.field) ->
              match f.fkind with
              | Slot _ | Hash _ -> ()
              | _ -> (
                  let j = !k in
                  incr k;
                  let fr = Printf.sprintf "(Obj.field %s %d)" r i in
                  let what = Printf.sprintf "%s field %d words" what i in
                  let subs =
                    List.filter_map
                      (fun (n, e) -> if n = j then Some (obj e) else None)
                      v.vsubs
                  in
                  Printf.bprintf b "  %s\n" (cost_call what fr subs f.owns);
                  (* A list sample against the words of each of its nodes. *)
                  match (f.owns, List.nth_opt v.vfields j) with
                  | ( {
                        words = [ 0 ];
                        uncounted = [ { per_node = Some pc; _ } ];
                        nodes = false;
                        _;
                      },
                      Some e )
                    when pc.uncounted = [] && List.mem_assoc e list_nodes ->
                      Printf.bprintf b "  %s\n"
                        (cost_call (what ^ " per node") fr []
                           (nodes_cost pc (List.assoc e list_nodes)))
                  | _ -> ()))
            fields
      | _ -> ())

let shape_checks ?(trees = []) b ~what ~v (shape : M.shape) =
  let r = "(Obj.repr (" ^ v.vexpr ^ "))" in
  cost_checks b ~what ~v ~r shape;
  match shape with
  | Constant n -> Printf.bprintf b "  const %S %s %d;\n" what r n
  | Block { tag; fields } ->
      Printf.bprintf b "  block %S %s %d %d;\n" what r tag (List.length fields);
      List.iteri
        (fun i (f : M.field) ->
          let fr = Printf.sprintf "(Obj.field %s %d)" r i in
          (match f.fkind with
          | Hash h ->
              Printf.bprintf b "  const %S %s %d;\n" (what ^ " hash") fr h
          | _ -> ());
          let c =
            word_check (Printf.sprintf "%s field %d (%s)" what i f.ty) fr f.word
          in
          if c <> "" then Printf.bprintf b "  %s\n" c)
        fields
  | Flat_float fields ->
      Printf.bprintf b "  block %S %s %d %d;\n" what r M.double_array_tag
        (List.length fields);
      List.iteri
        (fun i e ->
          Printf.bprintf b "  dbl %S %s %d (Obj.magic (%s) : float);\n"
            (Printf.sprintf "%s field %d" what i)
            r i e)
        v.vfields
  | Unboxed f -> (
      match v.vfields with
      | [ e ] ->
          Printf.bprintf b
            "  (let x = %s in same %S (Obj.repr (%s)) (Obj.repr x));\n" e what
            (v.vmake [ "x" ]);
          let c = word_check what r f.word in
          if c <> "" then Printf.bprintf b "  %s\n" c
      | _ -> ())
  | Ext_slot ->
      Printf.bprintf b
        "  block %S %s %d 2;\n\
        \  ptr %S (Obj.field %s 0) (Some %d);\n\
        \  imm %S (Obj.field %s 1);\n"
        what r M.object_tag (what ^ " name") r M.string_tag (what ^ " id") r
  | Mixed { tag; fields; scanned; slots } ->
      mixed_checks b ~what ~r ~trees ~tag ~fields ~scanned ~slots
  | Product fields ->
      (* An unboxed record has no block: check each value field through a
         projection, and a single value field as the value itself. *)
      let trees = Array.of_list trees in
      let native =
        if has_vec (Array.to_list trees) then "if native then " else ""
      in
      Printf.bprintf b "  %s(let p = %s in\n" native v.vexpr;
      List.iteri
        (fun i (f : M.field) ->
          match
            (f.fkind, if i < Array.length trees then Some trees.(i) else None)
          with
          | Label l, Some (Leaf lf) when lf.bits = None || lf.lty = "float" ->
              let fr = Printf.sprintf "(Obj.repr p.#%s)" l in
              let what = Printf.sprintf "%s field %d" what i in
              let c = word_check what fr f.word in
              if c <> "" then Printf.bprintf b "   %s\n" c;
              Printf.bprintf b "   %s\n"
                (cost_call (what ^ " words") fr [] f.owns);
              if List.length fields = 1 then
                Printf.bprintf b "   same %S (Obj.repr p) %s;\n" what fr
          | _ -> ())
        fields;
      Buffer.add_string b "   ());\n"
  | Rebind _ -> (
      (* A rebinding shares the original's extension slot. *)
      match v.vfields with
      | [ orig ] ->
          let slot e =
            Printf.sprintf
              "(Obj.repr (Obj.Extension_constructor.of_val (%s : exn)))" e
          in
          Printf.bprintf b "  same %S %s %s;\n" what (slot v.vexpr) (slot orig)
      | _ -> ())

let checker src (s : state) (u : M.compunit) =
  let b = Buffer.create 4096 in
  Buffer.add_string b src;
  Buffer.add_string b
    {|
let fails = ref 0
let fail what msg = incr fails; Printf.printf "MISMATCH %s: %s\n" what msg
let desc r = if Obj.is_int r then Printf.sprintf "immediate %d" (Obj.obj r : int)
  else Printf.sprintf "block tag %d size %d" (Obj.tag r) (Obj.size r)
let const what r n = if not (Obj.is_int r && (Obj.obj r : int) = n) then fail what (Printf.sprintf "expected immediate %d, got %s" n (desc r))
let block what r tag size = if Obj.is_int r || Obj.tag r <> tag || Obj.size r <> size then fail what (Printf.sprintf "expected block tag %d size %d, got %s" tag size (desc r))
let imm what r = if not (Obj.is_int r) then fail what ("expected an immediate, got " ^ desc r)
let ptr what r tag = if Obj.is_int r || (match tag with Some t -> Obj.tag r <> t | None -> false) then
  fail what (Printf.sprintf "expected a pointer%s, got %s" (match tag with Some t -> " tag " ^ string_of_int t | None -> "") (desc r))
let dbl what r i x = if Obj.is_int r || Obj.tag r <> Obj.double_array_tag || Obj.double_field r i <> x then fail what "expected a flat double"
let same what a b = if a != b then fail what ("expected the value itself, got " ^ desc a)
let native = Sys.backend_type = Sys.Native
(* A copy that shares nothing, so that constants the compiler shares are
   counted once per use. OxCaml cannot marshal mixed blocks. *)
let fresh r = try (Marshal.from_string (Marshal.to_string r [Marshal.No_sharing; Marshal.Closures]) 0 : Obj.t) with Invalid_argument _ -> r
let rw r = Obj.reachable_words (fresh r)
let cp (x : 'a) : 'a = Obj.obj (fresh (Obj.repr x))
let cost what r subs words range open_ =
  let n = rw r - List.fold_left (fun a s -> a + rw s) 0 subs in
  let lo = List.hd words and hi = List.nth words (List.length words - 1) in
  if not (if open_ then n >= lo else if range then lo <= n && n <= hi else List.mem n words) then
    fail what (Printf.sprintf "expected %s words, got %d"
      (if open_ then "at least " ^ string_of_int lo else if range then Printf.sprintf "%d to %d" lo hi
       else String.concat " or " (List.map string_of_int words)) n)
(* OxCaml takes one bit of the start-of-environment field for a flag. *)
let startenv_bits = if String.ends_with ~suffix:"+ox" Sys.ocaml_version then 54 else 55
(* Only read fields when the block has the predicted tag and size. *)
let is_block r tag size = not (Obj.is_int r) && Obj.tag r = tag && Obj.size r = size
let clos what r arity startenv =
  let ci = Obj.raw_field r 1 in
  let a = Nativeint.to_int (Nativeint.shift_right ci 56) in
  let se = Nativeint.to_int (Nativeint.logand (Nativeint.shift_right_logical ci 1) (Nativeint.pred (Nativeint.shift_left 1n startenv_bits))) in
  if (native && a <> arity) || se <> startenv then
    fail what (Printf.sprintf "expected closinfo arity %d, environment from %d; got arity %d, from %d" arity startenv a se)
|};
  if ox then
    Buffer.add_string b
      {|let mixed what r tag size scanned =
  block what r tag size;
  match Obj.Uniform_or_mixed.repr (Obj.Uniform_or_mixed.of_block r) with
  | Mixed { scannable_prefix_len = n } when n = scanned -> ()
  | Uniform when scanned = size -> ()
  | Mixed { scannable_prefix_len = n } -> fail what (Printf.sprintf "expected %d scanned fields, got %d" scanned n)
  | Uniform -> fail what "expected a mixed block, got a uniform one"
let flat what r i bits mask =
  let got = Obj.raw_field r i in
  if Nativeint.logand got mask <> Nativeint.logand bits mask then
    fail what (Printf.sprintf "expected flat bits %nx, got %nx" bits got)
let boxed what f x = if compare f x <> 0 then fail what ("expected the boxed value, got " ^ desc f)
external v128 : string -> int -> int64x2# = "%caml_string_getu128#"
|};
  Buffer.add_string b "let () =\n";
  (* Every generated value must meet a prediction: a missing one fails. *)
  let checked = Hashtbl.create 32 in
  let missing what = Printf.bprintf b "  fail %S \"no prediction\";\n" what in
  List.iter
    (fun (d : M.decl) ->
      let ty = d.name in
      let check case shape =
        match Hashtbl.find_opt s.values (ty, case) with
        | Some v ->
            Hashtbl.replace checked (ty, case) ();
            let trees =
              Option.value (Hashtbl.find_opt s.trees (ty, case)) ~default:[]
            in
            shape_checks ~trees b ~what:(ty ^ "." ^ case) ~v shape
        | None -> ()
      in
      match d.kind with
      | Record shape -> check "" shape
      | Variant cases | Polyvariant { cases; _ } ->
          List.iter (fun (c : M.case) -> check c.name c.shape) cases
      | Extension c -> (
          let ty =
            if Hashtbl.mem s.values ("exn", c.name) then "exn" else "ext"
          in
          match Hashtbl.find_opt s.values (ty, c.name) with
          | Some v ->
              Hashtbl.replace checked (ty, c.name) ();
              shape_checks b ~what:c.name
                ~v:{ v with vexpr = "(" ^ v.vexpr ^ " : " ^ ty ^ ")" }
                c.shape
          | None -> ())
      | Alias w | Abstract w -> (
          (* An abbreviation or abstract type: the word of its value. *)
          match Hashtbl.find_opt s.values (ty, "") with
          | Some v ->
              Hashtbl.replace checked (ty, "") ();
              let c = word_check ty ("(Obj.repr (" ^ v.vexpr ^ "))") w in
              if c <> "" then Printf.bprintf b "  %s\n" c
          | None -> ())
      | Open -> ())
    u.decls;
  Hashtbl.iter
    (fun (ty, case) _ ->
      if not (Hashtbl.mem checked (ty, case)) then
        missing (if case = "" then ty else ty ^ "." ^ case))
    s.values;
  (* First-class modules: each block against the prediction for its package
     type, and each submodule slot whose signature is a named module type
     against the prediction for that type, in turn. *)
  let rec package_checks ~psubs ~what ~depth r name =
    match List.find_opt (fun (p : M.package) -> p.pname = name) u.packages with
    | None -> missing what
    | Some p ->
        let n = List.length p.slots in
        let rv = Printf.sprintf "r%d" depth in
        Printf.bprintf b
          "  (let %s = %s in\n\
          \  block %S %s 0 %d;\n\
          \  if is_block %s 0 %d then begin\n"
          rv r what rv n rv n;
        List.iter
          (fun (sl : M.slot) ->
            let fr = Printf.sprintf "(Obj.field %s %d)" rv sl.index in
            let w = what ^ "." ^ sl.name in
            let c = word_check w fr sl.word in
            if c <> "" then Printf.bprintf b "  %s\n" c;
            match sl.item with
            | Class ->
                (* CamlinternalOO's class table: OxCaml adds a field. *)
                Printf.bprintf b "  block %S %s 0 %d;\n" w fr
                  (if ox then 4 else 3)
            | Module -> (
                match List.assoc_opt sl.name psubs with
                | Some inner ->
                    package_checks ~psubs ~what:w ~depth:(depth + 1) fr inner
                | None -> ())
            | _ -> ())
          p.slots;
        Printf.bprintf b "  end);\n"
  in
  List.iter
    (fun pk ->
      package_checks ~psubs:pk.psubs ~what:pk.pexpr ~depth:0
        ("(Obj.repr " ^ pk.pexpr ^ ")")
        pk.ptype)
    (List.rev s.modules);
  (* Stage 4: closures, lazy values and objects. *)
  (match u.values with
  | None -> if s.vchecks <> [] then missing "values"
  | Some vals ->
      let backend name =
        List.find_opt
          (fun (bc : M.backend_closures) -> bc.backend = name)
          vals.backends
      in
      let closure_checks ~native ~again values =
        let c = Buffer.create 256 in
        (match backend (if native then "native code" else "bytecode") with
        | Some { closures = Some cs; _ } -> (
            let v0, l0 = List.hd values in
            match
              List.find_opt
                (fun (cl : M.closure) ->
                  List.exists (fun (f : M.fn) -> f.fline = l0) cl.fns)
                cs
            with
            (* No block predicted: native code makes it a constant, so two
               calls give the same one. *)
            | None when native ->
                Printf.bprintf c
                  "    if Obj.repr %s != Obj.repr (%s) then fail %S \"no \
                   closure predicted, but each call makes one\";\n"
                  v0 again v0
            | None ->
                Printf.bprintf c "    fail %S \"no closure predicted\";\n" v0
            | Some cl ->
                Printf.bprintf c
                  "    if Obj.repr %s == Obj.repr (%s) then fail %S \"closure \
                   predicted, but calls share one block\";\n"
                  v0 again v0;
                let offs, envstart = M.closure_offsets ~native cl in
                let size = M.closure_size ~native cl in
                List.iter
                  (fun (v, l) ->
                    (* The function the value is: on its line, and not one the compiler split off. *)
                    let idx = ref (-1) in
                    List.iteri
                      (fun i (f : M.fn) ->
                        if
                          !idx < 0 && f.fline = l
                          && not (String.ends_with ~suffix:"_inner" f.fname)
                        then idx := i)
                      cl.fns;
                    if !idx < 0 then
                      Printf.bprintf c
                        "    fail %S \"no function predicted on line %d\";\n" v
                        l
                    else begin
                      let f = List.nth cl.fns !idx
                      and off = List.nth offs !idx in
                      let r = "(Obj.repr " ^ v ^ ")" in
                      let tag, sz =
                        if off = 0 then (M.closure_tag, size)
                        else (M.infix_tag, off)
                      in
                      Printf.bprintf c
                        "    block %S %s %d %d;\n\
                        \    if is_block %s %d %d then begin\n"
                        v r tag sz r tag sz;
                      Printf.bprintf c "    clos %S %s (%d) %d;\n" v r
                        (if f.tupled then -f.arity else f.arity)
                        (envstart - off);
                      List.iteri
                        (fun k (cv : M.capture) ->
                          let w =
                            word_check
                              (v ^ "." ^ cv.cvar)
                              (Printf.sprintf "(Obj.field %s %d)" r
                                 (envstart - off + k))
                              cv.cword
                          in
                          if w <> "" then Printf.bprintf c "    %s\n" w)
                        cl.env;
                      Printf.bprintf c "    end;\n"
                    end)
                  values)
        (* Flambda 2: OxCaml native closures are not predicted. *)
        | Some { closures = None; _ } when ox && native -> ()
        | Some { closures = None; _ } ->
            Printf.bprintf c "    fail %S \"closures not predicted\";\n"
              (fst (List.hd values))
        | None ->
            Printf.bprintf c "    fail %S \"no backend predicted\";\n"
              (fst (List.hd values)));
        Buffer.contents c
      in
      List.iter
        (function
          | Vclosure { values; again } ->
              Printf.bprintf b
                "  if native then begin\n\
                 %s    () end else begin\n\
                 %s    () end;\n"
                (closure_checks ~native:true ~again values)
                (closure_checks ~native:false ~again values)
          | Vlazy { v; line; ident; forced } -> (
              let r = "(Obj.repr " ^ v ^ ")" in
              let held = "(Obj.field " ^ r ^ " 0)" in
              let checks (zkind : M.lazy_kind) zword =
                let b = Buffer.create 256 in
                let word what r w =
                  let w = word_check what r w in
                  if w <> "" then Printf.bprintf b "  %s\n" w
                in
                (match zkind with
                | Itself -> (
                    match ident with
                    | Some id ->
                        Printf.bprintf b "  same %S %s (Obj.repr %s);\n" v r id
                    | None -> word v r zword)
                | Forward ->
                    Printf.bprintf b
                      "  block %S %s %d 1;\n  if is_block %s %d 1 then begin\n"
                      v r M.forward_tag r M.forward_tag;
                    (match ident with
                    | Some id ->
                        Printf.bprintf b "  same %S %s (Obj.repr %s);\n"
                          (v ^ " held") held id
                    | None -> ());
                    word (v ^ " held") held zword;
                    Printf.bprintf b "  end;\n"
                | Suspended when forced ->
                    (* Forcing makes a Forward block, which the GC may then
                       short-cut to the value itself. *)
                    Printf.bprintf b
                      "  (let x = Obj.repr (Lazy.force %s) in\n\
                      \   if %s != x then begin\n\
                      \     block %S %s %d 1;\n\
                      \     if is_block %s %d 1 then same %S %s x end;\n"
                      v r v r M.forward_tag r M.forward_tag (v ^ " held") held;
                    word (v ^ " result") "x" zword;
                    Printf.bprintf b "  );\n"
                | Suspended ->
                    Printf.bprintf b "  block %S %s %d 1;\n" v r M.lazy_tag);
                Buffer.contents b
              in
              match
                List.find_opt
                  (fun (z : M.lazy_value) -> z.zline = line)
                  vals.lazies
              with
              | None ->
                  Printf.bprintf b "  fail %S \"no lazy value predicted\";\n" v
              | Some { zkinds; zword; _ } -> (
                  match
                    ( List.assoc_opt "native code" zkinds,
                      List.assoc_opt "bytecode" zkinds )
                  with
                  | Some n, Some c when n = c ->
                      Buffer.add_string b (checks n zword)
                  | Some n, Some c ->
                      Printf.bprintf b
                        "  if native then begin\n\
                         %s    () end else begin\n\
                         %s    () end;\n"
                        (checks n zword) (checks c zword)
                  | _ ->
                      Printf.bprintf b
                        "  fail %S \"no lazy value predicted for a backend\";\n"
                        v))
          | Vobj { v; line } -> (
              let r = "(Obj.repr " ^ v ^ ")" in
              match
                List.find_opt (fun (o : M.obj) -> o.oline = line) vals.objects
              with
              | None ->
                  Printf.bprintf b "  fail %S \"no object predicted\";\n" v
              | Some o ->
                  let first = if o.env_slot then 3 else 2 in
                  let size = first + List.length o.ivars in
                  Printf.bprintf b
                    "  block %S %s %d %d;\n  if is_block %s %d %d then begin\n"
                    v r M.object_tag size r M.object_tag size;
                  if o.env_slot then
                    Printf.bprintf b "  ptr %S (Obj.field %s 2) (Some 0);\n"
                      (v ^ " environment") r;
                  List.iteri
                    (fun i (iv : M.ivar) ->
                      let w =
                        word_check
                          (v ^ "." ^ iv.vname)
                          (Printf.sprintf "(Obj.field %s %d)" r (first + i))
                          iv.vword
                      in
                      if w <> "" then Printf.bprintf b "  %s\n" w)
                    o.ivars;
                  Printf.bprintf b "  end;\n"))
        (List.rev s.vchecks));
  Buffer.add_string b "  if !fails > 0 then exit 1\n";
  Buffer.contents b

let run_out cmd out =
  Sys.command (Printf.sprintf "%s > %s 2>&1" cmd (Filename.quote out)) = 0

(* One round: the program from [seed], checked on both backends. Returns
   the report, the failures and the checks. *)
let round ~dir ~cmt seed =
  let out = Buffer.create 256 and failures = ref 0 and checks = ref 0 in
  st := Random.State.make [| seed |];
  let src, s = program () in
  let file = Filename.concat dir (Printf.sprintf "prog%d.ml" seed) in
  (match analyze ~file src with
  | Error msg ->
      (* A generator bug, not a lense bug; report it all the same. *)
      Printf.bprintf out
        "seed %d: generated program does not type-check\n%s\n%s\n" seed msg src;
      incr failures
  | Ok u ->
      (if cmt then
         match Cmt_diff.check ~ox ~ocamlc ~file src u with
         | None -> ()
         | Some msg ->
             Printf.bprintf out "seed %d: %s\n" seed msg;
             incr failures);
      let prog = checker src s u in
      checks :=
        List.length (String.split_on_char '\n' prog)
        - List.length (String.split_on_char '\n' src);
      Out_channel.with_open_bin file (fun oc -> output_string oc prog);
      (* The bytecode runs under [ocamlrun]: macOS scans each new
         executable on its first launch, which took 0.1 to 0.4 s a round,
         and ocamlrun is not new. *)
      List.iter
        (fun (name, comp, launch) ->
          let exe =
            Filename.concat dir (Printf.sprintf "prog%d.%s" seed name)
          in
          let log = exe ^ ".log" in
          if
            not
              (run_out
                 (Printf.sprintf "cd %s && %s -w -a %s -o %s"
                    (Filename.quote dir) comp (Filename.quote file)
                    (Filename.quote exe))
                 log)
          then (
            Printf.bprintf out
              "seed %d (%s): checker does not compile, see %s\n" seed name log;
            incr failures)
          else if not (run_out (launch (Filename.quote exe)) log) then (
            Printf.bprintf out "seed %d (%s): %s\n" seed name
              (In_channel.with_open_text log In_channel.input_all);
            incr failures))
        [
          ("native", ocamlopt, Fun.id);
          ("byte", ocamlc, fun exe -> ocamlrun ^ " " ^ exe);
        ]);
  (Buffer.contents out, !failures, !checks)

(* Run the rounds in [jobs] worker processes. Worker k takes the rounds
   k, k + jobs, k + 2 jobs..., in order, so the compiler-libs state that
   one round leaves behind still meets the next. A worker writes each
   report to a file and sends "seed failures checks" down a pipe. The
   reports print in seed order. With [stop], the first failure kills the
   workers. Returns the rounds run, the failures, the checks and whether
   the run stopped. *)
let rounds_in_workers ~dir ~cmt ~jobs ~stop ~seed ~rounds =
  let report_file sd =
    Filename.concat dir (Printf.sprintf "prog%d.report" sd)
  in
  flush_all ();
  let workers =
    List.init jobs (fun k ->
        let r, w = Unix.pipe ~cloexec:true () in
        match Unix.fork () with
        | 0 ->
            Unix.close r;
            (* Its own process group, so that [stop] also kills the
               compilers and checkers it runs. *)
            ignore (Unix.setsid ());
            let i = ref k in
            while !i < rounds do
              let sd = seed + !i in
              let report, fails, checks =
                try round ~dir ~cmt sd
                with e ->
                  ( Printf.sprintf "seed %d: fuzz.exe stopped: %s\n" sd
                      (Printexc.to_string e),
                    1,
                    0 )
              in
              Out_channel.with_open_bin (report_file sd) (fun oc ->
                  output_string oc report);
              let line = Printf.sprintf "%d %d %d\n" sd fails checks in
              ignore (Unix.write_substring w line 0 (String.length line));
              i := !i + jobs
            done;
            Unix._exit 0
        | pid ->
            Unix.close w;
            (pid, r, Buffer.create 64))
  in
  let results = Array.make rounds None and next = ref 0 in
  let failures = ref 0 and checks = ref 0 and stopped = ref false in
  let print i =
    let f = report_file (seed + i) in
    print_string (In_channel.with_open_bin f In_channel.input_all);
    Sys.remove f
  in
  let print_ready () =
    while !next < rounds && results.(!next) <> None do
      print !next;
      incr next
    done;
    flush stdout
  in
  let finish (pid, fd, _) =
    Unix.close fd;
    ignore (Unix.waitpid [] pid)
  in
  let live = ref workers and bytes = Bytes.create 4096 in
  while !live <> [] && not !stopped do
    let ready, _, _ =
      try Unix.select (List.map (fun (_, fd, _) -> fd) !live) [] [] (-1.)
      with Unix.Unix_error (EINTR, _, _) -> ([], [], [])
    in
    List.iter
      (fun fd ->
        let ((_, _, buf) as wk) = List.find (fun (_, f, _) -> f = fd) !live in
        let n = Unix.read fd bytes 0 (Bytes.length bytes) in
        if n = 0 then (
          finish wk;
          live := List.filter (fun (_, f, _) -> f <> fd) !live)
        else (
          Buffer.add_subbytes buf bytes 0 n;
          let lines = String.split_on_char '\n' (Buffer.contents buf) in
          Buffer.clear buf;
          let rec go = function
            | [] -> ()
            | [ partial ] -> Buffer.add_string buf partial
            | line :: rest ->
                Scanf.sscanf line "%d %d %d" (fun sd f c ->
                    results.(sd - seed) <- Some ();
                    failures := !failures + f;
                    checks := !checks + c;
                    if f > 0 && stop then stopped := true);
                go rest
          in
          go lines))
      ready;
    print_ready ()
  done;
  if !stopped then
    List.iter
      (fun ((pid, _, _) as wk) ->
        (try Unix.kill (-pid) Sys.sigkill with Unix.Unix_error _ -> ());
        (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ());
        finish wk)
      !live;
  let ran = ref 0 in
  Array.iteri
    (fun i r ->
      match r with
      | Some () ->
          incr ran;
          if i >= !next then print i
      | None when not !stopped ->
          Printf.printf "seed %d: its worker stopped before the round ended\n"
            (seed + i);
          incr failures
      | None -> ())
    results;
  (!ran, !failures, !checks, !stopped)

let () =
  let seed = ref (int_of_float (Unix.gettimeofday () *. 1000.) land 0xffffff) in
  let rounds = ref 30 and keep = ref "" and cmt = ref true and gen = ref "" in
  let jobs = ref (max 1 (Domain.recommended_domain_count () / 2)) in
  let stop = ref false in
  Arg.parse
    [
      ("-seed", Arg.Set_int seed, "N First seed");
      ("-rounds", Arg.Set_int rounds, "N Programs to try");
      ( "-j",
        Arg.Set_int jobs,
        "N Rounds to run at once (default: half the cores)" );
      ("-stop", Arg.Set stop, " Stop at the first failure");
      ("-keep", Arg.Set_string keep, "DIR Keep the programs here");
      ( "-gen",
        Arg.Set_string gen,
        "DIR Only write each program to DIR, unchecked, for scripts/jsdiff.sh"
      );
      ( "-no-cmt",
        Arg.Clear cmt,
        " Do not compare the model read from a .cmt with the source's" );
      ( "-ox-stdlib",
        Arg.String (fun d -> Lense_core_ox.Load.stdlib_dir := Some d),
        "DIR The OxCaml stdlib .cmi files" );
    ]
    (fun _ -> ())
    "fuzz.exe [-seed N] [-rounds N] [-j N] [-stop] [-keep DIR] [-no-cmt] [-gen \
     DIR]";
  if !gen <> "" then (
    ignore (Sys.command ("mkdir -p " ^ Filename.quote !gen));
    for i = 0 to !rounds - 1 do
      st := Random.State.make [| !seed + i |];
      let src, _ = program () in
      Out_channel.with_open_bin
        (Filename.concat !gen (Printf.sprintf "prog%d.ml" (!seed + i)))
        (fun oc -> output_string oc src)
    done;
    exit 0);
  (* A directory of its own unless -keep names one, so that two runs, on
     5.5 and on OxCaml, can go at once. *)
  let dir =
    if !keep <> "" then (
      let d =
        if Filename.is_relative !keep then Filename.concat (Sys.getcwd ()) !keep
        else !keep
      in
      ignore (Sys.command ("mkdir -p " ^ Filename.quote d));
      d)
    else Filename.temp_dir "lense-fuzz" ""
  in
  let jobs = max 1 (min !jobs !rounds) in
  let ran, failures, checks, stopped =
    rounds_in_workers ~dir ~cmt:!cmt ~jobs ~stop:!stop ~seed:!seed
      ~rounds:!rounds
  in
  Printf.printf
    "%d programs from seed %d, about %d checks each way, %d failures%s\n" ran
    !seed checks failures
    (if stopped then ", stopped at the first" else "");
  if !keep = "" then
    if failures = 0 then ignore (Sys.command ("rm -rf " ^ Filename.quote dir))
    else Printf.printf "the programs are in %s\n" dir;
  exit (if failures > 0 then 1 else 0)
