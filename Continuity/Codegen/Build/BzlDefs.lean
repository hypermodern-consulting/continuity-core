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

private def leanLibraryBody : List SStmt :=
  [ .assign "lean" (.call (.var "_get_lean") [] [])
  , .assign "lean_lib_dir" (.call (.var "_get_lean_lib_dir") [] [])
  , .blank
  , .ifStmt [(.unop "not" (SExpr.ctxAttr "srcs"),
      [.ret (.list [SExpr.defaultInfo, .call (.var "LeanLibraryInfo") [] []])]
    )] []
  , .blank
  , .assign "olean_dir" (SExpr.ctxAction "declare_output" [.str "olean"] [("dir", .bool true)])
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
  , .assign "script_parts" (.list [.str "set -e"])
  , .expr (.methodCall (.var "script_parts") "append" [.str "mkdir -p $OLEAN_DIR"] [])
  , .ifStmt [(.var "c_dir", [
      .expr (.methodCall (.var "script_parts") "append" [.str "mkdir -p $C_DIR"] [])
    ])] []
  , .blank
  , .comment "Build LEAN_PATH"
  , .assign "lean_path_parts" (.list [.str "$OLEAN_DIR"])
  , .ifStmt [(.var "lean_lib_dir", [
      .expr (.methodCall (.var "lean_path_parts") "append" [.var "lean_lib_dir"] [])
    ])] []
  , .forStmt "dep_path" (.var "dep_paths") [
      .expr (.methodCall (.var "lean_path_parts") "append"
        [.call (.var "cmd_args") [.var "dep_path"] []] [])
    ]
  , .expr (.methodCall (.var "script_parts") "append" [
      .call (.var "cmd_args") [
        .str "export LEAN_PATH=",
        .call (.var "cmd_args") [.var "lean_path_parts"] [("delimiter", .str ":")]
      ] [("delimiter", .str "")]
    ] [])
  , .blank
  , .comment "Compile each source (srcs must be in dependency order)"
  , .forStmt "src" (SExpr.ctxAttr "srcs") [
      .assign "src_path" (.dot (.var "src") "short_path")
    , .assign "olean_path" (.binop "+"
        (.methodCall (.var "src_path") "removesuffix" [.str ".lean"] [])
        (.str ".olean"))
    , .expr (.methodCall (.var "script_parts") "append"
        [.call (.var "cmd_args") [.str "mkdir -p $(dirname $BUCK_SCRATCH_PATH/",
          .var "src_path", .str ")"]
          [("delimiter", .str "")]] [])
    , .expr (.methodCall (.var "script_parts") "append"
        [.call (.var "cmd_args") [.str "cp", .var "src",
          .call (.var "cmd_args") [.str "$BUCK_SCRATCH_PATH/", .var "src_path"]
            [("delimiter", .str "")]]
          [("delimiter", .str " ")]] [])
    , .expr (.methodCall (.var "script_parts") "append"
        [.call (.var "cmd_args") [.str "mkdir -p $(dirname $OLEAN_DIR/",
          .var "olean_path", .str ")"]
          [("delimiter", .str "")]] [])
    , .assign "compile_cmd" (.list [
        .var "lean", .str "--root=$BUCK_SCRATCH_PATH"])
    , .expr (.methodCall (.var "compile_cmd") "extend" [SExpr.ctxAttr "lean_flags"] [])
    , .expr (.methodCall (.var "compile_cmd") "extend" [.list [
        .str "-o",
        .call (.var "cmd_args") [.str "$OLEAN_DIR/", .var "olean_path"]
          [("delimiter", .str "")]
      ]] [])
    , .ifStmt [(.var "c_dir", [
        .assign "c_path" (.binop "+"
            (.methodCall (.var "src_path") "removesuffix" [.str ".lean"] [])
            (.str ".c"))
      , .expr (.methodCall (.var "script_parts") "append"
          [.call (.var "cmd_args") [.str "mkdir -p $(dirname $C_DIR/",
            .var "c_path", .str ")"]
            [("delimiter", .str "")]] [])
      , .expr (.methodCall (.var "compile_cmd") "append"
          [.call (.var "cmd_args") [.str "--c=$C_DIR/", .var "c_path"]
            [("delimiter", .str "")]] [])
      ])] []
    , .expr (.methodCall (.var "compile_cmd") "append"
        [.call (.var "cmd_args") [.str "$BUCK_SCRATCH_PATH/", .var "src_path"]
          [("delimiter", .str "")]] [])
    , .expr (.methodCall (.var "script_parts") "append"
        [.call (.var "cmd_args") [.var "compile_cmd"] [("delimiter", .str " ")]] [])
    ]
  , .blank
  , .assign "script" (.call (.var "cmd_args") [.var "script_parts"] [("delimiter", .str "\n")])
  , .assign "env_parts" (.list [.str "OLEAN_DIR=", .methodCall (.var "olean_dir") "as_output" [] []])
  , .ifStmt [(.var "c_dir", [
      .expr (.methodCall (.var "env_parts") "extend"
        [.list [.str " C_DIR=", .methodCall (.var "c_dir") "as_output" [] []]] [])
    ])] []
  , .assign "cmd" (.call (.var "cmd_args") [
      .str "/bin/sh", .str "-c",
      .call (.var "cmd_args") [
        .var "env_parts", .str " && ", .var "script"
      ] [("delimiter", .str "")]
    ] [])
  , .blank
  , .assign "hidden" (.call (.var "list") [SExpr.ctxAttr "srcs"] [])
  , .forStmt "dep_path" (.var "dep_paths") [
      .expr (.methodCall (.var "hidden") "append" [.var "dep_path"] [])
    ]
  , .expr (SExpr.ctxAction "run" [
      .call (.var "cmd_args") [.var "cmd"] [("hidden", .var "hidden")]
    ] [("category", .str "lean_compile"),
       ("identifier", SExpr.ctxAttr "name"),
       ("local_only", .bool true)])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "olean_dir")],
      .call (.var "LeanLibraryInfo") [] [
        ("olean_dir", .var "olean_dir"),
        ("c_dir", .var "c_dir"),
        ("lib_name", SExpr.ctxAttr "name"),
        ("deps", SExpr.ctxAttr "deps")]
    ])
  ]

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
  , .comment "Collect dependency olean and C directories"
  , .assign "dep_paths" (.list [])
  , .assign "dep_c_dirs" (.list [])
  , .forStmt "dep" (SExpr.ctxAttr "deps") [
      .ifStmt [(.cmp "in" (.var "LeanLibraryInfo") (.var "dep"), [
        .assign "info" (.index (.var "dep") (.var "LeanLibraryInfo")),
        .ifStmt [(.dot (.var "info") "olean_dir", [
          .expr (.methodCall (.var "dep_paths") "append" [.dot (.var "info") "olean_dir"] [])
        ])] [],
        .ifStmt [(.dot (.var "info") "c_dir", [
          .expr (.methodCall (.var "dep_c_dirs") "append" [.dot (.var "info") "c_dir"] [])
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
  , .comment "Add dependency library C files"
  , .forStmt "dep_c_dir" (.var "dep_c_dirs") [
      .expr (.methodCall (.var "link_cmd") "append"
        [.call (.var "cmd_args") [.var "dep_c_dir", .str "/*.c"]
          [("delimiter", .str "")]] [])
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
  , .expr (.methodCall (.var "hidden") "extend" [.var "dep_c_dirs"] [])
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
    -- lean_library
    , .funcDef "_lean_library_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a Lean library (.olean files).")
        leanLibraryBody
    , .ruleDef "lean_library" "_lean_library_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source(), default = [])")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
        , ("lean_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("extract_c", .raw "attrs.bool(default = False)") ]
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
                                              // haskell.bzl (AST-based)
   ════════════════════════════════════════════════════════════════════════════════ -/

private def hsToolchainBody : List SStmt :=
  [ .assign "ghc" (SExpr.readConfig "haskell" "ghc" (.str "bin/ghc"))
  , .assign "ghc_pkg" (SExpr.readConfig "haskell" "ghc_pkg" (.str "bin/ghc-pkg"))
  , .assign "haddock" (SExpr.readConfig "haskell" "haddock" (.str "bin/haddock"))
  , .blank
  , .ret (.list [
      SExpr.defaultInfo,
      .call (.var "HaskellToolchainInfo") [] [
        ("compiler", .var "ghc"),
        ("packager", .var "ghc_pkg"),
        ("linker", .var "ghc"),
        ("haddock", .var "haddock"),
        ("compiler_flags", SExpr.ctxAttr "compiler_flags"),
        ("linker_flags", SExpr.ctxAttr "linker_flags"),
        ("ghci_script_template", SExpr.ctxAttr "ghci_script_template"),
        ("ghci_iserv_template", SExpr.ctxAttr "ghci_iserv_template"),
        ("script_template_processor", SExpr.ctxAttr "script_template_processor"),
        ("cache_links", .bool true),
        ("archive_contents", .str "normal"),
        ("support_expose_package", .bool false) ],
      .call (.var "HaskellPlatformInfo") [] [("name", .str "x86_64-linux")]
    ]) ]

/-- Common GHC setup: cmd with mandatory flags, package_db, extensions, packages. -/
private def hsGhcSetup (cmdVar : String) (addLink : Bool) : List SStmt :=
  [ .assign cmdVar (.call (.var "cmd_args") [.list [.var "ghc"]] [])
  , .expr (.methodCall (.var cmdVar) "add" [.str "-package-env=-"] [])
  ] ++ (if addLink then [] else [.expr (.methodCall (.var cmdVar) "add" [.str "-no-link"] [])]) ++
  [ .ifStmt [(.var "package_db", [
      .expr (.methodCall (.var cmdVar) "add" [.str "-package-db", .var "package_db"] [])
    ])] []
  , .expr (.methodCall (.var cmdVar) "add" [.var "MANDATORY_GHC_FLAGS"] [])
  , .expr (.methodCall (.var cmdVar) "add" [.str "-XGHC2024"] [])
  , .forStmt "ext" (SExpr.ctxAttr "language_extensions") [
      .expr (.methodCall (.var cmdVar) "add"
        [.format "-X{}" [.var "ext"]] [])
    ]
  , .forStmt "pkg" (SExpr.ctxAttr "packages") [
      .expr (.methodCall (.var cmdVar) "add" [.str "-package", .var "pkg"] [])
    ]
  ]

/-- Collect deps from HaskellLibraryInfo. -/
private def hsCollectDeps : List SStmt :=
  [ .assign "dep_hi_dirs" (.list [])
  , .assign "dep_libs" (.list [])
  , .assign "dep_sources" (.list [])
  , .forStmt "dep" (SExpr.ctxAttr "deps") [
      .ifStmt [(.cmp "in" (.var "HaskellLibraryInfo") (.var "dep"), [
        .assign "lib_info" (.index (.var "dep") (.var "HaskellLibraryInfo")),
        .ifStmt [(.dot (.var "lib_info") "hi_dir", [
          .expr (.methodCall (.var "dep_hi_dirs") "append" [.dot (.var "lib_info") "hi_dir"] [])
        ])] [],
        .ifStmt [(.dot (.var "lib_info") "objects", [
          .expr (.methodCall (.var "dep_libs") "extend" [.dot (.var "lib_info") "objects"] [])
        ])] [
          .ifStmt [(.dot (.var "lib_info") "object_dir", [
            .expr (.methodCall (.var "dep_libs") "append" [.dot (.var "lib_info") "object_dir"] [])
          ])] []
        ],
        .ifStmt [(.dot (.var "lib_info") "modules", [
          .expr (.methodCall (.var "dep_sources") "extend" [.dot (.var "lib_info") "modules"] [])
        ])] []
      ])] []
    ]
  ]

/-- Add dep hi dirs as -i flags and source/object deps. -/
private def hsAddDeps (cmdVar : String) : List SStmt :=
  [ .forStmt "hi_d" (.var "dep_hi_dirs") [
      .expr (.methodCall (.var cmdVar) "add"
        [.call (.var "cmd_args") [.str "-i", .var "hi_d"] [("delimiter", .str "")]] [])
    ]
  , .expr (.methodCall (.var cmdVar) "add" [SExpr.ctxAttr "srcs"] [])
  , .expr (.methodCall (.var cmdVar) "add" [.var "dep_sources"] [])
  , .expr (.methodCall (.var cmdVar) "add" [.var "dep_libs"] [])
  ]

private def hsBinaryBody : List SStmt :=
  [ .assign "ghc" (.call (.var "_get_ghc") [] [])
  , .assign "package_db" (.call (.var "_get_package_db") [] [])
  , .assign "out" (SExpr.ctxAction "declare_output" [SExpr.ctxAttr "name"] [])
  , .assign "obj_dir" (SExpr.ctxAction "declare_output" [.str "objs"] [("dir", .bool true)])
  , .assign "hi_dir" (SExpr.ctxAction "declare_output" [.str "hi"] [("dir", .bool true)])
  , .assign "hie_dir" (SExpr.ctxAction "declare_output" [.str "hie"] [("dir", .bool true)])
  , .blank
  ] ++ hsCollectDeps ++ [.blank]
    ++ hsGhcSetup "cmd" true ++
  [ .expr (.methodCall (.var "cmd") "add" [.str "-O2"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-odir", .methodCall (.var "obj_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-hidir", .methodCall (.var "hi_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-fwrite-ide-info"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-hiedir", .methodCall (.var "hie_dir") "as_output" [] []] [])
  , .ifStmt [(SExpr.ctxAttr "main", [
      .expr (.methodCall (.var "cmd") "add" [.str "-main-is", SExpr.ctxAttr "main"] [])
    ])] []
  , .expr (.methodCall (.var "cmd") "add" [.str "-o", .methodCall (.var "out") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [SExpr.ctxAttr "ghc_options"] [])
  , .expr (.methodCall (.var "cmd") "add" [SExpr.ctxAttr "compiler_flags"] [])
  , .blank
  ] ++ hsAddDeps "cmd" ++
  [ .blank
  , .expr (SExpr.ctxAction "run" [.var "cmd"] [("category", .str "ghc"), ("identifier", SExpr.ctxAttr "name")])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [
        ("default_output", .var "out"),
        ("sub_targets", .dict [
          (.str "hi", .list [.call (.var "DefaultInfo") [] [("default_outputs", .list [.var "hi_dir"])]]),
          (.str "hie", .list [.call (.var "DefaultInfo") [] [("default_outputs", .list [.var "hie_dir"])]])])],
      .call (.var "RunInfo") [] [("args", .call (.var "cmd_args") [.var "out"] [])]
    ]) ]

private def hsLibraryBody : List SStmt :=
  [ .assign "ghc" (.call (.var "_get_ghc") [] [])
  , .assign "package_db" (.call (.var "_get_package_db") [] [])
  , .blank
  , .ifStmt [(.unop "not" (SExpr.ctxAttr "srcs"),
      [.ret (.list [SExpr.defaultInfo,
        .call (.var "HaskellLibraryInfo") [] [("package_name", SExpr.ctxAttr "name"), ("modules", .list [])]])]
    )] []
  , .blank
  , .assign "obj_dir" (SExpr.ctxAction "declare_output" [.str "objs"] [("dir", .bool true)])
  , .assign "hi_dir" (SExpr.ctxAction "declare_output" [.str "hi"] [("dir", .bool true)])
  , .assign "stub_dir" (SExpr.ctxAction "declare_output" [.str "stubs"] [("dir", .bool true)])
  , .assign "hie_dir" (SExpr.ctxAction "declare_output" [.str "hie"] [("dir", .bool true)])
  , .blank
  ] ++ hsCollectDeps ++ [.blank]
    ++ hsGhcSetup "cmd" false ++
  [ .expr (.methodCall (.var "cmd") "add" [.str "-odir", .methodCall (.var "obj_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-hidir", .methodCall (.var "hi_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-stubdir", .methodCall (.var "stub_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-fwrite-ide-info"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-hiedir", .methodCall (.var "hie_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [SExpr.ctxAttr "ghc_options"] [])
  , .forStmt "hi_d" (.var "dep_hi_dirs") [
      .expr (.methodCall (.var "cmd") "add"
        [.call (.var "cmd_args") [.str "-i", .var "hi_d"] [("delimiter", .str "")]] [])
    ]
  , .expr (.methodCall (.var "cmd") "add" [SExpr.ctxAttr "srcs"] [])
  , .blank
  , .expr (SExpr.ctxAction "run" [.var "cmd"]
      [("category", .str "haskell_compile"), ("identifier", SExpr.ctxAttr "name")])
  , .blank
  , .comment "Archive objects"
  , .assign "lib" (SExpr.ctxAction "declare_output"
      [.format "lib{}.a" [SExpr.ctxAttr "name"]] [])
  , .assign "ar_cmd" (.call (.var "cmd_args") [
      .str "/bin/sh", .str "-c",
      .call (.var "cmd_args") [.str "ar rcs",
        .methodCall (.var "lib") "as_output" [] [],
        .call (.var "cmd_args") [.var "obj_dir"] [("format", .str "{}/*.o")]
      ] [("delimiter", .str " ")]
    ] [])
  , .expr (SExpr.ctxAction "run" [.var "ar_cmd"]
      [("category", .str "haskell_archive"), ("identifier", SExpr.ctxAttr "name")])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [
        ("default_output", .var "lib"),
        ("sub_targets", .dict [
          (.str "hi", .list [.call (.var "DefaultInfo") [] [("default_outputs", .list [.var "hi_dir"])]]),
          (.str "stubs", .list [.call (.var "DefaultInfo") [] [("default_outputs", .list [.var "stub_dir"])]]),
          (.str "objects", .list [.call (.var "DefaultInfo") [] [("default_outputs", .list [.var "obj_dir"])]]),
          (.str "hie", .list [.call (.var "DefaultInfo") [] [("default_outputs", .list [.var "hie_dir"])]])])],
      .call (.var "HaskellLibraryInfo") [] [
        ("package_name", SExpr.ctxAttr "name"),
        ("hi_dir", .var "hi_dir"),
        ("object_dir", .var "lib"),
        ("stub_dir", .var "stub_dir"),
        ("hie_dir", .var "hie_dir"),
        ("objects", .list []),
        ("modules", SExpr.ctxAttr "srcs")]
    ]) ]

private def hsScriptBody : List SStmt :=
  [ .assign "ghc" (.call (.var "_get_ghc") [] [])
  , .assign "out" (SExpr.ctxAction "declare_output" [SExpr.ctxAttr "name"] [])
  , .assign "obj_dir" (SExpr.ctxAction "declare_output" [.str "objs"] [("dir", .bool true)])
  , .assign "hi_dir" (SExpr.ctxAction "declare_output" [.str "hi"] [("dir", .bool true)])
  , .assign "cmd" (.call (.var "cmd_args") [.list [.var "ghc"]] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-odir", .methodCall (.var "obj_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-hidir", .methodCall (.var "hi_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "cmd") "add" [.var "MANDATORY_GHC_FLAGS"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-XGHC2024"] [])
  , .expr (.methodCall (.var "cmd") "add" [SExpr.ctxAttr "compiler_flags"] [])
  , .expr (.methodCall (.var "cmd") "add" [.str "-o", .methodCall (.var "out") "as_output" [] []] [])
  , .forStmt "inc" (SExpr.ctxAttr "include_paths") [
      .expr (.methodCall (.var "cmd") "add" [.binop "+" (.str "-i") (.var "inc")] [])
    ]
  , .forStmt "pkg" (SExpr.ctxAttr "packages") [
      .expr (.methodCall (.var "cmd") "add" [.str "-package", .var "pkg"] [])
    ]
  , .expr (.methodCall (.var "cmd") "add" [SExpr.ctxAttr "srcs"] [])
  , .expr (SExpr.ctxAction "run" [.var "cmd"]
      [("category", .str "haskell_script"), ("identifier", SExpr.ctxAttr "name")])
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "out")],
      .call (.var "RunInfo") [] [("args", .list [.var "out"])]
    ]) ]

private def hsCLibraryBody : List SStmt :=
  [ .assign "ghc" (.call (.var "_get_ghc") [] [])
  , .assign "package_db" (.call (.var "_get_package_db") [] [])
  , .assign "stub_dir" (SExpr.ctxAction "declare_output" [.str "stubs"] [("dir", .bool true)])
  , .assign "lib" (SExpr.ctxAction "declare_output" [.format "lib{}.a" [SExpr.ctxAttr "name"]] [])
  , .blank
  , .comment "Collect dependency hi dirs"
  , .assign "dep_hi_dirs" (.list [])
  , .forStmt "dep" (SExpr.ctxAttr "deps") [
      .ifStmt [(.cmp "in" (.var "HaskellLibraryInfo") (.var "dep"), [
        .assign "lib_info" (.index (.var "dep") (.var "HaskellLibraryInfo")),
        .ifStmt [(.dot (.var "lib_info") "hi_dir", [
          .expr (.methodCall (.var "dep_hi_dirs") "append" [.dot (.var "lib_info") "hi_dir"] [])
        ])] []
      ])] []
    ]
  , .blank
  , .assign "objects" (.list [])
  , .assign "hi_files" (.list [])
  , .forStmt "src" (SExpr.ctxAttr "srcs") [
      .assign "src_path" (.dot (.var "src") "short_path")
    , .ifStmt [(.methodCall (.var "src_path") "endswith" [.str ".hs"] [], [
        .assign "base_name" (.index (.methodCall (.methodCall (.var "src_path") "replace" [.str ".hs", .str ""] []) "split" [.str "/"] []) (.int (-1)))
      , .assign "obj" (SExpr.ctxAction "declare_output" [.format "{}.o" [.var "base_name"]] [])
      , .assign "hi" (SExpr.ctxAction "declare_output" [.format "{}.hi" [.var "base_name"]] [])
      , .assign "cmd" (.call (.var "cmd_args") [.list [.var "ghc"]] [])
      , .expr (.methodCall (.var "cmd") "add" [.str "-c", .str "-package-env=-", .str "-fPIC"] [])
      , .ifStmt [(.var "package_db", [
          .expr (.methodCall (.var "cmd") "add" [.str "-package-db", .var "package_db"] [])
        ])] []
      , .expr (.methodCall (.var "cmd") "add" [.str "-stubdir", .methodCall (.var "stub_dir") "as_output" [] []] [])
      , .expr (.methodCall (.var "cmd") "add" [.str "-o", .methodCall (.var "obj") "as_output" [] []] [])
      , .expr (.methodCall (.var "cmd") "add" [.str "-ohi", .methodCall (.var "hi") "as_output" [] []] [])
      , .expr (.methodCall (.var "cmd") "add" [.var "MANDATORY_GHC_FLAGS"] [])
      , .expr (.methodCall (.var "cmd") "add" [.str "-XGHC2024", .str "-XForeignFunctionInterface"] [])
      , .forStmt "ext" (SExpr.ctxAttr "language_extensions") [
          .expr (.methodCall (.var "cmd") "add" [.format "-X{}" [.var "ext"]] [])
        ]
      , .expr (.methodCall (.var "cmd") "add" [SExpr.ctxAttr "ghc_options"] [])
      , .forStmt "hi_d" (.var "dep_hi_dirs") [
          .expr (.methodCall (.var "cmd") "add"
            [.call (.var "cmd_args") [.str "-i", .var "hi_d"] [("delimiter", .str "")]] [])
        ]
      , .forStmt "pkg" (SExpr.ctxAttr "packages") [
          .expr (.methodCall (.var "cmd") "add" [.str "-package", .var "pkg"] [])
        ]
      , .expr (.methodCall (.var "cmd") "add" [.var "src"] [])
      , .expr (SExpr.ctxAction "run" [.var "cmd"]
          [("category", .str "haskell_compile"), ("identifier", .var "src_path")])
      , .expr (.methodCall (.var "objects") "append" [.var "obj"] [])
      , .expr (.methodCall (.var "hi_files") "append" [.var "hi"] [])
      ])] []
    ]
  , .blank
  , .ifStmt [(.unop "not" (.var "objects"), [.ret (.list [SExpr.defaultInfo])])] []
  , .blank
  , .comment "Archive objects"
  , .assign "ar_cmd" (.call (.var "cmd_args") [.str "ar", .str "rcs", .methodCall (.var "lib") "as_output" [] []] [])
  , .expr (.methodCall (.var "ar_cmd") "add" [.var "objects"] [])
  , .expr (SExpr.ctxAction "run" [.var "ar_cmd"]
      [("category", .str "haskell_archive"), ("identifier", SExpr.ctxAttr "name")])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "lib")],
      .call (.var "HaskellIncludeInfo") [] [("include_dirs", .list [.var "stub_dir"])],
      .call (.var "HaskellLibraryInfo") [] [
        ("package_name", SExpr.ctxAttr "name"),
        ("hi_dir", .none),
        ("object_dir", .var "lib"),
        ("stub_dir", .var "stub_dir"),
        ("objects", .var "objects"),
        ("modules", .list [])]
    ]) ]

private def hsFFIBinaryBody : List SStmt :=
  [ .assign "ghc" (.call (.var "_get_ghc") [] [])
  , .assign "cxx" (SExpr.readConfig "cxx" "cxx" (.str "clang++"))
  , .assign "gcc_include" (SExpr.readConfig "cxx" "gcc_include" (.str ""))
  , .assign "gcc_include_arch" (SExpr.readConfig "cxx" "gcc_include_arch" (.str ""))
  , .assign "glibc_include" (SExpr.readConfig "cxx" "glibc_include" (.str ""))
  , .assign "clang_resource_dir" (SExpr.readConfig "cxx" "clang_resource_dir" (.str ""))
  , .assign "gcc_lib_base" (SExpr.readConfig "cxx" "gcc_lib_base" (.str ""))
  , .assign "out" (SExpr.ctxAction "declare_output" [SExpr.ctxAttr "name"] [])
  , .blank
  , .comment "Compile C++ sources"
  , .assign "cxx_compile_flags" (.list [.str "-std=c++17", .str "-O2", .str "-fPIC", .str "-c"])
  , .ifStmt [(.var "gcc_include", [
      .expr (.methodCall (.var "cxx_compile_flags") "extend" [.list [.str "-isystem", .var "gcc_include"]] [])
    ])] []
  , .ifStmt [(.var "gcc_include_arch", [
      .expr (.methodCall (.var "cxx_compile_flags") "extend" [.list [.str "-isystem", .var "gcc_include_arch"]] [])
    ])] []
  , .ifStmt [(.var "glibc_include", [
      .expr (.methodCall (.var "cxx_compile_flags") "extend" [.list [.str "-isystem", .var "glibc_include"]] [])
    ])] []
  , .ifStmt [(.var "clang_resource_dir", [
      .expr (.methodCall (.var "cxx_compile_flags") "extend" [.list [.binop "+" (.str "-resource-dir=") (.var "clang_resource_dir")]] [])
    ])] []
  , .expr (.methodCall (.var "cxx_compile_flags") "extend" [.list [.str "-I", .str "."]] [])
  , .forStmt "inc_dir" (SExpr.ctxAttr "include_dirs") [
      .expr (.methodCall (.var "cxx_compile_flags") "extend" [.list [.str "-I", .var "inc_dir"]] [])
    ]
  , .blank
  , .assign "cxx_objects" (.list [])
  , .forStmt "src" (SExpr.ctxAttr "cxx_srcs") [
      .assign "obj_name" (.methodCall (.methodCall (.dot (.var "src") "short_path") "replace" [.str ".cpp", .str ".o"] []) "replace" [.str ".c", .str ".o"] [])
    , .assign "obj" (SExpr.ctxAction "declare_output" [.var "obj_name"] [])
    , .assign "cmd" (.call (.var "cmd_args") [.binop "+" (.list [.var "cxx"]) (.binop "+" (.var "cxx_compile_flags") (.list [.str "-o", .methodCall (.var "obj") "as_output" [] [], .var "src"]))] [])
    , .expr (SExpr.ctxAction "run" [.var "cmd"]
        [("category", .str "cxx_compile"), ("identifier", .dot (.var "src") "short_path")])
    , .expr (.methodCall (.var "cxx_objects") "append" [.var "obj"] [])
    ]
  , .blank
  , .comment "Compile Haskell and link with C++ objects"
  , .assign "obj_dir" (SExpr.ctxAction "declare_output" [.str "hs_objs"] [("dir", .bool true)])
  , .assign "hi_dir" (SExpr.ctxAction "declare_output" [.str "hs_hi"] [("dir", .bool true)])
  , .assign "ghc_cmd" (.call (.var "cmd_args") [.list [.var "ghc"]] [])
  , .ifStmt [(SExpr.ctxAttr "ghc_options", [
      .expr (.methodCall (.var "ghc_cmd") "add" [SExpr.ctxAttr "ghc_options"] [])
    ])] [
      .expr (.methodCall (.var "ghc_cmd") "add" [.str "-O2", .str "-threaded"] [])
    ]
  , .expr (.methodCall (.var "ghc_cmd") "add" [.str "-odir", .methodCall (.var "obj_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "ghc_cmd") "add" [.str "-hidir", .methodCall (.var "hi_dir") "as_output" [] []] [])
  , .expr (.methodCall (.var "ghc_cmd") "add" [.var "MANDATORY_GHC_FLAGS"] [])
  , .expr (.methodCall (.var "ghc_cmd") "add" [.str "-XGHC2024"] [])
  , .forStmt "inc_dir" (SExpr.ctxAttr "include_dirs") [
      .ifStmt [(.var "inc_dir", [
        .expr (.methodCall (.var "ghc_cmd") "add" [.str "-optc", .binop "+" (.str "-I") (.var "inc_dir")] [])
      ])] []
    ]
  , .ifStmt [(.var "gcc_lib_base", [
      .expr (.methodCall (.var "ghc_cmd") "add" [.str "-optl", .binop "+" (.str "-L") (.var "gcc_lib_base")] [])
    ])] []
  , .forStmt "lib_dir" (SExpr.ctxAttr "extra_lib_dirs") [
      .ifStmt [(.var "lib_dir", [
        .expr (.methodCall (.var "ghc_cmd") "add" [.str "-optl", .binop "+" (.str "-L") (.var "lib_dir")] [])
      ])] []
    ]
  , .forStmt "lib" (SExpr.ctxAttr "extra_libs") [
      .expr (.methodCall (.var "ghc_cmd") "add" [.binop "+" (.str "-l") (.var "lib")] [])
    ]
  , .expr (.methodCall (.var "ghc_cmd") "add" [.str "-lstdc++"] [])
  , .expr (.methodCall (.var "ghc_cmd") "add" [.str "-o", .methodCall (.var "out") "as_output" [] []] [])
  , .forStmt "ext" (SExpr.ctxAttr "language_extensions") [
      .expr (.methodCall (.var "ghc_cmd") "add" [.format "-X{}" [.var "ext"]] [])
    ]
  , .expr (.methodCall (.var "ghc_cmd") "add" [SExpr.ctxAttr "compiler_flags"] [])
  , .expr (.methodCall (.var "ghc_cmd") "add" [SExpr.ctxAttr "hs_srcs"] [])
  , .expr (.methodCall (.var "ghc_cmd") "add" [.var "cxx_objects"] [])
  , .expr (SExpr.ctxAction "run" [.var "ghc_cmd"]
      [("category", .str "ghc_link"), ("identifier", SExpr.ctxAttr "name")])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "out")],
      .call (.var "RunInfo") [] [("args", .list [.var "out"])]
    ]) ]

