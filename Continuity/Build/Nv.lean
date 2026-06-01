import Continuity.Build.Dep
import Continuity.Build.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He remembered a dead bat pressed flat as a dry leaf on
      runway concrete, wings spread in a final, unintended symmetry
      — something meant for the dark and the air, flattened onto
      the hard geometry of the ground. Like a computation mapped
      to silicon, like a kernel launched across a grid of cores
      that didn't care what it had been when it was still alive
      and flying. The architecture was always there, waiting in
      the chip; you just had to learn to see it in the ruins of
      whatever had come before."

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Nv

/-
  native build targets.

  defines `Binary` and `Library` target types for native
  compilation (`c`, `cuda`). each carries source files,
  `Dep`endencies, target `archs`, and `Vis`ibility. `Library`
  adds `exported_headers` for `#include` consumers.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // targets
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
