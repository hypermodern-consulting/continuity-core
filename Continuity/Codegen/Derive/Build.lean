import Continuity.Codegen.Build.ToDhall
import Continuity.Codegen.Build.ToStarlark
import Continuity.Codegen.Build.BzlDefs

import Continuity.Codegen.AST.Dhall.Ast
import Continuity.Codegen.AST.Dhall.Render
import Continuity.Codegen.AST.Dhall.Build
import Continuity.Codegen.AST.Starlark.Ast
import Continuity.Codegen.AST.Starlark.Render
import Continuity.Codegen.AST.Cpp.Primitives
import Continuity.Codegen.AST.Haskell.Primitives

import Continuity.Crypto.SHA256
import Continuity.Nix.Derivation

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The box was a universe, a poem, frozen on the boundaries of human
      experience. And it was also, he realized, a compiler — translating
      from the abstract to the concrete, from the type to the token, from
      the intention to the mechanism. Every edge in the graph was a rule;
      every node, a decision rendered permanent. The machine didn't dream;
      it derived."
                                                                    — Count Zero

     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Derive.Build

/-
  Derive build codegen — unified entry point for Build/Core/, Build/Rule/,
  and Build/Toolchain/ type derivations.

  Produces both Dhall AST and Starlark AST output.

  Currently delegates to the existing hand-written codegen modules
  (`ToDhall`, `ToStarlark`, `BzlDefs`). In a future pass these functions
  will be inlined here via Lean metaprogramming, eliminating the
  hand-maintained sync between type definitions and codegen tables.

  The framework is: one function per Build type → appropriate AST.
-/

open Continuity.Codegen.AST.Dhall
open Continuity.Codegen.AST.Starlark

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // dhall // derivations
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def deriveTripleDhall : Expr :=
  Continuity.Codegen.Build.emitTripleDhall

def deriveDepDhall : Expr :=
  Continuity.Codegen.Build.emitDepDhall

def deriveVisDhall : Expr :=
  Continuity.Codegen.Build.emitVisDhall

def deriveResourceDhall : Expr :=
  Continuity.Codegen.Build.emitResourceDhall

def deriveLibraryDhall : Expr :=
  Continuity.Codegen.Build.emitLibraryDhall

def deriveToolchainDhall : Expr :=
  Continuity.Codegen.Build.emitToolchainDhall

def deriveCxxDhall : Expr :=
  Continuity.Codegen.Build.emitCxxDhall

def deriveHaskellDhall : Expr :=
  Continuity.Codegen.Build.emitHaskellDhall

def deriveRustDhall : Expr :=
  Continuity.Codegen.Build.emitRustDhall

def deriveLeanDhall : Expr :=
  Continuity.Codegen.Build.emitLeanDhall

def deriveNvDhall : Expr :=
  Continuity.Codegen.Build.emitNvDhall

def derivePureScriptDhall : Expr :=
  Continuity.Codegen.Build.emitPureScriptDhall

def deriveGenruleDhall : Expr :=
  Continuity.Codegen.Build.emitGenruleDhall

def deriveNixCxxDhall : Expr :=
  Continuity.Codegen.Build.emitNixCxxDhall

def deriveRustCrateDhall : Expr :=
  Continuity.Codegen.Build.emitRustCrateDhall

def deriveRuleDhall : Expr :=
  Continuity.Codegen.Build.emitRuleDhall

def derivePackageDhall : Expr :=
  Continuity.Codegen.Build.emitPackageDhall

def derivePreludeDhall : Expr :=
  Continuity.Codegen.Build.emitPreludeDhall

def deriveBzlRuleDhall : Expr :=
  Continuity.Codegen.Build.emitBzlRuleDhall

def deriveBzlPackageDhall : Expr :=
  Continuity.Codegen.Build.emitBzlPackageDhall

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // all dhall // files
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def allDhallFiles : List (String × Expr) :=
  Continuity.Codegen.Build.preludeFiles

-- backward-compatible alias used by Main.lean
def preludeFiles : List (String × Expr) := allDhallFiles

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // starlark // derivations
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def allToolchains : Continuity.Codegen.Build.Starlark.ToolchainConfig :=
  Continuity.Codegen.Build.Starlark.allToolchains

def deriveToolchainsStarlark (config : Continuity.Codegen.Build.Starlark.ToolchainConfig) :
    List (String × String) :=
  Continuity.Codegen.Build.Starlark.starlarkFiles config

def starlarkFiles (config : Continuity.Codegen.Build.Starlark.ToolchainConfig) :
    List (String × String) := deriveToolchainsStarlark config

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // bzl // derivations
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def allBzlFiles : List (String × String) :=
  Continuity.Codegen.Build.BzlDefs.bzlFiles

def deriveBzlFiles : List (String × String) := allBzlFiles

-- backward-compatible alias used by Main.lean
def bzlFiles : List (String × String) := allBzlFiles

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // all starlark // files
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def allStarlarkFiles (config : Continuity.Codegen.Build.Starlark.ToolchainConfig) :
    List (String × String) :=
  deriveToolchainsStarlark config ++ deriveBzlFiles

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // c++ // primitives
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def emitCppPrimitives : String :=
  Continuity.Codegen.AST.Cpp.Primitives.emitCppPrimitives

def cppPrimitivesFiles : List (String × String) :=
  [("primitive/continuity_primitives.hpp", emitCppPrimitives)]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // haskell // primitives
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def hsPrimitivesFiles : List (String × String) :=
  [ ("grade/Continuity/Grade/Primitives.hs",
     Continuity.Codegen.AST.Haskell.Primitives.emitHsPrimitives)
  , ("grade/Control/Grade/Do.hs",
     Continuity.Codegen.AST.Haskell.Primitives.emitHsGradeDo)
  ]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                          // reflective // hash // verification
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-
  Reflective hash verification (§5 of the paper).

  Step 1 (deriveReflectiveManifest):
    Given a list of (path, content) pairs, compute
      h₁ := SHA256(LP("Derive") ++ LP(path₁) ++ LP(content₁) ++ ...)
    where each entry is length-prefixed for unambiguous hashing.
    Writes `h₁` to a MANIFEST.sha256 file.

  Step 2 (deriveReflectiveVerify):
    Recompute h₂ from the same files and check h₂ == h₁.
    This is the reflective check — the build system can re-run
    to verify that the current output matches the predicted hash.

  The LP-framing is identical to the one used in Nix/Derivation.lean,
  preventing boundary-shift injection attacks.
-/

open Continuity.Crypto.SHA256
open Continuity.Nix.Derivation

def deriveReflectiveManifest
    (files : List (String × String))
    (outDir : String)
    : IO String := do
  let mut manifest := ByteArray.empty
  for (path, content) in files do
    manifest := writeLPStr manifest path
    manifest := writeLPStr manifest content
  let h1 := hashHex manifest
  IO.FS.writeFile (outDir ++ "/MANIFEST.sha256") (h1 ++ "\n")
  pure h1

def deriveReflectiveVerify
    (files : List (String × String))
    (manifestPath : String)
    : IO Bool := do
  let h1bytes ← IO.FS.readFile manifestPath
  let h1 := h1bytes.trimAscii.toString.replace "\n" ""
  let mut expected := ByteArray.empty
  for (path, content) in files do
    expected := writeLPStr expected path
    expected := writeLPStr expected content
  let h2 := hashHex expected
  pure (h1 == h2)

def reflectivelyVerify
    (genFiles : List (String × String))
    (outDir : String)
    : IO Bool :=
  deriveReflectiveVerify genFiles (outDir ++ "/MANIFEST.sha256")

end Continuity.Codegen.Derive.Build
