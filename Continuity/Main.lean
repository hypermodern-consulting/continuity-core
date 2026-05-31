import Continuity.Derivation
import Continuity.Codegen.Build.ToDhall
import Continuity.Codegen.Build.ToStarlark
import Continuity.Codegen.Build.BzlDefs
import Continuity.Codegen.Codec.ToCpp
import Continuity.Codegen.Codec.ToHaskell
import Continuity.InitBuck2
import Continuity.Codegen.Effect
import Continuity.Crypto.SHA256

open Continuity.Codegen.Build
open Continuity.Codegen.Build.Starlark
open Continuity.Codegen.Build.BzlDefs
open Continuity.Codegen.Codec
open Continuity.Emit.Dhall
open Continuity.Emit.Starlark
open Continuity.InitBuck2

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

  -- Grade module (Haskell + C++)
  let gradeHsPath := s!"{outDir}/grade/Continuity/Grade.hs"
  let gradeHsDir := System.FilePath.mk gradeHsPath |>.parent |>.getD (System.FilePath.mk ".")
  IO.FS.createDirAll gradeHsDir
  IO.FS.writeFile gradeHsPath Continuity.Codegen.Effect.emitGradeModule
  IO.println s!"  wrote grade/Continuity/Grade.hs"

  let gradeCppPath := s!"{outDir}/grade/continuity_grade.hpp"
  let gradeCppDir := System.FilePath.mk gradeCppPath |>.parent |>.getD (System.FilePath.mk ".")
  IO.FS.createDirAll gradeCppDir
  IO.FS.writeFile gradeCppPath Continuity.Codegen.Effect.emitCppGradeEnum
  IO.println s!"  wrote grade/continuity_grade.hpp"

  -- Starlark toolchain files (generated from Lean)
  let starlarkOut := Continuity.Codegen.Build.Starlark.starlarkFiles
    Continuity.Codegen.Build.Starlark.allToolchains
  for (path, content) in starlarkOut do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"

  -- .bzl rule files (generated from BzlFile definitions)
  for (path, content) in Continuity.Codegen.Build.BzlDefs.bzlFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path}"

  -- Reflective hash prediction (§5 of the paper):
  -- Compute h1 = SHA-256(concatenated output) using the verified Lean implementation.
  -- This is the prediction. The build system can verify the files on disk match.
  -- LP-frame each entry: LP(path) ++ LP(content) for unambiguous hashing
  let mut manifest := ByteArray.empty
  for (path, expr) in preludeFiles do
    let content := render expr ++ "\n"
    manifest := Continuity.Derivation.writeLPStr manifest path
    manifest := Continuity.Derivation.writeLPStr manifest content
  for (path, content) in cppCodecFiles do
    manifest := Continuity.Derivation.writeLPStr manifest path
    manifest := Continuity.Derivation.writeLPStr manifest content
  for (path, content) in hsCodecFiles do
    manifest := Continuity.Derivation.writeLPStr manifest path
    manifest := Continuity.Derivation.writeLPStr manifest content

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
