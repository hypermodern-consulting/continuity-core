import Continuity.Build.Vis

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "You can go home now, Turner. We're done with you. You're good
      as new. The genrules had fired, each one in its turn, pulling
      source files through a pipeline of transformations, until out
      the other end came something that looked like it had always been
      there, self-identical and reproducible, the output of a command
      that could be run again and again and would always spit out the
      same result. Because that was the point, wasn't it? Not the
      artifact itself, but the rule that produced it, the invariant
      that survived every rebuild, the promise that given the same
      inputs in the same order under the same conditions, you would
      always arrive at the same place. A kind of mechanical faith.
      The only kind some people ever had."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  General-purpose build rules.

  `Genrule` describes an arbitrary build command that produces an
  output file from a set of input sources. It is the escape hatch:
  when no specialised target type fits, `Genrule` shells out and
  trusts the command to be reproducible. Visibility controls whether
  the output is accessible outside the package.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // genrule
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
