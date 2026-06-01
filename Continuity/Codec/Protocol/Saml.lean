import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "It was such an easy thing, death. He saw that now:
      it just happened. You didn't have to assert anything,
      didn't need to sign your name against some remote
      authority or wrap your identity in a payload that
      someone else would have to verify. You just stopped.
      There was no scanner waiting to extract the claim
      from your final bytes, no wrapping attack to prevent.
      The whole thing was a function whose only side effect
      was its own absence."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Saml

/-
  `SAML` assertion scanning with wrapping attack prevention.

  `findElement` locates named elements in XML without an XML
  parser, bounding search in O(n). `verify` is the only path
  from `UnverifiedAssertion` to `VerifiedAssertion`, ensuring
  identity claims can only be extracted from signed bytes.
-/

open Continuity.Codec.Core.Box Continuity.Codec.Core.Scanner

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // core // scanning
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def findElement (qname : String) (bs : Bytes) : Option (Bytes × Bytes) :=
  let openPfx := ("<" ++ qname).toUTF8
  let closeTag := ("</" ++ qname ++ ">").toUTF8
  let rec go (searchFrom : Nat) (fuel : Nat) : Option (Bytes × Bytes) :=
    match fuel with
    | 0 => none
    | fuel' + 1 =>
      match findBytes openPfx (bs.extract searchFrom bs.size) with
      | some relIdx =>
        let absIdx := searchFrom + relIdx
        let afterName := absIdx + openPfx.size
        if afterName < bs.size then
          let c := bs.data[afterName]!
          if c == 0x3E || c == 0x20 || c == 0x09 || c == 0x2F then
            match findByte 0x3E (bs.extract absIdx bs.size) with
            | some gtOff =>
              let contentStart := absIdx + gtOff + 1
              match findBytes closeTag (bs.extract contentStart bs.size) with
              | some endOff =>
                some (bs.extract (absIdx + openPfx.size) (absIdx + gtOff),
                      (bs.extract contentStart bs.size).extract 0 endOff)
              | none => none
            | none => none
          else go (absIdx + 1) fuel'
        else none
      | none => none
  go 0 bs.size

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // core // assertion
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure SignedPayload where
  signedBytes : Bytes
  signatureValue : Bytes

structure UnverifiedAssertion where
  issuer : String
  nameId : String
  conditions : Option Bytes
  signedPayload : SignedPayload

structure VerifiedAssertion where
  issuer : String
  nameId : String
  conditions : Option Bytes

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                 // core // verification
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- only way to get a `VerifiedAssertion`: pass signature verification
def verify (ua : UnverifiedAssertion)
    (verifyFn : Bytes → Bytes → Bool) : Option VerifiedAssertion :=
  if verifyFn ua.signedPayload.signedBytes ua.signedPayload.signatureValue then
    some ⟨ua.issuer, ua.nameId, ua.conditions⟩
  else none

theorem no_unverified_identity (ua : UnverifiedAssertion) (vf : Bytes → Bytes → Bool)
    (h : vf ua.signedPayload.signedBytes ua.signedPayload.signatureValue = false) :
    verify ua vf = none := by
  simp [verify, h]

end Continuity.Codec.Protocol.Saml
