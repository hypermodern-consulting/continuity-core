import Continuity.Build.Dep
import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                  // continuity // build // nv

   "The cores. The cores told her when to flee, when to lie still."
                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Nv

structure Binary where
  name  : String
  srcs  : List String
  deps  : List Dep    := []
  archs : List String := []
  vis   : Vis         := Vis.«public»
  deriving Repr, Inhabited

def binary (name : String) (srcs : List String) : Binary := { name, srcs }

structure Library where
  name             : String
  srcs             : List String
  exported_headers : List String := []
  deps             : List Dep    := []
  archs            : List String := []
  vis              : Vis         := Vis.«public»
  deriving Repr, Inhabited

def library (name : String) (srcs : List String) : Library := { name, srcs }

end Continuity.Build.Nv