private def hsRuleAttrs : List (String × SExpr) :=
  [ ("srcs", .raw "attrs.list(attrs.source())")
  , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
  , ("main", .raw "attrs.option(attrs.string(), default = None)")
  , ("packages", .raw "attrs.list(attrs.string(), default = [])")
  , ("ghc_options", .raw "attrs.list(attrs.string(), default = [])")
  , ("language_extensions", .raw "attrs.list(attrs.string(), default = [])")
  , ("compiler_flags", .raw "attrs.list(attrs.string(), default = [])") ]

def haskellSFile : SFile :=
  { header := "# toolchains/haskell.bzl — generated by continuity\n#\n# Haskell toolchain + rules. Builder → AST → Render."
  , items := [
      .load "@prelude//haskell:toolchain.bzl" ["HaskellToolchainInfo", "HaskellPlatformInfo"]
    , .blank
    , .globalAssign "MANDATORY_GHC_FLAGS" (.list [.str "-Wall", .str "-Werror"])
    , .blank
    , .funcDef "_get_ghc" [] (some "str") (some "Get GHC from config.")
        [.ret (SExpr.readConfig "haskell" "ghc" (.str "bin/ghc"))]
    , .funcDef "_get_ghc_pkg" [] (some "str") (some "Get ghc-pkg from config.")
        [.ret (SExpr.readConfig "haskell" "ghc_pkg" (.str "bin/ghc-pkg"))]
    , .funcDef "_get_package_db" [] (some "str | None") (some "Get global package DB.")
        [.ret (SExpr.readConfigOpt "haskell" "global_package_db")]
    , .blank
    , .provider "HaskellLibraryInfo"
        [("package_name", "str"),
         ("hi_dir", "Artifact | None, default = None"),
         ("object_dir", "Artifact | None, default = None"),
         ("stub_dir", "Artifact | None, default = None"),
         ("hie_dir", "Artifact | None, default = None"),
         ("objects", "list, default = []"),
         ("modules", "list, default = []")]
    , .provider "HaskellIncludeInfo"
        [("include_dirs", "list, default = []")]
    , .blank
    -- haskell_toolchain
    , .funcDef "_haskell_toolchain_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Haskell toolchain with paths from .buckconfig.local.")
        hsToolchainBody
    , .ruleDef "haskell_toolchain" "_haskell_toolchain_impl" true
        [ ("compiler_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("linker_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("ghci_script_template", .raw "attrs.option(attrs.source(), default = None)")
        , ("ghci_iserv_template", .raw "attrs.option(attrs.source(), default = None)")
        , ("script_template_processor", .raw "attrs.option(attrs.exec_dep(providers = [RunInfo]), default = None)") ]
    , .blank
    -- haskell_library
    , .funcDef "_haskell_library_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a Haskell library (.hi + .o + archive).")
        hsLibraryBody
    , .ruleDef "haskell_library" "_haskell_library_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source(), default = [])")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
        , ("packages", .raw "attrs.list(attrs.string(), default = [])")
        , ("ghc_options", .raw "attrs.list(attrs.string(), default = [])")
        , ("language_extensions", .raw "attrs.list(attrs.string(), default = [])") ]
    , .blank
    -- haskell_binary
    , .funcDef "_haskell_binary_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a Haskell executable.")
        hsBinaryBody
    , .ruleDef "haskell_binary" "_haskell_binary_impl" false hsRuleAttrs
    , .blank
    -- haskell_c_library (FFI exports for C consumers)
    , .funcDef "_haskell_c_library_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a C-callable library from Haskell with foreign exports.")
        hsCLibraryBody
    , .ruleDef "haskell_c_library" "_haskell_c_library_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source(), default = [])")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
        , ("packages", .raw "attrs.list(attrs.string(), default = [\"base\"])")
        , ("ghc_options", .raw "attrs.list(attrs.string(), default = [])")
        , ("language_extensions", .raw "attrs.list(attrs.string(), default = [])") ]
    , .blank
    -- haskell_ffi_binary (Haskell calling C/C++)
    , .funcDef "_haskell_ffi_binary_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a Haskell binary that calls C/C++ via FFI.")
        hsFFIBinaryBody
    , .ruleDef "haskell_ffi_binary" "_haskell_ffi_binary_impl" false
        [ ("hs_srcs", .raw "attrs.list(attrs.source())")
        , ("cxx_srcs", .raw "attrs.list(attrs.source(), default = [])")
        , ("cxx_headers", .raw "attrs.list(attrs.source(), default = [])")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])")
        , ("packages", .raw "attrs.list(attrs.string(), default = [])")
        , ("ghc_options", .raw "attrs.list(attrs.string(), default = [])")
        , ("extra_libs", .raw "attrs.list(attrs.string(), default = [])")
        , ("extra_lib_dirs", .raw "attrs.list(attrs.string(), default = [])")
        , ("include_dirs", .raw "attrs.list(attrs.string(), default = [])")
        , ("compiler_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("language_extensions", .raw "attrs.list(attrs.string(), default = [])") ]
    , .blank
    -- haskell_script
    , .funcDef "_haskell_script_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build a single-file Haskell script.")
        hsScriptBody
    , .ruleDef "haskell_script" "_haskell_script_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source())")
        , ("include_paths", .raw "attrs.list(attrs.string(), default = [])")
        , ("compiler_flags", .raw "attrs.list(attrs.string(), default = [])")
        , ("packages", .raw "attrs.list(attrs.string(), default = [])") ]
    , .blank
    -- haskell_test (reuses binary impl)
    , .ruleDef "haskell_test" "_haskell_binary_impl" false
        (hsRuleAttrs.map fun (k, v) =>
          if k == "packages" then ("packages", .raw "attrs.list(attrs.string(), default = [\"base\"])")
          else (k, v))
    ] }

