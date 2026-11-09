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
  [ ("int", "7"); ("bool", "true"); ("char", "'c'"); ("unit", "()"); ("float", "1.5");
    ("fl", "2.5"); ("string", "\"s\""); ("bytes", "(Bytes.make 1 'b')"); ("int32", "3l");
    ("int64", "4L"); ("nativeint", "5n"); ("int list", "[1]"); ("int list", "[]");
    ("int option", "(Some 1)"); ("int option", "None"); ("int * string", "(1, \"a\")");
    ("float array", "[|1.5|]"); ("float array", "[||]"); ("int array", "[|1|]");
    ("int -> int", "(fun x -> x + 1)"); ("int ref", "(ref 1)"); ("exn", "Not_found");
    ("exn", "(Failure \"f\")"); ("string Lazy.t", "(lazy (String.make 1 'z'))");
    ("[ `On | `Off ]", "`On"); ("[ `N of int ]", "(`N 3)"); ("fstr", "{ fa = 1.; fb = 2. }") ]
  |> List.map (fun (ty, expr) -> { ty; expr })

let prelude = "type fl = float\ntype fstr = { fa : float; fb : float }\ntype ext = ..\n"

(* One value to check: its expression, the expressions of the fields it
   was built from in block order, and a way to rebuild it from other field
   expressions. *)
type value = { vexpr : string; vfields : string list; vmake : string list -> string }

let value make fields = { vexpr = make fields; vfields = fields; vmake = make }
let constant e = value (fun _ -> e) []

type state = {
  decls : Buffer.t;
  mutable pool : sample list;
  values : (string * string, value) Hashtbl.t;  (** (type, case) -> value *)
  mutable modules : (string * string) list;  (** module, its module type *)
  mutable n : int;
}

let fresh s prefix =
  s.n <- s.n + 1;
  prefix ^ string_of_int s.n

let field_sample s = pick (if s.pool <> [] && chance 0.3 then s.pool else base)
let float_sample () = pick [ { ty = "float"; expr = "0.25" }; { ty = "fl"; expr = "0.75" } ]

(* Arguments of a constructor: a tuple or an inline record. *)
let args s =
  if chance 0.25 then
    let fs = List.init (1 + rand 3) (fun _ -> (fresh s "l", if chance 0.3 then float_sample () else field_sample s)) in
    let decl = "{ " ^ String.concat "; " (List.map (fun (l, x) -> l ^ " : " ^ x.ty) fs) ^ " }" in
    let make es = "{ " ^ String.concat "; " (List.map2 (fun (l, _) e -> l ^ " = " ^ e) fs es) ^ " }" in
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
              (c, Some ("(" ^ x.ty ^ ")", (fun es -> "(" ^ String.concat ", " es ^ ")"), [ x.expr ])))
        cases
    else cases
  in
  Printf.bprintf s.decls "type %s =%s%s\n" name
    (String.concat "" (List.map (fun (c, a) -> match a with None -> " | " ^ c | Some (d, _, _) -> " | " ^ c ^ " of " ^ d) cases))
    (if unboxed then " [@@unboxed]" else "");
  List.iter
    (fun (c, a) ->
      let v = match a with None -> constant c | Some (_, make, fs) -> value (fun es -> c ^ " " ^ make es) fs in
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
        (fresh s "f", chance 0.3, if floats then float_sample () else field_sample s))
  in
  Printf.bprintf s.decls "type %s = { %s }%s\n" name
    (String.concat "; " (List.map (fun (l, m, x) -> (if m && not unboxed then "mutable " else "") ^ l ^ " : " ^ x.ty) fs))
    (if unboxed then " [@@unboxed]" else "");
  let make es = "{ " ^ String.concat "; " (List.map2 (fun (l, _, _) e -> l ^ " = " ^ e) fs es) ^ " }" in
  let v = value make (List.map (fun (_, _, x) -> x.expr) fs) in
  add_value s name "" v;
  s.pool <- { ty = name; expr = "(" ^ v.vexpr ^ ")" } :: s.pool

