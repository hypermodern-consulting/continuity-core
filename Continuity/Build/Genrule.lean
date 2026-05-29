import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                              // continuity // build // genrule

   "It was a voice, and not a voice."
                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

structure Genrule where
  name : String
  out  : String
  cmd  : String
  srcs : List String := []
  vis  : Vis         := Vis.«public»
  deriving Repr, Inhabited

def genrule (name : String) (out : String) (cmd : String) : Genrule :=
  { name, out, cmd }

end Continuity.Build
