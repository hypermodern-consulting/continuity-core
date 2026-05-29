/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                   // continuity // build // dep
                                                                       dep.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   "He had a grip on her wrist and she felt the panic in his hand."

                                                                 — Count Zero
-/

/-!
  Dependency references. Single source of truth — every way to reference
  a dependency lives here. No divergent Dep types between layers.
-/

namespace Continuity.Build

inductive Dep where
  /-- local target in the same repo: `:foo` or `//pkg:foo` -/
  | local (target : String)
  /-- nix flake reference: `nixpkgs#openssl`, `.#libfoo`, `github:owner/repo#pkg` -/
  | flake (ref : String)
  /-- external content-addressed artifact -/
  | external (hash : String) (name : String)
  /-- pkg-config name: `openssl`, `zlib` -/
  | pkgConfig (name : String)
  deriving Repr, DecidableEq, Inhabited

namespace Dep

def nix (pkg : String) : Dep := Dep.flake s!"nixpkgs#{pkg}"
def nixMusl (pkg : String) : Dep := Dep.flake s!"nixpkgs#pkgsMusl.{pkg}"
def nixStatic (pkg : String) : Dep := Dep.flake s!"nixpkgs#pkgsStatic.{pkg}"

end Dep

end Continuity.Build