let gen_poly s =
  let name = fresh s "p" in
  let labels = [ "A"; "B"; "Cc"; "Dd"; "Ee"; "Ff"; "Gg"; "Hh" ] in
  let tags = List.sort_uniq compare (List.init (1 + rand 5) (fun _ -> pick labels)) in
  let tags = List.map (fun l -> (l, if chance 0.5 then Some (pick base) else None)) tags in
  Printf.bprintf s.decls "type %s = [ %s ]\n" name
    (String.concat " | " (List.map (function l, None -> "`" ^ l | l, Some x -> "`" ^ l ^ " of " ^ x.ty) tags));
  List.iter
    (fun (l, x) ->
      let v =
        match x with
        | None -> constant ("(`" ^ l ^ " : " ^ name ^ ")")
        | Some x -> value (fun es -> "(`" ^ l ^ " " ^ String.concat "" es ^ " : " ^ name ^ ")") [ x.expr ]
      in
      add_value s name ("`" ^ l) v;
      s.pool <- { ty = name; expr = v.vexpr } :: s.pool)
    tags

let gen_gadt s =
  let name = fresh s "g" in
  let cases =
    List.init (1 + rand 4) (fun _ ->
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
            let args = String.concat " * " (List.map (fun x -> "(" ^ x.ty ^ ")") xs) in
            Printf.sprintf " | %s : %s%s %s" c (if xs = [] then "" else args ^ " -> ") idx name)
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
  let existing = Hashtbl.fold (fun (ty, case) v acc -> if ty = "exn" then (case, v) :: acc else acc) s.values [] in
  if rebind && existing <> [] then (
    let target, tv = pick existing in
    Printf.bprintf s.decls "exception %s = %s\n" c target;
    (* The same arguments under the new name; vfields holds the original. *)
    let rename e = c ^ String.sub e (String.length target) (String.length e - String.length target) in
    add_value s "exn" c { vexpr = rename tv.vexpr; vfields = [ tv.vexpr ]; vmake = (fun es -> rename (tv.vmake es)) })
  else
    let a = if chance 0.4 then None else Some (args s) in
    let decl = match a with None -> c | Some (d, _, _) -> c ^ " of " ^ d in
    if ext then Printf.bprintf s.decls "type ext += %s\n" decl
    else Printf.bprintf s.decls "exception %s\n" decl;
    let v = match a with None -> constant c | Some (_, make, fs) -> value (fun es -> c ^ " " ^ make es) fs in
    add_value s (if ext then "ext" else "exn") c v

(* A module of random items, plus a coerced view of it with a random
   subset of its values in a random order. *)
