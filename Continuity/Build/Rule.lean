import Continuity.Build.Cxx
import Continuity.Build.Haskell
import Continuity.Build.Rust
import Continuity.Build.Lean4
import Continuity.Build.Nv
import Continuity.Build.Genrule

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // build // rule

   "The Finn, Bobby remembered, was a dealer in stolen anything."
                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-! Rule union — all build rules as a single discriminated union. -/

namespace Continuity.Build

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
