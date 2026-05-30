# Continuity

Verified metaprogramming platform. Lean 4 specifications with proofs generate
C, Haskell, and Dhall — one binary, zero sorry, seven axioms.

## Quick Start

```bash
# Bootstrap (one time — the Thompson step)
lake build

# Initialize a project
lake exe continuity init-buck2 \
    --tools-specification=examples/tools.dhall \
    ~/src/my-project

# Build
cd ~/src/my-project
buck2 build //...
```

## What It Does

Continuity is a single Lean 4 binary that:

1. **Reads** a tool specification (Dhall) describing where compilers live on disk
2. **Writes** buck2 scaffolding (`.buckconfig`, toolchain rules, build files)
3. **Generates** codec implementations (C headers, Haskell modules) from verified specs
4. **Emits** a typed build prelude (Dhall) for multi-language projects

The Lean kernel checks the specifications. Property tests check the generated code.
Two independent verification paths covering the same ground.

## Project Structure

```
Continuity/
  Main.lean                     CLI: generate, init-buck2
  InitBuck2.lean                Dhall spec → buck2 scaffolding
  StateMachine.lean             Protocol state machine DSL + Nix daemon

  Crypto.lean                   Opaque types, hybrid PQ verification
  Crypto/SHA256.lean            Pure Lean FIPS 180-4, kernel-distance

  Derivation.lean               Content-addressed store paths
  CAS.lean                      Content-addressable store model
  NAR.lean                      Nix archive serialization
  REAPI.lean                    Remote Execution API mapping

  Codec/
    Box.lean                    Bidirectional codec with roundtrip proof
    Scanner.lean                Zero-copy boundary detection
    Parser.lean                 Parsing without serialization proof
    Bytes.lean                  FixedBytes, LenPrefixed, takeN
    Guards.lean                 Bounded, expectPad, exhaustion theorems
    Varint.lean                 Protobuf varint (bv_decide roundtrip)
    Limits.lean                 Protocol constants with budget proofs
    Protocol.lean               Generic length-prefixed framing
    Nix.lean                    Nix daemon protocol (46 ops, NAR, handshake)
    Protobuf.lean               Wire format (tags, fields, zigzag)
    Git.lean                    Pack format (type/size, ofs-delta)
    GitTransport.lean           Smart transport (pkt-line, side-band)
    Http.lean                   HTTP/1.1 (methods, headers, request/response)
    Http2.lean                  HTTP/2 frames + HPACK
    Http3.lean                  HTTP/3 + QUIC varint + QPACK
    Zmtp.lean                   ZeroMQ transport (greeting, frames)
    Saml.lean                   Wrapping-attack-safe assertion scanner
    EVM.lean                    ABI encoding (attestation calldata)
    Json.lean                   Recursive descent parser
    Dhall/
      Lexer.lean                Dhall tokenizer
      Parser.lean               Dhall expression parser

  Emit/
    Dhall/  {Ast,Render,Build}  Dhall AST + pretty printer
    Haskell/{Ast,Render,Build}  Haskell AST + pretty printer
    Cpp/    {Ast,Render,Build}  C++ AST + pretty printer

  Build/
    Triple.lean                 Target triples (arch/vendor/os/abi/cpu/gpu)
    Action.lean                 DICE execution unit
    Command.lean                Process invocation
    Digest.lean                 Content hash (wraps SHA256Hash)
    ...8 more...                Dep, Vis, Resource, Toolchain, Rule, BzlFile

  Codegen/
    Build/ToDhall.lean          Build types → 19 Dhall files
    Codec/Spec.lean             CodecSpec intermediate representation
    Codec/ToCpp.lean            CodecSpec → 13 C++ headers
    Codec/ToHaskell.lean        CodecSpec → 13 Haskell modules

toolchains/
  lean.bzl                      lean_library, lean_binary for buck2
  cuda.bzl                      cuda_library, cuda_binary for buck2

examples/
  tools.dhall                   Tool specification (Lean + C + Haskell)
  tools-with-gpu.dhall          Tool specification with NVIDIA
  lean-hello/                   Lean library + binary example
  c-codec/                      C varint roundtrip tests
  hs-codec/                     Haskell varint roundtrip tests
  cuda-hello/                   CUDA kernel launch example

test/
  codec_test.c                  326K C property tests
  CodecTest.hs                  15K Haskell property tests
  codec_runtime.h               C++ wire format primitives
```

## Numbers

| Metric | Value |
|--------|-------|
| Lean files | 59 |
| Lines of Lean | 10,732 |
| `sorry` | 0 |
| Axioms | 7 |
| Generated files | 45 (19 Dhall + 13 C++ + 13 Haskell) |
| C property tests | 326,149 passed |
| Haskell property tests | 15,010 passed |
| Protocols | 13 (Nix, Protobuf, Git, HTTP/1-2-3, ZMTP, SAML, EVM, JSON, ...) |

## Axiom Budget

Every axiom, why it's there, and what breaks if it's wrong:

| Axiom | File | What it assumes |
|-------|------|-----------------|
| `hash_bytes` | Crypto.lean | SHA-256 exists as a function |
| `hash_injective` | Crypto.lean | Collision resistance (on `ByteArray`, not `∀ α`) |
| `ed25519_verify` | Crypto.lean | Ed25519 verification exists |
| `mldsa_verify` | Crypto.lean | ML-DSA (FIPS 204) verification exists |
| `slhdsa_verify` | Crypto.lean | SLH-DSA (FIPS 205) verification exists |
| `compress_size` | SHA256.lean | `#[a,b,c,d,e,f,g,h].size = 8` (structural) |
| `finalize_size_ax` | SHA256.lean | `8 × 4 = 32` (arithmetic) |

The last two are not security assumptions — they're arithmetic facts about the
SHA-256 algorithm that the normalizer can't reduce through 64-round folds.
Everything else is proven or computed by the Lean kernel.

## License

Straylight Defense License (MIT + Entity List/SDN/PLA/MSS carve-outs).
