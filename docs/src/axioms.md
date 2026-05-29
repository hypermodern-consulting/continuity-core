# Axiom Budget

Continuity has 7 axioms. Five are cryptographic assumptions (trust distance 1).
Two are structural arithmetic facts that should be provable but aren't yet
(trust distance 0, blocked by normalizer limitations).

## Cryptographic Axioms

These are the assumptions we're betting on. If any of these fail,
the entire content-addressed ecosystem (Git, Nix, Docker, Bitcoin)
fails with us.

### `hash_bytes : ByteArray → Hash`

SHA-256 exists as a function from byte arrays to hashes. This is the
opaque type-level version used in Crypto.lean for abstract reasoning.
The concrete implementation is in SHA256.lean (kernel-distance, no FFI).

### `hash_injective (a b : ByteArray) : hash_bytes a = hash_bytes b → a = b`

**The** axiom. Collision resistance for SHA-256, stated as injectivity
(the random oracle model). Strictly stronger than collision resistance,
but standard in formal verification of crypto protocols.

Note: this is quantified over `ByteArray`, not `∀ α`. The earlier v11
version had `∀ (α : Type) [Inhabited α]` which is falsifiable at `Unit`.
Fixed.

### `ed25519_verify`, `mldsa_verify`, `slhdsa_verify`

Signature verification functions exist. These are opaque — the implementations
come from libsodium/liboqs at FFI distance. The hybrid verification theorem
(`hybrid_full_requires_all`) proves that full-mode verification requires
all three schemes to pass.

## Structural Axioms

These are arithmetic facts, not security assumptions. They should be
theorems but the Lean normalizer can't close them.

### `compress_size (H : Array Word) (block : Array UInt8) (offset : Nat) : (compress H block offset).size = 8`

The SHA-256 compression function returns an 8-element array literal
(`#[H0+a, H1+b, ..., H7+h]`). This is structurally obvious but
`unfold compress; rfl` can't reduce through 64 rounds of folds with
free variables.

### `finalize_size_ax (H : Array Word) : (finalize H).size = 32`

8 words × 4 bytes = 32 bytes. `finalize` concatenates 8 calls to
`encodeBE32` (which produces 4 bytes each, proven: `encodeBE32_size : rfl`).
The 7-deep `Array.append` chain exhausts heartbeats before `simp` can close.

Both will discharge when we either raise heartbeat limits or write dedicated
`Array.size` automation. They're on the roadmap, not blocking anything.
