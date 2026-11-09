#2 "utils/config.fixed.ml"
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                       David Allsopp, Tarides UK.                       *)
(*                                                                        *)
(*   Copyright 2022 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Configuration for the boot compiler. The compiler should refuse to bootstrap
   if configured with values which would contradict the configuration below.
   The values below are picked to trigger errors if accidentally used in the
   compiler (e.g. for the C compiler). *)

let boot_cannot_call s = "/ The boot compiler should not call " ^ s

let bindir = "/tmp"
let standard_library_default = "/tmp"
let ccomp_type = "n/a"
let c_compiler = boot_cannot_call "the C compiler"
let c_output_obj = ""
let c_has_debug_prefix_map = true
let as_has_debug_prefix_map = false
let as_compress_debug_sections_flag = ""
let cc_compress_debug_sections_flag = ""
let ocamlc_cflags = ""
let ocamlc_cppflags = ""
let ocamlopt_cflags = ""
let ocamlopt_cppflags = ""
let bytecomp_c_libraries = ""
let bytecomp_c_compiler = ""
let native_c_compiler = c_compiler
let native_c_libraries = ""
let native_ldflags = ""
let native_pack_linker = boot_cannot_call "the linker"
let default_rpath = ""
let mksharedlibrpath = ""
let ar = boot_cannot_call "ar"
let supports_shared_libraries = true
let native_dynlink = true
let mkdll = native_pack_linker
let mkexe = native_pack_linker
let mkmaindll = native_pack_linker
let flambda = false
let flambda2 = true
let stack_allocation = true
let with_cpp_mangling = false
let probes = false
let poll_insertion = true
let with_flambda_invariants = false
let with_cmm_invariants = false
let windows_unicode = false
let flat_float_array = true
let function_sections = false
let afl_instrument = false
let native_compiler = true
let tsan = false
let architecture = {|arm64|}
let model = {|default|}
let system = {|macosx|}
let asm = boot_cannot_call "the assembler"
let asm_cfi_supported = true
let with_frame_pointers = false
let with_address_sanitizer = false
let reserved_header_bits = 8
let custom_ops_struct_size = 64
let ext_exe = ".ex_The boot compiler should not be using Config.ext_exe"
let ext_obj = ".o_The boot compiler cannot process C objects"
let ext_asm = ".s_The boot compiler should not be using Config.ext_asm"
let ext_lib = ".a_The boot compiler cannot process C libraries"
let ext_dll = ".so_The boot compiler cannot load DLLs"
let host = {|aarch64-apple-darwin|}
let target = {|aarch64-apple-darwin|}
let systhread_supported = true
let flexdll_dirs = []
let ar_supports_response_files = true

(* mshinwell: at present always use runtime4 for bootstrap *)
let runtime5 = true
let no_stack_checks = false
(* This setting is only for bootstrap, does not affect dune-built compilers: *)
let naked_pointers = false
let parameterised_modules = true
let multidomain = true
let objcopy_compress_debug_sections_flag = ""
let objcopy = ""
let syntax_quotations = false
let has_pclmul = false
let has_popcnt = false
let has_sse3 = false
let has_ssse3 = false
let has_sse4_1 = false
let has_sse4_2 = false
let has_bmi = false
let has_bmi2 = false
let has_avx = false
let has_avx2 = false
let oxcaml_dwarf = false
(* generated_by_vendor-oxcaml.sh *)
#3 "utils/config.common.ml.in"
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Portions of the Config module common to both the boot and main compiler. *)

(* The main OCaml version string has moved to ../build-aux/ocaml_version.m4 *)
let version = {|5.2.0+ox|}

let standard_library =
  try
    Sys.getenv "OCAMLLIB"
  with Not_found ->
  try
    Sys.getenv "CAMLLIB"
  with Not_found ->
    standard_library_default

let exec_magic_number = {magic|Caml1999X569|magic}
    (* exec_magic_number is duplicated in runtime/caml/exec.h *)
and cmi_magic_number = {magic|Caml1999I569|magic}
and cmo_magic_number = {magic|Caml1999O569|magic}
and cma_magic_number = {magic|Caml1999A569|magic}
and cmx_magic_number = {magic|Caml1999Y569|magic}
and cmxa_magic_number = {magic|Caml1999Z569|magic}
and ast_impl_magic_number = {magic|Caml1999M569|magic}
and ast_intf_magic_number = {magic|Caml1999N569|magic}
and cmxs_magic_number = {magic|Caml1999D569|magic}
and cmt_magic_number = {magic|Caml1999T569|magic}
and cms_magic_number = {magic|Caml1999S569|magic}
and cmj_magic_number = {magic|Caml1999J569|magic}
and cmja_magic_number = {magic|Caml1999K569|magic}
and linear_magic_number = {magic|Caml1999L569|magic}
and cfg_magic_number = {magic|Caml1999G569|magic}

let safe_string = true
let default_safe_string = true
let naked_pointers = false
let flambda_backend = true
let oxcaml = true
let parameterised_modules = true

