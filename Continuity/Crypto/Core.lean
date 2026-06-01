set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                        // continuity // crypto
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Cryptographic primitives. Opaque types, axiomatized properties.

  Trust distance 1: we assume SHA-256 collision resistance,
  Ed25519 unforgeability, ML-DSA/SLH-DSA security. These are
  mathematical conjectures about specific functions. The implementations
  are kernel-distance (Crypto/SHA256.lean) or FFI-distance.

  Post-quantum: ML-DSA (FIPS 204), SLH-DSA (FIPS 205), ML-KEM (FIPS 203).
  Hybrid mode: attacker must break ALL schemes to compromise.
-/

namespace Continuity.Crypto.Core


/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                             // opaque // types
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

opaque Hash : Type
@[instance] axiom Hash.instInhabited : Inhabited Hash
@[instance] axiom Hash.instDecidableEq : DecidableEq Hash
@[instance] axiom Hash.instRepr : Repr Hash
@[instance] axiom Hash.instBEq : BEq Hash

opaque Ed25519PublicKey : Type
@[instance] axiom Ed25519PublicKey.instInhabited : Inhabited Ed25519PublicKey
@[instance] axiom Ed25519PublicKey.instDecidableEq : DecidableEq Ed25519PublicKey

opaque Ed25519Signature : Type
@[instance] axiom Ed25519Signature.instInhabited : Inhabited Ed25519Signature

opaque MLDSAPublicKey : Type
@[instance] axiom MLDSAPublicKey.instInhabited : Inhabited MLDSAPublicKey

opaque MLDSASignature : Type
@[instance] axiom MLDSASignature.instInhabited : Inhabited MLDSASignature

opaque SLHDSAPublicKey : Type
@[instance] axiom SLHDSAPublicKey.instInhabited : Inhabited SLHDSAPublicKey

opaque SLHDSASignature : Type
@[instance] axiom SLHDSASignature.instInhabited : Inhabited SLHDSASignature


/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                              // hash // axioms
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

axiom hash_bytes : ByteArray → Hash

/-- Random oracle idealization: SHA-256 as injective function.
    Strictly stronger than collision resistance. Standard in formal
    verification of crypto protocols (Bellare & Rogaway 1993).
    If this fails, Git/Nix/Docker/Bitcoin all break — not just us. -/
axiom hash_injective (a b : ByteArray) : hash_bytes a = hash_bytes b → a = b


/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                         // signature // axioms
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

axiom ed25519_verify : Ed25519PublicKey → Hash → Ed25519Signature → Bool
axiom mldsa_verify : MLDSAPublicKey → Hash → MLDSASignature → Bool
axiom slhdsa_verify : SLHDSAPublicKey → Hash → SLHDSASignature → Bool

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                        // hybrid verification
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

structure HybridPublicKey where
  ed25519 : Ed25519PublicKey
  mldsa : MLDSAPublicKey
  slhdsa : SLHDSAPublicKey

structure HybridSignature where
  ed25519 : Ed25519Signature
  mldsa : MLDSASignature
  slhdsa : SLHDSASignature

inductive VerifyMode where
  | fast       -- ed25519 + ML-DSA
  | full       -- all three
  | classical  -- ed25519 only (fallback)
  deriving DecidableEq, Repr, Inhabited

noncomputable def hybridVerify (pk : HybridPublicKey) (msg : Hash)
    (sig : HybridSignature) (mode : VerifyMode := .fast) : Bool :=
    
  match mode with
  | .fast => ed25519_verify pk.ed25519 msg sig.ed25519 &&
             mldsa_verify pk.mldsa msg sig.mldsa
  | .full => ed25519_verify pk.ed25519 msg sig.ed25519 &&
             mldsa_verify pk.mldsa msg sig.mldsa &&
             slhdsa_verify pk.slhdsa msg sig.slhdsa
  | .classical => ed25519_verify pk.ed25519 msg sig.ed25519

theorem hybrid_fast_requires_both (pk : HybridPublicKey) (msg : Hash) (sig : HybridSignature)
    (h : hybridVerify pk msg sig .fast = true) :
    ed25519_verify pk.ed25519 msg sig.ed25519 = true ∧
    mldsa_verify pk.mldsa msg sig.mldsa = true := by
    
  simp only [hybridVerify, Bool.and_eq_true] at h; exact h

theorem hybrid_full_requires_all (pk : HybridPublicKey) (msg : Hash) (sig : HybridSignature)
    (h : hybridVerify pk msg sig .full = true) :
    ed25519_verify pk.ed25519 msg sig.ed25519 = true ∧
    mldsa_verify pk.mldsa msg sig.mldsa = true ∧
    slhdsa_verify pk.slhdsa msg sig.slhdsa = true := by
  simp only [hybridVerify, Bool.and_eq_true] at h
  
  obtain ⟨h12, h3⟩ := h; obtain ⟨h1, h2⟩ := h12; exact ⟨h1, h2, h3⟩

end Continuity.Crypto.Core
