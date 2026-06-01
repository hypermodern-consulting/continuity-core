import Continuity.Crypto.SHA256
import Continuity.Algebra.Grade

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "You swim in the datastream, but you breathe through
      the wall. Every packet, every syscall, every clock
      tick leaves a residue — not an effect, but a coeffect:
      the precondition you consumed without asking. The grade
      is the contract. The discharge is the receipt. And the
      receipt had better match the contract, or the wall
      notices."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Straylight.Coeffect

open Continuity.Algebra.Grade
open Continuity.Crypto.SHA256

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                         // runtime // coeffect
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

inductive Coeffect where
  | pure
  | network (host : String) (bytes_sent : Nat) (bytes_recv : Nat) (response_hash : SHA256Hash)
  | filesystem (path : String) (reads : Nat) (writes : Nat)
  | auth (provider : String) (credential_hash : SHA256Hash)
  | sandbox (device : String) (kernel_version : String)
  | time (timestamp : UInt64)
  | random (seed_hash : SHA256Hash)
  deriving Repr, Inhabited

def Coeffect.grade : Coeffect → Grade
  | .pure => []
  | .network _ _ _ _ => [.Net]
  | .filesystem _ _ _ => [.Fs]
  | .auth _ _ => [.Auth]
  | .sandbox _ _ => [.Sandbox]
  | .time _ => [.Time]
  | .random _ => [.Random]

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                         // discharge // proof
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

structure DischargeProof where
  coeffects : List Coeffect
  declared_grade : Grade
  derivation_hash : SHA256Hash
  output_hashes : List SHA256Hash
  builder_signature : Option String
  deriving Repr, Inhabited

def DischargeProof.actual_grade (dp : DischargeProof) : Grade :=
  dp.coeffects.foldl (fun acc c => Grade.plus acc c.grade) []

def DischargeProof.valid (dp : DischargeProof) : Bool :=
  (dp.actual_grade).all (dp.declared_grade.contains ·)

end Continuity.Straylight.Coeffect
