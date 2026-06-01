import Continuity.Build.Triple

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The knob was ridiculous, handmade, baleful; it was there to welcome
      him back to Mexico, to the Conroy place, to the dry heat and the
      high white walls and the bougainvillea drooping from the roof of
      the veranda. Each tool in this place had a history, a provenance,
      a reason for being exactly where it was. Someone had chosen every
      piece with intent, had configured this environment to do work."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  Build Toolchains.

  Toolchain types and default constructors. Each structure models
  a compiler or build tool with its flags and configuration. The
  `mk'` constructors provide minimal defaults — just a name.

  Bootstrap toolchains (`PythonBootstrap`, `GenruleToolchain`)
  model non-compiler build tools that still need version tracking.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // cxx // toolchain
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure CxxToolchain where
  name          : String
  c_extra_flags : List String := []
  cxx_extra_flags : List String := []
  link_style    : String := "static"
  deriving Repr, Inhabited

def CxxToolchain.mk' (name : String) : CxxToolchain := { name }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // haskell // toolchain
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure HaskellToolchain where
  name           : String
  compiler_flags : List String := []
  deriving Repr, Inhabited

def HaskellToolchain.mk' (name : String) : HaskellToolchain := { name }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // lean // toolchain
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure LeanToolchain where
  name       : String
  lean_flags : List String := []
  deriving Repr, Inhabited

def LeanToolchain.mk' (name : String) : LeanToolchain := { name }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // rust // toolchain
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure RustToolchain where
  name            : String
  default_edition : String := "2021"
  rustc_flags     : List String := []
  deriving Repr, Inhabited

def RustToolchain.mk' (name : String) : RustToolchain := { name }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // nv // toolchain
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure NvToolchain where
  name     : String
  nv_archs : List String := ["sm_90"]
  deriving Repr, Inhabited

def NvToolchain.mk' (name : String) : NvToolchain := { name }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                  // execution // platform
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure ExecutionPlatform where
  name           : String
  local_enabled  : Bool := true
  remote_enabled : Bool := false
  deriving Repr, Inhabited

def ExecutionPlatform.mk' (name : String) : ExecutionPlatform := { name }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // bootstrap // toolchains
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure PythonBootstrap where
  name : String
  deriving Repr, Inhabited

structure GenruleToolchain where
  name : String
  deriving Repr, Inhabited

end Continuity.Build
