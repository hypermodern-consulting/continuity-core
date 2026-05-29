import Continuity.Build.Triple

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                             // continuity // build // toolchain
                                                                 toolchain.lean

   "She was the white girl, the one who could access the Other Side."

                                                                 — Count Zero
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Toolchain types — what tools exist and how they're configured.
  Types + default constructors + flag rendering, all one concept.
-/

namespace Continuity.Build


/- ════════════════════════════════════════════════════════════════════════════════
                                                             // cxx toolchain
   ════════════════════════════════════════════════════════════════════════════════ -/

structure CxxToolchain where
  name          : String
  c_extra_flags : List String := []
  cxx_extra_flags : List String := []
  link_style    : String := "static"
  deriving Repr, Inhabited

def CxxToolchain.mk' (name : String) : CxxToolchain := { name }


/- ════════════════════════════════════════════════════════════════════════════════
                                                         // haskell toolchain
   ════════════════════════════════════════════════════════════════════════════════ -/

structure HaskellToolchain where
  name           : String
  compiler_flags : List String := []
  deriving Repr, Inhabited

def HaskellToolchain.mk' (name : String) : HaskellToolchain := { name }


/- ════════════════════════════════════════════════════════════════════════════════
                                                            // lean toolchain
   ════════════════════════════════════════════════════════════════════════════════ -/

structure LeanToolchain where
  name       : String
  lean_flags : List String := []
  deriving Repr, Inhabited

def LeanToolchain.mk' (name : String) : LeanToolchain := { name }


/- ════════════════════════════════════════════════════════════════════════════════
                                                            // rust toolchain
   ════════════════════════════════════════════════════════════════════════════════ -/

structure RustToolchain where
  name            : String
  default_edition : String := "2021"
  rustc_flags     : List String := []
  deriving Repr, Inhabited

def RustToolchain.mk' (name : String) : RustToolchain := { name }


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // nv toolchain
   ════════════════════════════════════════════════════════════════════════════════ -/

structure NvToolchain where
  name     : String
  nv_archs : List String := ["sm_90"]
  deriving Repr, Inhabited

def NvToolchain.mk' (name : String) : NvToolchain := { name }


/- ════════════════════════════════════════════════════════════════════════════════
                                                      // execution platform
   ════════════════════════════════════════════════════════════════════════════════ -/

structure ExecutionPlatform where
  name           : String
  local_enabled  : Bool := true
  remote_enabled : Bool := false
  deriving Repr, Inhabited

def ExecutionPlatform.mk' (name : String) : ExecutionPlatform := { name }


/- ════════════════════════════════════════════════════════════════════════════════
                                                        // bootstrap toolchains
   ════════════════════════════════════════════════════════════════════════════════ -/

structure PythonBootstrap where
  name : String
  deriving Repr, Inhabited

structure GenruleToolchain where
  name : String
  deriving Repr, Inhabited


end Continuity.Build
