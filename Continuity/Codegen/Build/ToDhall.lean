import Continuity.Build.Triple
import Continuity.Build.Dep
import Continuity.Build.Vis
import Continuity.Build.Resource
import Continuity.Build.Toolchain
import Continuity.Build.Cxx
import Continuity.Emit.Dhall.Ast
import Continuity.Emit.Dhall.Render
import Continuity.Emit.Dhall.Build

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                         // continuity // codegen // build // dhall
                                                                    to-dhall.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Dhall codegen for the Build data model.

  This is the Thompson loop at the build layer: Lean type definitions
  are the source of truth, this module generates the Dhall prelude files
  from them. If you change the Lean types, the Dhall changes.

  The codegen reflects over the Lean inductives (via explicit constructor
  lists — not Lean metaprogramming) and produces:
    - Dhall union types matching the Lean inductives
    - Dhall render functions (merge expressions)
    - Dhall record types matching the Lean structures
    - Common value definitions
    - Export records
-/

namespace Continuity.Codegen.Build

open Continuity.Emit.Dhall


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // helpers
   ════════════════════════════════════════════════════════════════════════════════ -/

/-! helpers for generating common Dhall patterns from constructor lists. -/

/-- Generate a Dhall union type from a list of constructor names (no payloads). -/
def emitEnum (names : List String) : Expr :=
  Expr.enum names

/-- Generate a Dhall merge expression that maps constructors to strings.
    `λ(x : T) → merge { c1 = "s1", c2 = "s2", ... } x` -/
def emitRenderFn (paramName : String) (typeName : String)
    (mapping : List (String × String)) : Expr :=
  Expr.lambda paramName (Expr.var typeName)
    (Expr.merge
      (Expr.record (mapping.map fun (con, str) => (con, Expr.str str)))
      (Expr.var paramName)
      Option.none)

/-- Generate a Dhall merge that maps constructors to `Optional Text`.
    Constructors mapping to "" produce `None Text`, others produce `Some "..."`. -/
def emitOptionalRenderFn (paramName : String) (typeName : String)
    (mapping : List (String × String)) : Expr :=
  Expr.lambda paramName (Expr.var typeName)
    (Expr.merge
      (Expr.record (mapping.map fun (con, str) =>
        if str == "" then (con, Expr.none (Expr.ty "Text"))
        else (con, Expr.some (Expr.str str))))
      (Expr.var paramName)
      Option.none)

/-- Generate a Dhall merge that maps constructors to Bool (true if match). -/
def emitPredicate (paramName : String) (typeName : String)
    (trueCtors : List String) (allCtors : List String) : Expr :=
  Expr.lambda paramName (Expr.var typeName)
    (Expr.merge
      (Expr.record (allCtors.map fun con =>
        (con, Expr.bool (trueCtors.contains con))))
      (Expr.var paramName)
      Option.none)


/- ════════════════════════════════════════════════════════════════════════════════
                                                       // constructor tables
   ════════════════════════════════════════════════════════════════════════════════ -/

/-! these tables mirror the Lean inductives. if you add a constructor to
    the Lean type, add it here. this is the price of not using Lean
    metaprogramming — explicit sync. the benefit: readable, auditable,
    no macro magic. -/

def archTable : List (String × String) :=
  [("x86_64", "x86_64"), ("aarch64", "aarch64"), ("riscv64", "riscv64"),
   ("wasm32", "wasm32"), ("armv7", "armv7")]

def vendorTable : List (String × String) :=
  [("unknown", "unknown"), ("pc", "pc"), ("apple", "apple"), ("nvidia", "nvidia")]

def osTable : List (String × String) :=
  [("linux", "linux"), ("darwin", "darwin"), ("windows", "windows"),
   ("wasi", "wasi"), ("none", "none")]

def abiTable : List (String × String) :=
  [("gnu", "gnu"), ("musl", "musl"), ("eabi", "eabi"),
   ("eabihf", "eabihf"), ("msvc", "msvc"), ("none", "")]

