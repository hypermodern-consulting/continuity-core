import Continuity.Build.BzlFile
import Continuity.Emit.Starlark.Render

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                  // continuity // codegen // build // bzl-defs
                                                                bzl-defs.lean

   "It was a Deck — a deck that could take you through the Ice."
                                                               — Neuromancer
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Toolchain .bzl file definitions as BzlFile values.

  Each .bzl file under toolchains/ is defined here as a Lean term.
  The Starlark renderer produces the text. When the bundled prelude
  changes (adds a required field, renames a type), the fix is here —
  one place, one rebuild, all .bzl files updated.

  Implementation bodies are raw Starlark strings. The surrounding
  structure (loads, attrs, providers, rule declarations) is typed.
-/

set_option autoImplicit false

namespace Continuity.Codegen.Build.BzlDefs

open Continuity.Build
open Continuity.Emit.Starlark


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // cxx.bzl
   ════════════════════════════════════════════════════════════════════════════════ -/

private def cxxImplBody : String :=
  "    \"\"\"\n" ++
  "    LLVM toolchain with paths from .buckconfig.local.\n" ++
  "    Reads [cxx] section for absolute Nix store paths.\n" ++
  "    \"\"\"\n" ++
  "    cc = read_root_config(\"cxx\", \"cc\", \"clang\")\n" ++
  "    cxx = read_root_config(\"cxx\", \"cxx\", \"clang++\")\n" ++
  "    ar = read_root_config(\"cxx\", \"ar\", \"llvm-ar\")\n" ++
  "    ld = read_root_config(\"cxx\", \"ld\", \"ld.lld\")\n" ++
  "\n" ++
  "    # Turing Registry flags from config\n" ++
  "    config_c_flags_str = read_root_config(\"cxx.flags\", \"c_flags\", \"\")\n" ++
  "    config_cxx_flags_str = read_root_config(\"cxx.flags\", \"cxx_flags\", \"\")\n" ++
  "    config_c_flags = config_c_flags_str.split() if config_c_flags_str else []\n" ++
  "    config_cxx_flags = config_cxx_flags_str.split() if config_cxx_flags_str else []\n" ++
  "\n" ++
  "    # Include flags from config paths\n" ++
  "    include_flags = []\n" ++
  "    clang_resource_dir = read_root_config(\"cxx\", \"clang_resource_dir\", None)\n" ++
  "    if clang_resource_dir:\n" ++
  "        include_flags.append(\"-resource-dir=\" + clang_resource_dir)\n" ++
  "        include_flags.append(\"-isystem\" + clang_resource_dir + \"/include\")\n" ++
  "    gcc_include = read_root_config(\"cxx\", \"gcc_include\", None)\n" ++
  "    if gcc_include:\n" ++
  "        include_flags.append(\"-isystem\" + gcc_include)\n" ++
  "    gcc_include_arch = read_root_config(\"cxx\", \"gcc_include_arch\", None)\n" ++
  "    if gcc_include_arch:\n" ++
  "        include_flags.append(\"-isystem\" + gcc_include_arch)\n" ++
  "    glibc_include = read_root_config(\"cxx\", \"glibc_include\", None)\n" ++
  "    if glibc_include:\n" ++
  "        include_flags.append(\"-isystem\" + glibc_include)\n" ++
  "    mdspan_include = read_root_config(\"cxx\", \"mdspan_include\", None)\n" ++
  "    if mdspan_include:\n" ++
  "        include_flags.append(\"-isystem\" + mdspan_include)\n" ++
  "\n" ++
  "    # Link flags from config paths\n" ++
  "    llvm_bin_dir = ld.rsplit(\"/\", 1)[0] if \"/\" in ld else None\n" ++
  "    extra_link_flags = []\n" ++
  "    if llvm_bin_dir:\n" ++
  "        extra_link_flags.append(\"-B\" + llvm_bin_dir)\n" ++
  "    extra_link_flags.append(\"-fuse-ld=lld\")\n" ++
  "    glibc_lib = read_root_config(\"cxx\", \"glibc_lib\", None)\n" ++
  "    if glibc_lib:\n" ++
  "        extra_link_flags.append(\"-B\" + glibc_lib)\n" ++
  "        extra_link_flags.append(\"-L\" + glibc_lib)\n" ++
  "        extra_link_flags.append(\"-Wl,-rpath,\" + glibc_lib)\n" ++
  "    gcc_lib = read_root_config(\"cxx\", \"gcc_lib\", None)\n" ++
  "    if gcc_lib:\n" ++
  "        extra_link_flags.append(\"-B\" + gcc_lib)\n" ++
  "        extra_link_flags.append(\"-L\" + gcc_lib)\n" ++
  "        extra_link_flags.append(\"-Wl,-rpath,\" + gcc_lib)\n" ++
  "    gcc_lib_base = read_root_config(\"cxx\", \"gcc_lib_base\", None)\n" ++
  "    if gcc_lib_base:\n" ++
  "        extra_link_flags.append(\"-L\" + gcc_lib_base)\n" ++
  "        extra_link_flags.append(\"-Wl,-rpath,\" + gcc_lib_base)\n" ++
  "\n" ++
  "    # Combine: include + registry + extra\n" ++
  "    c_flags = include_flags + config_c_flags + ctx.attrs.c_extra_flags\n" ++
  "    cxx_flags = include_flags + config_cxx_flags + ctx.attrs.cxx_extra_flags\n" ++
  "    link_flags = extra_link_flags + ctx.attrs.link_flags\n" ++
  "\n" ++
  "    return [\n" ++
  "        DefaultInfo(),\n" ++
  "        CxxToolchainInfo(\n" ++
  "            internal_tools = ctx.attrs._internal_tools[CxxInternalTools],\n" ++
  "            linker_info = LinkerInfo(\n" ++
  "                linker = _run_info(cxx),\n" ++
  "                linker_flags = link_flags,\n" ++
  "                post_linker_flags = [],\n" ++
  "                archiver = _run_info(ar),\n" ++
  "                archiver_type = \"gnu\",\n" ++
  "                archiver_supports_argfiles = True,\n" ++
  "                generate_linker_maps = False,\n" ++
  "                lto_mode = LtoMode(\"none\"),\n" ++
  "                type = LinkerType(\"gnu\"),\n" ++
  "                link_binaries_locally = True,\n" ++
  "                link_libraries_locally = True,\n" ++
  "                archive_objects_locally = True,\n" ++
  "                use_archiver_flags = True,\n" ++
  "                static_dep_runtime_ld_flags = [],\n" ++
  "                static_pic_dep_runtime_ld_flags = [],\n" ++
  "                shared_dep_runtime_ld_flags = [],\n" ++
  "                independent_shlib_interface_linker_flags = [],\n" ++
  "                shlib_interfaces = ShlibInterfacesMode(\"disabled\"),\n" ++
  "                link_style = LinkStyle(ctx.attrs.link_style),\n" ++
  "                link_weight = 1,\n" ++
  "                binary_extension = \"\",\n" ++
  "                object_file_extension = \"o\",\n" ++
  "                shared_library_name_default_prefix = \"lib\",\n" ++
  "                shared_library_name_format = \"{}.so\",\n" ++
  "                shared_library_versioned_name_format = \"{}.so.{}\",\n" ++
  "                static_library_extension = \"a\",\n" ++
  "                force_full_hybrid_if_capable = False,\n" ++
  "                is_pdb_generated = False,\n" ++
  "                link_ordering = None,\n" ++
  "            ),\n" ++
  "            bolt_enabled = False,\n" ++
  "            binary_utilities_info = BinaryUtilitiesInfo(\n" ++
  "                nm = RunInfo(args = [\"llvm-nm\"]),\n" ++
  "                objcopy = RunInfo(args = [\"llvm-objcopy\"]),\n" ++
  "                objdump = RunInfo(args = [\"llvm-objdump\"]),\n" ++
  "                ranlib = RunInfo(args = [\"llvm-ranlib\"]),\n" ++
  "                strip = RunInfo(args = [\"llvm-strip\"]),\n" ++
  "                dwp = None,\n" ++
  "                bolt_msdk = None,\n" ++
  "            ),\n" ++
  "            cxx_compiler_info = CxxCompilerInfo(\n" ++
  "                compiler = _run_info(cxx),\n" ++
  "                preprocessor_flags = [],\n" ++
  "                compiler_flags = cxx_flags,\n" ++
  "                compiler_type = \"clang\",\n" ++
  "            ),\n" ++
  "            c_compiler_info = CCompilerInfo(\n" ++
  "                compiler = _run_info(cc),\n" ++
  "                preprocessor_flags = [],\n" ++
  "                compiler_flags = c_flags,\n" ++
  "                compiler_type = \"clang\",\n" ++
  "            ),\n" ++
  "            as_compiler_info = CCompilerInfo(\n" ++
  "                compiler = _run_info(cc),\n" ++
  "                compiler_type = \"clang\",\n" ++
  "            ),\n" ++
  "            asm_compiler_info = CCompilerInfo(\n" ++
  "                compiler = _run_info(cc),\n" ++
  "                compiler_type = \"clang\",\n" ++
  "            ),\n" ++
  "            header_mode = HeaderMode(\"symlink_tree_only\"),\n" ++
  "            cpp_dep_tracking_mode = \"makefile\",\n" ++
  "            pic_behavior = PicBehavior(\"supported\"),\n" ++
  "            runtime_dependency_handling = RuntimeDependencyHandling(\"symlink\"),\n" ++
  "            llvm_link = RunInfo(args = [\"llvm-link\"]),\n" ++
  "        ),\n" ++
  "        CxxPlatformInfo(name = \"x86_64\"),\n" ++
  "    ]"

