set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "I envy you the ordered flesh from which they unfold. I speak as one
      who can no longer tolerate that simple state, the cells of my body
      having opted for the quixotic pursuit of individual careers. A more
      fortunate man would have been allowed to die at last, or be coded
      at the core of some bit of hardware. But I seem constrained, by a
      byzantine net of circumstance that requires, I understand, something
      like a tenth of my annual income."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  The Resource Coeffect Algebra.

  Resources are what builds *require* from the environment — not what
  they *do* (effects), but what they *need* (coeffects). A build that
  reads `/etc/hosts` demands `filesystem`. A build that fetches from
  `$ARTIFACTORY` demands `network`. Pure computations demand nothing.

  Resources form a monoid under `⊗` (combine):
    `pure ⊗ r = r`               (identity)
    `(r ⊗ s) ⊗ t = r ⊗ (s ⊗ t)` (associativity)
    `r ⊆ r ⊗ s`                  (monotonicity)

  Proofs of these properties live in `Build/Properties.lean`.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                   // core // resource algebra
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Resource where
  | pure
  | network
  | auth (provider : String)
  | sandbox (name : String)
  | filesystem (path : String)
  deriving Repr, DecidableEq, Inhabited

abbrev Resources := List Resource

namespace Resources

def pure : Resources := []
def network : Resources := [Resource.network]
def auth (provider : String) : Resources := [Resource.auth provider]
def sandbox (name : String) : Resources := [Resource.sandbox name]
def filesystem (path : String) : Resources := [Resource.filesystem path]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                   // combine
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def combine (r s : Resources) : Resources := r ++ s

instance : Append Resources := ⟨combine⟩

def isPure (r : Resources) : Bool := r.isEmpty

end Resources
end Continuity.Build
