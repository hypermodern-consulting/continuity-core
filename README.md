# Continuity

Verified metaprogramming for secure computation.

Continuity models builds, emits code, and proves properties about both.
The output is C++, Haskell, and Dhall. The proofs are the point.

*Dedicated to Spencer James Reesman.*

## Setup

```
# Enter the dev shell (installs elan, pulls the lean toolchain)
nix develop

# Build
lake build

# Run
lake exe continuity
```

### Emacs

Install `lean4-mode` from MELPA or straight.el:

```elisp
(use-package lean4-mode
  :straight (lean4-mode :type git
             :host github
             :repo "leanprover-community/lean4-mode"
             :files ("*.el" "data"))
  :commands lean4-mode)
```

The `.dir-locals.el` handles project-level settings.
The language server starts automatically when you open a `.lean` file.
It will take a few seconds on first open while it elaborates imports.

## Architecture

```
Continuity/
│
├── Codec/                      ── THE TYPE LAYER ──
│   │                           Where Box lives. Proven combinators.
│   │                           Nothing here knows about C++ or Haskell.
│   │                           Nothing here knows about Nix or Git.
│   │
│   ├── Box.lean                The core: Box α with roundtrip + consumption.
│   │                           Parse, serialize, the proofs. This is the
│   │                           most important file in the project.
│   │
│   ├── Combinators.lean        seq, iso, lenPrefixed, padded, fixed.
│   │                           Each combinator preserves roundtrip by
│   │                           construction. No protocol-specific logic.
│   │
│   ├── Spec.lean               BoxSpec: the reified structure of a Box,
│   │                           proof terms erased. The reflection boundary.
│   │                           Box → BoxSpec is one direction only.
│   │
│   └── Properties.lean         Theorems about BoxSpec: wireSize additivity,
│                               iso preservation, alignment correctness.
│                               The propositions. No terms, no codegen.
│
├── Protocol/                   ── THE TERM LAYER ──
│   │                           Where wire formats are defined as BoxSpec
│   │                           instances. Each file is a protocol.
│   │                           These are the terms — concrete data.
│   │
│   ├── Nix.lean                Nix wire: nixString, storePath, pathInfo,
│   │                           derivation fields. The formats Continuity
│   │                           needs to speak to replace the Nix evaluator.
│   │
│   ├── NAR.lean                Nix Archive format. Fixed headers, padded
│   │                           strings, recursive directory entries.
│   │
│   ├── REAPI.lean              Remote Execution API: digest, findMissing,
│   │                           actionResult. The Bazel/Buck2 convergence
│   │                           point. Protobuf-on-wire.
│   │
│   ├── Git.lean                Pack format, object IDs, refs, upload-pack.
│   │                           What the CAS needs to fetch sources.
│   │
│   ├── Protobuf.lean           Varint, field tags, length-delimited.
│   │                           The wire encoding under gRPC and REAPI.
│   │
│   ├── GRPC.lean               Frame header (compressed flag + u32be length
│   │                           + payload). Thin layer over Protobuf.
│   │
│   ├── HTTP2.lean              HPACK frame header, settings, data payload.
│   │                           The transport under gRPC.
│   │
│   └── ZMTP.lean               ZeroMQ greeting + frame. The transport
│                               under the Nix daemon protocol.
│
├── CAS/                        ── THE STAR ──
│   │                           Content-Addressed Storage as a first-class
│   │                           algebraic object with theorems.
│   │
│   ├── Model.lean              structure CAS: put, get, hash.
│   │                           Axiom: hash injective (collision resistance).
│   │                           Theorem: put-then-get roundtrip.
│   │                           Theorem: deduplication (same content → same key).
│   │                           This is the Straylight CAS spec.
│   │
│   ├── Blob.lean               CASBlob codec: hash(32) + content(var).
│   │                           The on-wire representation.
│   │
│   └── Attestation.lean        Vouch entries, chain headers, hybrid sigs.
│                               How you prove a blob is what it claims.
│                               Capability certs live here.
│
├── Build/                      ── THE BUILD MODEL ──
│   │                           Not codecs. Data structures about computation.
│   │                           Triples, toolchains, rules, derivations.
│   │                           Dhall is the render target, not a codec peer.
│   │
│   ├── Triple.lean             Arch × Vendor × OS × ABI × CPU × GPU.
│   │                           The target description. Enumerated, finite.
│   │
│   ├── Toolchain.lean          CxxToolchain, HaskellToolchain, LeanToolchain,
│   │                           NvToolchain. Flags, paths, versions.
│   │
│   ├── Rule.lean               CxxLibrary, HaskellLibrary, Genrule.
│   │                           The build graph nodes. Each rule knows its
│   │                           inputs, outputs, deps, toolchain.
│   │
│   ├── Derivation.lean         The Nix derivation model. Inputs, builder,
│   │                           env, outputs. Content-addressed via CAS.
│   │                           Axioms: execute_derivation, output_content_addressed.
│   │
│   ├── Cache.lean              Toolchain equivalence as Quotient.
│   │                           Theorem: coset membership → cache hit valid.
│   │                           Isolation monotonicity.
│   │
│   └── Properties.lean         Build-level theorems. Derivation hash
│                               injectivity. Faithful extraction (Wadler).
│                               Parametricity of the build function.
│
├── Algebra/                    ── COEFFECTS ──
│   │                           The graded monad. What effects a computation
│   │                           requires and how they're discharged.
│   │
│   ├── Grade.lean              GradeLabel enum: net, fs, crypto, gpu, etc.
│   │                           GradeSet as Finset GradeLabel.
│   │                           Monoid instance (union).
│   │
│   └── GradedMonad.lean        The graded monad class. pure at identity,
│                               bind composes grades. Coeffect discharge
│                               theorem: all grades satisfied → safe to run.
│
├── Crypto/                     ── KERNEL-DISTANCE HASH ──
│   │
│   └── SHA256.lean             150 lines. Pure Lean 4 arithmetic.
│                               FIPS 180-4 test vectors via #eval.
│                               No FFI. Verified by the kernel.
│
├── Trust.lean                  The trust hierarchy:
│                               kernel < crypto < toolchain < consensus.
│                               Total order. Each level's axioms.
│                               The Thompson loop formalization.
│
├── Emit/                       ── TARGET LANGUAGE ASTs ──
│   │                           One AST per target. One renderer per target.
│   │                           Templates for the output shape.
│   │                           Codegen authors produce AST values, never strings.
│   │
│   ├── Cpp/
│   │   ├── Ast.lean            CType, CExpr, CStmt, CDecl.
│   │   │                       The C++23 subset we emit.
│   │   │
│   │   ├── Render.lean         Ast → String. The ONLY place C++ strings
│   │   │                       are assembled. Templates with «guillemets».
│   │   │
│   │   └── Codegen.lean        BoxSpec → List CDecl. Pure data transformation.
│   │
│   ├── Haskell/
│   │   ├── Ast.lean            HsType, HsExpr, HsPat, HsDecl.
│   │   │
│   │   ├── Render.lean         Ast → String. Haskell layout rules.
│   │   │
│   │   └── Codegen.lean        BoxSpec → List HsDecl.
│   │
│   ├── Dhall/
│   │   ├── Ast.lean            DhallExpr: records, unions, let bindings.
│   │   │                       NOT a codec target. A build description target.
│   │   │
│   │   ├── Render.lean         Ast → String.
│   │   │
│   │   └── Codegen.lean        Build/Rule.lean → List DhallExpr.
│   │                           The Thompson loop.
│   │
│   └── TestGen/
│       ├── Vectors.lean        Box → concrete test vectors via #eval.
│       │
│       ├── CppTests.lean       Vectors → Catch2 test cases.
│       │
│       └── HaskellTests.lean   Vectors → HSpec + QuickCheck.
│
├── StateMachine/               ── PROTOCOL STATE ──
│   │
│   ├── Machine.lean            State, Event, Transition.
│   │
│   └── Properties.lean         Reachability, deadlock freedom, liveness.
│
├── Pipeline.lean               The single entry point.
│                               Registry of all protocols → all targets.
│
└── Main.lean                   CLI. `continuity generate ./out`
```

## Straylight Standard

- `autoImplicit false` — say what you mean.
- Fully qualified constructors — no dot shorthand.
- Every file: one-paragraph module doc.
- Proofs: `sorry` is tracked, labeled, and has a plan.
- CDR byline for collaborative work.

## License

Straylight Defense License (MIT + Entity List/SDN/PLA/MSS carve-outs).

---

Straylight Software / Hypermodern LLC, San Juan, PR.