def cxxBzl : BzlFile :=
  { header := String.intercalate "\n"
      [ "# toolchains/cxx.bzl — generated by continuity"
      , "#"
      , "# LLVM C++ toolchain using hermetic Nix store paths."
      , "# One toolchain for host + device. No GCC. No nvcc."
      , "#"
      , "# Paths read from .buckconfig.local [cxx] section." ]
  , loads :=
      [ ⟨"@prelude//cxx:cxx_toolchain_types.bzl",
          [ "BinaryUtilitiesInfo", "CCompilerInfo", "CvtresCompilerInfo"
          , "CxxCompilerInfo", "CxxInternalTools", "CxxPlatformInfo"
          , "CxxToolchainInfo", "DepTrackingMode", "LinkerInfo"
          , "LinkerType", "PicBehavior", "RcCompilerInfo"
          , "RuntimeDependencyHandling", "ShlibInterfacesMode" ]⟩
      , ⟨"@prelude//cxx:headers.bzl", ["HeaderMode"]⟩
      , ⟨"@prelude//linking:link_info.bzl", ["LinkStyle"]⟩
      , ⟨"@prelude//linking:lto.bzl", ["LtoMode"]⟩ ]
  , helpers :=
      [ { name := "_run_info"
        , params := ["args"]
        , body := "    return None if args == None else RunInfo(args = [args])" } ]
  , rules :=
      [ { impl :=
            { name := "_llvm_toolchain_impl"
            , body := cxxImplBody
            , is_toolchain := true }
        , attrs :=
            [ ⟨"c_extra_flags", .stringList, ""⟩
            , ⟨"cxx_extra_flags", .stringList, ""⟩
            , ⟨"link_flags", .stringList, ""⟩
            , ⟨"link_style", .string (some "static"), ""⟩
            , ⟨"_internal_tools", .raw "attrs.default_only(attrs.exec_dep(providers = [CxxInternalTools], default = \"prelude//cxx/tools:internal_tools\"))", ""⟩ ] } ] }