def cpuTable : List (String × String) :=
  [("generic", "generic"), ("native", "native"),
   ("x86_64_v2", "x86-64-v2"), ("x86_64_v3", "x86-64-v3"), ("x86_64_v4", "x86-64-v4"),
   ("znver3", "znver3"), ("znver4", "znver4"), ("znver5", "znver5"),
   ("sapphirerapids", "sapphirerapids"), ("alderlake", "alderlake"),
   ("neoverse_v2", "neoverse-v2"), ("neoverse_n2", "neoverse-n2"),
   ("cortex_a78ae", "cortex-a78ae"), ("cortex_a78c", "cortex-a78c"),
   ("apple_m1", "apple-m1"), ("apple_m2", "apple-m2"),
   ("apple_m3", "apple-m3"), ("apple_m4", "apple-m4")]

def gpuTable : List (String × String) :=
  [("none", ""), ("sm_80", "sm_80"), ("sm_86", "sm_86"), ("sm_87", "sm_87"),
   ("sm_89", "sm_89"), ("sm_90", "sm_90"), ("sm_90a", "sm_90a"),
   ("sm_100", "sm_100"), ("sm_100a", "sm_100a"), ("sm_120", "sm_120")]

def archNames   : List String := archTable.map Prod.fst
def vendorNames : List String := vendorTable.map Prod.fst
def osNames     : List String := osTable.map Prod.fst
def abiNames    : List String := abiTable.map Prod.fst
def cpuNames    : List String := cpuTable.map Prod.fst
def gpuNames    : List String := gpuTable.map Prod.fst


/- ════════════════════════════════════════════════════════════════════════════════
                                                          // triple emission
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Emit a Dhall triple record value from a Lean Triple. -/
def emitTriple (t : Continuity.Build.Triple) : Expr :=
  let archStr := t.arch.render
  let vendorStr := t.vendor.render
  let osStr := t.os.render
  let cpuStr := t.cpu.render
  buildRecord do
    field "arch"   <| Expr.enumVal "Arch" archNames archStr
    field "vendor" <| Expr.enumVal "Vendor" vendorNames vendorStr
    field "os"     <| Expr.enumVal "OS" osNames osStr
    field "abi"    <| Expr.enumVal "ABI" abiNames t.abi.render
    field "cpu"    <| Expr.enumVal "Cpu" cpuNames cpuStr
    field "gpu"    <| Expr.enumVal "Gpu" gpuNames t.gpu.render

/-- Emit a named triple binding: `let name : Triple = { ... }` -/
def emitNamedTriple (name : String) (t : Continuity.Build.Triple) : String × Option Expr × Expr :=
  (name, Option.some (Expr.var "Triple"), emitTriple t)


/- ════════════════════════════════════════════════════════════════════════════════
                                                       // Triple.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Generate the complete Triple.dhall module. -/
