import Continuity.Nix.Derivation
import Continuity.Codegen.Build.ToDhall
import Continuity.Codegen.Build.ToStarlark
import Continuity.Codegen.Build.BzlDefs
import Continuity.Codegen.Codec.ToCpp
import Continuity.Codegen.Codec.ToHaskell
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

open Continuity.Codegen.Build
open Continuity.Codegen.Build.Starlark
open Continuity.Codegen.Build.BzlDefs
open Continuity.Codegen.Codec
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
  let total := preludeFiles.length + cppCodecFiles.length + hsCodecFiles.length

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

  -- `Starlark` toolchain files (generated from Lean)
  let starlarkOut := Continuity.Codegen.Build.Starlark.starlarkFiles
    Continuity.Codegen.Build.Starlark.allToolchains
  for (path, content) in starlarkOut do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"

  -- `.bzl` rule files (generated from `BzlFile` definitions in Lean)
  for (path, content) in Continuity.Codegen.Build.BzlDefs.bzlFiles do
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
  -- compute `h1 = SHA-256(concatenated output)` using the verified Lean implementation.
  -- this is the prediction. the build system can verify the files on disk match.
  -- LP-frame each entry: `LP(path) ++ LP(content)` for unambiguous hashing
  let mut manifest := ByteArray.empty
  for (path, expr) in preludeFiles do
    let content := render expr ++ "\n"
    manifest := Continuity.Nix.Derivation.writeLPStr manifest path
    manifest := Continuity.Nix.Derivation.writeLPStr manifest content
  for (path, content) in cppCodecFiles do
    manifest := Continuity.Nix.Derivation.writeLPStr manifest path
    manifest := Continuity.Nix.Derivation.writeLPStr manifest content
  for (path, content) in hsCodecFiles do
    manifest := Continuity.Nix.Derivation.writeLPStr manifest path
    manifest := Continuity.Nix.Derivation.writeLPStr manifest content

  let h1 := Continuity.Crypto.SHA256.hashHex manifest
  IO.FS.writeFile (outDir ++ "/MANIFEST.sha256") (h1 ++ "\n")
  IO.println s!"h1 = {h1}"
  IO.println s!"Done. {total} files generated."

def findSpec (args : List String) : Option String :=
  let pfx := "--tools-specification="
  let pfxLen := pfx.length
  match args.find? (fun s => s.startsWith pfx) with
  | some s => some (String.ofList (s.toList.drop pfxLen))
  | none => none

def findTarget (args : List String) : String :=
  (args.filter (fun s => !s.startsWith "--")).head?.getD "."

def main (args : List String) : IO Unit := do
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
