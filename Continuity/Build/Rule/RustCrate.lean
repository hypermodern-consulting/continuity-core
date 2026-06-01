import Continuity.Build.Core.Vis

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Turner knew crates. Not the wooden kind, the kind that lived
      in registries with version numbers and cryptographic hashes,
      the kind that propagated through dependency graphs like a
      slow-acting virus, each one carrying its own assumptions about
      what the world looked like and what guarantees the linker would
      honour. Some of them pulled in fifty other crates, each with
      its own hash and its own quiet demands, until the whole thing
      was less a program than a negotiated settlement between several
      hundred strangers who had never spoken to each other."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Rule.RustCrate

/-
  Rust dependency specifications.

  `CratesIo` models a crate fetched from `crates.io` with version,
  integrity hash, feature flags, dependencies, and optional proc-macro
  support. `HttpArchive` models a tarball fetched via HTTP with an
  optional directory-strip prefix. Both carry `Vis`ibility.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // rustcrate // cratesio
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure CratesIo where
  name       : String
  version    : String
  sha256     : String
  features   : List String := []
  deps       : List String := []
  proc_macro : Bool        := false
  vis        : Vis
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                  // rustcrate // httparc
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure HttpArchive where
  name         : String
  url          : String
  sha256       : String
  strip_prefix : Option String
  vis          : Vis
  deriving Repr, Inhabited

end Continuity.Build.Rule.RustCrate
