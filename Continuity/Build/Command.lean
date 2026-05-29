/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               // continuity // build // command
                                                                   command.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Command: the execution specification for an action.

  A command is a program + args + env. It does not carry the inputs
  or outputs — those live on the Action. The command is "what to run,"
  the Action is "what to run with what."

  This type is deliberately minimal. No IO, no effects. A command
  is a pure description of an invocation.
-/

namespace Continuity.Build

structure Command where
  /-- program to execute (absolute path or PATH-resolved) -/
  program : String
  /-- arguments -/
  args : List String := []
  /-- environment variables (key-value pairs) -/
  env : List (String × String) := []
  /-- working directory (relative to sandbox root) -/
  workDir : Option String := Option.none
  deriving Repr, Inhabited

end Continuity.Build