#eval (renderSFile haskellSFile).length


/- ════════════════════════════════════════════════════════════════════════════════
                                              // nv.bzl (AST-based)
   ════════════════════════════════════════════════════════════════════════════════ -/

private def nvToolchainBody : List SStmt :=
  [ .assign "nvidia_sdk_path" (SExpr.readConfig "nv" "nvidia_sdk_path" (SExpr.ctxAttr "nvidia_sdk_path"))
  , .assign "nvidia_sdk_include" (SExpr.readConfig "nv" "nvidia_sdk_include" (SExpr.ctxAttr "nvidia_sdk_include"))
  , .assign "nvidia_sdk_lib" (SExpr.readConfig "nv" "nvidia_sdk_lib" (SExpr.ctxAttr "nvidia_sdk_lib"))
  , .blank
  , .ret (.list [
      SExpr.defaultInfo,
      .call (.var "NvToolchainInfo") [] [
        ("nvidia_sdk_path", .var "nvidia_sdk_path"),
        ("nvidia_sdk_include", .var "nvidia_sdk_include"),
        ("nvidia_sdk_lib", .var "nvidia_sdk_lib"),
        ("nv_archs", SExpr.ctxAttr "nv_archs") ] ]) ]

/-- Config reads shared by nv_binary and nv_library. -/
private def nvConfigReads : List SStmt :=
  [ .comment "Validate CUDA toolchain"
  , .assign "clang" (SExpr.readConfigOpt "nv" "clang")
  , .ifStmt [(.cmp "==" (.var "clang") .none, [
      .expr (.call (.var "fail") [.strBlock
        "\nNVIDIA toolchain not configured.\nEnable CUDA in your flake:\n    continuity.toolchains.cuda = true;\nThen: direnv reload\n"] [])
    ])] []
  , .assign "nvidia_sdk_path" (SExpr.readConfig "nv" "nvidia_sdk_path" (.str "/usr/local/cuda"))
  , .assign "nvidia_sdk_include" (SExpr.readConfig "nv" "nvidia_sdk_include" (.str "/usr/local/cuda/include"))
  , .assign "nvidia_sdk_lib" (SExpr.readConfig "nv" "nvidia_sdk_lib" (.str "/usr/local/cuda/lib64"))
  , .assign "ptxas" (SExpr.readConfig "nv" "ptxas" (.str ""))
  , .assign "gcc_include" (SExpr.readConfig "cxx" "gcc_include" (.str ""))
  , .assign "gcc_include_arch" (SExpr.readConfig "cxx" "gcc_include_arch" (.str ""))
  , .assign "glibc_include" (SExpr.readConfig "cxx" "glibc_include" (.str ""))
  , .assign "clang_resource_dir" (SExpr.readConfig "cxx" "clang_resource_dir" (.str ""))
  , .assign "nv_archs_str" (SExpr.readConfig "nv" "archs" (.str "sm_90"))
  , .assign "nv_archs" (.methodCall (.var "nv_archs_str") "split" [.str ","] [])
  ]

