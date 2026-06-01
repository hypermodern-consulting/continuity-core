import Continuity.Build.Dep

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The exceedingly rich were no longer even remotely human.
      They'd become something else — constellations of obligation,
      vast networks of dependency woven so tightly that no single
      thread could be cut without threatening the whole. Every
      component owed its existence to a dozen others, and every
      resolution was a fragile truce between competing versions
      of the world. The trick, if you wanted to survive in their
      gravity, was knowing which dependencies were load-bearing
      and which could be vendored away."

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  library dependency types.

  a `LibDep` describes what a project needs (`curl`, `zlib`,
  `simdjson`). `Nix` resolves each one to store paths. the
  resolved form flows through `Dhall` into `Buck2` as
  `prebuilt_cxx_library` targets.

  no upstream package managers. `Nix` is the package manager.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // deps // library
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure LibDep where
  name     : String
  flake    : String
  flakeDev : Option String := Option.none
  libs     : List String := []
  pc       : Option String := Option.none
  deriving Repr, Inhabited

structure ResolvedLib where
  name       : String
  includeDir : String
  libDir     : String
  libs       : List String
  deriving Repr, Inhabited

structure LibSpec where
  cxx     : List LibDep := []
  haskell : List String := []
  deriving Repr, Inhabited

end Continuity.Build
