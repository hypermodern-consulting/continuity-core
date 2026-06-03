import Lake

open Lake DSL

package «continuity» where
  leanOptions := #[
    ⟨`autoImplicit, false⟩,   -- no implicit variables; say what you mean
    ⟨`warningAsError, true⟩   -- treat warnings as errors
  ]

@[default_target]
lean_lib «Continuity» where
  srcDir := "."

lean_exe «continuity» where
  root := `Continuity.Main