/- ════════════════════════════════════════════════════════════════════════════════
                                                                    // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

-- Verify the generated cxx.bzl compiles to valid Starlark

#eval (renderBzlFile cxxBzl).length


/- ════════════════════════════════════════════════════════════════════════════════
                                              // lean.bzl (AST-based)
   ════════════════════════════════════════════════════════════════════════════════ -/

private def leanToolchainBody : List SStmt :=
  [ .comment "Read from config, fall back to attrs"
  , .assign "lean" (SExpr.readConfig "lean" "lean" (SExpr.ctxAttr "lean"))
  , .assign "leanc" (SExpr.readConfig "lean" "leanc" (SExpr.ctxAttr "leanc"))
  , .assign "lean_lib_dir"
      (SExpr.readConfig "lean" "lean_lib_dir" (SExpr.ctxAttr "lean_lib_dir"))
  , .assign "lean_include_dir"
      (SExpr.readConfig "lean" "lean_include_dir" (SExpr.ctxAttr "lean_include_dir"))
  , .blank
  , .ret (.list [
      SExpr.defaultInfo,
      .call (.var "LeanToolchainInfo") [] [
        ("lean", .var "lean"),
        ("leanc", .var "leanc"),
        ("lean_lib_dir", .var "lean_lib_dir"),
        ("lean_include_dir", .var "lean_include_dir") ] ]) ]

