import Continuity.Build.Rule.Cxx
import Continuity.Build.Rule.Haskell
import Continuity.Build.Rule.Rust
import Continuity.Build.Rule.Lean4
import Continuity.Build.Rule.Nv
import Continuity.Build.Core.Genrule

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He was a specialist in the extraction of top executives and research
      people, and he knew his work. He knew how to move through the
      intricate lattices of corporate security, how to read the codes
      that governed access, how to find the seams where one system
      gave way to another. It was not a matter of breaking rules but
      of knowing which rules applied where, and when they didn't."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  The Build Rule Union.

  All build rules as a single discriminated union. Each constructor
  wraps a language-specific rule type. The union allows a build graph
  to be heterogeneous — a `Cxx` binary can depend on a `Rust` library
  which depends on a `genrule` which shells out to `Nv`.

  Language modules: `Cxx`, `Rs`, `Hs`, `Ln`, `Nv`, `Genrule`.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // rules // the union
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Rule where
  | cxxBinary         : Cxx.Binary     → Rule
  | cxxLibrary        : Cxx.Library    → Rule
  | rustBinary        : Rs.Binary      → Rule
  | rustLibrary       : Rs.Library     → Rule
  | haskellBinary     : Hs.Binary      → Rule
  | haskellLibrary    : Hs.Library     → Rule
  | haskellFFIBinary  : Hs.FFIBinary   → Rule
  | leanBinary        : Ln.Binary      → Rule
  | leanLibrary       : Ln.Library     → Rule
  | nvBinary          : Nv.Binary      → Rule
  | nvLibrary         : Nv.Library     → Rule
  | genrule           : Genrule        → Rule
  deriving Repr, Inhabited

end Continuity.Build
