/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                              // continuity // build // resource
                                                                  resource.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  The coeffect algebra. Resources are what builds *require* from the
  environment. This is not effects (what builds do). This is coeffects
  (what builds need).

  Resources form a monoid under `⊗` (tensor/combine):
    `pure ⊗ r = r`               (identity)
    `(r ⊗ s) ⊗ t = r ⊗ (s ⊗ t)` (associativity)
    `r ⊆ r ⊗ s`                  (monotonicity)

  Proofs of these properties live in `Build/Properties.lean`.
-/

namespace Continuity.Build

/-- A single resource requirement. -/
inductive Resource where
  | pure                           -- needs nothing external
  | network                        -- needs network access
  | auth (provider : String)       -- needs credential
  | sandbox (name : String)        -- needs isolation
  | filesystem (path : String)     -- needs filesystem access
  deriving Repr, DecidableEq, Inhabited

/-- A set of resource requirements (combined via ⊗). -/
abbrev Resources := List Resource

namespace Resources

def pure : Resources := []
def network : Resources := [Resource.network]
def auth (provider : String) : Resources := [Resource.auth provider]
def sandbox (name : String) : Resources := [Resource.sandbox name]
def filesystem (path : String) : Resources := [Resource.filesystem path]

/-- Tensor product: combine two resource sets. -/
def combine (r s : Resources) : Resources := r ++ s

/-- `⊗` notation for resource combination. -/
instance : Append Resources := ⟨combine⟩

def isPure (r : Resources) : Bool := r.isEmpty

end Resources

end Continuity.Build