private def leanGetConfig (name sect key : String) (errMsg : Option String) : STop :=
  .funcDef s!"_get_{name}" [] (some "str | None") (some s!"Get {name} from config.") [
    .assign "path" (SExpr.readConfigOpt sect key),
    .ifStmt [(.cmp "==" (.var "path") .none,
      match errMsg with
      | some msg => [.expr (.call (.var "fail") [.strBlock msg] [])]
      | none     => [.ret .none]
    )] [],
    .ret (.var "path") ]

private def leanBinaryBody : List SStmt :=
  -- This is the complex one — multi-file Lean compilation + linking.
  -- Uses shell script via cmd_args to handle LEAN_PATH, file copying, etc.
  [ .assign "lean" (.call (.var "_get_lean") [] [])
  , .assign "leanc" (.call (.var "_get_leanc") [] [])
  , .assign "lean_lib_dir" (.call (.var "_get_lean_lib_dir") [] [])
  , .blank
  , .ifStmt [(.unop "not" (SExpr.ctxAttr "srcs"),
      [.expr (.call (.var "fail") [.str "lean_binary requires at least one source file"] [])]
    )] []
  , .blank
  , .comment "Output"
  , .assign "exe" (SExpr.ctxAction "declare_output" [SExpr.ctxAttr "name"] [])
  , .assign "olean_dir"
      (SExpr.ctxAction "declare_output" [.str "olean"] [("dir", .bool true)])
  , .assign "c_dir"
      (SExpr.ctxAction "declare_output" [.str "c"] [("dir", .bool true)])
  , .blank
  , .comment "Collect dependency olean directories"
  , .assign "dep_paths" (.list [])
  , .forStmt "dep" (SExpr.ctxAttr "deps") [
      .ifStmt [(.cmp "in" (.var "LeanLibraryInfo") (.var "dep"), [
        .assign "info" (.index (.var "dep") (.var "LeanLibraryInfo")),
        .ifStmt [(.dot (.var "info") "olean_dir", [
          .expr (.methodCall (.var "dep_paths") "append" [.dot (.var "info") "olean_dir"] [])
        ])] []
      ])] []
    ]
  , .blank
  , .comment "Build LEAN_PATH"
  , .assign "lean_path_parts" (.list [.str "$OLEAN_DIR", .str "$BUCK_SCRATCH_PATH"])
  , .ifStmt [(.var "lean_lib_dir", [
      .expr (.methodCall (.var "lean_path_parts") "append" [.var "lean_lib_dir"] [])
    ])] []
  , .forStmt "dep_path" (.var "dep_paths") [
      .expr (.methodCall (.var "lean_path_parts") "append"
        [.call (.var "cmd_args") [.var "dep_path"] []] [])
    ]
  , .blank
  , .comment "Build script: compile each source to C, then link with leanc"
  , .assign "script_parts" (.list [.str "set -e"])
  , .expr (.methodCall (.var "script_parts") "append" [.str "mkdir -p $OLEAN_DIR $C_DIR"] [])
  , .blank
  , .expr (.methodCall (.var "script_parts") "append" [
      .call (.var "cmd_args") [
        .str "export LEAN_PATH=",
        .call (.var "cmd_args") [.var "lean_path_parts"]
          [("delimiter", .str ":")]
      ] [("delimiter", .str "")]
    ] [])
  , .blank
  , .comment "Determine module structure"
  , .assign "root_module" (SExpr.ctxAttr "root_module")
  , .assign "c_files" (.list [])
  , .assign "compile_order" (.list [])
  , .assign "main_src" .none
  , .blank
  , .forStmt "src" (SExpr.ctxAttr "srcs") [
      .ifStmt [(.cmp "==" (.dot (.var "src") "basename") (.str "Main.lean"), [
        .assign "main_src" (.var "src")
      ])] [
        .expr (.methodCall (.var "compile_order") "append" [.var "src"] [])
      ]
    ]
  , .ifStmt [(.var "main_src", [
      .expr (.methodCall (.var "compile_order") "append" [.var "main_src"] [])
    ])] [
      .assign "main_src" (.index (SExpr.ctxAttr "srcs") (.int 0))
    ]
  , .blank
  , .ifStmt [(.var "root_module", [
      .expr (.methodCall (.var "script_parts") "append"
        [.format "mkdir -p $BUCK_SCRATCH_PATH/{}" [.var "root_module"]] [])
    ])] []
  , .blank
  , .comment "Copy and compile each source"
  , .forStmt "src" (.var "compile_order") [
      .assign "module_name"
        (.methodCall (.dot (.var "src") "basename") "removesuffix" [.str ".lean"] [])
    , .blank
    , .ifStmt [
        (.binop "and" (.var "root_module")
          (.cmp "!=" (.dot (.var "src") "basename") (.str "Main.lean")), [
          .assign "dest_path" (.format "$BUCK_SCRATCH_PATH/{}/{}" [.var "root_module", .dot (.var "src") "basename"])
          , .assign "c_file" (.format "$C_DIR/{}.{}.c" [.var "root_module", .var "module_name"])
          , .assign "olean_file" (.format "$OLEAN_DIR/{}/{}.olean" [.var "root_module", .var "module_name"])
          , .expr (.methodCall (.var "script_parts") "append"
              [.format "mkdir -p $OLEAN_DIR/{}" [.var "root_module"]] [])
        ])] [
          .assign "dest_path" (.format "$BUCK_SCRATCH_PATH/{}" [.dot (.var "src") "basename"])
          , .assign "c_file" (.format "$C_DIR/{}.c" [.var "module_name"])
          , .assign "olean_file" (.format "$OLEAN_DIR/{}.olean" [.var "module_name"])
        ]
    , .expr (.methodCall (.var "c_files") "append" [.var "c_file"] [])
    , .expr (.methodCall (.var "script_parts") "append"
        [.call (.var "cmd_args") [.str "cp", .var "src", .var "dest_path"] [("delimiter", .str " ")]] [])
    , .assign "compile_cmd" (.list [
        .var "lean", .str "--root=$BUCK_SCRATCH_PATH",
        .str "-o", .var "olean_file",
        .call (.var "cmd_args") [.str "--c=", .var "c_file"] [("delimiter", .str "")]])
    , .expr (.methodCall (.var "compile_cmd") "extend" [SExpr.ctxAttr "lean_flags"] [])
    , .expr (.methodCall (.var "compile_cmd") "append" [.var "dest_path"] [])
    , .expr (.methodCall (.var "script_parts") "append"
        [.call (.var "cmd_args") [.var "compile_cmd"] [("delimiter", .str " ")]] [])
    ]
  , .blank
  , .comment "Link with leanc"
  , .assign "link_cmd" (.list [.var "leanc", .str "-o", .methodCall (.var "exe") "as_output" [] []])
  , .expr (.methodCall (.var "link_cmd") "extend" [SExpr.ctxAttr "link_flags"] [])
  , .forStmt "c_file" (.var "c_files") [
      .expr (.methodCall (.var "link_cmd") "append" [.var "c_file"] [])
    ]
  , .expr (.methodCall (.var "script_parts") "append"
      [.call (.var "cmd_args") [.var "link_cmd"] [("delimiter", .str " ")]] [])
  , .blank
  , .assign "script" (.call (.var "cmd_args") [.var "script_parts"] [("delimiter", .str "\n")])
  , .assign "cmd" (.call (.var "cmd_args") [
      .str "/bin/sh", .str "-c",
      .call (.var "cmd_args") [
          .str "OLEAN_DIR=", .methodCall (.var "olean_dir") "as_output" [] [],
          .str " C_DIR=", .methodCall (.var "c_dir") "as_output" [] [],
          .str " && ", .var "script"]
        [("delimiter", .str "")]
    ] [])
  , .blank
  , .assign "hidden" (.call (.var "list") [SExpr.ctxAttr "srcs"] [])
  , .expr (.methodCall (.var "hidden") "extend" [.var "dep_paths"] [])
  , .blank
  , .expr (SExpr.ctxAction "run" [
      .call (.var "cmd_args") [.var "cmd"] [("hidden", .var "hidden")]
    ] [("category", .str "lean_link"),
       ("identifier", SExpr.ctxAttr "name"),
       ("local_only", .bool true)])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "exe")],
      .call (.var "RunInfo") [] [("args", .call (.var "cmd_args") [.var "exe"] [])]
    ])
  ]

