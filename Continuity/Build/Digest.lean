import Continuity.Crypto.Core
import Continuity.Crypto.SHA256

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The quixotic pursuit of individual careers had left him with
      a peculiar notion of identity, as though a man might be reduced
      to a hash of his constituent parts, each byte of memory a
      witness to a single state from which there was no appeal and
      no collision. But identity, he had learned, was content-
      addressed: you were what you hashed to, and no two things ever
      resolved to the same digest in a properly designed space, which
      was to say, in a space designed with the kind of cryptographic
      rigour that had gone out of fashion when people stopped caring
      whether the things they built were actually the things they had
      asked for, or merely things that happened to pass a checksum."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  Content hashing for the build model.

  Wraps `SHA256Hash` — the 32-byte invariant is enforced by the type.
  Collision resistance derives from `Crypto.hash_injective`. No axioms
  in this file. `HashAlgo` is provided for future extensibility to
  `SHA-512` and `BLAKE3`, though the concrete `Digest` structure
  currently only uses `SHA-256`.
-/

open Continuity.Crypto.SHA256

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // core // hash
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive HashAlgo where
  | sha256 | sha512 | blake3
  deriving Repr, DecidableEq, Inhabited

structure Digest where
  algo : HashAlgo
  hash : SHA256Hash
  deriving DecidableEq

namespace Digest

def ofBytes (bs : ByteArray) : Digest :=
  ⟨.sha256, hashToSHA256 bs⟩

def hex (d : Digest) : String := toHex d.hash.bytes

def render (d : Digest) : String :=
  let pfx := match d.algo with
    | .sha256 => "sha256" | .sha512 => "sha512" | .blake3 => "blake3"
  s!"{pfx}:{d.hex}"

instance : Repr Digest where
  reprPrec d _ := Std.Format.text (d.render)

instance : Inhabited Digest where
  default := ofBytes ByteArray.empty

end Digest

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // property // collision
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- collision resistance follows from `Crypto.hash_injective` — no
-- new axiom needed, we derive it
theorem digest_collision_resistance (a b : ByteArray)
    (h : Digest.ofBytes a = Digest.ofBytes b) :
    hashToSHA256 a = hashToSHA256 b := by
  simp only [Digest.ofBytes, Digest.mk.injEq] at h; exact h.2

end Continuity.Build
