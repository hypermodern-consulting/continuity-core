import Continuity.Build.Triple
import Continuity.Build.Dep
import Continuity.Build.Resource
import Continuity.Build.Digest
import Continuity.Build.Command

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // build // action
                                                                    action.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Action — the atomic execution unit for the DICE.

  This is the true primitive. Not a derivation (Nix's monolithic unit),
  not a rule (user-facing). An Action is one command, independently
  cacheable, independently schedulable.

  The point: a CxxLibrary with 50 source files is not one Action. It's
  50 compile Actions + 1 link Action. The compiles run in parallel,
  each cached by input hash. This is what Shred.lean produces.

  The relationship to Nix: you *regroup* Actions into Derivations when
  talking to Nix (backward compat). REAPI maps 1:1 because REAPI
  Actions are this type, essentially.
-/

namespace Continuity.Build

/-- Output specification: what an action produces. -/
structure OutputSpec where
  /-- output path (relative to action root) -/
  path : String
  /-- whether this is the "primary" output for caching purposes -/
  primary : Bool := true
  deriving Repr, Inhabited

/-- The atomic execution unit.

    An Action is a pure description — no IO, no effects. It says
    "run this command with these inputs, expect these outputs, on
    this platform, requiring these resources." Determinism is
    structural: the same inputs produce the same outputs because
    the command is a function. -/
structure Action where
  /-- human-readable name: "compile foo.cpp", "link libbar.a" -/
  name      : String
  /-- what to run -/
  command   : Command
  /-- content-addressed input references -/
  inputs    : List Digest
  /-- what gets produced -/
  outputs   : List OutputSpec
  /-- coeffect requirements -/
  resources : Resources
  /-- where it runs -/
  platform  : Triple
  deriving Repr, Inhabited

/-- BuildSpec: the common interface for anything that can become Actions. -/
structure BuildSpec where
  name      : String
  deps      : List Dep
  outputs   : List String
  resources : Resources
  system    : Triple
  deriving Repr, Inhabited

/-- Typeclass for types that can be projected to a BuildSpec.
    Rule, Target, and Action all implement this. -/
class ToBuildSpec (α : Type) where
  toBuildSpec : α → BuildSpec

instance : ToBuildSpec Action where
  toBuildSpec a :=
    { name      := a.name
    , deps      := []  -- actions reference digests, not deps
    , outputs   := a.outputs.map OutputSpec.path
    , resources := a.resources
    , system    := a.platform }

end Continuity.Build
