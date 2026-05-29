-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--                                              // continuity // render // buck2
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--
--   "Turner watched the grid with the pale intensity of a man who
--    has seen the same strip of desert a hundred times."
--
--                                                                 — Count Zero
--

--| Buck2 Starlark renderer.
--|
--| This is the ONLY place that knows about Buck2 rule names,
--| Starlark syntax, or .bzl file conventions. The prelude types
--| flow in, Starlark text flows out.
--|
--| The circular dependency is broken here: the prelude never
--| imports this. This imports the prelude.

let P = ../../Prelude.dhall
let C  = ../../lang/Cxx.dhall
let Ru = ../../lang/Rust.dhall
let H  = ../../lang/Haskell.dhall
let L  = ../../lang/Lean.dhall
let N  = ../../lang/Nv.dhall
let PS = ../../lang/PureScript.dhall
let G  = ../../lang/Genrule.dhall
let NC = ../../lang/NixCxx.dhall
let RC = ../../lang/RustCrate.dhall
let D = ../../core/Dep.dhall
let V = ../../core/Vis.dhall
let TC = ../../build/Toolchain.dhall
let R = ../../build/Rule.dhall

-- ── starlark primitives ─────────────────────────────────────────────────

let q = \(t : Text) -> Text/show t

let list = \(xs : List Text) ->
    "[" ++ P.Text.concatSep ", " (P.List.map Text Text q xs) ++ "]"

let vis = \(v : V.Vis) -> merge { Public = "[\"PUBLIC\"]", Private = "[]" } v

let cxxStd = \(s : C.CxxStd) -> merge
    { Cxx11 = "-std=c++11", Cxx14 = "-std=c++14", Cxx17 = "-std=c++17"
    , Cxx20 = "-std=c++20", Cxx23 = "-std=c++23" } s

-- ── dep extraction ──────────────────────────────────────────────────────

let flakes
    : List D.Dep -> List Text
    = \(ds : List D.Dep) ->
        P.List.concatMap D.Dep Text
          (\(d : D.Dep) -> merge
            { Local    = \(_ : Text) -> [] : List Text
            , Flake    = \(r : Text) -> [r]
            , External = \(_ : { hash : Text, name : Text }) -> [] : List Text
            , PkgConfig = \(_ : Text) -> [] : List Text
            } d) ds

let locals
    : List D.Dep -> List Text
    = \(ds : List D.Dep) ->
        P.List.concatMap D.Dep Text
          (\(d : D.Dep) -> merge
            { Local    = \(t : Text) -> [t]
            , Flake    = \(_ : Text) -> [] : List Text
            , External = \(_ : { hash : Text, name : Text }) -> [] : List Text
            , PkgConfig = \(_ : Text) -> [] : List Text
            } d) ds

-- ── rule renderers ──────────────────────────────────────────────────────

let renderCxxBinary
    : C.Binary -> Text
    = \(b : C.Binary) ->
        let cf = [cxxStd b.std] # b.cflags
        in ''
        cxx_binary(
            name = ${q b.name},
            srcs = ${list b.srcs},
            deps = ${list (locals b.deps)},
            compiler_flags = ${list cf},
            linker_flags = ${list b.ldflags},
            visibility = ${vis b.vis},
        )
        ''

let renderCxxLibrary
    : C.Library -> Text
    = \(l : C.Library) ->
        let cf = [cxxStd l.std] # l.cflags
        in ''
        cxx_library(
            name = ${q l.name},
            srcs = ${list l.srcs},
            exported_headers = ${list l.hdrs},
            deps = ${list (locals l.deps)},
            compiler_flags = ${list cf},
            visibility = ${vis l.vis},
        )
        ''

let renderHaskellBinary
    : H.Binary -> Text
    = \(b : H.Binary) ->
        ''
        haskell_binary(
            name = ${q b.name},
            srcs = ${list b.srcs},
            main = ${q b.main},
            deps = ${list (locals b.deps)},
            compiler_flags = ${list b.ghcFlags},
            visibility = ${vis b.vis},
        )
        ''

let renderHaskellLibrary
    : H.Library -> Text
    = \(l : H.Library) ->
        ''
        haskell_library(
            name = ${q l.name},
            srcs = ${list l.srcs},
            deps = ${list (locals l.deps)},
            compiler_flags = ${list l.ghcFlags},
            visibility = ${vis l.vis},
        )
        ''