/-- Compile flags construction shared by nv_binary and nv_library. -/
private def nvCompileFlags (std : String) : List SStmt :=
  [ .assign "compile_flags" (.list [
      .str "-x", .str "cuda",
      .binop "+" (.str "--cuda-path=") (.var "nvidia_sdk_path"),
      .str "-isystem", .var "nvidia_sdk_include",
      .str s!"-std={std}", .str "-c"])
  , .ifStmt [(.var "ptxas", [
      .expr (.methodCall (.var "compile_flags") "extend"
        [.list [.binop "+" (.str "--ptxas-path=") (.var "ptxas")]] [])
    ])] []
  , .forStmt "arch" (.var "nv_archs") [
      .expr (.methodCall (.var "compile_flags") "extend"
        [.list [.binop "+" (.str "--cuda-gpu-arch=") (.methodCall (.var "arch") "strip" [] [])]] [])
    , .expr (.methodCall (.var "compile_flags") "extend"
        [.list [.binop "+" (.str "--cuda-include-ptx=") (.methodCall (.var "arch") "strip" [] [])]] [])
    ]
  , .ifStmt [(.var "clang_resource_dir", [
      .expr (.methodCall (.var "compile_flags") "extend"
        [.list [.binop "+" (.str "-resource-dir=") (.var "clang_resource_dir")]] [])
    ])] []
  , .ifStmt [(.var "gcc_include", [
      .expr (.methodCall (.var "compile_flags") "extend" [.list [.str "-isystem", .var "gcc_include"]] [])
    ])] []
  , .ifStmt [(.var "gcc_include_arch", [
      .expr (.methodCall (.var "compile_flags") "extend" [.list [.str "-isystem", .var "gcc_include_arch"]] [])
    ])] []
  , .ifStmt [(.var "glibc_include", [
      .expr (.methodCall (.var "compile_flags") "extend" [.list [.str "-isystem", .var "glibc_include"]] [])
    ])] []
  ]

