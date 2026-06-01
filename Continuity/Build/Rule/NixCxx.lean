import Continuity.Build.Core.Vis

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The Finn's code was weird but it worked. It was assembled out
      of parts that didn't belong together — a Nix expression here, a
      C++ template there, the whole thing held together by a build
      system that seemed to have been written by someone who thought
      determinism was a moral imperative and reproducibility was the
      only virtue that mattered. When it compiled, it compiled the
      same way every time, down to the bit, and when it didn't compile
      it told you exactly why in language that made you feel like the
      error was somehow your fault for not understanding the universe
      well enough."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Rule.NixCxx

/-
  Nix-based C++ build targets.

  `NixCxxBinary` describes an executable built with Nix-provided
  toolchains and libraries. Source files, Nix dependencies, C++
  library dependencies, and compiler/linker flags are all explicit.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                  // nixcxx // nixcxxbinary
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure NixCxxBinary where
  name           : String
  srcs           : List String
  nix_deps       : List String
  deps           : List String := []
  compiler_flags : List String := []
  linker_flags   : List String := []
  vis            : Vis
  deriving Repr, Inhabited

end Continuity.Build.Rule.NixCxx