def leanSFile : SFile :=
  { header := "# toolchains/lean.bzl — generated by continuity\n#\n# Lean 4 compilation rules. Builder → AST → Render."
  , items := [
      -- Providers
      .provider "LeanLibraryInfo"
        [("olean_dir", "Artifact | None, default = None"),
         ("c_dir", "Artifact | None, default = None"),
         ("lib_name", "str, default = \"\""),
         ("deps", "list, default = []")]
    , .provider "LeanToolchainInfo"
        [("lean", "str"), ("leanc", "str"),
         ("lean_lib_dir", "str | None, default = None"),
         ("lean_include_dir", "str | None, default = None")]
    , .blank
    -- Config helpers
    , leanGetConfig "lean" "lean" "lean"
        (some "\nlean compiler not configured.\nConfigure via Nix .buckconfig.local [lean] section.\n")
    , leanGetConfig "leanc" "lean" "leanc"
        (some "leanc not configured. See [lean] section in .buckconfig")
    , .funcDef "_get_lean_lib_dir" [] (some "str | None")
        (some "Get Lean standard library directory.")
        [.ret (SExpr.readConfigOpt "lean" "lean_lib_dir")]
    , .funcDef "_get_lean_include_dir" [] (some "str | None")
        (some "Get Lean C headers directory.")
        [.ret (SExpr.readConfigOpt "lean" "lean_include_dir")]
    , .blank
    -- lean_binary
    , .funcDef "_lean_binary_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a Lean executable with hierarchical module support.")
        leanBinaryBody
    , .ruleDef "lean_binary" "_lean_binary_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source(), default = [])")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
        , ("root_module", .raw "attrs.option(attrs.string(), default = None)")
        , ("lean_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("link_flags", .raw "attrs.list(attrs.string(), default = [])") ]
    , .blank
    -- lean_toolchain
    , .funcDef "_lean_toolchain_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Lean toolchain with paths from .buckconfig.local.")
        leanToolchainBody
    , .ruleDef "lean_toolchain" "_lean_toolchain_impl" true
        [ ("lean", .raw "attrs.string(default = \"lean\")")
        , ("leanc", .raw "attrs.string(default = \"leanc\")")
        , ("lean_lib_dir", .raw "attrs.option(attrs.string(), default = None)")
        , ("lean_include_dir", .raw "attrs.option(attrs.string(), default = None)") ]
    ] }

