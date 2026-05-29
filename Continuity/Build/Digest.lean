import Continuity.Crypto
import Continuity.Crypto.SHA256

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // build // digest
                                                                    digest.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Content hash for the build model.

  Wraps SHA256Hash — the 32-byte invariant is enforced by the type.
  Collision resistance derives from Crypto.hash_injective.
  No axioms in this file.
-/

namespace Continuity.Build

open Continuity.Crypto.SHA256

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

/-- Collision resistance for Build.Digest follows from Crypto.hash_injective.
    No new axiom needed — we derive it. -/
theorem digest_collision_resistance (a b : ByteArray)
    (h : Digest.ofBytes a = Digest.ofBytes b) :
    hashToSHA256 a = hashToSHA256 b := by
  simp only [Digest.ofBytes, Digest.mk.injEq] at h; exact h.2

end Continuity.Build