let renderLeanBinary
    : L.Binary -> Text
    = \(b : L.Binary) ->
        ''
        lean_binary(
            name = ${q b.name},
            srcs = ${list b.srcs},
            root = ${q b.root},
            deps = ${list (locals b.deps)},
            visibility = ${vis b.vis},
        )
        ''

let renderLeanLibrary
    : L.Library -> Text
    = \(l : L.Library) ->
        ''
        lean_library(
            name = ${q l.name},
            srcs = ${list l.srcs},
            root = ${q l.root},
            deps = ${list (locals l.deps)},
            visibility = ${vis l.vis},
        )
        ''

-- ── main renderer ───────────────────────────────────────────────────────

let renderRule
    : R.Rule -> Text
    = \(r : R.Rule) ->
        merge
          { CxxBinary        = renderCxxBinary
          , CxxLibrary       = renderCxxLibrary
          , HaskellBinary    = renderHaskellBinary
          , HaskellLibrary   = renderHaskellLibrary
          , HaskellFFIBinary = \(_ : H.FFIBinary) -> "# TODO: haskell_ffi_binary"
          , LeanBinary       = renderLeanBinary
          , LeanLibrary      = renderLeanLibrary
          , RustBinary       = \(b : Ru.Binary) ->
            let ef = merge { E2015 = "2015", E2018 = "2018", E2021 = "2021", E2024 = "2024" } b.edition
            in ''
            rust_binary(
                name = ${q b.name},
                srcs = ${list b.srcs},
                deps = ${list (locals b.deps)},
                edition = ${q ef},
                visibility = ${vis b.vis},
            )
            ''
          , RustLibrary      = \(b : Ru.Library) ->
            let ef = merge { E2015 = "2015", E2018 = "2018", E2021 = "2021", E2024 = "2024" } b.edition
            in ''
            rust_library(
                name = ${q b.name},
                srcs = ${list b.srcs},
                deps = ${list (locals b.deps)},
                edition = ${q ef},
                visibility = ${vis b.vis},
            )
            ''
          , NvBinary         = \(_ : N.Binary) -> "# TODO: nv_binary"
          , NvLibrary        = \(_ : N.Library) -> "# TODO: nv_library"
          , PureScriptApp    = \(_ : PS.App) -> "# TODO: purescript_app"
          , PureScriptBinary = \(_ : PS.Binary) -> "# TODO: purescript_binary"
          , PureScriptLibrary = \(_ : PS.Library) -> "# TODO: purescript_library"
          , Genrule          = \(g : G.Genrule) ->
            ''
            genrule(
                name = ${q g.name},
                out = ${q g.out},
                cmd = ${q g.cmd},
                srcs = ${list g.srcs},
                visibility = ${vis g.vis},
            )
            ''
          , NixCxxBinary     = \(_ : NC.NixBinary) -> "# TODO: nix_cxx_binary"
          , CratesIo         = \(_ : RC.CratesIo) -> "# TODO: crates_io"
          , HttpArchive      = \(_ : RC.HttpArchive) -> "# TODO: http_archive"
          }
          r

-- ── toolchain renderers ─────────────────────────────────────────────────

let renderCxxToolchain
    : TC.CxxToolchain -> Text
    = \(tc : TC.CxxToolchain) ->
        ''
        llvm_toolchain(
            name = ${q tc.name},
            c_extra_flags = ${list tc.c_extra_flags},
            cxx_extra_flags = ${list tc.cxx_extra_flags},
            link_style = ${q tc.link_style},
            visibility = ["PUBLIC"],
        )
        ''

let renderHaskellToolchain
    : TC.HaskellToolchain -> Text
    = \(tc : TC.HaskellToolchain) ->
        ''
        haskell_toolchain(
            name = ${q tc.name},
            compiler_flags = ${list tc.compiler_flags},
            visibility = ["PUBLIC"],
        )
        ''

let renderExecutionPlatform
    : TC.ExecutionPlatform -> Text
    = \(ep : TC.ExecutionPlatform) ->
        ''
        lre_execution_platform(
            name = ${q ep.name},
            local_enabled = ${if ep.local_enabled then "True" else "False"},
            remote_enabled = ${if ep.remote_enabled then "True" else "False"},
            visibility = ["PUBLIC"],
        )
        ''

in  { -- rule rendering
      renderRule
    , renderCxxBinary
    , renderCxxLibrary
    , renderHaskellBinary
    , renderHaskellLibrary
    , renderLeanBinary
    , renderLeanLibrary
      -- toolchain rendering
    , renderCxxToolchain
    , renderHaskellToolchain
    , renderExecutionPlatform
      -- utilities
    , flakes
    , locals
    }
