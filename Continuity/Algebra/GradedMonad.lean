import Continuity.Algebra.Grade

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                        // continuity // algebra // gradedmonad
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Graded Monad — Orchard's Effect class in Lean.

  M : Grade → Type → Type

  gpure : α → M [] α
  gbind : M g₁ α → (α → M g₂ β) → M (g₁ ∪ g₂) β

  Targets Haskell via Control.Effect (effect-monad 0.9):
    instance Effect GradedM where
      type Unit GradedM = '[]
      type Plus GradedM f g = f :∪ g
      return = ...
      (>>=) = ...

  C++ carries grades as phantom template parameters:
    template<GradeLabel... Gs> struct GradedResult { T value; };
  C++ cannot discharge — discharge happens at the Haskell boundary.
-/

namespace Continuity.Algebra.GradedMonad

open Continuity.Algebra.Grade
open Grade (unit full plus subset mem isPure isReproducible)


/- ═══════════════════════════════════════════════════════════════════════════
                                                            // opaque // monad
   ═══════════════════════════════════════════════════════════════════════════ -/

opaque GradedM (g : Grade) (α : Type) : Type
@[instance] axiom GradedM.instInhabited {g : Grade} : Inhabited (GradedM g Unit)

axiom gpure {α : Type} : α → GradedM unit α
axiom gbind {α β : Type} {g₁ g₂ : Grade} :
  GradedM g₁ α → (α → GradedM g₂ β) → GradedM (plus g₁ g₂) β
axiom gmap {α β : Type} {g : Grade} : (α → β) → GradedM g α → GradedM g β
axiom gsub {α : Type} {g₁ g₂ : Grade} : subset g₁ g₂ → GradedM g₁ α → GradedM g₂ α


/- ══════════════════════════════════════════════════════════════════════════
                                                      // effect // primitives
   ══════════════════════════════════════════════════════════════════════════ -/

axiom netRequest {α : Type} : String → GradedM [Label.Net] α
axiom readAuth : String → GradedM [Label.Auth] String
axiom readFile : String → GradedM [Label.Fs] String
axiom readCA {α : Type} : String → GradedM [Label.FsCA] α
axiom logMsg : String → GradedM [Label.Log] Unit
axiom getTime : GradedM [Label.Time] Nat
axiom getRandom : Nat → GradedM [Label.Random] (List UInt8)
axiom cryptoOp {α : Type} : String → GradedM [Label.Crypto] α


/- ═══════════════════════════════════════════════════════════════════════════
                                                           // domain // grades
   ═══════════════════════════════════════════════════════════════════════════ -/

def gradeSSPHandshake : Grade := [Label.Net, Label.Crypto]
def gradeSSPAuth : Grade := [Label.Net, Label.Crypto, Label.Auth]
def gradeNixClient : Grade := [Label.Net, Label.FsCA]
def gradeCodec : Grade := unit
def gradeAttest : Grade := [Label.Auth, Label.Crypto, Label.Time]
def gradeCASWrite : Grade := unit

theorem codec_is_pure : isPure gradeCodec = true := rfl
theorem cas_write_is_pure : isPure gradeCASWrite = true := rfl
theorem codec_is_reproducible : isReproducible gradeCodec = true := rfl
theorem attest_not_reproducible : isReproducible gradeAttest = false := by native_decide
theorem ssp_not_reproducible : isReproducible gradeSSPHandshake = false := by native_decide
theorem fsca_reproducible : isReproducible [Label.FsCA] = true := by native_decide

end Continuity.Algebra.GradedMonad
