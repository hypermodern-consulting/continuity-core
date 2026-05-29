import Continuity.Build.Dep
import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                   // continuity // build // cxx

   "The Ono-Sendai Cyberspace 7 was the most powerful computer that Bobby
    had ever seen."
                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Cxx

inductive CxxStd where
  | cxx11 | cxx14 | cxx17 | cxx20 | cxx23
  deriving Repr, DecidableEq, Inhabited

structure Binary where
  name    : String
  srcs    : List String
  deps    : List Dep
  std     : CxxStd      := CxxStd.cxx17
  cflags  : List String  := []
  ldflags : List String  := []
  vis     : Vis          := Vis.«public»
  deriving Repr, Inhabited

def binary (name : String) (srcs : List String) (deps : List Dep) : Binary :=
  { name, srcs, deps }

structure Library where
  name   : String
  srcs   : List String
  hdrs   : List String   := []
  deps   : List Dep
  std    : CxxStd        := CxxStd.cxx17
  cflags : List String   := []
  vis    : Vis           := Vis.«public»
  deriving Repr, Inhabited

def library (name : String) (srcs : List String) (deps : List Dep) : Library :=
  { name, srcs, deps }

end Continuity.Build.Cxx
