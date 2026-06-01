import Continuity.Build.Core.Vis

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The construct, whatever it was, had the feel of something half-
      compiled, a source tree that had never been fully linked. Marly
      could see the stubs where functions had been declared but never
      defined, the import paths that terminated in nothing. It was
      like walking through a cathedral built from sketches. Beautiful
      in intent, but none of the doors opened onto anything real. Only
      the dependencies held it together — an elaborate lattice of
      promises, each one assuming the others would be kept."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build.Rule.PureScript

/-
  PureScript build targets.

  `PureScriptApp` describes a web application with optional HTML and
  CSS entrypoints. `PureScriptBinary` is a command-line executable.
  `PureScriptLibrary` is a shareable module collection. All carry
  source specifications, Spago package set references, and `Vis`ibility.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // purescript // app
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure PureScriptApp where
  name       : String
  srcs       : String
  spago_yaml : String
  spago_lock : Option String
  main       : String
  index_html : Option String
  style_css  : Option String
  vis        : Vis
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                 // purescript // binary
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure PureScriptBinary where
  name       : String
  srcs       : String
  spago_yaml : String
  main       : String
  vis        : Vis
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                // purescript // library
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure PureScriptLibrary where
  name       : String
  srcs       : String
  spago_yaml : Option String
  vis        : Vis
  deriving Repr, Inhabited

end Continuity.Build.Rule.PureScript
