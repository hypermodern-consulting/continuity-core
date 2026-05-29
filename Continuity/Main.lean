import Continuity.Codegen.Build.ToDhall

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                          // continuity // main
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

open Continuity.Codegen.Build
open Continuity.Emit.Dhall

def main (args : List String) : IO Unit := do
  let outDir := args.head? |>.getD "output/continuity-prelude"
  IO.println s!"Generating Continuity prelude → {outDir}/"

  for (path, expr) in preludeFiles do
    let fullPath := s!"{outDir}/{path}"
    -- ensure parent directory exists
    let dir := System.FilePath.mk fullPath |>.parent |>.getD (System.FilePath.mk ".")
    IO.FS.createDirAll dir
    let content := render expr ++ "\n"
    IO.FS.writeFile fullPath content
    IO.println s!"  wrote {path} ({content.length} bytes)"

  IO.println s!"Done. {preludeFiles.length} files generated."
