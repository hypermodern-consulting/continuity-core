set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "You make me think about horses, Marly had said,
      and he had laughed because he understood exactly
      what she meant. A command is not a negotiation. It
      enters the world complete and armed — its arguments
      shaped like the saddle, its environment the stall
      in which the thing is born. You give it a name,
      you give it the words, and it runs. Or it doesn't.
      Either way, the world is different after, and
      whatever was inside the box has already changed
      everything outside it."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  `Command`: the execution specification for an `Action`.

  A command is a program + args + env. It does not carry the inputs
  or outputs — those live on the `Action`. The command is "what to run,"
  the `Action` is "what to run with what."

  This type is deliberately minimal. No `IO`, no effects. A command
  is a pure description of an invocation.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // command
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure Command where
  -- program to execute (absolute path or `PATH`-resolved)
  program : String
  -- arguments
  args : List String := []
  -- environment variables (key-value pairs)
  env : List (String × String) := []
  -- working directory (relative to sandbox root)
  workDir : Option String := Option.none
  deriving Repr, Inhabited

end Continuity.Build
