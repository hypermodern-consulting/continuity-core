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

  sha256 is currently the only supported digest. BLAKE3 and SHA-512
  types are defined in `Crypto/Core.lean` as ByteArray stubs pending
  verified implementations.

  Wraps `SHA256Hash` — the 32-byte invariant is enforced by the type.
  Collision resistance derives from `Crypto.hash_injective`. No axioms
  in this file.
-/

open Continuity.Crypto.SHA256

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // core // hash
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure SHA256Digest where
  hash : SHA256Hash
  deriving DecidableEq

namespace SHA256Digest

def ofBytes (bs : ByteArray) : SHA256Digest :=
  ⟨hashToSHA256 bs⟩

def hex (d : SHA256Digest) : String := toHex d.hash.bytes

def render (d : SHA256Digest) : String :=
  s!"sha256:{d.hex}"

instance : Repr SHA256Digest where
  reprPrec d _ := Std.Format.text (d.render)

instance : Inhabited SHA256Digest where
  default := ofBytes ByteArray.empty

end SHA256Digest

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // property // collision
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `SHA256Digest.mk` is injective, which follows from `Crypto.hash_injective`.
theorem digest_mk_inj (a b : ByteArray)
    (h : SHA256Digest.ofBytes a = SHA256Digest.ofBytes b) :
    hashToSHA256 a = hashToSHA256 b := by
  simp only [SHA256Digest.ofBytes, SHA256Digest.mk.injEq] at h; exact h

end Continuity.Build
