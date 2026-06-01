import Continuity.Codec.Dhall.Parser
import Continuity.Codegen.AST.Dhall.Ast

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "A few drops of rain blew into her face. Smell of rain and wet earth.
      She looked down at the foundations that had been poured before
      anyone understood what the structure would become. You start with
      what you know and scaffold upward — tool on tool, rule on rule —
      until the system compiles itself into being. Configuration files
      are the bones of any build; without them, the code is just text.

      Her father had taught her that. He'd been a builder in the years
      before the war, when things were still made by hand. 'You lay the
      formwork first,' he'd say, 'then you pour.'"

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.CLI.InitBuck2

/-
  Buck2 workspace initializer.

  Reads a Dhall specification file, extracts toolchain paths,
  and generates the scaffolding files needed to build with `Buck2`:
  `.buckroot`, `.buckconfig`, `toolchains/BUCK`, and optional
  language-specific `toolchains/.bzl` files.
-/

open Continuity.Codegen.AST.Dhall (Expr)
open Continuity.Codec.Dhall (parse)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // spec extraction
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- get a string field from a record expression: { key = "value" }
def getField (e : Expr) (key : String) : Option Expr :=
  match e with
  | .record fields => fields.find? (fun (k, _) => k == key) |>.map Prod.snd
  | _ => none

-- unwrap `Some(x)` → `some x`, `None` → `none`
def unwrapOptional (e : Expr) : Option Expr :=
  match e with
  | .some v => some v
  | .none _ => none
  | other   => some other

-- extract a string from `Expr.text`
def getString (e : Expr) : Option String :=
  match e with
  | .text s => some s
  | _ => none

-- get a nested string: spec.section.field
def getNestedString (spec : Expr) (sect fld : String) : Option String := do
  let sectionExpr ← getField spec sect
  let inner ← unwrapOptional sectionExpr
  let fieldExpr ← getField inner fld
  getString fieldExpr

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // buck2 generation
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure ToolPaths where
  leanRoot : Option String := none
  cc       : Option String := none
  cxx      : Option String := none
  ghc      : Option String := none
  cabal    : Option String := none
  rustc    : Option String := none
  cargo    : Option String := none
  nvcc     : Option String := none
  cudaRoot : Option String := none
  reapiEndpoint : Option String := none
  reapiInstance : Option String := none

def extractTools (spec : Expr) : ToolPaths :=
  { leanRoot := getNestedString spec "lean" "root"
    cc       := getNestedString spec "cxx" "cc"
    cxx      := getNestedString spec "cxx" "cxx"
    ghc      := getNestedString spec "haskell" "ghc"
    cabal    := getNestedString spec "haskell" "cabal"
    rustc    := getNestedString spec "rust" "rustc"
    cargo    := getNestedString spec "rust" "cargo"
    nvcc     := getNestedString spec "nv" "nvcc"
    cudaRoot := getNestedString spec "nv" "cuda_root"
    reapiEndpoint := getNestedString spec "reapi" "endpoint"
    reapiInstance := getNestedString spec "reapi" "instance_name"
  }

def generateBuckconfig (tools : ToolPaths) : String :=
  let base := "[cells]
  root = .
  prelude = prelude
  toolchains = toolchains
  none = none
[cell_aliases]
  config = prelude
  ovr_config = prelude
  fbcode = none
  fbsource = none
  fbcode_macros = none
  buck = none
[external_cells]
  prelude = bundled
[parser]
  target_platform_detector_spec = target:root//...->prelude//platforms:default
[build]
  execution_platforms = prelude//platforms:default\n"

  let lean := match tools.leanRoot with
    | some root => s!"[lean]\n  lean = {root}/bin/lean\n  leanc = {root}/bin/leanc\n  lean_lib_dir = {root}/lib/lean\n  lean_include_dir = {root}/include\n"
    | none => ""

  let cxx := match tools.cc, tools.cxx with
    | some cc, some cxx => s!"[cxx]\n  cc = {cc}\n  cxx = {cxx}\n"
    | some cc, none     => s!"[cxx]\n  cc = {cc}\n  cxx = {cc}\n"
    | _, _              => ""

  let hs := match tools.ghc with
    | some ghc =>
      let cabalLine := match tools.cabal with | some c => s!"\n  cabal = {c}" | none => ""
      s!"[haskell]\n  ghc = {ghc}{cabalLine}\n"
    | none => ""

  let nv := match tools.nvcc with
    | some nvcc =>
      let cudaRoot := tools.cudaRoot.getD "/usr/local/cuda"
      s!"[nv]
  nvcc = {nvcc}
  cuda_root = {cudaRoot}
"
    | none => ""

  let reapi := match tools.reapiEndpoint with
    | some ep =>
      let inst := tools.reapiInstance.getD "default"
      s!"[reapi]\n  endpoint = {ep}\n  instance_name = {inst}\n"
    | none => ""

  base ++ lean ++ cxx ++ hs ++ nv ++ reapi

def toolchainsBuck : String :=
  "load(\"@prelude//toolchains:demo.bzl\", \"system_demo_toolchains\")\nsystem_demo_toolchains()\n"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // entry point
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def initBuck2 (specPath targetDir : String) : IO Unit := do
  let specContent ← IO.FS.readFile specPath
  let spec ← match parse specContent with
    | some e => pure e
    | none => throw (IO.Error.userError s!"Failed to parse {specPath}")

  let tools := extractTools spec

  IO.println s!"continuity init-buck2"
  IO.println s!"  spec: {specPath}"
  IO.println s!"  target: {targetDir}"
  if tools.leanRoot.isSome then IO.println s!"  ✓ lean: {tools.leanRoot.get!}"
  if tools.cc.isSome then IO.println s!"  ✓ cxx: {tools.cc.get!}"
  if tools.ghc.isSome then IO.println s!"  ✓ haskell: {tools.ghc.get!}"
  if tools.rustc.isSome then IO.println s!"  ✓ rust: {tools.rustc.get!}"
  if tools.nvcc.isSome then IO.println s!"  ✓ nv: {tools.nvcc.get!}"
  if tools.reapiEndpoint.isSome then IO.println s!"  ✓ reapi: {tools.reapiEndpoint.get!}"

  IO.FS.createDirAll (targetDir ++ "/toolchains")

  IO.FS.writeFile (targetDir ++ "/.buckroot") ""
  IO.FS.writeFile (targetDir ++ "/.buckconfig") (generateBuckconfig tools)
  IO.FS.writeFile (targetDir ++ "/toolchains/BUCK") toolchainsBuck

  -- lean.bzl is read from the file system at runtime (toolchains/lean.bzl
  -- in the continuity source tree). we embed a reference, not the content.
  if tools.leanRoot.isSome then
    let leanBzl ← IO.FS.readFile "toolchains/lean.bzl" <|>
                   pure "-- lean.bzl not found; copy from continuity/toolchains/lean.bzl\n"
    IO.FS.writeFile (targetDir ++ "/toolchains/lean.bzl") leanBzl

  if tools.nvcc.isSome then
    let cudaBzl ← IO.FS.readFile "toolchains/cuda.bzl" <|>
                   pure "-- cuda.bzl not found; copy from continuity/toolchains/cuda.bzl
"
    IO.FS.writeFile (targetDir ++ "/toolchains/cuda.bzl") cudaBzl

  let gitignore := "buck-out\n.buckroot\n"
  IO.FS.writeFile (targetDir ++ "/.gitignore") gitignore

  IO.println s!"\nDone. Run: cd {targetDir} && buck2 build //..."

end Continuity.CLI.InitBuck2
