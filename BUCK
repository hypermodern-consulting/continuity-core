load("@toolchains//:lean.bzl", "lean_binary", "lean_library")

lean_library(
    name = "continuity-lib",
    srcs = [
        # ── leaf types (no internal imports) ──────────────────────────
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
        "Continuity/Build/Library.lean",
        "Continuity/Algebra/Grade.lean",
        "Continuity/Algebra/GradedMonad.lean",
        "Continuity/Crypto.lean",
        "Continuity/Crypto/SHA256.lean",
        "Continuity/StateMachine.lean",
        "Continuity/CAS.lean",
        "Continuity/NAR.lean",
        "Continuity/Derivation.lean",
        "Continuity/REAPI.lean",

        # ── codec layer ───────────────────────────────────────────────
        "Continuity/Codec/Box.lean",
        "Continuity/Codec/Scanner.lean",
        "Continuity/Codec/Parser.lean",
        "Continuity/Codec/Bytes.lean",
        "Continuity/Codec/Guards.lean",
        "Continuity/Codec/Varint.lean",
        "Continuity/Codec/Protocol.lean",
        "Continuity/Codec/Limits.lean",
        "Continuity/Codec/Nix.lean",
        "Continuity/Codec/Protobuf.lean",
        "Continuity/Codec/Git.lean",
        "Continuity/Codec/GitTransport.lean",
        "Continuity/Codec/Http.lean",
        "Continuity/Codec/Http2.lean",
        "Continuity/Codec/Http3.lean",
        "Continuity/Codec/Zmtp.lean",
        "Continuity/Codec/Saml.lean",
        "Continuity/Codec/EVM.lean",
        "Continuity/Codec/Json.lean",
        "Continuity/Codec/Dhall/Lexer.lean",
        "Continuity/Codec/Dhall/Parser.lean",

        # ── emit ASTs (depend on Build types) ─────────────────────────
        "Continuity/Emit/Dhall/Ast.lean",
        "Continuity/Emit/Haskell/Ast.lean",
        "Continuity/Emit/Cpp/Ast.lean",
        "Continuity/Emit/Starlark/Ast.lean",

        # ── emit renderers (depend on ASTs + Build) ───────────────────
        "Continuity/Emit/Dhall/Render.lean",
        "Continuity/Emit/Dhall/Build.lean",
        "Continuity/Emit/Haskell/Render.lean",
        "Continuity/Emit/Haskell/Build.lean",
        "Continuity/Emit/Cpp/Render.lean",
        "Continuity/Emit/Cpp/Build.lean",
        "Continuity/Emit/Starlark/Render.lean",

        # ── codegen (depend on everything) ────────────────────────────
        "Continuity/InitBuck2.lean",
        "Continuity/Codegen/Build/ToDhall.lean",
        "Continuity/Codegen/Build/ToStarlark.lean",
        "Continuity/Codegen/Build/BzlDefs.lean",
        "Continuity/Codegen/Effect.lean",
        "Continuity/Codegen/Codec/Spec.lean",
        "Continuity/Codegen/Codec/ToCpp.lean",
        "Continuity/Codegen/Codec/ToHaskell.lean",
    ],
    deps = [],
)

lean_binary(
    name = "continuity",
    srcs = ["Continuity/Main.lean"],
    deps = [":continuity-lib"],
)