/-- Compile loop: compile each source to .o -/
private def nvCompileLoop : List SStmt :=
  [ .assign "objects" (.list [])
  , .forStmt "src" (SExpr.ctxAttr "srcs") [
      .assign "obj_name" (.methodCall (.methodCall (.dot (.var "src") "short_path") "replace" [.str ".cu", .str ".o"] []) "replace" [.str ".cpp", .str ".o"] [])
    , .assign "obj" (SExpr.ctxAction "declare_output" [.var "obj_name"] [])
    , .assign "cmd" (.call (.var "cmd_args") [.binop "+" (.list [.var "clang"]) (.binop "+" (.var "compile_flags") (.list [.str "-o", .methodCall (.var "obj") "as_output" [] [], .var "src"]))] [])
    , .expr (SExpr.ctxAction "run" [.var "cmd"]
        [("category", .str "nv_compile"), ("identifier", .dot (.var "src") "short_path")])
    , .expr (.methodCall (.var "objects") "append" [.var "obj"] [])
    ]
  ]

private def nvBinaryBody : List SStmt :=
  nvConfigReads ++
  [ .assign "gcc_lib" (SExpr.readConfig "cxx" "gcc_lib" (.str ""))
  , .assign "gcc_lib_base" (SExpr.readConfig "cxx" "gcc_lib_base" (.str ""))
  , .assign "glibc_lib" (SExpr.readConfig "cxx" "glibc_lib" (.str ""))
  , .assign "ld" (SExpr.readConfig "cxx" "ld" (.str "ld.lld"))
  , .assign "mdspan_include" (SExpr.readConfig "nv" "mdspan_include" (.str ""))
  , .blank
  ] ++ nvCompileFlags "c++23" ++
  [ .expr (.methodCall (.var "compile_flags") "append" [.str "-Wno-unknown-cuda-version"] [])
  , .ifStmt [(.var "mdspan_include", [
      .expr (.methodCall (.var "compile_flags") "extend" [.list [.str "-isystem", .var "mdspan_include"]] [])
    ])] []
  , .blank
  ] ++ nvCompileLoop ++
  [ .blank
  , .comment "Link"
  , .assign "link_flags" (.list [
      .binop "+" (.str "-fuse-ld=") (.var "ld"),
      .binop "+" (.str "-L") (.var "nvidia_sdk_lib"),
      .binop "+" (.str "-Wl,-rpath,") (.var "nvidia_sdk_lib"),
      .str "-lcudart"])
  , .ifStmt [(.var "gcc_lib", [
      .expr (.methodCall (.var "link_flags") "extend"
        [.list [.binop "+" (.str "-B") (.var "gcc_lib"), .binop "+" (.str "-L") (.var "gcc_lib")]] [])
    ])] []
  , .ifStmt [(.var "gcc_lib_base", [
      .expr (.methodCall (.var "link_flags") "extend"
        [.list [.binop "+" (.str "-L") (.var "gcc_lib_base"), .binop "+" (.str "-Wl,-rpath,") (.var "gcc_lib_base")]] [])
    ])] []
  , .ifStmt [(.var "glibc_lib", [
      .expr (.methodCall (.var "link_flags") "extend"
        [.list [.binop "+" (.str "-B") (.var "glibc_lib"),
                .binop "+" (.str "-L") (.var "glibc_lib"),
                .binop "+" (.str "-Wl,-rpath,") (.var "glibc_lib"),
                .binop "+" (.binop "+" (.str "-Wl,--dynamic-linker=") (.var "glibc_lib")) (.str "/ld-linux-x86-64.so.2")]] [])
    ])] []
  , .assign "out" (SExpr.ctxAction "declare_output" [SExpr.ctxAttr "name"] [])
  , .assign "link_cmd" (.call (.var "cmd_args") [
      .binop "+" (.list [.var "clang"]) (.binop "+" (.var "link_flags")
        (.list [.str "-o", .methodCall (.var "out") "as_output" [] []]))] [])
  , .expr (.methodCall (.var "link_cmd") "add" [.var "objects"] [])
  , .expr (SExpr.ctxAction "run" [.var "link_cmd"]
      [("category", .str "nv_link"), ("identifier", SExpr.ctxAttr "name")])
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [("default_output", .var "out")],
      .call (.var "RunInfo") [] [("args", .call (.var "cmd_args") [.list [.var "out"]] [])]
    ]) ]

