# Architecture

## Layers

Continuity has five layers. Each depends only on layers below it.

```
┌─────────────────────────────────────────────────────┐
│  CLI                                                │
│  Main.lean, InitBuck2.lean                          │
├─────────────────────────────────────────────────────┤
│  Codegen                                            │
│  Build/ToDhall, Codec/{Spec,ToCpp,ToHaskell}        │
├──────────────────┬──────────────────────────────────┤
│  CAS Stack       │  State Machine                   │
│  Crypto, SHA256  │  Transition, Combinators         │
│  Derivation      │  Nix Daemon Handshake            │
│  CAS, NAR, REAPI │  Operation Loop                  │
├──────────────────┴──────────────────────────────────┤
│  Codec Layer                                        │
│  Box, Scanner, Parser, Bytes, Guards, Varint        │
│  Protocol, Limits                                   │
│  Nix, Protobuf, Git, HTTP/1-2-3, ZMTP, SAML, EVM   │
│  Json, Dhall                                        │
├─────────────────────────────────────────────────────┤
│  Build Model                                        │
│  Triple, Action, Command, Digest, Rule, BzlFile     │
├─────────────────────────────────────────────────────┤
│  Emit Layer                                         │
│  Dhall, Haskell, C++ — AST + Render + Build         │
└─────────────────────────────────────────────────────┘
```

## Data Flow

```
tools.dhall ──→ InitBuck2 ──→ .buckconfig
                             toolchains/*.bzl
                             .buckroot

Lean types  ──→ ToDhall   ──→ 19 Dhall files (build prelude)
            ──→ ToCpp     ──→ 13 C++ headers (codec types + stubs)
            ──→ ToHaskell ──→ 13 Haskell modules (codec types + parsers)
```

## Codec Architecture

The codec layer uses three abstractions at increasing power levels:

### Box (bidirectional, proven roundtrip)

```
structure Box (α : Type) where
  parse     : Bytes → ParseResult α
  serialize : α → Bytes
  roundtrip   : ∀ a, parse (serialize a) = .ok a .empty
  consumption : ∀ a extra, parse (serialize a ++ extra) = .ok a extra
```

A `Box` is the gold standard: parse and serialize are inverse, proven.
Varint, u8, u64le, nixString, attestCalldata all have Boxes.

### Scanner (zero-copy boundary detection)

Finds where a value starts and ends without allocating or parsing.
Used for: HTTP header scanning, JSON boundary detection, SAML element finding.

### Parser (parse only, no serialize proof)

When you can parse but can't or don't need to prove roundtrip.
Used for: Git pack format (stateful), JSON (multiple valid serializations).

### Composition

Boxes compose via `seq` (sequential) and `isoBox` (isomorphism):

```lean
-- Sequential: parse A then B, serialize A then B
def seq (a : Box α) (b : Box β) : Box (α × β)

-- Isomorphism: if A ≅ B and you have Box A, get Box B
def isoBox (box : Box α) (f : α → β) (g : β → α) ... : Box β
```

## CAS Stack

```
ByteArray ──→ SHA256.hash ──→ SHA256Hash (32 bytes, proven)
                                  │
                                  ▼
                              CAS.Digest (hash + size)
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼              ▼
              Derivation      NAR.lean      REAPI.lean
              (store paths)   (archive fmt)  (remote exec)
```

Content goes in, gets hashed (kernel-distance SHA-256), gets a store path
(Derivation), can be looked up by REAPI digest (Mapping).

## State Machine

The state machine DSL is protocol-level, not byte-level. It produces
intents that the event loop translates to system calls.

```
                    ┌───────────────────────┐
                    │  StateMachine.lean     │
                    │  ServerState × Event   │
                    │  → ServerState × [Act] │
                    └───────────┬───────────┘
                                │ intents
                    ┌───────────▼───────────┐
                    │  Event Loop           │
                    │  (io_uring / epoll)   │
                    │  Act → SQE            │
                    │  CQE → Event          │
                    └───────────────────────┘
```

Combinators: `product` (parallel), `sum` (choice), `sequential` (handoff),
`mapActions`, `extendState`, `withState`.

The Nix daemon machine: `serverHandshake.sequential(daemonOps)`.
Version negotiation → feature intersection → REAPI upgrade → operation loop.

## Trust Model

```
Distance 0: rfl — Lean's type theory, the kernel
Distance 1: Crypto — SHA-256, Ed25519, ML-DSA, SLH-DSA
Distance 2: OS — namespaces, syscalls, io_uring
Distance 3: Toolchain — compilers, linkers
Distance 4: Consensus — human agreement, governance
```

Everything in Continuity is distance 0 or 1. The crypto axioms are
distance 1. The structural axioms (compress_size, finalize_size) should
be distance 0 but the normalizer can't close them — they're arithmetic
facts, not security assumptions.
