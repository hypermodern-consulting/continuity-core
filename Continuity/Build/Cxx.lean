import Continuity.Build.Dep
import Continuity.Build.Vis

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The breakers rolled in, their edges as clear as green glass,
      each one a construct assembled from smaller units, linked
      together by a protocol no one had formalised but everyone who
      built code understood. Some of them carried flags, invisible
      to the human eye, that declared the standard under which they
      had been compiled; others were silent, their provenance
      obscured by layers of linking and a history no linker could
      fully resolve. It hardly mattered. What mattered was that at
      the point of contact, where wave met shore, every symbol found
      its definition and nothing segfaulted into the void. There were
      those who compiled with different flags, or against different
      headers, and for them the waves broke differently, if they
      broke at all. Most of them wrote libraries and never saw the
      ocean."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Cxx

/-
  C++ build targets.

  `CxxStd` enumerates supported C++ language standards. `Binary`
  describes an executable target: source files, dependencies,
  compilation flags, and visibility. `Library` extends this with
  exported header files.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // core // standards
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive CxxStd where
  | cxx11 | cxx14 | cxx17 | cxx20 | cxx23
  deriving Repr, DecidableEq, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // core // binary
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // library
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
