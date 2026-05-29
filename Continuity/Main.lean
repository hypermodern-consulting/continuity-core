import Continuity.Codegen.Build.ToDhall
import Continuity.Codegen.Codec.ToCpp
import Continuity.Codegen.Codec.ToHaskell

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                          // continuity // main
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

open Continuity.Codegen.Build
open Continuity.Codegen.Codec
open Continuity.Emit.Dhall

def main (args : List String) : IO Unit := do
  let outDir := args.head? |>.getD "output/continuity-prelude"
  IO.println s!"Generating Continuity prelude → {outDir}/"

  -- Build layer → Dhall
  for (path, expr) in preludeFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    let content := render expr ++ "\n"
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path} ({content.length} bytes)"

  -- Codec layer → C++
  for (path, content) in cppCodecFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path} ({content.length} bytes)"

  -- Codec layer → Haskell
  for (path, content) in hsCodecFiles do
    let fullPath := s!"{outDir}/{path}"
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path} ({content.length} bytes)"

  let total := preludeFiles.length + cppCodecFiles.length + hsCodecFiles.length
  IO.println s!"Done. {total} files generated ({preludeFiles.length} Dhall + {cppCodecFiles.length} C++ + {hsCodecFiles.length} Haskell)."
