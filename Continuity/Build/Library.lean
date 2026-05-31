import Continuity.Build.Dep

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               // continuity // build // library
                                                                  library.lean

   "The cores knew the names of every library in the grid."
                                                               — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Library dependency types.

  A LibDep describes what a project needs (curl, zlib, simdjson).
  Nix resolves each one to store paths. The resolved form flows
  through Dhall into Buck2 as prebuilt_cxx_library targets.

  No upstream package managers. Nix is the package manager.
-/

namespace Continuity.Build

/-- An unresolved library dependency — what the project declares it needs. -/
structure LibDep where
  /-- Library name used in Buck2 targets: `//third-party:curl` -/
  name    : String
  /-- Nix flake reference: `"nixpkgs#curl"` -/
  flake   : String
  /-- Override: separate dev output for headers (default: derived from flake) -/
  flakeDev : Option String := Option.none
  /-- Link flags if not derivable: `["-lcurl"]` -/
  libs    : List String := []
  /-- pkg-config name if different from name -/
  pc      : Option String := Option.none
  deriving Repr, Inhabited

/-- A resolved library — after Nix fills in store paths. -/
structure ResolvedLib where
  /-- Library name -/
  name       : String
  /-- Absolute path to header directory -/
  includeDir : String
  /-- Absolute path to library directory -/
  libDir     : String
  /-- Link flags: `["-lcurl"]` -/
  libs       : List String
  deriving Repr, Inhabited

/-- A project's library specification. -/
structure LibSpec where
  /-- C/C++ libraries -/
  cxx     : List LibDep := []
  /-- Haskell packages (resolved by ghcWithPackages, not cabal) -/
  haskell : List String := []
  deriving Repr, Inhabited

end Continuity.Build