def emitTripleDhall : Expr :=
  -- type declarations
  let archType   := ("Arch",   Option.some (Expr.ty "Type"), emitEnum archNames)
  let vendorType := ("Vendor", Option.some (Expr.ty "Type"), emitEnum vendorNames)
  let osType     := ("OS",     Option.some (Expr.ty "Type"), emitEnum osNames)
  let abiType    := ("ABI",    Option.some (Expr.ty "Type"), emitEnum abiNames)
  let cpuType    := ("Cpu",    Option.some (Expr.ty "Type"), emitEnum cpuNames)
  let gpuType    := ("Gpu",    Option.some (Expr.ty "Type"), emitEnum gpuNames)

  let tripleType := ("Triple", Option.some (Expr.ty "Type"), buildRecordType do
    field "arch"   (Expr.var "Arch")
    field "vendor" (Expr.var "Vendor")
    field "os"     (Expr.var "OS")
    field "abi"    (Expr.var "ABI")
    field "cpu"    (Expr.var "Cpu")
    field "gpu"    (Expr.var "Gpu"))

  -- render functions
  let renderArch   := ("renderArch",   Option.none, emitRenderFn "a" "Arch" archTable)
  let renderVendor := ("renderVendor", Option.none, emitRenderFn "v" "Vendor" vendorTable)
  let renderOS     := ("renderOS",     Option.none, emitRenderFn "o" "OS" osTable)
  let renderABI    := ("renderABI",    Option.none, emitOptionalRenderFn "a" "ABI" abiTable)
  let renderCpu    := ("renderCpu",    Option.none, emitRenderFn "c" "Cpu" cpuTable)
  let renderGpu    := ("renderGpu",    Option.none, emitOptionalRenderFn "g" "Gpu" gpuTable)
  let abiIsNone    := ("abiIsNone",    Option.none, emitPredicate "a" "ABI" ["none"] abiNames)
  let gpuIsNone    := ("gpuIsNone",    Option.none, emitPredicate "g" "Gpu" ["none"] gpuNames)

  -- common triples
  open Continuity.Build in
  let triples := [
    emitNamedTriple "x86_64-linux-gnu"     Triple.x86_64_linux_gnu,
    emitNamedTriple "x86_64-linux-musl"    Triple.x86_64_linux_musl,
    emitNamedTriple "aarch64-linux-gnu"    Triple.aarch64_linux_gnu,
    emitNamedTriple "aarch64-apple-darwin" Triple.aarch64_apple_darwin,
    emitNamedTriple "wasm32-wasi"          Triple.wasm32_wasi,
    emitNamedTriple "grace-hopper"         Triple.grace_hopper,
    emitNamedTriple "jetson-orin"          Triple.jetson_orin,
    emitNamedTriple "dgx-blackwell"        Triple.dgx_blackwell
  ]

  -- export record
  let exports := buildRecord do
    -- types
    field "Arch"    (Expr.var "Arch")
    field "Vendor"  (Expr.var "Vendor")
    field "OS"      (Expr.var "OS")
    field "ABI"     (Expr.var "ABI")
    field "Cpu"     (Expr.var "Cpu")
    field "Gpu"     (Expr.var "Gpu")
    field "Triple"  (Expr.var "Triple")
    -- render functions
    field "render"       (Expr.var "render")
    field "renderArch"   (Expr.var "renderArch")
    field "renderVendor" (Expr.var "renderVendor")
    field "renderOS"     (Expr.var "renderOS")
    field "renderABI"    (Expr.var "renderABI")
    field "renderCpu"    (Expr.var "renderCpu")
    field "renderGpu"    (Expr.var "renderGpu")
    field "abiIsNone"    (Expr.var "abiIsNone")
    field "gpuIsNone"    (Expr.var "gpuIsNone")
    -- common triples
    field "x86_64-linux-gnu"     (Expr.var "x86_64-linux-gnu")
    field "aarch64-linux-gnu"    (Expr.var "aarch64-linux-gnu")
    field "aarch64-apple-darwin" (Expr.var "aarch64-apple-darwin")
    field "grace-hopper"         (Expr.var "grace-hopper")
    field "jetson-orin"          (Expr.var "jetson-orin")
    field "dgx-blackwell"        (Expr.var "dgx-blackwell")

  -- assemble the let chain
  let allBindings :=
    [archType, vendorType, osType, abiType, cpuType, gpuType, tripleType,
     renderArch, renderVendor, renderOS, renderABI, renderCpu, renderGpu,
     abiIsNone, gpuIsNone] ++ triples

  Expr.letChain allBindings exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

-- the money shot: does the loop close?
#eval render emitTripleDhall


-- end of original emitters — new modules follow


/- ════════════════════════════════════════════════════════════════════════════════
                                                         // Dep.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitDepDhall : Expr :=
  let depType := ("Dep", Option.some (Expr.ty "Type"),
    Expr.unionType [
      ("Local",     Option.some (Expr.ty "Text")),
      ("Flake",     Option.some (Expr.ty "Text")),
      ("External",  Option.some (buildRecordType do
        field "hash" (Expr.ty "Text")
        field "name" (Expr.ty "Text"))),
      ("PkgConfig", Option.some (Expr.ty "Text"))
    ])

  let local_   := ("local",     Option.none, Expr.var "Dep.Local")
  let flake_   := ("flake",     Option.none, Expr.var "Dep.Flake")
  let pkgcfg   := ("pkgconfig", Option.none, Expr.var "Dep.PkgConfig")
  let external := ("external",  Option.none,
    Expr.lambda "hash" (Expr.ty "Text")
      (Expr.lambda "name" (Expr.ty "Text")
        (Expr.app (Expr.var "Dep.External") (buildRecord do
          field "hash" (Expr.var "hash")
          field "name" (Expr.var "name")))))

  let nix := ("nix", Option.none,
    Expr.lambda "p" (Expr.ty "Text")
      (Expr.app (Expr.var "Dep.Flake")
        (Expr.interpolation ["nixpkgs#", ""] [Expr.var "p"])))

  let exports := buildRecord do
    field "Dep"       (Expr.var "Dep")
    field "local"     (Expr.var "local")
    field "flake"     (Expr.var "flake")
    field "external"  (Expr.var "external")
    field "pkgconfig" (Expr.var "pkgconfig")
    field "nix"       (Expr.var "nix")

  Expr.letChain [depType, local_, flake_, pkgcfg, external, nix] exports

