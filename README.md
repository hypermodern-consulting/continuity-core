# Continuity

Verified metaprogramming platform for attested builds. Lean 4 source of truth
generates Dhall prelude, C++/Haskell/Rust codecs, and Buck2 toolchain rules.

```
       "Coeffects: what a computation NEEDS from the world."
                                          — Petricek, Orchard, Mycroft

       "Arrange a build right, you get a big block of text that says
        'I audit you xz/liblzma/openssh/pytorch/Metallama—"
                                          — B. R. "b7r6" 🏴
```

## Coeffect Algebra

A build is a computation. Every computation has effects (what it does to the
world) and coeffects (what it needs from the world). A build that downloads
from the internet needs `Network`. A build that signs artifacts needs `Auth`.
A build that reads `$HOME/.cargo/config.toml` needs `Filesystem`.

These are not comments. They are **types**:

```
data Coeffect = Pure | Network | Auth | Sandbox | Filesystem | Time | Random | Env | Identity
data Grade = List Coeffect    -- set semantics, tensor product = union
```

A build indexed by `Grade` carries a **proof obligation**. To run a
`Network`-graded build you must provide evidence of network access
(proxy logs, response hashes, timing). To run a `Sandbox`-graded
build you must provide evidence of the sandbox environment (kernel
version, device configuration, driver versions).

The coeffect algebra forms a **semiring**: `Pure` is the identity,
tensor product is set union, the laws are proven in `Algebra/Grade.lean`.

This enables **attested builds**: a build produces not just artifacts but
a cryptographic attestation that it consumed exactly the resources it
declared, no more, no less. The attestation references the Lean proof
that the coeffect algebra holds, signed by the build VM's identity key.

## State Machines

State machines are where the proofs earn their keep. A verified codec proves
that `parse(serialize(x)) = x`. A verified state machine proves something
harder: that every reachable state handles every possible input, that invalid
transitions are impossible, and that the machine cannot get stuck.

```
       machine<M> concept                    Continuity.StateMachine
       ═══════════════════                   ════════════════════════

       state_type                              S E A : Type
       initial() → state                       initial : S
       step(state, event) →                    transition : S → E → Transition S A
         step_result<state>                    isTerminal : S → Bool
       done(state) → bool
                                            proofs:
       C++ static_assert:                      transition is total (∀ s e, ∃ s')
         machine<sigil_machine>                terminal → no further events
         machine<zmtp_machine>                 composition preserves determinism
```

The `StateMachine.lean` DSL is a proof-bearing specification language. You
define states, events, actions, and transitions. The DSL produces:

1. **C++ state machines** targeting the `evring::machine<M>` concept from
   `libevring-cpp`. These plug directly into the `io_uring` event loop and
   compile with `static_assert(machine<M>)`.

2. **Abstract machine combinators** targeting the `abstract_machine<I,O>`
   concept: `compose`, `identity`, `filter`, `accumulate`. Category laws
   verified at compile time.

3. **Protocol state machines** for every codec: Nix daemon handshake
   (6 states → handshake → ready/failed), ZMTP greeting exchange
   (greeting → handshake → connected), HTTP/1.1 request/response
   (send → wait_write → receive → wait_read → done), HTTP/2 connection
   preface + SETTINGS exchange, TLS handshake.

The target is `libevring-cpp/src/evring/machine/machine.h`, which already has
real verified codec machines (SIGIL at 581 lines, ZMTP at 590 lines) extracted
by the Cornell pipeline. Our `StateMachine.lean` DSL replaces that pipeline
with a Lean-native one, adding composition proofs and machine-category theorems
that the hand-written headers lack.

## QualifiedDo — Graded Monad Integration

