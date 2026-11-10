(* The Obj fuzz oracle. Each round writes a program of random declarations,
   predicts the shape of a value of every constructor with lense, then
   compiles a checker that builds those values and inspects them with Obj.
   The ground truth is the running program, so no second compiler is needed.

   fuzz.exe [-seed N] [-rounds N] [-keep DIR]
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
(* Which compiler the oracle runs, read from the ocamlc on PATH. lense
   type-checks with the matching half of its build. *)
let ox =
  let ic =
    Unix.open_process_in
      "ocamlfind ocamlc -version 2>/dev/null || ocamlc -version"
  in
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

type ftree = Leaf of leaf | Prod of ftree list

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

let rec tree_ty = function
  | Leaf l -> if l.bits = None then "(" ^ l.lty ^ ")" else l.lty
  | Prod ts -> "#(" ^ String.concat " * " (List.map tree_ty ts) ^ ")"

(* Value leaves go through [cp], a copy that shares nothing: OxCaml cannot
   marshal a mixed block to undo the constants that native code shares. *)
let rec tree_expr = function
  | Leaf l when l.bits = None || l.lty = "float" -> "(cp " ^ l.lexpr ^ ")"
  | Leaf l -> l.lexpr
  | Prod ts -> "#(" ^ String.concat ", " (List.map tree_expr ts) ^ ")"

type state = {
  decls : Buffer.t;
  trees : (string * string, ftree list) Hashtbl.t;
      (** OxCaml: (type, case) -> fields *)
  mutable pool : sample list;
  values : (string * string, value) Hashtbl.t;  (** (type, case) -> value *)
  mutable modules : (string * string) list;
      (** module, a package type it is packed into *)
  mutable n : int;
  mutable vchecks : vcheck list;  (** Stage 4 values to check. *)
  mutable classes : (string * sample list * (string * bool * sample) list) list;
      (** class, parameters, vals *)
}

(* A Stage 4 value, found in the prediction by the line its definition starts on. *)
and vcheck =
  | Vclosure of { values : (string * int) list }
      (** Each function of one block: the value, its line. *)
  | Vlazy of { v : string; line : int; ident : string option }
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
let gen_mixed s =
  let value_leaf () =
    let x =
      pick (List.filter (fun x -> x.ty <> "float" && x.ty <> "fl") base)
    in
    { lty = x.ty; lexpr = x.expr; bits = None; mask = "0n"; boxed = x.expr }
  in
  let floats_only = chance 0.2 in
  let rec tree depth =
    if floats_only then
      Leaf (if chance 0.5 then float_leaf else List.hd flat_leaves)
    else
      match rand 10 with
      | 0 | 1 | 2 | 3 | 4 -> Leaf (pick flat_leaves)
      | 5 when depth = 0 -> Prod (List.init (2 + rand 2) (fun _ -> tree 1))
      | 6 -> Leaf float_leaf
      | _ -> Leaf (value_leaf ())
  in
  let fields () = List.init (1 + rand 4) (fun _ -> tree 0) in
  if chance 0.5 then (
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
            (fun (_, _, t) -> match t with Leaf l -> l.boxed | Prod _ -> "()")
            fs;
        vmake = make;
        vsubs = [];
      }
    in
    add_value s name "" v;
    Hashtbl.replace s.trees (name, "") (List.map (fun (_, _, t) -> t) fs))
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
      cases

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

(* A module of random items, and a package type of a random subset of
   them in a random order, which the module is packed into. *)
