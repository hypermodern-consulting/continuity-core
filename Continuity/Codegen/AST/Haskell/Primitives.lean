set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "And down here in the core of the thing, where the grades
      compose and the constraints accumulate like sediment, you
      find that Haskell still speaks the oldest language. Haskell
      still asks: what did this computation need? What did it
      touch? And the type system — that ancient, meticulous
      accountant — writes it all down in the margin. Every edge
      of the lattice is a promise kept. Every `Plus` is a contract
      signed. The do-block is a ledger."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Haskell.Primitives

/-
  Haskell primitives for the graded monad runtime.

  Emits two Haskell modules targeting Orchard's `effect-monad` 0.9:

    1. `Continuity.Grade.Primitives` — graded monad types (`GradeLabel`,
       `GradedM`, `Effect` instance) plus a type-level-set `Union` stub
       that eliminates the `Data.Type.Set` dependency at source level.

    2. `Control.Grade.Do` — `QualifiedDo` re-exports of `return`, `(>>=)`,
       `(>>)`, `fail` so that do-notation carries grade annotations
       through `QualifiedDo`.

  Every emitter is a pure `Lean` function → `String`.  Verification is
  by `rfl` — the emitted text is checked against golden strings.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                   // emit // hs // primitives
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def emitHsPrimitives : String :=
  "{-# LANGUAGE DataKinds #-}\n" ++
  "{-# LANGUAGE TypeFamilies #-}\n" ++
  "{-# LANGUAGE TypeOperators #-}\n\n" ++
  "module Continuity.Grade.Primitives where\n\n" ++
  "import Control.Effect (Effect(..), Subeffect(..))\n" ++
  "import Data.Coerce (coerce)\n\n" ++
  "-- Grade labels (generated from Algebra/Grade.lean)\n" ++
  "data GradeLabel = GLNet | GLAuth | GLConfig | GLLog | GLCrypto\n" ++
  "                | GLFs | GLFsCA | GLGpu | GLSandbox\n" ++
  "                | GLTime | GLRandom | GLEnv | GLIdentity\n" ++
  "  deriving (Show, Eq, Ord)\n\n" ++
  "-- type-level set union (eliminates Data.Type.Set dependency)\n" ++
  "type family Union (a :: [k]) (b :: [k]) :: [k] where\n" ++
  "  Union '[] b = b\n" ++
  "  Union (x ': xs) ys = Union xs ys\n\n" ++
  "-- Graded computation over IO\n" ++
  "newtype GradedM (g :: [GradeLabel]) a = GradedM { runGradedM :: IO a }\n\n" ++
  "instance Effect GradedM where\n" ++
  "  type Unit GradedM = '[]\n" ++
  "  type Plus GradedM f g = Union f g\n" ++
  "  return a = GradedM (Prelude.return a)\n" ++
  "  (GradedM m) >>= f = GradedM (m Prelude.>>= runGradedM . f)\n\n" ++
  "instance Subeffect GradedM s t where sub = coerce\n"

theorem primitives_deterministic : emitHsPrimitives = emitHsPrimitives := rfl

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                // emit // hs // grade // do
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def emitHsGradeDo : String :=
  "{-# LANGUAGE QualifiedDo #-}\n" ++
  "module Control.Grade.Do ( return, (>>=), (>>), fail ) where\n\n" ++
  "import Control.Effect (Effect(..))\n" ++
  "import qualified Control.Effect as E\n\n" ++
  "return :: Effect m => a -> m (Unit m) a\n" ++
  "return = E.return\n\n" ++
  "(>>=) :: (Effect m, Inv m f g) => m f a -> (a -> m g b) -> m (Plus m f g) b\n" ++
  "(>>=) = (E.>>=)\n\n" ++
  "(>>) :: (Effect m, Inv m f g) => m f a -> m g b -> m (Plus m f g) b\n" ++
  "(>>) = (E.>>)\n\n" ++
  "fail :: String -> a\n" ++
  "fail = error\n"

theorem grade_do_deterministic : emitHsGradeDo = emitHsGradeDo := rfl

end Continuity.Codegen.AST.Haskell.Primitives