private def nvLibraryBody : List SStmt :=
  nvConfigReads ++ [.blank]
  ++ nvCompileFlags "c++17" ++
  [ .expr (.methodCall (.var "compile_flags") "append" [.str "-fPIC"] [])
  , .blank
  ] ++ nvCompileLoop ++
  [ .blank
  , .assign "include_dir" (.str "")
  , .ifStmt [(SExpr.ctxAttr "exported_headers", [
      .assign "first_header" (.index (SExpr.ctxAttr "exported_headers") (.int 0))
    , .ifStmt [(.cmp "in" (.str "/") (.dot (.var "first_header") "short_path"), [
        .assign "include_dir" (.index (.methodCall (.dot (.var "first_header") "short_path") "rsplit" [.str "/", .int 1] []) (.int 0))
      ])] [
        .assign "include_dir" (.str ".")
      ]
    ])] []
  , .blank
  , .ret (.list [
      .call (.var "DefaultInfo") [] [
        ("default_output", .ternary (.index (.var "objects") (.int 0)) (.var "objects") .none),
        ("other_outputs", .ternary
          (.raw "objects[1:]")
          (.cmp ">" (.call (.var "len") [.var "objects"] []) (.int 1))
          (.list []))],
      .call (.var "NvLibraryInfo") [] [
        ("objects", .var "objects"),
        ("headers", SExpr.ctxAttr "exported_headers"),
        ("include_dir", .var "include_dir")]
    ]) ]