let gen_module s =
  let m = fresh s "M" in
  let items =
    List.init (1 + rand 6) (fun _ ->
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
  Printf.bprintf s.decls "module %s = struct %s end\nmodule type %s_S = module type of %s\n" m
    (String.concat " " (List.map item_src items)) m m;
  s.modules <- (m, m ^ "_S") :: s.modules;
  let sig_item = function
    | `Val (v, x) -> Some (Printf.sprintf "val %s : %s" v x.ty)
    | `Ext e -> if chance 0.5 then Some (Printf.sprintf "val %s : 'a -> 'a" e) else None
    | `Exn x -> Some ("exception " ^ x)
    | `Type _ -> None
    | `Sub sm -> Some (if chance 0.5 then "module " ^ sm ^ " : sig val w : string end" else "module " ^ sm ^ " : sig val z : int val w : string end")
  in
  let chosen = List.filter_map (fun it -> if chance 0.7 then sig_item it else None) items in
  let shuffled = List.map snd (List.sort compare (List.map (fun x -> (rand 1000, x)) chosen)) in
  let c = m ^ "c" in
  Printf.bprintf s.decls "module %s : sig %s end = %s\nmodule type %s_S = module type of %s\n" c
    (String.concat " " shuffled) m c c;
  s.modules <- (c, c ^ "_S") :: s.modules

let program () =
  let s = { decls = Buffer.create 2048; pool = []; values = Hashtbl.create 32; modules = []; n = 0 } in
  for _ = 1 to 4 + rand 8 do
    match rand 10 with
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
  | Pointer { tag = Some t; _ } -> Printf.sprintf "ptr %S %s (Some %d);" what r t
  | Pointer { tag = None; _ } -> Printf.sprintf "ptr %S %s None;" what r
  | Any _ | Double -> ""

let shape_checks b ~what ~v (shape : M.shape) =
  let r = "(Obj.repr (" ^ v.vexpr ^ "))" in
  match shape with
  | Constant n -> Printf.bprintf b "  const %S %s %d;\n" what r n
  | Block { tag; fields } ->
      Printf.bprintf b "  block %S %s %d %d;\n" what r tag (List.length fields);
      List.iteri
        (fun i (f : M.field) ->
          let fr = Printf.sprintf "(Obj.field %s %d)" r i in
          (match f.fkind with
          | Hash h -> Printf.bprintf b "  const %S %s %d;\n" (what ^ " hash") fr h
          | _ -> ());
          let c = word_check (Printf.sprintf "%s field %d (%s)" what i f.ty) fr f.word in
          if c <> "" then Printf.bprintf b "  %s\n" c)
        fields
  | Flat_float fields ->
      Printf.bprintf b "  block %S %s %d %d;\n" what r M.double_array_tag (List.length fields);
      List.iteri
        (fun i e -> Printf.bprintf b "  dbl %S %s %d (%s);\n" (Printf.sprintf "%s field %d" what i) r i e)
        v.vfields
  | Unboxed f -> (
      match v.vfields with
      | [ e ] ->
          Printf.bprintf b "  (let x = %s in same %S (Obj.repr (%s)) (Obj.repr x));\n" e what (v.vmake [ "x" ]);
          let c = word_check what r f.word in
          if c <> "" then Printf.bprintf b "  %s\n" c
      | _ -> ())
  | Ext_slot ->
      Printf.bprintf b "  block %S %s %d 2;\n  ptr %S (Obj.field %s 0) (Some %d);\n  imm %S (Obj.field %s 1);\n"
        what r M.object_tag (what ^ " name") r M.string_tag (what ^ " id") r
  | Rebind _ -> (
      (* A rebinding shares the original's extension slot. *)
      match v.vfields with
      | [ orig ] ->
          let slot e = Printf.sprintf "(Obj.repr (Obj.Extension_constructor.of_val (%s : exn)))" e in
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
let () =
|};
  List.iter
    (fun (d : M.decl) ->
      let ty = d.name in
      let check case shape =
        match Hashtbl.find_opt s.values (ty, case) with
        | Some v -> shape_checks b ~what:(ty ^ "." ^ case) ~v shape
        | None -> ()
      in
      match d.kind with
      | Record shape -> check "" shape
      | Variant cases | Polyvariant { cases; _ } -> List.iter (fun (c : M.case) -> check c.name c.shape) cases
      | Extension c -> (
          let ty = if Hashtbl.mem s.values ("exn", c.name) then "exn" else "ext" in
          match Hashtbl.find_opt s.values (ty, c.name) with
          | Some v -> shape_checks b ~what:c.name ~v:{ v with vexpr = "(" ^ v.vexpr ^ " : " ^ ty ^ ")" } c.shape
          | None -> ())
      | Alias _ | Abstract _ | Open -> ())
    u.decls;
  (* Stage 2: structure blocks and coercions. *)
  List.iter
    (fun (m, mt) ->
      let r = Printf.sprintf "(Obj.repr (module %s : %s))" m mt in
      match List.find_opt (fun (st : M.structure) -> st.mname = m) u.modules with
      | Some st ->
          Printf.bprintf b "  block %S %s 0 %d;\n" ("module " ^ m) r (List.length st.slots);
          List.iter
            (fun (sl : M.slot) ->
              let c = word_check (Printf.sprintf "%s.%s" m sl.name) (Printf.sprintf "(Obj.field %s %d)" r sl.index) sl.word in
              if c <> "" then Printf.bprintf b "  %s\n" c)
            st.slots
      | None -> ())
    s.modules;
  List.iter
    (fun (m, mt) ->
      let prefix = "module " ^ m ^ " : " in
      match
        List.find_opt
          (fun (c : M.coercion) -> String.length c.context >= String.length prefix && String.sub c.context 0 (String.length prefix) = prefix)
          u.coercions
      with
      | Some { copy = Some moves; _ } ->
          let src = String.sub m 0 (String.length m - 1) in
          let cr = Printf.sprintf "(Obj.repr (module %s : %s))" m mt in
          let sr = Printf.sprintf "(Obj.repr (module %s : %s_S))" src src in
          Printf.bprintf b "  block %S %s 0 %d;\n" ("coerced " ^ m) cr (List.length moves);
          List.iter
            (fun (mv : M.move) ->
              let what = Printf.sprintf "coerced %s field %d (%s)" m mv.dst mv.name in
              let dst = Printf.sprintf "(Obj.field %s %d)" cr mv.dst in
              match mv.how with
              | Copy -> Printf.bprintf b "  same %S %s (Obj.field %s %d);\n" what dst sr mv.src
              | Wrapped_primitive -> Printf.bprintf b "  ptr %S %s (Some %d);\n" what dst M.closure_tag
              | Coerced | Realised_alias -> Printf.bprintf b "  ptr %S %s (Some 0);\n" what dst)
            moves
      | _ -> ())
    s.modules;
  Buffer.add_string b "  if !fails > 0 then exit 1\n";
  Buffer.contents b

let run cmd = Sys.command (cmd ^ " > /dev/null 2>&1") = 0

let run_out cmd out = Sys.command (Printf.sprintf "%s > %s 2>&1" cmd (Filename.quote out)) = 0

let () =
  let seed = ref (int_of_float (Unix.gettimeofday () *. 1000.) land 0xffffff) in
  let rounds = ref 30 and keep = ref "" in
  Arg.parse
    [ ("-seed", Arg.Set_int seed, "N First seed"); ("-rounds", Arg.Set_int rounds, "N Programs to try");
      ("-keep", Arg.Set_string keep, "DIR Keep the programs here") ]
    (fun _ -> ()) "fuzz.exe [-seed N] [-rounds N] [-keep DIR]";
  let ocamlopt = Option.value (Sys.getenv_opt "LENSE_OCAMLOPT") ~default:"ocamlfind ocamlopt -package unix" in
  let ocamlc = Option.value (Sys.getenv_opt "LENSE_OCAMLC") ~default:"ocamlfind ocamlc -package unix" in
  let ocamlopt = if run "ocamlfind -version" then ocamlopt else "ocamlopt" in
  let ocamlc = if run "ocamlfind -version" then ocamlc else "ocamlc" in
  let dir = if !keep <> "" then !keep else Filename.concat (Filename.get_temp_dir_name ()) "lense-fuzz" in
  ignore (Sys.command ("mkdir -p " ^ Filename.quote dir));
  let failures = ref 0 and checks = ref 0 in
  for i = 0 to !rounds - 1 do
    let seed = !seed + i in
    st := Random.State.make [| seed |];
    let src, s = program () in
    let file = Filename.concat dir (Printf.sprintf "prog%d.ml" seed) in
    match Lense_core.Load.typecheck ~include_dirs:[] ~file ~intf:false src with
    | exception Lense_core.Load.Failed msg ->
        (* A generator bug, not a lense bug; report it all the same. *)
        Printf.printf "seed %d: generated program does not type-check\n%s\n%s\n" seed msg src;
        incr failures
    | unit_name, input ->
        let u = Lense_core.Analyze.analyze ~file ~unit_name ~src:(Some src) input in
        let prog = checker src s u in
        checks := !checks + List.length (String.split_on_char '\n' prog) - List.length (String.split_on_char '\n' src);
        let oc = open_out file in
        output_string oc prog;
        close_out oc;
        List.iter
          (fun (name, comp) ->
            let exe = Filename.concat dir (Printf.sprintf "prog%d.%s" seed name) in
            let log = exe ^ ".log" in
            if not (run_out (Printf.sprintf "cd %s && %s -w -a %s -o %s" (Filename.quote dir) comp (Filename.quote file) (Filename.quote exe)) log)
            then (
              Printf.printf "seed %d (%s): checker does not compile, see %s\n" seed name log;
              incr failures)
            else if not (run_out (Filename.quote exe) log) then (
              Printf.printf "seed %d (%s): %s\n" seed name (In_channel.with_open_text log In_channel.input_all);
              incr failures))
          [ ("native", ocamlopt); ("byte", ocamlc) ]
  done;
  Printf.printf "%d programs from seed %d, about %d checks each way, %d failures\n" !rounds !seed !checks !failures;
  exit (if !failures > 0 then 1 else 0)
