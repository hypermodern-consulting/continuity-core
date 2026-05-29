/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                   // continuity // build // vis
                                                                       vis.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-- Target visibility. `«private»` uses Lean's name-quoting
    syntax to escape the keyword. -/
inductive Vis where
  | «public» | «private»
  deriving Repr, DecidableEq, Inhabited

end Continuity.Build
