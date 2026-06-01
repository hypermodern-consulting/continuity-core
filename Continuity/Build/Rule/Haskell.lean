import Continuity.Build.Core.Dependency
import Continuity.Build.Core.Vis

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Silicon's on the way out, Turner. What rests beneath — the
      irreducible, the actual layer of atoms — it's just another
      abstraction once you learn to look at it right. The builder's
      real medium isn't the substrate, silicon or gallium arsenide
      or whatever comes next. It's the structure. The clean lines of
      a well-constructed namespace. The moment the linker resolves
      every symbol without complaint. That's craft. Everything else
      is packaging, and packaging changes. The craft stays."

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Hs

/-
  haskell build targets.

  defines `Binary`, `Library`, and `FFIBinary` — the three target
  types for `ghc`-based builds. each carries source files,
  `Dep`endencies, `ghcFlags`, and `Vis`ibility. `FFIBinary` adds
  `cSrcs`, `cFlags`, and `ldFlags` for foreign-function builds.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // targets
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