#eval (renderSFile leanSFile).length


/- ════════════════════════════════════════════════════════════════════════════════
                                              // rust.bzl (AST-based)
   ════════════════════════════════════════════════════════════════════════════════ -/

private def rustToolchainBody : List SStmt :=
  [ .assign "rustc" (SExpr.readConfig "rust" "rustc" (.str "rustc"))
  , .assign "rustdoc" (SExpr.readConfig "rust" "rustdoc" (.str "rustdoc"))
  , .assign "clippy_driver"
      (SExpr.readConfig "rust" "clippy_driver" (.str "clippy-driver"))
  , .assign "target_triple"
      (SExpr.readConfig "rust" "target_triple" (.str "x86_64-unknown-linux-gnu"))
  , .blank
  , .ret (.list [
      SExpr.defaultInfo,
      .call (.var "RustToolchainInfo") [] [
        ("compiler", SExpr.runInfo (.list [.var "rustc"])),
        ("rustdoc", SExpr.runInfo (.list [.var "rustdoc"])),
        ("clippy_driver", SExpr.runInfo (.list [.var "clippy_driver"])),
        ("rustc_target_triple", .var "target_triple"),
        ("default_edition", SExpr.ctxAttr "default_edition"),
        ("panic_runtime", .call (.var "PanicRuntime") [SExpr.ctxAttr "panic_runtime"] []),
        ("rustc_flags", SExpr.ctxAttr "rustc_flags"),
        ("rustc_binary_flags", SExpr.ctxAttr "rustc_binary_flags"),
        ("rustc_test_flags", SExpr.ctxAttr "rustc_test_flags"),
        ("rustdoc_flags", SExpr.ctxAttr "rustdoc_flags"),
        ("allow_lints", SExpr.ctxAttr "allow_lints"),
        ("deny_lints", SExpr.ctxAttr "deny_lints"),
        ("warn_lints", SExpr.ctxAttr "warn_lints"),
        ("report_unused_deps", SExpr.ctxAttr "report_unused_deps"),
        ("doctests", SExpr.ctxAttr "doctests") ] ]) ]