let interface_suffix = ref ".mli"

let max_tag = 243
(* This is normally the same as in obj.ml, but we have to define it
   separately because it can differ when we're in the middle of a
   bootstrapping phase. *)
let lazy_tag = 246

let max_young_wosize = 256
let stack_threshold = 32 (* see runtime/caml/config.h *)
let stack_safety_margin = 6
let default_executable_name =
  match Sys.os_type with
    "Unix" -> "a.out"
  | "Win32" | "Cygwin" -> "camlprog.exe"
  | _ -> "camlprog"
type configuration_value =
  | String of string
  | Int of int
  | Bool of bool

let configuration_variables () =
  let p x v = (x, String v) in
  let p_int x v = (x, Int v) in
  let p_bool x v = (x, Bool v) in
[
  p "version" version;
  p "standard_library_default" standard_library_default;
  p "standard_library" standard_library;
  p "ccomp_type" ccomp_type;
  p "c_compiler" c_compiler;
  p "ocamlc_cflags" ocamlc_cflags;
  p "ocamlc_cppflags" ocamlc_cppflags;
  p "ocamlopt_cflags" ocamlopt_cflags;
  p "ocamlopt_cppflags" ocamlopt_cppflags;
  p "bytecomp_c_compiler" bytecomp_c_compiler;
  p "native_c_compiler" native_c_compiler;
  p "bytecomp_c_libraries" bytecomp_c_libraries;
  p "native_c_libraries" native_c_libraries;
  p "native_ldflags" native_ldflags;
  p "native_pack_linker" native_pack_linker;
  p_bool "native_compiler" native_compiler;
  p "architecture" architecture;
  p "model" model;
  p_int "int_size" Sys.int_size;
  p_int "word_size" Sys.word_size;
  p "system" system;
  p "asm" asm;
  p_bool "asm_cfi_supported" asm_cfi_supported;
  p_bool "with_frame_pointers" with_frame_pointers;
  p_bool "with_address_sanitizer" with_address_sanitizer;
  p_bool "with_cpp_mangling" with_cpp_mangling;
  p "ext_exe" ext_exe;
  p "ext_obj" ext_obj;
  p "ext_asm" ext_asm;
  p "ext_lib" ext_lib;
  p "ext_dll" ext_dll;
  p "os_type" Sys.os_type;
  p "default_executable_name" default_executable_name;
  p_bool "systhread_supported" systhread_supported;
  p "host" host;
  p "target" target;
  p_bool "flambda" flambda;
  p_bool "flambda2" flambda2;
  p_bool "safe_string" safe_string;
  p_bool "default_safe_string" default_safe_string;
  p_bool "flat_float_array" flat_float_array;
  p_bool "function_sections" function_sections;
  p_bool "afl_instrument" afl_instrument;
  p_bool "tsan" tsan;
  p_bool "windows_unicode" windows_unicode;
  p_bool "supports_shared_libraries" supports_shared_libraries;
  p_bool "native_dynlink" native_dynlink;
  p_bool "naked_pointers" naked_pointers;
  p_bool "parameterised_modules" parameterised_modules;

  p "exec_magic_number" exec_magic_number;
  p "cmi_magic_number" cmi_magic_number;
  p "cmo_magic_number" cmo_magic_number;
  p "cma_magic_number" cma_magic_number;
  p "cmx_magic_number" cmx_magic_number;
  p "cmxa_magic_number" cmxa_magic_number;
  p "ast_impl_magic_number" ast_impl_magic_number;
  p "ast_intf_magic_number" ast_intf_magic_number;
  p "cmxs_magic_number" cmxs_magic_number;
  p "cmt_magic_number" cmt_magic_number;
  p "cms_magic_number" cms_magic_number;
  p "cmj_magic_number" cmj_magic_number;
  p "cmja_magic_number" cmja_magic_number;
  p "linear_magic_number" linear_magic_number;

  (* "flambda_backend" is still printed for compatibility *)
  p_bool "flambda_backend" flambda_backend;
  p_bool "probes" probes;
  p_bool "stack_allocation" stack_allocation;

  p_bool "no_stack_checks" no_stack_checks;
  p_bool "multidomain" multidomain;
  p_bool "poll_insertion" poll_insertion;
  p_bool "ox" oxcaml;
  p_bool "oxcaml_dwarf" oxcaml_dwarf;
  p "objcopy" objcopy;
]

let print_config_value oc = function
  | String s ->
      Printf.fprintf oc "%s" s
  | Int n ->
      Printf.fprintf oc "%d" n
  | Bool p ->
      Printf.fprintf oc "%B" p

let print_config oc =
  let print (x, v) =
    Printf.fprintf oc "%s: %a\n" x print_config_value v in
  List.iter print (configuration_variables ());
  flush oc

let config_var x =
  match List.assoc_opt x (configuration_variables()) with
  | None -> None
  | Some v ->
      let s = match v with
        | String s -> s
        | Int n -> Int.to_string n
        | Bool b -> string_of_bool b
      in
      Some s

let merlin = false
