import Continuity.Build.Dep
import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               // continuity // build // lean4

   "There's no there, there. They taught that to children, something
    about the net ..."
                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Ln

structure Binary where
  name      : String
  srcs      : List String
  deps      : List Dep
  root      : String      := "Main.lean"
  leanFlags : List String  := []
  vis       : Vis          := Vis.«public»
  deriving Repr, Inhabited

def binary (name : String) (srcs : List String) (deps : List Dep) : Binary :=
  { name, srcs, deps }

structure Library where
  name      : String
  srcs      : List String
  deps      : List Dep
  root      : String      := "lib.lean"
  leanFlags : List String  := []
  vis       : Vis          := Vis.«public»
  deriving Repr, Inhabited

def library (name : String) (srcs : List String) (deps : List Dep) : Library :=
  { name, srcs, deps }

end Continuity.Build.Ln
