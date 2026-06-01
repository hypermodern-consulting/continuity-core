import Continuity.Nix.Derivation
import Continuity.Codegen.Derive.Build
import Continuity.Codegen.Derive.Codec
import Continuity.Codegen.Derive.StateMachine
import Continuity.Codegen.Derive.TestVectors
import Continuity.CLI.InitBuck2
import Continuity.Codegen.Algebra.Effect
import Continuity.Crypto.SHA256

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Cyberspace exists, insofar as it can be said to exist, by
      virtue of human agency. And the code you emit — Dhall, C++,
      Starlark, Haskell — is the agency, made machine-readable.
      The prelude files are the scaffolding. The codec machinery
      is the translation layer. What you generate isn't a program;
      it's the shape that a program will fill.

      The hash you compute at the end — `h1` — is the proof that
      the shape is the shape you meant to cut. Same files, same
      hash, every time. That's the contract."

                                                                     — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity

open Continuity.Codegen.Derive.Build
open Continuity.Codegen.Derive.Codec
open Continuity.Codegen.Derive.StateMachine
open Continuity.Codegen.Derive.TestVectors
open Continuity.Codegen.AST.Dhall
open Continuity.Codegen.AST.Starlark
open Continuity.CLI.InitBuck2

def cmdGenerate (outDir : String) : IO Unit := do
  IO.println s!"Generating Continuity prelude → {outDir}/"
  for (path, expr) in preludeFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath (render expr ++ "\n")
    IO.println s!"  wrote {path}"
  for (path, content) in cppCodecFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"
  for (path, content) in hsCodecFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"
  -- Phase 3.5: test vectors from Lean evaluation
  let testVectorsPath := s!"{outDir}/test/codec_test_vectors.cpp"
  let testVectorsDir := System.FilePath.mk testVectorsPath |>.parent |>.getD (System.FilePath.mk ".")
  IO.FS.createDirAll testVectorsDir
  IO.FS.writeFile testVectorsPath deriveCppTests
  IO.println s!"  wrote test/codec_test_vectors.cpp"
  -- Phase 5.2/5.4: state machine headers (C++)
  for (path, content) in cppStateMachineFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"

  -- `Grade` module (Haskell + C++)
  let gradeHsPath := s!"{outDir}/grade/Continuity/Grade.hs"
  let gradeHsDir := System.FilePath.mk gradeHsPath |>.parent |>.getD (System.FilePath.mk ".")
  IO.FS.createDirAll gradeHsDir
  IO.FS.writeFile gradeHsPath Continuity.Codegen.Algebra.Effect.emitGradeModule
  IO.println s!"  wrote grade/Continuity/Grade.hs"

  let gradeCppPath := s!"{outDir}/grade/continuity_grade.hpp"
  let gradeCppDir := System.FilePath.mk gradeCppPath |>.parent |>.getD (System.FilePath.mk ".")
  IO.FS.createDirAll gradeCppDir
  IO.FS.writeFile gradeCppPath Continuity.Codegen.Algebra.Effect.emitCppGradeEnum
  IO.println s!"  wrote grade/continuity_grade.hpp"

  -- `Grade` primitives (Haskell graded monad + QualifiedDo)
  for (path, content) in hsPrimitivesFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"

  -- `Starlark` toolchain files (generated from Lean)
  let starlarkOut := starlarkFiles allToolchains
  for (path, content) in starlarkOut do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"

  -- `.bzl` rule files (generated from `BzlFile` definitions in Lean)
  for (path, content) in bzlFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path} (generated)"

  -- `.bzl` files not yet migrated to `BzlFile` definitions (read from disk)
  let diskBzl := ["rust_crate.bzl", "execution.bzl",
                   "cuda.bzl", "nix.bzl", "python.bzl"]
  for bzl in diskBzl do
    let srcPath := s!"toolchains/{bzl}"
    let dstPath := s!"{outDir}/toolchains/{bzl}"
    let content ← IO.FS.readFile srcPath <|> pure ""
    if !content.isEmpty then
      IO.FS.writeFile dstPath content
      IO.println s!"  wrote toolchains/{bzl} (copied)"

  -- reflective hash prediction (§5 of the paper):
  -- collect all generated (path, content) pairs and compute
  -- h₁ := SHA256(LP-framed concatenation) via deriveReflectiveManifest.
  -- LP-frame each entry: LP(path) ++ LP(content) for unambiguous hashing.
  let mut generatedFiles : List (String × String) := []
  for (path, expr) in preludeFiles do
    generatedFiles := (path, render expr ++ "\n") :: generatedFiles
  for (path, content) in cppCodecFiles do
    generatedFiles := (path, content) :: generatedFiles
  for (path, content) in hsCodecFiles do
    generatedFiles := (path, content) :: generatedFiles
  generatedFiles := ("test/codec_test_vectors.cpp", deriveCppTests) :: generatedFiles
  for (path, content) in cppStateMachineFiles do
    generatedFiles := (path, content) :: generatedFiles
  for (path, content) in hsPrimitivesFiles do
    generatedFiles := (path, content) :: generatedFiles
  generatedFiles := ("grade/Continuity/Grade.hs", Continuity.Codegen.Algebra.Effect.emitGradeModule) :: generatedFiles
  generatedFiles := ("grade/continuity_grade.hpp", Continuity.Codegen.Algebra.Effect.emitCppGradeEnum) :: generatedFiles
  for (path, content) in starlarkOut do
    generatedFiles := (path, content) :: generatedFiles
  for (path, content) in bzlFiles do
    generatedFiles := (path, content) :: generatedFiles

  let h1 ← deriveReflectiveManifest generatedFiles.reverse outDir

  -- reflective verification: re-compute h₂ and check h₂ == h₁
  let verifies ← reflectivelyVerify generatedFiles.reverse outDir
  if verifies then
    IO.println s!"Reflective check: h₁ = h₂ = {h1} ✓"
  else
    IO.eprintln s!"Reflective check FAILED: h₁ = {h1}, re-computed h₂ differs"

  let total := preludeFiles.length + cppCodecFiles.length + hsCodecFiles.length +
    hsPrimitivesFiles.length + cppPrimitivesFiles.length + cppStateMachineFiles.length
  IO.println s!"h₁ = {h1}"
  IO.println s!"Done. {total} files generated."

def findSpec (args : List String) : Option String :=
  let pfx := "--tools-specification="
  let pfxLen := pfx.length
  match args.find? (fun s => s.startsWith pfx) with
  | some s => some (String.ofList (s.toList.drop pfxLen))
  | none => none

def findTarget (args : List String) : String :=
  (args.filter (fun s => !s.startsWith "--")).head?.getD "."

def run (args : List String) : IO Unit := do
  match args.head? with
  | some "--help" | some "-h" =>
    IO.println "continuity — verified metaprogramming platform"
    IO.println ""
    IO.println "  generate <output-dir>         Emit prelude (Dhall + C++ + Haskell)"
    IO.println "  init-buck2 --tools-specification=<spec.dhall> [dir]"
    IO.println "                                Generate buck2 scaffolding from tool spec"
  | some "generate" => cmdGenerate (args.tail.head?.getD "output/continuity-prelude")
  | some "init-buck2" =>
    match findSpec args.tail with
    | some spec => initBuck2 spec (findTarget args.tail)
    | none => IO.eprintln "error: --tools-specification=<path> required"
  | _ => cmdGenerate (args.head?.getD "output/continuity-prelude")

end Continuity

def main (args : List String) : IO Unit :=
  Continuity.run args
