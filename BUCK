load("@toolchains//:lean.bzl", "lean_library", "lean_binary")

lean_library(
    name = "continuity-lib",
    srcs = [
        # Emit (no internal deps)
        "Continuity/Emit/Dhall/Ast.lean",
        "Continuity/Emit/Dhall/Render.lean",
        "Continuity/Emit/Dhall/Build.lean",
        "Continuity/Emit/Haskell/Ast.lean",
        "Continuity/Emit/Haskell/Render.lean",
        "Continuity/Emit/Haskell/Build.lean",
        "Continuity/Emit/Cpp/Ast.lean",
        "Continuity/Emit/Cpp/Render.lean",
        "Continuity/Emit/Cpp/Build.lean",
        # Codec
        "Continuity/Codec/Box.lean",
        "Continuity/Codec/Scanner.lean",
        "Continuity/Codec/Parser.lean",
        "Continuity/Codec/Dhall/Lexer.lean",
        "Continuity/Codec/Dhall/Parser.lean",
        # Build (leaves first)
        "Continuity/Build/Triple.lean",
        "Continuity/Build/Dep.lean",
        "Continuity/Build/Vis.lean",
        "Continuity/Build/Resource.lean",
        "Continuity/Build/Digest.lean",
        "Continuity/Build/Command.lean",
        "Continuity/Build/Action.lean",
        "Continuity/Build/Toolchain.lean",
        "Continuity/Build/Cxx.lean",
        "Continuity/Build/Haskell.lean",
        "Continuity/Build/Rust.lean",
        "Continuity/Build/Lean4.lean",
        "Continuity/Build/Nv.lean",
        "Continuity/Build/Genrule.lean",
        "Continuity/Build/Rule.lean",
        "Continuity/Build/BzlFile.lean",
        # Codegen (depends on Emit + Build)
        "Continuity/Codegen/Build/ToDhall.lean",
    ],
    deps = [],
)

lean_binary(
    name = "continuity",
    srcs = ["Continuity/Main.lean"],
    deps = [":continuity-lib"],
)
