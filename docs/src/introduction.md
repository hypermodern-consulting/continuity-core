# Continuity

Continuity is a verified metaprogramming platform. It's a single Lean 4 binary
that reads a tool specification, generates build scaffolding, and emits codec
implementations — with every specification backed by machine-checked proofs.

The name comes from Gibson's Sprawl trilogy, where Villa Straylight was the
space station where the AIs lived. Continuity is the verified core that
everything else is built on.

## What Problem Does It Solve?

Build systems are configuration languages pretending to be software. They
have no types, no proofs, no guarantees. A misconfigured linker flag can
cost days. A wrong byte offset in a protocol parser can cost everything.

Continuity makes these problems compile errors:

- **Wire format codecs** are specified in Lean with roundtrip proofs. The
  generated C and Haskell code has the same structure the proofs cover.
- **Build configurations** are typed. A `Triple` has an `Arch`, not a string.
  A `Digest` wraps a `SHA256Hash`, not raw bytes.
- **Protocol state machines** are deterministic by construction. The transition
  function is total — every (state, event) pair has exactly one outcome.

## Who Is This For?

Systems programmers who are tired of bugs that types would have caught.
If you've ever debugged a byte-offset error in a binary protocol, a
stale build cache, or a linker flag that silently changed semantics —
this is the tool that makes those bugs impossible.
