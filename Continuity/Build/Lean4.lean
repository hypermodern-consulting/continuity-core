import Continuity.Build.Dep
import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "There was some magic chemistry in that impending darkness,
      an alchemy that folded proof terms into running code and
      axioms into conclusions. The kernel trusted nothing but each
      reduction step — one small certainty building upon another,
      like counters in a game no one could cheat. In the black,
      with nothing to see but the shape of the computation itself,
      you learned to read the type of the thing you were building
      before you ever ran it. Before you ever needed to."

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Ln

/-
  lean 4 build targets.

  defines `Binary` and `Library` target types for `lean`
  compilation. each carries source files, `Dep`endencies,
  `leanFlags`, and `Vis`ibility. the `root` field names the
  entry point (`Main.lean` for binaries, `lib.lean` for
  libraries).
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // targets
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