private def rustBinaryBody : List SStmt :=
  [ .assign "rustc" (SExpr.readConfig "rust" "rustc" (.str "rustc"))
  , .assign "out" (SExpr.ctxAction "declare_output" [SExpr.ctxAttr "name"] [])
  , .assign "cmd" (.call (.var "cmd_args") [.list [.var "rustc"]] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "--edition", SExpr.ctxAttr "edition"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-O"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-o", .methodCall (.var "out") "as_output" [] []] [])
  , .blank
  , .comment "Collect deps (rlibs)"
  , .forStmt "dep" (SExpr.ctxAttr "deps") [
      .ifStmt [(.cmp "in" (.var "RustLibraryInfo") (.var "dep"), [
        .assign "lib_info" (.index (.var "dep") (.var "RustLibraryInfo"))
      , .expr (.methodCall (.var "cmd") "add"
          [.call (.var "cmd_args") [.str "--extern",
            .call (.var "cmd_args") [.dot (.var "lib_info") "crate_name", .str "=", .dot (.var "lib_info") "rlib"]
              [("delimiter", .str "")]] []] [])
      , .expr (.methodCall (.var "cmd") "add"
          [.call (.var "cmd_args") [.dot (.var "lib_info") "rlib"]
            [("format", .str "-Ldependency={}"), ("parent", .int 1)]] [])
      , .forStmt "trans_rlib" (.dot (.var "lib_info") "transitive_deps") [
          .expr (.methodCall (.var "cmd") "add"
            [.call (.var "cmd_args") [.var "trans_rlib"]
              [("format", .str "-Ldependency={}"), ("parent", .int 1)]] [])
        ]
      ])] []
    ]
  , .blank
  , .comment "Binary root is the first source file"
  , .ifStmt [(SExpr.ctxAttr "srcs", [
      .expr (.methodCall (.var "cmd") "add" [.index (SExpr.ctxAttr "srcs") (.int 0)] [])
    , .ifStmt [(.cmp ">" (.call (.var "len") [SExpr.ctxAttr "srcs"] []) (.int 1), [
        .expr (.methodCall (.var "cmd") "add"
          [.call (.var "cmd_args") [] [("hidden", .raw "ctx.attrs.srcs[1:]")]] [])
      ])] []
    ])] []
  , .blank
  , .expr (SExpr.ctxAction "run" [.var "cmd"] [("category", .str "rustc")])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "out")],
      .call (.var "RunInfo") [] [("args", .call (.var "cmd_args") [.var "out"] [])]
    ]) ]

private def rustLibraryBody : List SStmt :=
  [ .assign "rustc" (SExpr.readConfig "rust" "rustc" (.str "rustc"))
  , .assign "crate_name" (.binop "or" (SExpr.ctxAttr "crate_name") (SExpr.ctxAttr "name"))
  , .blank
  , .ifStmt [(SExpr.ctxAttr "proc_macro", [
      .assign "out" (SExpr.ctxAction "declare_output" [.format "lib{}.so" [.var "crate_name"]] [])
    , .assign "crate_type" (.str "proc-macro")
    ])] [
      .assign "out" (SExpr.ctxAction "declare_output" [.format "lib{}.rlib" [.var "crate_name"]] [])
    , .assign "crate_type" (.str "rlib")
    ]
  , .blank
  , .assign "cmd" (.call (.var "cmd_args") [.list [.var "rustc"]] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "--crate-type", .var "crate_type"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "--crate-name", .var "crate_name"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "--edition", SExpr.ctxAttr "edition"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-O"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-o", .methodCall (.var "out") "as_output" [] []] [])
  , .blank
  , .ifStmt [(SExpr.ctxAttr "proc_macro", [
      .expr (.methodCall (.var "cmd") "add" [.str "--extern", .str "proc_macro"] [])
    ])] []
  , .forStmt "feature" (SExpr.ctxAttr "features") [
      .expr (.methodCall (.var "cmd") "add"
        [.str "--cfg", .format "feature=\"{}\"" [.var "feature"]] [])
    ]
  , .blank
  , .assign "transitive_deps" (.list [])
  , .forStmt "dep" (SExpr.ctxAttr "deps") [
      .ifStmt [(.cmp "in" (.var "RustLibraryInfo") (.var "dep"), [
        .assign "lib_info" (.index (.var "dep") (.var "RustLibraryInfo"))
      , .expr (.methodCall (.var "cmd") "add"
          [.call (.var "cmd_args") [.str "--extern",
            .call (.var "cmd_args") [.dot (.var "lib_info") "crate_name", .str "=", .dot (.var "lib_info") "rlib"]
              [("delimiter", .str "")]] []] [])
      , .expr (.methodCall (.var "cmd") "add"
          [.call (.var "cmd_args") [.dot (.var "lib_info") "rlib"]
            [("format", .str "-Ldependency={}"), ("parent", .int 1)]] [])
      , .expr (.methodCall (.var "transitive_deps") "append" [.dot (.var "lib_info") "rlib"] [])
      , .forStmt "trans_rlib" (.dot (.var "lib_info") "transitive_deps") [
          .expr (.methodCall (.var "cmd") "add"
            [.call (.var "cmd_args") [.var "trans_rlib"]
              [("format", .str "-Ldependency={}"), ("parent", .int 1)]] [])
        , .expr (.methodCall (.var "transitive_deps") "append" [.var "trans_rlib"] [])
        ]
      ])] []
    ]
  , .blank
  , .ifStmt [(SExpr.ctxAttr "srcs", [
      .expr (.methodCall (.var "cmd") "add" [.index (SExpr.ctxAttr "srcs") (.int 0)] [])
    , .ifStmt [(.cmp ">" (.call (.var "len") [SExpr.ctxAttr "srcs"] []) (.int 1), [
        .expr (.methodCall (.var "cmd") "add"
          [.call (.var "cmd_args") [] [("hidden", .raw "ctx.attrs.srcs[1:]")]] [])
      ])] []
    ])] []
  , .blank
  , .expr (SExpr.ctxAction "run" [.var "cmd"] [("category", .str "rustc")])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "out")],
      .call (.var "RustLibraryInfo") [] [
        ("rlib", .var "out"),
        ("crate_name", .var "crate_name"),
        ("transitive_deps", .var "transitive_deps")]
    ]) ]

