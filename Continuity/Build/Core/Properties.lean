import Continuity.Build.Core.Resource

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The box was a universe, a poem, frozen on the
       boundaries of human experience."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Core.Properties

/-
  Resource Coeffect Properties.

  Proofs that the `Resource` monoid satisifies the required algebraic
  laws: identity, associativity, and monotonicity. These theorems
  establish that `Resources` forms a partially-ordered monoid under
  `combine`, justifying the coeffects model used by the build system.
-/

open Continuity.Build

theorem combine_pure_left (r : Resources) : Resources.combine Resources.pure r = r := by
  simp [Resources.combine, Resources.pure, List.append]

theorem combine_pure_right (r : Resources) : Resources.combine r Resources.pure = r := by
  simp [Resources.combine, Resources.pure, List.append]

theorem combine_assoc (r s t : Resources) : Resources.combine (Resources.combine r s) t = Resources.combine r (Resources.combine s t) := by
  simp [Resources.combine, List.append_assoc]

theorem combine_subset_left (r s : Resources) : r ⊆ Resources.combine r s := by
  simp [Resources.combine, List.subset_append_left]

theorem combine_subset_right (r s : Resources) : s ⊆ Resources.combine r s := by
  simp [Resources.combine, List.subset_append_right]

end Continuity.Build.Core.Properties