#eval render emitDepDhall


/- ════════════════════════════════════════════════════════════════════════════════
                                                    // Toolchain.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitToolchainDhall : Expr :=
  let cxxTc := ("CxxToolchain", Option.none, buildRecordType do
    field "name"           (Expr.ty "Text")
    field "c_extra_flags"  (Expr.listOf (Expr.ty "Text"))
    field "cxx_extra_flags" (Expr.listOf (Expr.ty "Text"))
    field "link_style"     (Expr.ty "Text"))

  let cxxDflt := ("cxxToolchain", Option.none,
    Expr.lambda "name" (Expr.ty "Text") (buildRecord do
      field "name"           (Expr.var "name")
      field "c_extra_flags"  (Expr.emptyList (Expr.ty "Text"))
      field "cxx_extra_flags" (Expr.emptyList (Expr.ty "Text"))
      field "link_style"     (Expr.str "static")))

  let hsTc := ("HaskellToolchain", Option.none, buildRecordType do
    field "name"           (Expr.ty "Text")
    field "compiler_flags" (Expr.listOf (Expr.ty "Text")))

  let hsDflt := ("haskellToolchain", Option.none,
    Expr.lambda "name" (Expr.ty "Text") (buildRecord do
      field "name"           (Expr.var "name")
      field "compiler_flags" (Expr.emptyList (Expr.ty "Text"))))

  let rustTc := ("RustToolchain", Option.none, buildRecordType do
    field "name"            (Expr.ty "Text")
    field "default_edition" (Expr.ty "Text")
    field "rustc_flags"     (Expr.listOf (Expr.ty "Text")))

  let rustDflt := ("rustToolchain", Option.none,
    Expr.lambda "name" (Expr.ty "Text") (buildRecord do
      field "name"            (Expr.var "name")
      field "default_edition" (Expr.str "2021")
      field "rustc_flags"     (Expr.emptyList (Expr.ty "Text"))))

  let lnTc := ("LeanToolchain", Option.none, buildRecordType do
    field "name"       (Expr.ty "Text")
    field "lean_flags" (Expr.listOf (Expr.ty "Text")))

  let lnDflt := ("leanToolchain", Option.none,
    Expr.lambda "name" (Expr.ty "Text") (buildRecord do
      field "name"       (Expr.var "name")
      field "lean_flags" (Expr.emptyList (Expr.ty "Text"))))

  let nvTc := ("NvToolchain", Option.none, buildRecordType do
    field "name"     (Expr.ty "Text")
    field "nv_archs" (Expr.listOf (Expr.ty "Text")))

  let nvDflt := ("nvToolchain", Option.none,
    Expr.lambda "name" (Expr.ty "Text") (buildRecord do
      field "name"     (Expr.var "name")
      field "nv_archs" (Expr.listLit [Expr.str "sm_90"])))

  let execPlat := ("ExecutionPlatform", Option.none, buildRecordType do
    field "name"           (Expr.ty "Text")
    field "local_enabled"  (Expr.ty "Bool")
    field "remote_enabled" (Expr.ty "Bool"))

  let execDflt := ("executionPlatform", Option.none,
    Expr.lambda "name" (Expr.ty "Text") (buildRecord do
      field "name"           (Expr.var "name")
      field "local_enabled"  Expr.tt
      field "remote_enabled" Expr.ff))

  let exports := buildRecord do
    field "CxxToolchain"      (Expr.var "CxxToolchain")
    field "cxxToolchain"      (Expr.var "cxxToolchain")
    field "HaskellToolchain"  (Expr.var "HaskellToolchain")
    field "haskellToolchain"  (Expr.var "haskellToolchain")
    field "RustToolchain"     (Expr.var "RustToolchain")
    field "rustToolchain"     (Expr.var "rustToolchain")
    field "LeanToolchain"     (Expr.var "LeanToolchain")
    field "leanToolchain"     (Expr.var "leanToolchain")
    field "NvToolchain"       (Expr.var "NvToolchain")
    field "nvToolchain"       (Expr.var "nvToolchain")
    field "ExecutionPlatform" (Expr.var "ExecutionPlatform")
    field "executionPlatform" (Expr.var "executionPlatform")

  Expr.letChain
    [cxxTc, cxxDflt, hsTc, hsDflt, rustTc, rustDflt,
     lnTc, lnDflt, nvTc, nvDflt, execPlat, execDflt]
    exports

