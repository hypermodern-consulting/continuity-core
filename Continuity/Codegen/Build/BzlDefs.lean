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

def bzlFiles : List (String × String) :=
  [ ("toolchains/cxx.bzl", renderBzlFile cxxBzl)
  ]

end Continuity.Codegen.Build.BzlDefs
