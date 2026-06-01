set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Because he had a good agent, he had a good contract. And
      because he had a good contract, the dependencies were all
      pinned down, immutable, each one referenced by a name that
      could not be repointed and a hash that could not be altered.
      Nothing crept in. No version drift, no breaking changes,
      no transitive nightmare where one library pulled in another
      that pulled in a third that had been abandoned three years ago
      by a developer who had since left the planet. The system held
      together because each piece knew exactly what it needed from
      every other piece, and no piece asked for more than it could
      give, and the whole thing was rendered down to a single,
      unambiguous DAG you could walk from leaf to root with your
      eyes closed."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  Dependency references.

  Single source of truth — every way to reference a dependency lives
  here. `Dep` is a closed inductive covering local targets, `Nix`
  flakes, content-addressed `External` artifacts, and `pkg-config`
  names. Helper constructors in the `Dep` namespace provide ergonomic
  shorthand for common `Nix` package patterns.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // core // dependency
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Dep where
  -- local target in the same repo: `:foo` or `//pkg:foo`
  | local (target : String)
  -- `Nix` flake reference: `nixpkgs#openssl`, `.#libfoo`, `github:owner/repo#pkg`
  | flake (ref : String)
  -- external content-addressed artifact
  | external (hash : String) (name : String)
  -- `pkg-config` name
  | pkgConfig (name : String)
  deriving Repr, DecidableEq, Inhabited

namespace Dep

def nix (pkg : String) : Dep := Dep.flake s!"nixpkgs#{pkg}"
def nixMusl (pkg : String) : Dep := Dep.flake s!"nixpkgs#pkgsMusl.{pkg}"
def nixStatic (pkg : String) : Dep := Dep.flake s!"nixpkgs#pkgsStatic.{pkg}"

end Dep

end Continuity.Build
