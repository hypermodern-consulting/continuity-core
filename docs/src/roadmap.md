# Roadmap

## Discharge structural axioms

`compress_size` and `finalize_size_ax` are arithmetic facts, not security
assumptions. They should be provable with better `Array.size` automation
or increased heartbeat limits. Priority: low (not blocking anything).

## Dedicated C and Haskell toolchain rules

`cxx.bzl` and `haskell.bzl` to replace genrule usage. The Lean and CUDA
toolchains show the pattern. Priority: medium (genrules work but don't
cache optimally).

## Starlark as emit target

Add `Emit/Starlark/{Ast,Render}.lean` alongside Dhall/Haskell/Cpp.
Generate BUCK files directly from the Lean type model instead of
going through Dhall. This eliminates the `to-starlark.dhall` bridge.
Priority: medium.

## LRE integration

Wire the REAPI mapping to an actual remote executor. The `.buckconfig`
`[reapi]` section is already generated — it just needs an endpoint.
Priority: high (this is the whole point).

## NAR streaming

The current `NAR.serialize` produces a complete `ByteArray` in memory.
For large store paths, this needs to stream via the state machine
intents. Priority: medium.

## Rust toolchain

`rust.bzl` for cargo-free Rust compilation via buck2. The Build model
already has `Rust.lean` with crate types and edition tracking.
Priority: low (no active Rust projects).

## Property test generation

Generate QuickCheck `Arbitrary` instances and C randomized tests
directly from the CodecSpec. Currently the tests are hand-written.
Priority: low (hand-written tests are adequate).
