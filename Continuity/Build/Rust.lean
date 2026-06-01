import Continuity.Build.Dep
import Continuity.Build.Vis

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Mitchell's the man who made biochips work, essentially. The whole
      biosoft industry. He took the basic concepts of biochip design
      and turned them into something you could build on, something
      that scaled. Before Mitchell, the theory was there but nobody
      could make it stable enough for production. He found the rules
      that made the stack hold together."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Rs

/-
  Rust Build Rules.

  `Binary` and `Library` targets with edition tracking, feature flags,
  proc-macro support, and visibility control. The `Rs` abbreviation
  keeps the rule union in `Build/Rule.lean` compact.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // rust // edition
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Edition where
  | e2015 | e2018 | e2021 | e2024
  deriving Repr, DecidableEq, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // rust // binary
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // rust // library
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
