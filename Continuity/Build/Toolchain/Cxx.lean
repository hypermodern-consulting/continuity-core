set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The mythform is usually encountered in one of two modes. One
      mode assumes that the data in question already exists and the
      mythform provides a convenient interface. The other mode
      assumes the data does not exist and the mythform provides a
      way of generating it. This second mode is known as prophecy."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Toolchain.Cxx

/-
  Build Toolchains.

  Toolchain types and default constructors. Each structure models
  a compiler or build tool with its flags and configuration. The
  `mk'` constructors provide minimal defaults — just a name.

  Bootstrap toolchains (`PythonBootstrap`, `GenruleToolchain`)
  model non-compiler build tools that still need version tracking.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // link // style
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive LinkStyle where
  | static | shared
  deriving Repr, DecidableEq, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // cxx // toolchain
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure CxxToolchain where
  name          : String
  c_extra_flags : List String := []
  cxx_extra_flags : List String := []
  link_style    : LinkStyle := .static
  deriving Repr, Inhabited

def CxxToolchain.mk' (name : String) : CxxToolchain := { name }

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

end Continuity.Build.Toolchain.Cxx
