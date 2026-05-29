/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // build // digest
                                                                    digest.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Content hash. The identity type for content-addressed storage.

  We model the hash as an opaque string (hex-encoded digest) rather than
  a fixed-width BitVec because: hash algorithms vary (SHA-256, BLAKE3),
  the proof obligations are about the *properties* of hashing (collision
  resistance, determinism), not the bit layout.

  The collision resistance axiom is the one axiom in the system — it says
  "different content produces different hashes." This is not provable from
  first principles (it's a cryptographic assumption), so we declare it.
-/

namespace Continuity.Build

inductive HashAlgo where
  | sha256 | sha512 | blake3
  deriving Repr, DecidableEq, Inhabited

structure Digest where
  algo : HashAlgo
  hex  : String
  deriving Repr, DecidableEq, Inhabited

namespace Digest

def render (d : Digest) : String :=
  let pfx := match d.algo with
    | HashAlgo.sha256 => "sha256"
    | HashAlgo.sha512 => "sha512"
    | HashAlgo.blake3 => "blake3"
  s!"{pfx}:{d.hex}"

end Digest

/-- The collision resistance axiom. This is the one declared axiom in
    Continuity — everything else is proven. It says: if two byte
    sequences have the same digest, they are equal. This is a
    cryptographic assumption, not a mathematical fact. -/
axiom digest_collision_free :
  ∀ (f : ByteArray → Digest) (a b : ByteArray),
    f a = f b → a = b

end Continuity.Build