The graded monad from `Algebra/GradedMonad.lean` targets Orchard's `effect-monad`
Haskell library, modernized for GHC 9.12's `QualifiedDo` in
[effect-monad-912](https://github.com/effect-monad/effect-monad).

### Why QualifiedDo Matters

Before: `{-# LANGUAGE RebindableSyntax #-}` hijacked ALL `do`-blocks in a module.
You couldn't mix graded and normal `IO` `do` blocks. Tooling broke.

After: `{-# LANGUAGE QualifiedDo #-}` with `import Control.Effect.Do qualified as E`.
Graded blocks use `E.do`, normal blocks use `do`. Coexistence without compromise.

### Mapped 1:1 to Lean

| Orchard (Haskell) | Continuity (Lean) |
|---|---|
| `Unit m :: k` | `Grade.unit : Grade` (always `[]`) |
| `Plus m f g :: k` | `Grade.plus g₁ g₂ : Grade` |
| `return :: a → m (Unit m) a` | `gpure : α → GradedM unit α` |
| `(>>=) :: m f a → (a → m g b) → m (Plus m f g) b` | `gbind : GradedM g₁ α → (α → GradedM g₂ β) → GradedM (plus g₁ g₂) β` |
| `Subeffect sub` | `gsub : subset g₁ g₂ → GradedM g₁ α → GradedM g₂ α` |

### Generated Haskell

The codegen emits a `GradedM` newtype + `Effect` instance that compiles with
`effect-monad` 0.9 out of the box:

```haskell
newtype GradedM (g :: [GradeLabel]) a = GradedM { runGradedM :: IO a }

instance Effect GradedM where
  type Unit GradedM = '[]
  type Plus GradedM f g = Union f g
  return a = GradedM (Prelude.return a)
  (GradedM m) >>= f = GradedM (m Prelude.>>= runGradedM . f)

instance Subeffect GradedM s t where sub = coerce
```

The phantom grade type carries zero runtime cost. `sub` is a no-op `coerce`.
Generated handler stubs declare their grade obligation:

```haskell
type CASBlobGrade = '[GLCrypto, GLFs]
handleCASBlob :: CASBlob -> GradedM CASBlobGrade ()
```

### C++ Grade Pattern

The C++ side uses a `constexpr` bitfield enum with zero runtime overhead:

```cpp
enum class GradeLabel : uint16_t {
    Net = 1 << 0, Auth = 1 << 1, Config = 1 << 2, Log = 1 << 3,
    Crypto = 1 << 4, Fs = 1 << 5, FsCA = 1 << 6, Gpu = 1 << 7,
    Sandbox = 1 << 8, Time = 1 << 9, Random = 1 << 10,
    Env = 1 << 11, Identity = 1 << 12
};

struct Grade {
    uint16_t bits = 0;
    constexpr Grade operator|(Grade other) const { ... }
    constexpr bool is_subset_of(Grade other) const { return (bits & ~other.bits) == 0; }
    constexpr bool is_pure() const { return bits == 0; }
};

template<typename T>
struct ParseResult {
    T value;
    std::span<const uint8_t> remaining;
    Grade grade;  // what has been verified about this data
};
```

Every parse function returns `ParseResult<T>`, initialized with `grade_unit`
(pure). After verification passes (signature check, timestamp check, auth),
helper functions lift the grade:

```cpp
auto r = parse_cas_blob(buf);
r = with_crypto_grade(r);          // r.grade |= grade_crypto
r = with_time_grade(r);            // r.grade |= grade_time
```

The grade is **monotonic** — once tagged, it can only grow. This is enforced by
the `Grade` type itself (no public mutation, only `operator|`). The codec
registry in `CodeGen/Unified.lean` maps each codec to its handler grade:

```
cas_blob       → [crypto, fs]
ssp_init       → [crypto, net, random]
sigil_request  → [net, gpu, auth]
attest_calldata → [crypto, identity, net]
```

These handler grades are emitted as Haskell `type XxxGrade` annotations and
are planned for C++ `constexpr Grade` annotations.

## Architecture

```
                                    ┌──────────────────────┐
                                    │   Continuity.lean     │
                                    │   (module root)       │
                                    └──────────┬───────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
          ┌─────────▼────────┐      ┌─────────▼────────┐      ┌──────────▼─────────┐
          │   Algebra/       │      │   Codec/          │      │   Build/            │
          │   Grade labels   │      │   Verified wire   │      │   Abstract build    │
          │   Graded monad   │      │   format codecs   │      │   system types      │
          │   Reproducibility│      │   Protocol impls  │      │   Rules + toolchains│
          └─────────┬────────┘      └─────────┬────────┘      └──────────┬─────────┘
                    │                          │                          │
                    │              ┌───────────▼───────────┐              │
                    │              │   Codegen/Derive/     │              │
                    │              │   Walks Codec/Protocol│              │
                    │              │   Walks Build/ types  │              │
                    │              │   → target-language   │              │
                    │              │     AST constructors  │              │
                    │              └───────────┬───────────┘              │
                    │                          │                          │
                    │     ┌────────────────────┼────────────────────┐     │
                    │     │                    │                    │     │
                    │ ┌───▼────┐ ┌─────────┐ ┌─▼──────────┐ ┌──────▼──┐ │
                    │ │Dhall   │ │ C++     │ │ Haskell    │ │Starlark │ │
                    │ │Builder │ │ Builder │ │ Builder    │ │Builder  │ │
                    │ │AST     │ │ AST     │ │ AST        │ │AST      │ │
                    │ │Render  │ │ Render  │ │ Render     │ │Render   │ │
                    │ └───┬────┘ └────┬────┘ └──────┬─────┘ └────┬─────┘ │
                    │     │          │              │             │       │
                    │     ▼          ▼              ▼             ▼       │
                    │  .dhall    .hpp/.cpp      .hs/.cabal     .bzl/BUCK  │
                    │                                                      │
                    └──────────────────────────────────────────────────────┘

         ┌───────────────────────────────────────────────────────────┐
         │                    Generated Output                       │
         │                                                           │
         │  prelude/*.dhall   — typed build DSL (Triple, Dep, Cxx,  │
         │                      Haskell, Rust, Lean, Nv, Genrule,    │
         │                      Rule, Toolchain, package.dhall)      │
         │                                                           │
         │  codec/*.hpp       — C++23 headers with parse/serialize   │
         │                      from verified Box combinators        │
         │                                                           │
         │  codec/*.hs        — Haskell modules with parse/serialize │
         │                      from verified Box combinators        │
         │                                                           │
         │  toolchains/*.bzl  — Buck2 toolchain rules (lean, rust,   │
         │                      haskell, cxx, nv, purescript)        │
         │                                                           │
         │  toolchains/BUCK   — Toolchain registrations              │
         └───────────────────────────────────────────────────────────┘
```

## Project Tree (Target State)

```
Continuity/
│
├── Algebra/                          — coeffect grade lattice
│   ├── Grade.lean                    — coeffect labels + grade algebra
│   └── GradedMonad.lean              — graded monad typeclass
│
├── Build/                            — abstract build system (source of truth)
│   ├── Core/
│   │   ├── Triple.lean               — arch/vendor/os/abi/cpu/gpu enums
│   │   ├── Dependency.lean           — Local | Flake | External | PkgConfig
│   │   ├── Digest.lean               — SHA256 | BLAKE3 | SHA512 (two stubs)
│   │   ├── Vis.lean                  — Public | Private
│   │   ├── Resource.lean             — Pure | Network | Auth | Sandbox | Filesystem
│   │   ├── Command.lean              — tool + args
│   │   ├── Action.lean               — inputs(Digest) → env → command → outputs
│   │   ├── Rule.lean                 — all 18 rule constructors
│   │   ├── Library.lean              — build graph composition
│   │   ├── Properties.lean           — build-level theorems (NEW)
│   │   └── Genrule.lean              — shell-out rule
│   ├── Rule/
│   │   ├── Cxx.lean                  — cxx_binary, cxx_library
│   │   ├── Haskell.lean              — haskell_binary, haskell_library, haskell_ffi_binary
│   │   ├── Rust.lean                 — rust_binary, rust_library
│   │   ├── Lean4.lean                — lean_binary, lean_library
│   │   ├── Nv.lean                   — nv_binary, nv_library
│   │   ├── PureScript.lean           — purescript_app, purescript_binary, purescript_library
│   │   ├── RustCrate.lean            — crates_io, http_archive
│   │   └── NixCxx.lean               — nix_cxx_binary
│   └── Toolchain/
│       ├── Cxx.lean                  — cxx_toolchain (link_style: inductive)
│       ├── Haskell.lean              — haskell_toolchain (ghc, flags)
│       ├── Rust.lean                 — rust_toolchain (rustc, edition: Edition)
│       ├── Lean4.lean                — lean_toolchain (lean, leanc, lib/include dirs)
│       └── Nv.lean                   — nv_toolchain (nvcc, archs: List Gpu)
│
├── Codec/                            — verified wire format codecs (proof substrate)
│   ├── Core/
│   │   ├── Box.lean                  — LL(0) bidirectional serialization + proofs
│   │   ├── Bytes.lean                — takeN, FixedBytes, LenPrefixed + proofs
│   │   ├── Varint.lean               — protobuf-style varint + roundtrip proof
│   │   ├── Scanner.lean              — delimiter scanning + consumption theorem
│   │   ├── Parser.lean               — LL(k) token-based parsing + determinism
│   │   ├── Guards.lean               — Bounded wrapper + exhaustion theorems
│   │   └── Limits.lean               — protocol constants + bounded box instances
│   ├── Dhall/
│   │   ├── Lexer.lean                — Dhall tokenizer
│   │   └── Parser.lean               — Dhall expression parser (roundtrips with codegen)
│   └── Protocol/
│       ├── Protocol.lean             — LengthCodec, BoundedFrame, common abstractions
│       ├── Nix.lean                  — worker protocol, WorkerOp (46 ops), NixString
│       ├── Protobuf.lean             — varint-encoded Tag, Field, WireType
│       ├── Git.lean                  — pack format, ObjectId (SHA-1 + SHA-256)
│       ├── GitTransport.lean         — pkt-line framing
│       ├── Http.lean                 — HTTP/1.1 request/response
│       ├── Http2.lean                — frame header (24-bit length field)
│       ├── Http3.lean                — QUIC varint frame
│       ├── Zmtp.lean                 — greeting (64-byte invariant), frame flags
│       ├── Saml.lean                 — assertion parsing, signature verification
│       ├── EVM.lean                  — ABI-encoded attestation calldata
│       ├── Json.lean                 — recursive descent JSON parser
│       └── StateMachine.lean         — protocol state machines + determinism
│
├── Codegen/                          — code generation
│   ├── Derive/
│   │   ├── Build.lean                — walks Build/{Core,Rule,Toolchain} → Dhall+Starlark AST
│   │   └── Codec.lean                — walks Codec/Protocol/ → C+++Haskell AST
│   ├── AST/
│   │   ├── Dhall/
│   │   │   ├── Builder.lean          — RecordM, LetM, ListM monadic builders
│   │   │   ├── Ast.lean              — Expr, Module, BinOp, Import types
│   │   │   └── Render.lean           — Expr → Dhall text
│   │   ├── Cpp/
│   │   │   ├── Builder.lean          — StmtM, FileM monadic builders
│   │   │   ├── Ast.lean              — CType, CExpr, CStmt, CDecl, CFile types
│   │   │   └── Render.lean           — AST → C++ text
│   │   ├── Haskell/
│   │   │   ├── Builder.lean          — DoM, DeclM, FieldM monadic builders
│   │   │   ├── Ast.lean              — HsType, HsExpr, HsPat, HsDecl, HsModule types
│   │   │   └── Render.lean           — AST → Haskell text
│   │   └── Starlark/
│   │       ├── Builder.lean          — monadic builders for SExpr/SStmt/STop
│   │       ├── Ast.lean              — SFile, STop, SStmt, SExpr, SParam types
│   │       └── Render.lean           — AST → .bzl/BUCK text (single pipeline)
│   └── Algebra/
│       └── Effect.lean               — graded monad → Haskell + C++ grade emission
│
├── Crypto/
│   ├── Core.lean                     — SHA256Hash, hash_injective axiom
│   └── SHA256.lean                   — verified FIPS 180-4 SHA-256
│
├── Nix/
│   ├── Derivation.lean               — derivation parsing + serialization
│   └── NAR.lean                      — Nix archive format
│
├── Straylight/
│   ├── CAS.lean                      — content-addressed storage, Merkle trees
│   └── REAPI.lean                    — remote execution API mapping
│
├── StateMachine/
│   └── StateMachine.lean             — verified state machine DSL
│
├── CLI/
│   └── InitBuck2.lean                — buck2 scaffolding generator
│
├── Main.lean                         — CLI entry point
└── Continuity.lean                   — module root (imports all)
```

## Work Plan

Work blocks are ordered monotonically by value. Each block produces a
verifiable delta: the build passes, the generated output is identical
or strictly improved, and the proof surface is preserved or expanded.

### Phase 0 — Clean Foundation

| # | Block | What | Verifies |
|---|-------|------|----------|
| 0.1 | `s/Dep/Dependency` | Rename `Build/Dep.lean` → `Build/Core/Dependency.lean`, update all imports | `lake build` |
| 0.2 | Reorganize `Build/` | Create `Core/`, `Rule/`, `Toolchain/` subdirectories. Move `Triple`, `Dependency`, `Digest`, `Vis`, `Resource`, `Command`, `Action`, `Rule`, `Library`, `Genrule` to `Core/`. Move `Cxx`, `Haskell`, `Rust`, `Lean4`, `Nv` to `Rule/`. Move toolchain files to `Toolchain/`. Add parent `.lean` files. | `lake build` |
| 0.3 | Delete `Build/BzlFile.lean` | Legacy Starlark types. `BzlFile`, `BzlRule`, `RuleImpl`, `Attr`, `AttrType` superseded by `SFile`/`SExpr` in `Codegen/AST/Starlark/`. Port `cxxBzl` to `SFile`. | `lake build`, generated .bzl identical |
| 0.4 | Fix `Digest.algo` | `algo : HashAlgo` claims sha256/sha512/blake3 but `hash : SHA256Hash` can only be SHA-256. Add `BLAKE3Hash` and `SHA512Hash` stubs, make `hash` a dependent type or tagged union. | `lake build`, type checks |
| 0.5 | Replace string toolchain fields | `link_style : String` → inductive `LinkStyle`. `default_edition : String` → `Edition` (exists in `Rust.lean`). `nv_archs : List String` → `List Gpu` (exists in `Triple.lean`). | `lake build`, Dhall output unchanged |
| 0.6 | Add missing `Build/Properties.lean` | Referenced by `Resource.lean` line 32 but doesn't exist. Add with correct header. | `lake build` |
| 0.7 | Rename vacuous theorems | `digest_collision_resistance` → `digest_mk_inj`. `zlib_deterministic` → `zlib_option_some_inj`. Names match what's actually proven. | `lake build` |
| 0.8 | Delete `Codegen/Codec/Spec.lean` | Hand-written parallel type definitions diverged from Protocol types. | `lake build` (removes unused code) |

### Phase 1 — Add Missing Build Types

| # | Block | What | Verifies |
|---|-------|------|----------|
| 1.1 | `Build/Rule/PureScript.lean` | `purescript_app`, `purescript_binary`, `purescript_library` with field parity against Dhall `Rule` union. | `lake build` |
| 1.2 | `Build/Rule/RustCrate.lean` | `crates_io`, `http_archive` with field parity. | `lake build` |
| 1.3 | `Build/Rule/NixCxx.lean` | `nix_cxx_binary` with field parity. | `lake build` |
| 1.4 | Extend `Build/Core/Rule.lean` | Add new constructors to `Rule` sum type. | `lake build` |

### Phase 2 — Unify Serialization

| # | Block | What | Verifies |
|---|-------|------|----------|
| 2.1 | Delete legacy `renderBzlFile` half | Remove `renderBzlFile`, `renderRule`, `renderToolchainCall`, `renderBuckFile` from `Starlark/Render.lean`. Only `renderSFile` remains. | `lake build`, all generated .bzl identical |
| 2.2 | `Codegen/AST/Starlark/Builder.lean` | Monadic `SExpr`/`SStmt`/`STop` builders for ergonomic AST construction. | `lake build` |
| 2.3 | Delete `Codegen/Build/ToDhall.lean` | Replace with `Codegen/Derive/Build.lean` that walks `Build/` types. | Generated Dhall identical |
| 2.4 | Delete `Codegen/Build/ToStarlark.lean` | Replace with Starlark emission path in `Codegen/Derive/Build.lean`. | Generated .bzl identical |
| 2.5 | Delete `Codegen/Build/BzlDefs.lean` | Per-toolchain .bzl rules now generated from `Build/Toolchain/` types via `Derive/Build.lean`. | Generated toolchain .bzl identical |
| 2.6 | Delete `Codegen/Codec/ToCpp.lean` | Replace with `Codegen/Derive/Codec.lean` walking `Codec/Protocol/` types. | Generated C++ headers identical or improved |
| 2.7 | Delete `Codegen/Codec/ToHaskell.lean` | Replace with `Codegen/Derive/Codec.lean`. | Generated Haskell modules identical or improved |

### Phase 3 — Replace Stubs with Verified Codegen

| # | Block | What | Verifies |
|---|-------|------|----------|
| 3.1 | Wire `Box` combinators into C++ codegen | Emit C++ that calls verified parsing logic matching `Box` roundtrip proofs. Replace `return std::nullopt` stubs. | `lake build`, generated C++ compiles via buck2 |
| 3.2 | Wire `Box` combinators into Haskell codegen | Emit Haskell calling verified parsing logic. Replace `error "stub"` implementations. | `lake build`, generated Haskell compiles via GHC |
| 3.3 | Add C++ grade/coeffect annotations | Generate `[[nodiscard]]` grade-tagged parse result types matching `Algebra/Grade.lean`. Use pattern from `libevring-cpp/src/evring/core/`. | `lake build`, C++ compiles |
| 3.4 | Add Haskell graded monad types | Generate `GradedM` from `Algebra/GradedMonad.lean` using pattern from `straylight/generated/haskell/`. | `lake build`, Haskell compiles |
| 3.5 | Generate test vectors from Lean evaluation | For each verified `Box`, produce test vector triples (input, serialize, parse-output). Validate C++/Haskell against the oracle. | `lake build`, test vectors match |

### Phase 4 — Proof Completion

| # | Block | What | Verifies |
|---|-------|------|----------|
| 4.1 | Discharge `LengthCodec` proofs | Wrap `gitEncodeLength`, `nixEncodeLength`, `zmtpEncodeLength` into `LengthCodec` instances with `roundtrip`, `encode_size`, `decode_append` proofs. | `lake build`, proofs check |
| 4.2 | Fix Protobuf `Tag` encoding | Wire the correct varint packing (field_number << 3 \| wire_type) into the codec derivation. After Phase 2 this is automatic from Protocol types. | `lake build` |
| 4.3 | Fix Varint spec to use actual varint | After Phase 2, derivation from `Codec/Core/Varint.lean` produces varint-aware code instead of u64le stubs. | Generated code uses varint encoding |
| 4.4 | Add EVM calldata roundtrip proof | `encodeUint64` zero-padding + u64le; prove `decodeUint64 ∘ encodeUint64 = id`. | `lake build` |
| 4.5 | Add HTTP2 full-header roundtrip | Currently only `FrameType` enum has roundtrip proof. Add for complete `FrameHeader`. | `lake build` |
| 4.6 | Borrow `bv_decide` proof patterns | For bitvector LE/BE encoding proofs, use `bv_decide` from `Std.Tactic.BVDecide` (pattern proven in `straylight/0x01-continuity/Codec/Proofs.lean`). | `lake build` |

### Phase 5 — Engine Integration

| # | Block | What | Verifies |
|---|-------|------|----------|
| 5.1 | Generate state machine headers for `libevring-cpp` | Use `StateMachine/StateMachine.lean` DSL to produce C++ state machines matching the `evring::machine` concept from `libevring-cpp/src/evring/machine/machine.h`. | C++ compiles with `static_assert(machine<M>)` |
| 5.2 | Align protocol codecs with `libevring-cpp` protocol headers | SIGIL and ZMTP codecs in `libevring-cpp/src/evring/protocol/` have real implementations; verify our Codec/Protocol/ types match and the generated output replaces them correctly. | Binary-identical output vs hand-written |
| 5.3 | Add abstract machine category alignment | Mirror `libevring-cpp/src/evring/machine/abstract_machine.h` in the codegen output. The `static_assert` category laws should derive from the state machine proofs. | `lake build`, C++ `static_assert`s pass |
| 5.4 | Generate HTTP/1.1 and HTTP/2 state machines | `libevring-cpp` has working HTTP state machines with llhttp/nghttp2. Generate equivalents from our Protocol types. | C++ compiles, test vectors pass |

### Phase 6 — Attested Build Bootstrapping

| # | Block | What | Verifies |
|---|-------|------|----------|
| 6.1 | Implement `Coeffect.lean` (the discharge version) | Borrow the Gateway coeffect types from `straylight/0x01-continuity/Gateway/CoeffectProofs.lean` — `Hash`, `PublicKey`, `Signature`, `DischargeProof`. | `lake build` |
| 6.2 | Emit attestation Dhall | Build specs produce `attestation.dhall` containing coeffect declarations, discharge evidence, Lean proof hashes, and signatures. | `lake build`, attestation valid per Dhall typecheck |
| 6.3 | Reflective hash verification | `BuildSpec/Fixed.lean` pattern from `straylight/`: compute `h₁ := moduleHash`, verify generated output hashes match prediction. | `lake build` |
| 6.4 | Nix flake integration | Generated output (Dhall prelude + C++/Haskell/Rust codecs + toolchain rules + attestation) exposed as a Nix flake output, consumable by downstream projects. | `nix build .#generated` |

## Axiom Budget

Every axiom, why it's there, and what breaks if it's wrong:

| Axiom | File | What it assumes |
|-------|------|-----------------|
| `hash_injective` | Crypto/Core.lean | SHA-256 collision resistance (on `ByteArray`) |
| `ed25519_verify` | Crypto/Core.lean | Ed25519 verification exists |
| `mldsa_verify` | Crypto/Core.lean | ML-DSA (FIPS 204) verification exists |
| `slhdsa_verify` | Crypto/Core.lean | SLH-DSA (FIPS 205) verification exists |
| `compress_size` | Crypto/SHA256.lean | `#[a,b,c,d,e,f,g,h].size = 8` (structural) |
| `finalize_size_ax` | Crypto/SHA256.lean | `8 × 4 = 32` (arithmetic) |

SHA-256 has a pure Lean implementation (FIPS 180-4 in `Crypto/SHA256.lean`).
Collision resistance is the single cryptographic assumption. Ed25519, ML-DSA,
and SLH-DSA are opaque signature verification axioms pending verified
implementations.

## Borrowed Patterns

From `effect-monad-912` (`/home/b7r6/src/libevring/effect-monad-912/`):
- **`QualifiedDo` integration**: `Control.Effect.Do` (48 lines) re-exports
  `return`, `(>>=)`, `(>>)`, `fail` qualified — graded `E.do` coexists with
  normal `do` in the same module. Zero-cost at runtime (phantom type params).
- **`Effect` class with `Inv` constraint**: `type Inv m f g :: Constraint`
  lets instances gate `>>=` on set-property proofs (IsSet, Unionable, Split)
  while defaulting to `()`. Our `GradedM` uses `()`, `coerce`-based `Subeffect`.
- **16 example files as integration tests**: The library has zero formal tests.
  Each example compiles and demonstrates type-level grade correctness. We should
  emit equivalent usage examples in generated Haskell modules.

From `libevring-cpp` (`/home/b7r6/src/libevring-cpp/`):
- **C++ state machine concept**: `evring::machine<M>` with `state_type`,
  `initial()`, `step()`, `done()` — our `StateMachine.lean` DSL targets this
- **Real verified codec headers**: `sigil.h` (581 lines) and `zmtp.h` (590 lines)
  with full parse/serialize, not stubs — our codegen must produce at least this
- **Abstract machine category**: `abstract_machine<I,O>` with `compose`, `identity`,
  `filter`, `accumulate` — our state machine proofs should generate these
- **Engine state machines**: HTTP/1.1 (llhttp), HTTP/2 (nghttp2), TLS (libtls),
  process (pidfd+io_uring) — our Protocol types should generate equivalent machines

From `straylight/0x01-continuity` (`/home/b7r6/src/straylight/0x01-continuity/`):
- **`Box` with `roundtrip` + `consumption` proofs**: 710 lines, 0 sorry, 6
  primitives, 50+ theorems — the canonical pattern for proof-carrying codecs
- **`bv_decide` for bitvector proofs**: `Std.Tactic.BVDecide` automates LE/BE
  encoding/decoding proofs (hundreds of manual lines avoided)
- **`BoxSpec` deep embedding**: Inductive type free of proof terms — a clean
  bridge between proven `Box` structures and code generation IR
- **C++ grade bitfield pattern**: `enum class GradeLabel : uint16_t` with
  `constexpr operator|`, `ParseResult<T>` carrying a `Grade grade` field,
  `with_crypto_grade()` / `with_time_grade()` lifters — monotonic, zero-runtime-cost
- **`CodecEntry.handlerGrade`**: Per-codec grade registry mapping 30+ codecs
  to their coeffect obligations (`cas_blob → [crypto, fs]`, `ssp_init →
  [crypto, net, random]`, etc.)
- **Test vector engine**: `mkVector` using `box.serialize` → validate
  C++/Haskell against the Lean oracle
- **Gateway coeffect discharge**: `CoeffectProofs.lean` (305 lines), `Proofs.lean`
  (376 lines) — proves fallback chain termination, retry termination, cache
  determinism — the runtime that discharges coeffects
- **Dhall as unified build target**: 20 files in `Build/Dhall/`, each language
  owns its Dhall fragment via `.toAst`, unified by `Generate.lean`

## Quick Start

```bash
lake build
lake exe continuity generate output/continuity-prelude
lake exe continuity init-buck2 --tools-specification=examples/tools.dhall
```

## License

Straylight Defense License (MIT + Entity List/SDN/PLA/MSS carve-outs).
