set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The mindless glide of the thing, Marly thought, watching it move
      through the display. Visibility is a kind of vulnerability here.
      What you see can see you back. In the matrix, things only exist
      when they are observed — the private unobserved in their blind
      sectors, the public rendered in lines of neon geometry, every
      surface tagged with the implicit permissions that govern access.

      She remembered the boxes: Cornell's sealed worlds, some of them
      with their backs turned to the glass, private even in display.
      Not everything was meant to be looked at."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  Target Visibility.

  A build target is either `public` — visible to dependents outside
  its `BUCK` file — or `private` — visible only within the file that
  defines it. `«private»` uses `Lean`'s name-quoting syntax to escape
  the keyword.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // core // vis
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Vis where
  | «public» | «private»
  deriving Repr, DecidableEq, Inhabited

end Continuity.Build