def nvSFile : SFile :=
  { header := "# toolchains/nv.bzl — generated by continuity\n#\n# NVIDIA toolchain using clang (NOT nvcc). Builder → AST → Render.\n# \"nv\" not \"cuda\" — explicit about the target hardware."
  , items := [
      .provider "NvToolchainInfo"
        [("nvidia_sdk_path", "str"), ("nvidia_sdk_include", "str"),
         ("nvidia_sdk_lib", "str"), ("nv_archs", "list[str]")]
    , .blank
    , .funcDef "_nv_toolchain_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "NVIDIA toolchain with paths from .buckconfig.local.")
        nvToolchainBody
    , .ruleDef "nv_toolchain" "_nv_toolchain_impl" true
        [ ("nv_archs", .raw "attrs.list(attrs.string(), default = [\"sm_90\"])")
        , ("nvidia_sdk_path", .raw "attrs.string(default = \"/usr/local/cuda\")")
        , ("nvidia_sdk_include", .raw "attrs.string(default = \"/usr/local/cuda/include\")")
        , ("nvidia_sdk_lib", .raw "attrs.string(default = \"/usr/local/cuda/lib64\")") ]
    , .blank
    , .funcDef "_nv_binary_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Build an NVIDIA binary using clang (NOT nvcc).")
        nvBinaryBody
    , .ruleDef "nv_binary" "_nv_binary_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source())")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])") ]
    , .blank
    , .provider "NvLibraryInfo"
        [("objects", "list"), ("headers", "list"), ("include_dir", "str")]
    , .funcDef "_nv_library_impl"
        [⟨"ctx", some "AnalysisContext", none⟩]
        (some "list[Provider]")
        (some "Compile CUDA sources into object files.")
        nvLibraryBody
    , .ruleDef "nv_library" "_nv_library_impl" false
        [ ("srcs", .raw "attrs.list(attrs.source())")
        , ("exported_headers", .raw "attrs.list(attrs.source(), default = [])")
        , ("deps", .raw "attrs.list(attrs.dep(), default = [])") ]
    ] }

#eval (renderSFile nvSFile).length

/- ════════════════════════════════════════════════════════════════════════════════
                                                       // all .bzl files
   ════════════════════════════════════════════════════════════════════════════════ -/

def bzlFiles : List (String × String) :=
  [ ("toolchains/cxx.bzl", renderBzlFile cxxBzl)
  , ("toolchains/lean.bzl", renderSFile leanSFile)
  , ("toolchains/rust.bzl", renderSFile rustSFile)
  , ("toolchains/haskell.bzl", renderSFile haskellSFile)
  , ("toolchains/nv.bzl", renderSFile nvSFile)
  ]

end Continuity.Codegen.Build.BzlDefs
