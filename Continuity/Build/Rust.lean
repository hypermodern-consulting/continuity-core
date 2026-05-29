import Continuity.Build.Dep
import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // build // rust

   "The mall crowds were a faceless blur of motion."
                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Rs

inductive Edition where
  | e2015 | e2018 | e2021 | e2024
  deriving Repr, DecidableEq, Inhabited

structure Binary where
  name      : String
  srcs      : List String
  deps      : List Dep
  edition   : Edition     := Edition.e2021
  features  : List String := []
  rustflags : List String := []
  vis       : Vis         := Vis.«public»
  deriving Repr, Inhabited

def binary (name : String) (srcs : List String) (deps : List Dep) : Binary :=
  { name, srcs, deps }

structure Library where
  name       : String
  srcs       : List String
  deps       : List Dep
  edition    : Edition          := Edition.e2021
  crate_name : Option String    := Option.none
  features   : List String      := []
  proc_macro : Bool             := false
  vis        : Vis              := Vis.«public»
  deriving Repr, Inhabited

def library (name : String) (srcs : List String) (deps : List Dep) : Library :=
  { name, srcs, deps }

end Continuity.Build.Rs
