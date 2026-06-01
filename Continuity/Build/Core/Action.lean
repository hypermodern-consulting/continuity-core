import Continuity.Build.Core.Triple
import Continuity.Build.Core.Dependency
import Continuity.Build.Core.Resource
import Continuity.Build.Core.Digest
import Continuity.Build.Core.Command

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He flew on. His credit chip was a rectangle of black
      mirror, edged with gold, and each transaction it
      authorized was atomic — indivisible, a single event
      that either completed or did not. No intermediate
      state was ever visible to the vast distributed
      ledger that consumed his life in microsecond
      increments. He had learned, years ago in a back-
      alley bar in Chiba, that the secret to surviving
      any complex system was to break it down. One
      action. One consequence. One hash. Never think
      about the second until the first has left its
      signature in the world."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  `Action` — the atomic execution unit for the DICE.

  This is the true primitive. Not a derivation (`Nix`'s monolithic unit),
  not a rule (user-facing). An `Action` is one command, independently
  cacheable, independently schedulable.

  The point: a `CxxLibrary` with 50 source files is not one `Action`. It's
  50 compile `Action`s + 1 link `Action`. The compiles run in parallel,
  each cached by input hash. This is what `Shred.lean` produces.

  The relationship to `Nix`: you *regroup* `Action`s into `Derivation`s when
  talking to `Nix` (backward compat). `REAPI` maps 1:1 because `REAPI`
  `Action`s are this type, essentially.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // output spec
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- output specification: what an `Action` produces.
structure OutputSpec where
  -- output path (relative to action root)
  path : String
  -- whether this is the "primary" output for caching purposes
  primary : Bool := true
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                   // action
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- the atomic execution unit: a pure description with no `IO`, no effects.
-- it says "run this command with these inputs, expect these outputs, on
-- this platform, requiring these resources." determinism is structural:
-- the same inputs produce the same outputs because the command is a function.
structure Action where
  -- human-readable name: "compile foo.cpp", "link libbar.a"
  name      : String
  -- what to run
  command   : Command
  -- content-addressed input references
  inputs    : List SHA256Digest
  -- what gets produced
  outputs   : List OutputSpec
  -- coeffect requirements
  resources : Resources
  -- where it runs
  platform  : Triple
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // build spec
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- the common interface for anything that can become `Action`s.
structure BuildSpec where
  name      : String
  deps      : List Dep
  outputs   : List String
  resources : Resources
  system    : Triple
  deriving Repr, Inhabited

-- typeclass for types that can be projected to a `BuildSpec`.
-- `Rule`, `Target`, and `Action` all implement this.
class ToBuildSpec (α : Type) where
  toBuildSpec : α → BuildSpec

instance : ToBuildSpec Action where
  toBuildSpec a :=
    { name      := a.name
    , deps      := []  -- `Action`s reference `SHA256Digest`s, not `Dep`s
    , outputs   := a.outputs.map OutputSpec.path
    , resources := a.resources
    , system    := a.platform }

end Continuity.Build