let gen_module s =
  let m = fresh s "M" in
  let items =
    List.init
      (1 + rand 6)
      (fun _ ->
        match rand 6 with
        | 0 -> `Ext (fresh s "e")
        | 1 -> `Exn (fresh s "X")
        | 2 -> `Type (fresh s "ty")
        | 3 -> `Sub (fresh s "S")
        | _ -> `Val (fresh s "v", pick base))
  in
  let item_src = function
    | `Val (v, x) -> Printf.sprintf "let %s : %s = %s" v x.ty x.expr
    | `Ext e -> Printf.sprintf "external %s : 'a -> 'a = \"%%identity\"" e
    | `Exn x -> "exception " ^ x
    | `Type t -> "type " ^ t ^ " = int"
    | `Sub sm -> "module " ^ sm ^ " = struct let z = 1 let w = \"w\" end"
  in
  Printf.bprintf s.decls "module %s = struct %s end\n" m
    (String.concat " " (List.map item_src items));
  let sig_item = function
    | `Val (v, x) -> Some (Printf.sprintf "val %s : %s" v x.ty)
    | `Ext e ->
        if chance 0.5 then Some (Printf.sprintf "val %s : 'a -> 'a" e) else None
    | `Exn x -> Some ("exception " ^ x)
    | `Type _ -> None
    | `Sub sm ->
        Some
          (if chance 0.5 then "module " ^ sm ^ " : sig val w : string end"
           else "module " ^ sm ^ " : sig val z : int val w : string end")
  in
  let chosen =
    List.filter_map (fun it -> if chance 0.7 then sig_item it else None) items
  in
  let shuffled =
    List.map snd (List.sort compare (List.map (fun x -> (rand 1000, x)) chosen))
  in
  let p = m ^ "_P" in
  Printf.bprintf s.decls
    "module type %s = sig %s end\ntype pk_%s = (module %s)\n" p
    (String.concat " " shuffled)
    m p;
  s.modules <- (m, p) :: s.modules

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
  let params =
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
  let args = String.concat " " (List.map (fun (_, x) -> x.expr) caps) in
  match rand 4 with
  | 0 ->
      let l = line s in
      let n = 1 + rand 3 in
      Printf.bprintf s.decls "  fun %s -> %sx0\n"
        (String.concat " " (List.init n (Printf.sprintf "(x%d : int)")))
        use;
      Printf.bprintf s.decls "let %s = %s %s\n" v f args;
      s.vchecks <- Vclosure { values = [ (v, l) ] } :: s.vchecks
  | 1 ->
      let l = line s in
      Printf.bprintf s.decls "  fun (x0, x1) -> %s(x0 : int) + x1\n" use;
      Printf.bprintf s.decls "let %s = %s %s\n" v f args;
      s.vchecks <- Vclosure { values = [ (v, l) ] } :: s.vchecks
  | 2 ->
      let l = line s in
      Printf.bprintf s.decls "  fun ?(o = 1) (x0 : int) -> %so + x0\n" use;
      Printf.bprintf s.decls "let %s = %s %s\n" v f args;
      s.vchecks <- Vclosure { values = [ (v, l) ] } :: s.vchecks
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
      s.vchecks <- Vclosure { values = [ (v, l1); (v2, l2) ] } :: s.vchecks

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
      ]
  in
  if e = id then Printf.bprintf s.decls "let %s : %s = %s\n" id x.ty x.expr;
  let l = line s in
  Printf.bprintf s.decls "let %s = lazy %s\n" v e;
  s.vchecks <-
    Vlazy { v; line = l; ident = (if e = id then Some id else None) }
    :: s.vchecks

let gen_class s =
  let c = fresh s "cl" in
  let params = List.init (rand 3) (fun _ -> (fresh s "p", field_sample s)) in
  let used = List.filter (fun _ -> chance 0.6) params in
  let vals = List.init (rand 4) (fun _ -> (fresh s "a", field_sample s)) in
  let parent =
    if s.classes <> [] && chance 0.6 then Some (pick s.classes) else None
  in
  let vals = List.map (fun (a, x) -> (a, chance 0.3, x)) vals in
  let val_src (a, m, x) =
    Printf.sprintf "val %s%s : %s = %s"
      (if m then "mutable " else "")
      a x.ty x.expr
  in
  let fields = List.map val_src vals in
  let fields =
    match parent with
    | None -> fields
    | Some (pc, pps, pvals) ->
        let inh =
          "inherit " ^ pc
          ^ String.concat "" (List.map (fun x -> " " ^ x.expr) pps)
        in
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
        let i = rand (List.length fields + 1) in
        List.filteri (fun j _ -> j < i) fields
        @ [ inh ] @ extra
        @ List.filteri (fun j _ -> j >= i) fields
  in
  let meth =
    if used = [] then "method m" ^ c ^ " = 0"
    else
      "method m" ^ c ^ " = Sys.opaque_identity ("
      ^ String.concat ", " (List.map fst used)
      ^ ")"
  in
  let o = fresh s "ob" in
  let args = String.concat "" (List.map (fun (_, x) -> " " ^ x.expr) params) in
  if chance 0.7 then (
    let l = line s in
    Printf.bprintf s.decls "class %s %s = object %s %s end\n" c
      (String.concat " "
         (List.map (fun (p, x) -> "(" ^ p ^ " : " ^ x.ty ^ ")") params))
      (String.concat " " fields) meth;
    Printf.bprintf s.decls "let %s = new %s%s\n" o c args;
    s.classes <- (c, List.map snd params, vals) :: s.classes;
    s.vchecks <- Vobj { v = o; line = l } :: s.vchecks)
  else (
    (* An immediate object in a function: its parameters are local variables. *)
    Printf.bprintf s.decls "let %s %s =\n" c
      (if params = [] then "()"
       else
         String.concat " "
           (List.map (fun (p, x) -> "(" ^ p ^ " : " ^ x.ty ^ ")") params));
    let l = line s in
    Printf.bprintf s.decls "  object %s %s end\n" (String.concat " " fields)
      meth;
    Printf.bprintf s.decls "let %s = %s%s\n" o c
      (if params = [] then " ()" else args);
    s.vchecks <- Vobj { v = o; line = l } :: s.vchecks)

let gen_values s =
  match rand 3 with 0 -> gen_closure s | 1 -> gen_lazy s | _ -> gen_class s

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
    match rand 17 with
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

(* The leaf at a slot's part path, such as ".1". *)
let rec leaf_at t path =
  match (t, path) with
  | Leaf l, [] -> Some l
  | Prod ts, j :: rest -> (
      match int_of_string_opt j with
      | Some j when j < List.length ts -> leaf_at (List.nth ts j) rest
      | _ -> None)
  | _ -> None

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
              Printf.bprintf b "    flat %S %s %d %s %s;\n" w r !o bits mask
          | _ -> ())
      | word ->
          let c = word_check w fr word in
          if c <> "" then Printf.bprintf b "    %s\n" c);
      o := !o + sl.words)
    slots;
  Printf.bprintf b "  end else begin\n    block %S %s %d %d;\n" what r tag
    (List.length fields);
  List.iteri
    (fun i (f : M.field) ->
      let fr = Printf.sprintf "(Obj.field %s %d)" r i in
      let w = Printf.sprintf "%s byte field %d (%s)" what i f.ty in
      let tree = if i < Array.length trees then Some trees.(i) else None in
      match tree with
      | Some (Leaf l) when l.bits <> None ->
          Printf.bprintf b "    boxed %S %s (Obj.repr %s);\n" w fr l.boxed
      | Some (Prod ts) ->
          Printf.bprintf b "    block %S %s 0 %d;\n" w fr (List.length ts)
      | _ ->
          let c = word_check w fr f.word in
          if c <> "" then Printf.bprintf b "    %s\n" c)
    fields;
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
  | Product _ -> ()
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
      | Alias _ | Abstract _ | Open -> ())
    u.decls;
  Hashtbl.iter
    (fun (ty, case) _ ->
      if not (Hashtbl.mem checked (ty, case)) then
        missing (if case = "" then ty else ty ^ "." ^ case))
    s.values;
  (* First-class modules: pack each module into a package type that has
     fewer of its items, in another order. *)
  List.iter
    (fun (m, mt) ->
      match List.find_opt (fun (p : M.package) -> p.pname = mt) u.packages with
      | Some p ->
          let r = Printf.sprintf "(Obj.repr (module %s : %s))" m mt in
          Printf.bprintf b "  block %S %s 0 %d;\n"
            ("(module " ^ mt ^ ")")
            r (List.length p.slots);
          List.iter
            (fun (sl : M.slot) ->
              let c =
                word_check
                  (Printf.sprintf "(module %s).%s" mt sl.name)
                  (Printf.sprintf "(Obj.field %s %d)" r sl.index)
                  sl.word
              in
              if c <> "" then Printf.bprintf b "  %s\n" c)
            p.slots
      | None -> missing ("(module " ^ mt ^ ")"))
    s.modules;
  (* Stage 4: closures, lazy values and objects. *)
  (match u.values with
  | None -> if s.vchecks <> [] then missing "values"
  | Some vals ->
      let backend name =
        List.find_opt
          (fun (bc : M.backend_closures) -> bc.backend = name)
          vals.backends
      in
      let closure_checks ~native values =
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
            | None ->
                Printf.bprintf c "    fail %S \"no closure predicted\";\n" v0
            | Some cl ->
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
          | Vclosure { values } ->
              Printf.bprintf b
                "  if native then begin\n\
                 %s    () end else begin\n\
                 %s    () end;\n"
                (closure_checks ~native:true values)
                (closure_checks ~native:false values)
          | Vlazy { v; line; ident } -> (
              let r = "(Obj.repr " ^ v ^ ")" in
              match
                List.find_opt
                  (fun (z : M.lazy_value) -> z.zline = line)
                  vals.lazies
              with
              | None ->
                  Printf.bprintf b "  fail %S \"no lazy value predicted\";\n" v
              | Some { zkind = Itself; zword; _ } -> (
                  match ident with
                  | Some id ->
                      Printf.bprintf b "  same %S %s (Obj.repr %s);\n" v r id
                  | None ->
                      let w = word_check v r zword in
                      if w <> "" then Printf.bprintf b "  %s\n" w)
              | Some { zkind = Forward; _ } ->
                  Printf.bprintf b "  block %S %s %d 1;\n" v r M.forward_tag
              | Some { zkind = Suspended; _ } ->
                  Printf.bprintf b "  block %S %s %d 1;\n" v r M.lazy_tag)
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

let run cmd = Sys.command (cmd ^ " > /dev/null 2>&1") = 0

let run_out cmd out =
  Sys.command (Printf.sprintf "%s > %s 2>&1" cmd (Filename.quote out)) = 0

let () =
  let seed = ref (int_of_float (Unix.gettimeofday () *. 1000.) land 0xffffff) in
  let rounds = ref 30 and keep = ref "" in
  Arg.parse
    [
      ("-seed", Arg.Set_int seed, "N First seed");
      ("-rounds", Arg.Set_int rounds, "N Programs to try");
      ("-keep", Arg.Set_string keep, "DIR Keep the programs here");
      ( "-ox-stdlib",
        Arg.String (fun d -> Lense_core_ox.Load.stdlib_dir := Some d),
        "DIR The OxCaml stdlib .cmi files" );
    ]
    (fun _ -> ())
    "fuzz.exe [-seed N] [-rounds N] [-keep DIR]";
  let ocamlopt =
    Option.value
      (Sys.getenv_opt "LENSE_OCAMLOPT")
      ~default:"ocamlfind ocamlopt -package unix"
  in
  let ocamlc =
    Option.value
      (Sys.getenv_opt "LENSE_OCAMLC")
      ~default:"ocamlfind ocamlc -package unix"
  in
  let ocamlopt = if run "ocamlfind -version" then ocamlopt else "ocamlopt" in
  let ocamlc = if run "ocamlfind -version" then ocamlc else "ocamlc" in
  let dir =
    if !keep <> "" then !keep
    else Filename.concat (Filename.get_temp_dir_name ()) "lense-fuzz"
  in
  ignore (Sys.command ("mkdir -p " ^ Filename.quote dir));
  let failures = ref 0 and checks = ref 0 in
  for i = 0 to !rounds - 1 do
    let seed = !seed + i in
    st := Random.State.make [| seed |];
    let src, s = program () in
    let file = Filename.concat dir (Printf.sprintf "prog%d.ml" seed) in
    match analyze ~file src with
    | Error msg ->
        (* A generator bug, not a lense bug; report it all the same. *)
        Printf.printf "seed %d: generated program does not type-check\n%s\n%s\n"
          seed msg src;
        incr failures
    | Ok u ->
        let prog = checker src s u in
        checks :=
          !checks
          + List.length (String.split_on_char '\n' prog)
          - List.length (String.split_on_char '\n' src);
        let oc = open_out file in
        output_string oc prog;
        close_out oc;
        List.iter
          (fun (name, comp) ->
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
              Printf.printf "seed %d (%s): checker does not compile, see %s\n"
                seed name log;
              incr failures)
            else if not (run_out (Filename.quote exe) log) then (
              Printf.printf "seed %d (%s): %s\n" seed name
                (In_channel.with_open_text log In_channel.input_all);
              incr failures))
          [ ("native", ocamlopt); ("byte", ocamlc) ]
  done;
  Printf.printf
    "%d programs from seed %d, about %d checks each way, %d failures\n" !rounds
    !seed !checks !failures;
  exit (if !failures > 0 then 1 else 0)
