import Continuity.Build.Dep
import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               // continuity // build // haskell

   "Legba, Ougou Feray, Bakoulou Baka, Petro Simbi, you will
    have what I have, my horse, all my horses."
                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Hs

structure Binary where
  name     : String
  srcs     : List String
  deps     : List Dep
  main     : String      := "Main"
  ghcFlags : List String := []
  vis      : Vis         := Vis.«public»
  deriving Repr, Inhabited

def binary (name : String) (srcs : List String) (deps : List Dep) : Binary :=
  { name, srcs, deps }

structure Library where
  name     : String
  srcs     : List String
  deps     : List Dep
  modules  : List String := []
  ghcFlags : List String := []
  vis      : Vis         := Vis.«public»
  deriving Repr, Inhabited

def library (name : String) (srcs : List String) (deps : List Dep) : Library :=
  { name, srcs, deps }

structure FFIBinary where
  name     : String
  srcs     : List String
  cSrcs    : List String
  deps     : List Dep
  main     : String      := "Main"
  ghcFlags : List String := []
  cFlags   : List String := []
  ldFlags  : List String := []
  vis      : Vis         := Vis.«public»
  deriving Repr, Inhabited

def ffiBinary (name : String) (srcs : List String) (cSrcs : List String) (deps : List Dep) : FFIBinary :=
  { name, srcs, cSrcs, deps }

end Continuity.Build.Hs