#eval render emitToolchainDhall


/- ════════════════════════════════════════════════════════════════════════════════
                                                       // Cxx.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitCxxDhall : Expr :=
  let cxxStdNames := ["Cxx11", "Cxx14", "Cxx17", "Cxx20", "Cxx23"]

  let cxxStd := ("CxxStd", Option.some (Expr.ty "Type"), emitEnum cxxStdNames)

  let depRef := Expr.importFile "core/Dep.dhall"
  let visRef := Expr.importFile "core/Vis.dhall"
  let d := ("D", Option.none, depRef)
  let v := ("V", Option.none, visRef)

  let binaryType := ("Binary", Option.none, buildRecordType do
    field "name"    (Expr.ty "Text")
    field "srcs"    (Expr.listOf (Expr.ty "Text"))
    field "deps"    (Expr.listOf (Expr.field (Expr.var "D") "Dep"))
    field "std"     (Expr.var "CxxStd")
    field "cflags"  (Expr.listOf (Expr.ty "Text"))
    field "ldflags" (Expr.listOf (Expr.ty "Text"))
    field "vis"     (Expr.field (Expr.var "V") "Vis"))

  let binaryFn := ("binary", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" (Expr.listOf (Expr.ty "Text"))
        (Expr.lambda "deps" (Expr.listOf (Expr.field (Expr.var "D") "Dep"))
          (buildRecord do
            field "name"    (Expr.var "name")
            field "srcs"    (Expr.var "srcs")
            field "deps"    (Expr.var "deps")
            field "std"     (Expr.enumVal "CxxStd" cxxStdNames "Cxx17")
            field "cflags"  (Expr.emptyList (Expr.ty "Text"))
            field "ldflags" (Expr.emptyList (Expr.ty "Text"))
            field "vis"     (Expr.field (Expr.var "V") "public")))))

  let libraryType := ("Library", Option.none, buildRecordType do
    field "name"   (Expr.ty "Text")
    field "srcs"   (Expr.listOf (Expr.ty "Text"))
    field "hdrs"   (Expr.listOf (Expr.ty "Text"))
    field "deps"   (Expr.listOf (Expr.field (Expr.var "D") "Dep"))
    field "std"    (Expr.var "CxxStd")
    field "cflags" (Expr.listOf (Expr.ty "Text"))
    field "vis"    (Expr.field (Expr.var "V") "Vis"))

  let libraryFn := ("library", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" (Expr.listOf (Expr.ty "Text"))
        (Expr.lambda "deps" (Expr.listOf (Expr.field (Expr.var "D") "Dep"))
          (buildRecord do
            field "name"   (Expr.var "name")
            field "srcs"   (Expr.var "srcs")
            field "deps"   (Expr.var "deps")
            field "hdrs"   (Expr.emptyList (Expr.ty "Text"))
            field "std"    (Expr.enumVal "CxxStd" cxxStdNames "Cxx17")
            field "cflags" (Expr.emptyList (Expr.ty "Text"))
            field "vis"    (Expr.field (Expr.var "V") "public")))))

  let exports := buildRecord do
    field "CxxStd"  (Expr.var "CxxStd")
    field "Binary"  (Expr.var "Binary")
    field "binary"  (Expr.var "binary")
    field "Library" (Expr.var "Library")
    field "library" (Expr.var "library")

  Expr.letChain
    [d, v, cxxStd, binaryType, binaryFn, libraryType, libraryFn]
    exports

#eval render emitCxxDhall

end Continuity.Codegen.Build
