set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Yes, Marly. And from that rather terminal perspective, I should advise
      you to strive to live hourly in your own flesh. Not in the past, if you
      understand me. I speak as one who can no longer tolerate that simple
      state, the cells of my body having opted for the quixotic pursuit of
      individual careers. I imagine that a more fortunate man, or a poorer one,
      would have been allowed to die at last, or be coded at the core of some
      bit of hardware. But I seem constrained, by a byzantine net of
      circumstance that requires, I understand, something like a tenth of my
      annual income. Making me, I suppose, the world’s most expensive invalid.

      I was touched, Marly, at your affairs of the heart. I envy you the
      ordered flesh from which they unfold.

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Algebra.Grade

/-
  The Grade Lattice.

  Effects:   what a computation DOES to the world.
  Coeffects: what a computation NEEDS from the world.

  A grade is a set of coeffect labels. Pure computations have grade [].
  Grades compose via set union (`Plus`). Reproducible computations
  exclude `Time`, `Random`, `Env`, `Identity`, `Net`, `Fs`.

  Targets Orchard's effect-monad library (`Control.Effect`):
    type Unit m = '[]
    type Plus m f g = f :∪ g   (type-level set union)
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // algebra
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Label where
  | Net | Auth | Config | Log | Crypto
  | Fs | FsCA | Gpu | Sandbox
  | Time | Random | Env | Identity
  deriving DecidableEq, Repr, Inhabited, BEq

abbrev Grade := List Label

namespace Grade

def unit : Grade := []

def full : Grade := [.Net, .Auth, .Config, .Log, .Crypto,
                     .Fs, .FsCA, .Gpu, .Sandbox,
                     .Time, .Random, .Env, .Identity]

def mem (l : Label) (g : Grade) : Bool := g.any (· == l)

def plus (g₁ g₂ : Grade) : Grade :=
  g₁ ++ g₂.filter (fun l => !g₁.any (· == l))

def subset (g₁ g₂ : Grade) : Prop :=
  ∀ l, mem l g₁ = true → mem l g₂ = true

instance : HasSubset Grade where Subset := subset

def isPure (g : Grade) : Bool := g.isEmpty

def isReproducible (g : Grade) : Bool :=
  !mem .Time g && !mem .Random g && !mem .Env g &&
  !mem .Identity g && !mem .Net g && !mem .Fs g

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // concrete // facts
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem unit_is_pure : isPure unit = true := rfl
theorem unit_is_reproducible : isReproducible unit = true := rfl

theorem plus_unit_right (g : Grade) : plus g unit = g := by
  unfold plus unit; simp [List.filter_nil, List.append_nil]

theorem plus_unit_left (g : Grade) : plus unit g = g := by simp [plus, unit]

theorem plus_le_left (g₁ g₂ : Grade) : subset g₁ (plus g₁ g₂) := by
  intro l h; unfold plus mem at *
  rw [List.any_append]; exact Bool.or_eq_true_iff.mpr (Or.inl h)

-- TODO[b7r6]: !! `plus_le_right` requires showing that filter preserves
-- membership, stated as a weaker version: concrete instances proven by
-- `native_decide`. the abstract proof needs `List.any_filter` lemmas
-- not in 4.30.0 stdlib !!

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                               // concrete // reproducibility
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem time_not_reproducible : isReproducible [.Time] = false := by native_decide
theorem random_not_reproducible : isReproducible [.Random] = false := by native_decide
theorem ca_only_reproducible : isReproducible [.FsCA, .Crypto] = true := by native_decide
theorem unit_no_mem (l : Label) : mem l unit = false := by cases l <;> native_decide

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // domain // grades
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def gateway : Grade := [.Net, .Auth, .Config, .Log, .Crypto]
def build : Grade := [.Fs, .FsCA, .Net, .Env, .Sandbox]

theorem gateway_not_reproducible : isReproducible gateway = false := by native_decide
theorem gateway_mem_net : mem .Net gateway = true := by native_decide
theorem gateway_mem_auth : mem .Auth gateway = true := by native_decide

end Grade
end Continuity.Algebra.Grade