def rustSFile : SFile :=
  { header := "# toolchains/rust.bzl — generated by continuity\n#\n# Hermetic Rust toolchain + rules. Builder → AST → Render."
  , items := [
      .load "@prelude//rust:rust_toolchain.bzl" ["PanicRuntime", "RustToolchainInfo"]
    , .blank
    , .provider "RustCrateInfo"
        [("rlib", "Artifact"), ("rmeta", "Artifact | None, default = None"), ("crate_name", "str")]
    , .provider "RustLibraryInfo"
        [("rlib", "Artifact"), ("crate_name", "str"), ("transitive_deps", "list, default = []")]
    , .blank
    -- rust_toolchain
    , .funcDef "_rust_toolchain_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Rust toolchain with paths from .buckconfig.local.")
        rustToolchainBody
    , .ruleDef "rust_toolchain" "_rust_toolchain_impl" true
        [ ("default_edition", .raw "attrs.string(default = \"2021\")")
        , ("panic_runtime", .raw "attrs.string(default = \"unwind\")")
        , ("rustc_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("rustc_binary_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("rustc_test_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("rustdoc_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("allow_lints", .raw "attrs.list(attrs.string(), default = [])")
        , ("deny_lints", .raw "attrs.list(attrs.string(), default = [])")
        , ("warn_lints", .raw "attrs.list(attrs.string(), default = [])")
        , ("report_unused_deps", .raw "attrs.bool(default = False)")
        , ("doctests", .raw "attrs.bool(default = False)") ]
    , .blank
    -- rust_binary
    , .funcDef "_rust_binary_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a Rust binary.")
        rustBinaryBody
    , .ruleDef "rust_binary" "_rust_binary_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source())")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
        , ("edition", .raw "attrs.string(default = \"2021\")") ]
    , .blank
    -- rust_library
    , .funcDef "_rust_library_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a Rust library (rlib).")
        rustLibraryBody
    , .ruleDef "rust_library" "_rust_library_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source())")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
        , ("edition", .raw "attrs.string(default = \"2021\")")
        , ("crate_name", .raw "attrs.option(attrs.string(), default = None)")
        , ("proc_macro", .raw "attrs.bool(default = False)")
        , ("features", .raw "attrs.list(attrs.string(), default = [])") ]
    ] }

#eval (renderSFile rustSFile).length

/- ════════════════════════════════════════════════════════════════════════════════
                                                       // all .bzl files
   ════════════════════════════════════════════════════════════════════════════════ -/

def bzlFiles : List (String × String) :=
  [ ("toolchains/cxx.bzl", renderBzlFile cxxBzl)
  , ("toolchains/lean.bzl", renderSFile leanSFile)
  , ("toolchains/rust.bzl", renderSFile rustSFile)
  ]

end Continuity.Codegen.Build.BzlDefs
