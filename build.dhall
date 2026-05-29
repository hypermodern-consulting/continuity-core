let C = ./.continuity-prelude/package.dhall
let R = ./.continuity-prelude/render/buck2/package.dhall
let Lean = ./.continuity-prelude/render/buck2/toolchains/lean.dhall
let Exec = ./.continuity-prelude/render/buck2/toolchains/execution.dhall

let lib =
      C.lang.Lean.library
        "continuity-lib"
        [ "Continuity/Emit/Dhall/Ast.lean"
        , "Continuity/Emit/Dhall/Render.lean"
        , "Continuity/Emit/Dhall/Build.lean"
        , "Continuity/Emit/Haskell/Ast.lean"
        , "Continuity/Emit/Haskell/Render.lean"
        , "Continuity/Emit/Haskell/Build.lean"
        , "Continuity/Emit/Cpp/Ast.lean"
        , "Continuity/Emit/Cpp/Render.lean"
        , "Continuity/Emit/Cpp/Build.lean"
        , "Continuity/Codec/Box.lean"
        , "Continuity/Codec/Scanner.lean"
        , "Continuity/Codec/Parser.lean"
        , "Continuity/Codec/Dhall/Lexer.lean"
        , "Continuity/Codec/Dhall/Parser.lean"
        , "Continuity/Build/Triple.lean"
        , "Continuity/Build/Dep.lean"
        , "Continuity/Build/Vis.lean"
        , "Continuity/Build/Resource.lean"
        , "Continuity/Build/Digest.lean"
        , "Continuity/Build/Command.lean"
        , "Continuity/Build/Action.lean"
        , "Continuity/Build/Toolchain.lean"
        , "Continuity/Build/Cxx.lean"
        , "Continuity/Build/Haskell.lean"
        , "Continuity/Build/Rust.lean"
        , "Continuity/Build/Lean4.lean"
        , "Continuity/Build/Nv.lean"
        , "Continuity/Build/Genrule.lean"
        , "Continuity/Build/Rule.lean"
        , "Continuity/Build/BzlFile.lean"
        , "Continuity/Codegen/Build/ToDhall.lean"
        ]
        ([] : List C.Dep)

let exe =
      C.lang.Lean.binary
        "continuity"
        [ "Continuity/Main.lean" ]
        [ C.dep.local ":continuity-lib" ]

in  { buck =
          R.renderRule (C.rule.leanLibrary lib)
        ++ "\n"
        ++ R.renderRule (C.rule.leanBinary exe)
    , toolchain_bzl = Lean.render
    , execution_bzl = Exec.render
    }
