import Continuity.Build.Triple
import Continuity.Build.Dep
import Continuity.Build.Vis
import Continuity.Build.Resource
import Continuity.Build.Toolchain
import Continuity.Build.Cxx
import Continuity.Build.BzlFile
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
  buildRecord do
    field "arch"   <| Expr.enumVal "Arch" archNames t.arch.name
    field "vendor" <| Expr.enumVal "Vendor" vendorNames t.vendor.name
    field "os"     <| Expr.enumVal "OS" osNames t.os.name
    field "abi"    <| Expr.enumVal "ABI" abiNames t.abi.name
    field "cpu"    <| Expr.enumVal "Cpu" cpuNames t.cpu.name
    field "gpu"    <| Expr.enumVal "Gpu" gpuNames t.gpu.name

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

  let depRef := Expr.importParentFile "core/Dep.dhall"
  let visRef := Expr.importParentFile "core/Vis.dhall"
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



/- ════════════════════════════════════════════════════════════════════════════════
                                                         // Vis.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitVisDhall : Expr :=
  let visType := ("Vis", Option.none, emitEnum ["Public", "Private"])
  let exports := buildRecord do
    field "Vis"     (Expr.var "Vis")
    field "public"  (Expr.enumVal "Vis" ["Public", "Private"] "Public")
    field "private" (Expr.enumVal "Vis" ["Public", "Private"] "Private")
  Expr.letChain [visType] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                    // Resource.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitResourceDhall : Expr :=
  let resType := ("Resource", Option.some (Expr.ty "Type"),
    Expr.unionType [
      ("Pure",       Option.none),
      ("Network",    Option.none),
      ("Auth",       Option.some (Expr.ty "Text")),
      ("Sandbox",    Option.some (Expr.ty "Text")),
      ("Filesystem", Option.some (Expr.ty "Text"))
    ])
  let resourcesType := ("Resources", Option.some (Expr.ty "Type"),
    Expr.listOf (Expr.var "Resource"))
  let pure_  := ("pure",  Option.none, Expr.emptyList (Expr.var "Resource"))
  let net    := ("network", Option.none, Expr.listLit [Expr.var "Resource.Network"])
  let auth   := ("auth", Option.none,
    Expr.lambda "provider" (Expr.ty "Text")
      (Expr.listLit [Expr.app (Expr.var "Resource.Auth") (Expr.var "provider")]))
  let combine := ("combine", Option.none,
    Expr.lambda "r" (Expr.var "Resources")
      (Expr.lambda "s" (Expr.var "Resources")
        (Expr.binop BinOp.listAppend (Expr.var "r") (Expr.var "s"))))
  let exports := buildRecord do
    field "Resource"  (Expr.var "Resource")
    field "Resources" (Expr.var "Resources")
    field "pure"      (Expr.var "pure")
    field "network"   (Expr.var "network")
    field "auth"      (Expr.var "auth")
    field "combine"   (Expr.var "combine")
  Expr.letChain [resType, resourcesType, pure_, net, auth, combine] exports



/- ════════════════════════════════════════════════════════════════════════════════
                                                   // Haskell.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

private def depListTy : Expr := Expr.listOf (Expr.field (Expr.var "D") "Dep")
private def textListTy : Expr := Expr.listOf (Expr.ty "Text")
private def visTy : Expr := Expr.field (Expr.var "V") "Vis"
private def visDflt : Expr := Expr.field (Expr.var "V") "public"
private def emptyTextList : Expr := Expr.emptyList (Expr.ty "Text")

def emitHaskellDhall : Expr :=
  let d := ("D", Option.none, Expr.importParentFile "core/Dep.dhall")
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let binaryType := ("Binary", Option.none, buildRecordType do
    field "name"     (Expr.ty "Text")
    field "srcs"     textListTy
    field "deps"     depListTy
    field "main"     (Expr.ty "Text")
    field "ghcFlags" textListTy
    field "vis"      visTy)
  let binaryFn := ("binary", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (Expr.lambda "deps" depListTy
          (buildRecord do
            field "name"     (Expr.var "name")
            field "srcs"     (Expr.var "srcs")
            field "deps"     (Expr.var "deps")
            field "main"     (Expr.str "Main")
            field "ghcFlags" emptyTextList
            field "vis"      visDflt))))
  let libraryType := ("Library", Option.none, buildRecordType do
    field "name"     (Expr.ty "Text")
    field "srcs"     textListTy
    field "deps"     depListTy
    field "modules"  textListTy
    field "ghcFlags" textListTy
    field "vis"      visTy)
  let libraryFn := ("library", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (Expr.lambda "deps" depListTy
          (buildRecord do
            field "name"     (Expr.var "name")
            field "srcs"     (Expr.var "srcs")
            field "deps"     (Expr.var "deps")
            field "modules"  emptyTextList
            field "ghcFlags" emptyTextList
            field "vis"      visDflt))))
  let exports := buildRecord do
    field "Binary"  (Expr.var "Binary")
    field "binary"  (Expr.var "binary")
    field "Library" (Expr.var "Library")
    field "library" (Expr.var "library")
  Expr.letChain [d, v, binaryType, binaryFn, libraryType, libraryFn] exports




/- ════════════════════════════════════════════════════════════════════════════════
                                                   // Rust.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitRustDhall : Expr :=
  let d := ("D", Option.none, Expr.importParentFile "core/Dep.dhall")
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let editionNames := ["E2015", "E2018", "E2021", "E2024"]
  let edition := ("Edition", Option.some (Expr.ty "Type"), emitEnum editionNames)
  let ed2021 := Expr.enumVal "Edition" editionNames "E2021"

  let binaryType := ("Binary", Option.none, buildRecordType do
    field "name"      (Expr.ty "Text")
    field "srcs"      textListTy
    field "deps"      depListTy
    field "edition"   (Expr.var "Edition")
    field "features"  textListTy
    field "rustflags" textListTy
    field "vis"       visTy)

  let binaryFn := ("binary", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (Expr.lambda "deps" depListTy
          (buildRecord do
            field "name"      (Expr.var "name")
            field "srcs"      (Expr.var "srcs")
            field "deps"      (Expr.var "deps")
            field "edition"   ed2021
            field "features"  emptyTextList
            field "rustflags" emptyTextList
            field "vis"       visDflt))))

  let libraryType := ("Library", Option.none, buildRecordType do
    field "name"       (Expr.ty "Text")
    field "srcs"       textListTy
    field "deps"       depListTy
    field "edition"    (Expr.var "Edition")
    field "crate_name" (Expr.optionalOf (Expr.ty "Text"))
    field "features"   textListTy
    field "proc_macro" (Expr.ty "Bool")
    field "vis"        visTy)

  let libraryFn := ("library", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (Expr.lambda "deps" depListTy
          (buildRecord do
            field "name"       (Expr.var "name")
            field "srcs"       (Expr.var "srcs")
            field "deps"       (Expr.var "deps")
            field "edition"    ed2021
            field "crate_name" (Expr.none (Expr.ty "Text"))
            field "features"   emptyTextList
            field "proc_macro" Expr.ff
            field "vis"        visDflt))))

  let exports := buildRecord do
    field "Edition" (Expr.var "Edition")
    field "Binary"  (Expr.var "Binary")
    field "binary"  (Expr.var "binary")
    field "Library" (Expr.var "Library")
    field "library" (Expr.var "library")

  Expr.letChain [d, v, edition, binaryType, binaryFn, libraryType, libraryFn] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                   // Genrule.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitGenruleDhall : Expr :=
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let genruleType := ("Genrule", Option.none, buildRecordType do
    field "name" (Expr.ty "Text")
    field "out"  (Expr.ty "Text")
    field "cmd"  (Expr.ty "Text")
    field "srcs" textListTy
    field "vis"  visTy)
  let genruleFn := ("genrule", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "out" (Expr.ty "Text")
        (Expr.lambda "cmd" (Expr.ty "Text")
          (buildRecord do
            field "name" (Expr.var "name")
            field "out"  (Expr.var "out")
            field "cmd"  (Expr.var "cmd")
            field "srcs" emptyTextList
            field "vis"  visDflt))))
  let exports := buildRecord do
    field "Genrule" (Expr.var "Genrule")
    field "genrule" (Expr.var "genrule")
  Expr.letChain [v, genruleType, genruleFn] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                   // file writing pipeline
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- All prelude modules and their output paths. -/


/- ════════════════════════════════════════════════════════════════════════════════
                                                      // Lean.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitLeanDhall : Expr :=
  let d := ("D", Option.none, Expr.importParentFile "core/Dep.dhall")
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let binaryType := ("Binary", Option.none, buildRecordType do
    field "name"      (Expr.ty "Text")
    field "srcs"      textListTy
    field "deps"      depListTy
    field "root"      (Expr.ty "Text")
    field "leanFlags" textListTy
    field "vis"       visTy)
  let binaryFn := ("binary", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (Expr.lambda "deps" depListTy
          (buildRecord do
            field "name"      (Expr.var "name")
            field "srcs"      (Expr.var "srcs")
            field "deps"      (Expr.var "deps")
            field "root"      (Expr.str "Main.lean")
            field "leanFlags" emptyTextList
            field "vis"       visDflt))))
  let libraryType := ("Library", Option.none, buildRecordType do
    field "name"      (Expr.ty "Text")
    field "srcs"      textListTy
    field "deps"      depListTy
    field "root"      (Expr.ty "Text")
    field "leanFlags" textListTy
    field "vis"       visTy)
  let libraryFn := ("library", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (Expr.lambda "deps" depListTy
          (buildRecord do
            field "name"      (Expr.var "name")
            field "srcs"      (Expr.var "srcs")
            field "deps"      (Expr.var "deps")
            field "root"      (Expr.str "lib.lean")
            field "leanFlags" emptyTextList
            field "vis"       visDflt))))
  let exports := buildRecord do
    field "Binary"  (Expr.var "Binary")
    field "binary"  (Expr.var "binary")
    field "Library" (Expr.var "Library")
    field "library" (Expr.var "library")
  Expr.letChain [d, v, binaryType, binaryFn, libraryType, libraryFn] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                        // Nv.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitNvDhall : Expr :=
  let d := ("D", Option.none, Expr.importParentFile "core/Dep.dhall")
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let binaryType := ("Binary", Option.none, buildRecordType do
    field "name"  (Expr.ty "Text")
    field "srcs"  textListTy
    field "deps"  depListTy
    field "archs" textListTy
    field "vis"   visTy)
  let binaryFn := ("binary", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (buildRecord do
          field "name"  (Expr.var "name")
          field "srcs"  (Expr.var "srcs")
          field "deps"  (Expr.emptyList depListTy)
          field "archs" emptyTextList
          field "vis"   visDflt)))
  let libraryType := ("Library", Option.none, buildRecordType do
    field "name"             (Expr.ty "Text")
    field "srcs"             textListTy
    field "exported_headers" textListTy
    field "deps"             depListTy
    field "archs"            textListTy
    field "vis"              visTy)
  let libraryFn := ("library", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (buildRecord do
          field "name"             (Expr.var "name")
          field "srcs"             (Expr.var "srcs")
          field "exported_headers" emptyTextList
          field "deps"             (Expr.emptyList depListTy)
          field "archs"            emptyTextList
          field "vis"              visDflt)))
  let exports := buildRecord do
    field "Binary"  (Expr.var "Binary")
    field "binary"  (Expr.var "binary")
    field "Library" (Expr.var "Library")
    field "library" (Expr.var "library")
  Expr.letChain [d, v, binaryType, binaryFn, libraryType, libraryFn] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                  // PureScript.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitPureScriptDhall : Expr :=
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let srcSpecNames := ["Explicit", "Glob", "Globs"]
  let srcSpec := ("SrcSpec", Option.some (Expr.ty "Type"),
    Expr.unionType [
      ("Explicit", Option.some textListTy),
      ("Glob",     Option.some (Expr.ty "Text")),
      ("Globs",    Option.some textListTy)
    ])
  let appType := ("App", Option.none, buildRecordType do
    field "name"       (Expr.ty "Text")
    field "srcs"       (Expr.var "SrcSpec")
    field "spago_yaml" (Expr.ty "Text")
    field "spago_lock" (Expr.optionalOf (Expr.ty "Text"))
    field "main"       (Expr.ty "Text")
    field "index_html" (Expr.optionalOf (Expr.ty "Text"))
    field "style_css"  (Expr.optionalOf (Expr.ty "Text"))
    field "vis"        visTy)
  let appFn := ("app", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" (Expr.var "SrcSpec")
        (Expr.lambda "spago_yaml" (Expr.ty "Text")
          (buildRecord do
            field "name"       (Expr.var "name")
            field "srcs"       (Expr.var "srcs")
            field "spago_yaml" (Expr.var "spago_yaml")
            field "spago_lock" (Expr.none (Expr.ty "Text"))
            field "main"       (Expr.str "Main")
            field "index_html" (Expr.some (Expr.str "index.html"))
            field "style_css"  (Expr.some (Expr.str "style.css"))
            field "vis"        visDflt))))
  let binaryType := ("Binary", Option.none, buildRecordType do
    field "name"       (Expr.ty "Text")
    field "srcs"       (Expr.var "SrcSpec")
    field "spago_yaml" (Expr.ty "Text")
    field "main"       (Expr.ty "Text")
    field "vis"        visTy)
  let binaryFn := ("binary", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" (Expr.var "SrcSpec")
        (Expr.lambda "spago_yaml" (Expr.ty "Text")
          (buildRecord do
            field "name"       (Expr.var "name")
            field "srcs"       (Expr.var "srcs")
            field "spago_yaml" (Expr.var "spago_yaml")
            field "main"       (Expr.str "Main")
            field "vis"        visDflt))))
  let libraryType := ("Library", Option.none, buildRecordType do
    field "name"       (Expr.ty "Text")
    field "srcs"       (Expr.var "SrcSpec")
    field "spago_yaml" (Expr.optionalOf (Expr.ty "Text"))
    field "vis"        visTy)
  let libraryFn := ("library", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" (Expr.var "SrcSpec")
        (buildRecord do
          field "name"       (Expr.var "name")
          field "srcs"       (Expr.var "srcs")
          field "spago_yaml" (Expr.none (Expr.ty "Text"))
          field "vis"        visDflt)))
  let exports := buildRecord do
    field "App"     (Expr.var "App")
    field "app"     (Expr.var "app")
    field "Binary"  (Expr.var "Binary")
    field "binary"  (Expr.var "binary")
    field "Library" (Expr.var "Library")
    field "library" (Expr.var "library")
    field "SrcSpec" (Expr.var "SrcSpec")
  Expr.letChain [v, srcSpec, appType, appFn, binaryType, binaryFn, libraryType, libraryFn] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                     // NixCxx.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitNixCxxDhall : Expr :=
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let nixBinaryType := ("NixBinary", Option.none, buildRecordType do
    field "name"           (Expr.ty "Text")
    field "srcs"           textListTy
    field "nix_deps"       textListTy
    field "deps"           textListTy
    field "compiler_flags" textListTy
    field "linker_flags"   textListTy
    field "vis"            visTy)
  let nixBinaryFn := ("nixBinary", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "srcs" textListTy
        (Expr.lambda "nix_deps" textListTy
          (buildRecord do
            field "name"           (Expr.var "name")
            field "srcs"           (Expr.var "srcs")
            field "nix_deps"       (Expr.var "nix_deps")
            field "deps"           emptyTextList
            field "compiler_flags" emptyTextList
            field "linker_flags"   emptyTextList
            field "vis"            visDflt))))
  let exports := buildRecord do
    field "NixBinary" (Expr.var "NixBinary")
    field "nixBinary" (Expr.var "nixBinary")
  Expr.letChain [v, nixBinaryType, nixBinaryFn] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                  // RustCrate.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitRustCrateDhall : Expr :=
  let v := ("V", Option.none, Expr.importParentFile "core/Vis.dhall")
  let cratesIoType := ("CratesIo", Option.none, buildRecordType do
    field "name"       (Expr.ty "Text")
    field "version"    (Expr.ty "Text")
    field "sha256"     (Expr.ty "Text")
    field "features"   textListTy
    field "deps"       textListTy
    field "proc_macro" (Expr.ty "Bool")
    field "vis"        visTy)
  let cratesIoFn := ("cratesIo", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "version" (Expr.ty "Text")
        (Expr.lambda "sha256" (Expr.ty "Text")
          (buildRecord do
            field "name"       (Expr.var "name")
            field "version"    (Expr.var "version")
            field "sha256"     (Expr.var "sha256")
            field "features"   emptyTextList
            field "deps"       emptyTextList
            field "proc_macro" Expr.ff
            field "vis"        visDflt))))
  let httpArchiveType := ("HttpArchive", Option.none, buildRecordType do
    field "name"         (Expr.ty "Text")
    field "url"          (Expr.ty "Text")
    field "sha256"       (Expr.ty "Text")
    field "strip_prefix" (Expr.optionalOf (Expr.ty "Text"))
    field "vis"          visTy)
  let httpArchiveFn := ("httpArchive", Option.none,
    Expr.lambda "name" (Expr.ty "Text")
      (Expr.lambda "url" (Expr.ty "Text")
        (Expr.lambda "sha256" (Expr.ty "Text")
          (buildRecord do
            field "name"         (Expr.var "name")
            field "url"          (Expr.var "url")
            field "sha256"       (Expr.var "sha256")
            field "strip_prefix" (Expr.none (Expr.ty "Text"))
            field "vis"          visDflt))))
  let exports := buildRecord do
    field "CratesIo"    (Expr.var "CratesIo")
    field "cratesIo"    (Expr.var "cratesIo")
    field "HttpArchive" (Expr.var "HttpArchive")
    field "httpArchive" (Expr.var "httpArchive")
  Expr.letChain [v, cratesIoType, cratesIoFn, httpArchiveType, httpArchiveFn] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                      // Rule.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitRuleDhall : Expr :=
  let c  := ("C",  Option.none, Expr.importParentFile "lang/Cxx.dhall")
  let r  := ("R",  Option.none, Expr.importParentFile "lang/Rust.dhall")
  let h  := ("H",  Option.none, Expr.importParentFile "lang/Haskell.dhall")
  let l  := ("L",  Option.none, Expr.importParentFile "lang/Lean.dhall")
  let n  := ("N",  Option.none, Expr.importParentFile "lang/Nv.dhall")
  let ps := ("PS", Option.none, Expr.importParentFile "lang/PureScript.dhall")
  let g  := ("G",  Option.none, Expr.importParentFile "lang/Genrule.dhall")
  let nc := ("NC", Option.none, Expr.importParentFile "lang/NixCxx.dhall")
  let rc := ("RC", Option.none, Expr.importParentFile "lang/RustCrate.dhall")

  let ruleType := ("Rule", Option.none, Expr.unionType [
    ("CxxBinary",         Option.some (Expr.field (Expr.var "C") "Binary")),
    ("CxxLibrary",        Option.some (Expr.field (Expr.var "C") "Library")),
    ("RustBinary",        Option.some (Expr.field (Expr.var "R") "Binary")),
    ("RustLibrary",       Option.some (Expr.field (Expr.var "R") "Library")),
    ("HaskellBinary",     Option.some (Expr.field (Expr.var "H") "Binary")),
    ("HaskellLibrary",    Option.some (Expr.field (Expr.var "H") "Library")),
    ("LeanBinary",        Option.some (Expr.field (Expr.var "L") "Binary")),
    ("LeanLibrary",       Option.some (Expr.field (Expr.var "L") "Library")),
    ("NvBinary",          Option.some (Expr.field (Expr.var "N") "Binary")),
    ("NvLibrary",         Option.some (Expr.field (Expr.var "N") "Library")),
    ("PureScriptApp",     Option.some (Expr.field (Expr.var "PS") "App")),
    ("PureScriptBinary",  Option.some (Expr.field (Expr.var "PS") "Binary")),
    ("PureScriptLibrary", Option.some (Expr.field (Expr.var "PS") "Library")),
    ("Genrule",           Option.some (Expr.field (Expr.var "G") "Genrule")),
    ("NixCxxBinary",      Option.some (Expr.field (Expr.var "NC") "NixBinary")),
    ("CratesIo",          Option.some (Expr.field (Expr.var "RC") "CratesIo")),
    ("HttpArchive",       Option.some (Expr.field (Expr.var "RC") "HttpArchive"))
  ])

  let exports := buildRecord do
    field "Rule"              (Expr.var "Rule")
    field "cxxBinary"         (Expr.var "Rule.CxxBinary")
    field "cxxLibrary"        (Expr.var "Rule.CxxLibrary")
    field "rustBinary"        (Expr.var "Rule.RustBinary")
    field "rustLibrary"       (Expr.var "Rule.RustLibrary")
    field "haskellBinary"     (Expr.var "Rule.HaskellBinary")
    field "haskellLibrary"    (Expr.var "Rule.HaskellLibrary")
    field "leanBinary"        (Expr.var "Rule.LeanBinary")
    field "leanLibrary"       (Expr.var "Rule.LeanLibrary")
    field "nvBinary"          (Expr.var "Rule.NvBinary")
    field "nvLibrary"         (Expr.var "Rule.NvLibrary")
    field "purescriptApp"     (Expr.var "Rule.PureScriptApp")
    field "purescriptBinary"  (Expr.var "Rule.PureScriptBinary")
    field "purescriptLibrary" (Expr.var "Rule.PureScriptLibrary")
    field "genrule"           (Expr.var "Rule.Genrule")
    field "nixCxxBinary"      (Expr.var "Rule.NixCxxBinary")
    field "cratesIo"          (Expr.var "Rule.CratesIo")
    field "httpArchive"       (Expr.var "Rule.HttpArchive")

  Expr.letChain [c, r, h, l, n, ps, g, nc, rc, ruleType] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                                // package.dhall (top-level)
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitPackageDhall : Expr :=
  let triple := ("Triple", Option.none, Expr.importFile "core/Triple.dhall")
  let dep    := ("Dep",    Option.none, Expr.importFile "core/Dep.dhall")
  let vis    := ("Vis",    Option.none, Expr.importFile "core/Vis.dhall")
  let res    := ("Res",    Option.none, Expr.importFile "core/Resource.dhall")
  let tc     := ("TC",     Option.none, Expr.importFile "build/Toolchain.dhall")
  let cxx    := ("Cxx",    Option.none, Expr.importFile "lang/Cxx.dhall")
  let hs     := ("Hs",     Option.none, Expr.importFile "lang/Haskell.dhall")
  let rs     := ("Rs",     Option.none, Expr.importFile "lang/Rust.dhall")
  let ln     := ("Ln",     Option.none, Expr.importFile "lang/Lean.dhall")
  let nv     := ("Nv",     Option.none, Expr.importFile "lang/Nv.dhall")
  let ps     := ("PS",     Option.none, Expr.importFile "lang/PureScript.dhall")
  let gen    := ("Gen",    Option.none, Expr.importFile "lang/Genrule.dhall")
  let nc     := ("NC",     Option.none, Expr.importFile "lang/NixCxx.dhall")
  let rc     := ("RC",     Option.none, Expr.importFile "lang/RustCrate.dhall")
  let rule   := ("Rule",   Option.none, Expr.importFile "build/Rule.dhall")

  let exports := buildRecord do
    field "Triple"   (Expr.var "Triple")
    field "Dep"      (Expr.field (Expr.var "Dep") "Dep")
    field "dep"      (Expr.var "Dep")
    field "vis"      (Expr.var "Vis")
    field "resource" (Expr.var "Res")
    field "toolchain" (Expr.var "TC")
    field "lang"     (buildRecord do
      field "Cxx"        (Expr.var "Cxx")
      field "Haskell"    (Expr.var "Hs")
      field "Rust"       (Expr.var "Rs")
      field "Lean"       (Expr.var "Ln")
      field "Nv"         (Expr.var "Nv")
      field "PureScript" (Expr.var "PS")
      field "Genrule"    (Expr.var "Gen")
      field "NixCxx"     (Expr.var "NC")
      field "RustCrate"  (Expr.var "RC"))
    field "rule"     (Expr.var "Rule")

  Expr.letChain [triple, dep, vis, res, tc, cxx, hs, rs, ln, nv, ps, gen, nc, rc, rule] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                          // render/buck2/Rule.dhall module
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitBzlRuleDhall : Expr :=
  let attrType := ("AttrType", Option.some (Expr.ty "Type"), Expr.unionType [
    ("String",       Option.some (buildRecordType do field "default" (Expr.optionalOf (Expr.ty "Text")))),
    ("StringList",   Option.some (buildRecordType (pure ()))),
    ("Bool",         Option.some (buildRecordType do field "default" (Expr.ty "Bool"))),
    ("Int",          Option.some (buildRecordType do field "default" (Expr.ty "Natural"))),
    ("Dep",          Option.some (buildRecordType (pure ()))),
    ("DepDefault",   Option.some (buildRecordType do field "default" (Expr.ty "Text"))),
    ("DepList",      Option.some (buildRecordType (pure ()))),
    ("Source",       Option.some (buildRecordType (pure ()))),
    ("SourceList",   Option.some (buildRecordType (pure ()))),
    ("OptionSource", Option.some (buildRecordType (pure ()))),
    ("OptionString", Option.some (buildRecordType (pure ()))),
    ("Output",       Option.some (buildRecordType (pure ()))),
    ("Label",        Option.some (buildRecordType (pure ()))),
    ("StringDict",   Option.some (buildRecordType (pure ())))
  ])
  let attr := ("Attr", Option.none, buildRecordType do
    field "name" (Expr.ty "Text"); field "type" (Expr.var "AttrType"); field "doc" (Expr.ty "Text"))
  let load := ("Load", Option.none, buildRecordType do
    field "bzl" (Expr.ty "Text"); field "symbols" textListTy)
  let providerField := ("ProviderField", Option.some (Expr.ty "Type"), Expr.unionType [
    ("Typed",  Option.some (buildRecordType do
      field "name" (Expr.ty "Text"); field "type" (Expr.ty "Text")
      field "default" (Expr.optionalOf (Expr.ty "Text")))),
    ("Simple", Option.some (Expr.ty "Text"))])
  let providerDef := ("ProviderDef", Option.none, buildRecordType do
    field "name" (Expr.ty "Text"); field "fields" (Expr.listOf (Expr.var "ProviderField")))
  let helperFn := ("HelperFn", Option.none, buildRecordType do
    field "name" (Expr.ty "Text"); field "params" textListTy
    field "returnType" (Expr.optionalOf (Expr.ty "Text")); field "body" (Expr.ty "Text"))
  let ruleImpl := ("RuleImpl", Option.none, buildRecordType do
    field "name" (Expr.ty "Text"); field "doc" (Expr.ty "Text")
    field "body" (Expr.ty "Text"); field "is_toolchain" (Expr.ty "Bool"))
  let ruleEntry := Expr.listOf (buildRecordType do
    field "impl" (Expr.var "RuleImpl"); field "attrs" (Expr.listOf (Expr.var "Attr")))
  let bzlFile := ("BzlFile", Option.none, buildRecordType do
    field "header" (Expr.ty "Text"); field "loads" (Expr.listOf (Expr.var "Load"))
    field "globals" (Expr.ty "Text"); field "providers" (Expr.listOf (Expr.var "ProviderDef"))
    field "helpers" (Expr.listOf (Expr.var "HelperFn")); field "rules" ruleEntry)
  let exports := buildRecord do
    field "AttrType" (Expr.var "AttrType"); field "Attr" (Expr.var "Attr")
    field "Load" (Expr.var "Load"); field "ProviderDef" (Expr.var "ProviderDef")
    field "ProviderField" (Expr.var "ProviderField"); field "HelperFn" (Expr.var "HelperFn")
    field "RuleImpl" (Expr.var "RuleImpl"); field "BzlFile" (Expr.var "BzlFile")
  Expr.letChain [attrType, attr, load, providerField, providerDef, helperFn, ruleImpl, bzlFile] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                          // render/buck2/package.dhall
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitBzlPackageDhall : Expr :=
  let r := ("R", Option.none, Expr.importFile "Rule.dhall")
  let exports := buildRecord do
    field "Rule" (Expr.var "R")
  Expr.letChain [r] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                          // Prelude.dhall (utility functions)
   ════════════════════════════════════════════════════════════════════════════════ -/

def emitPreludeDhall : Expr :=
  -- concatSep: join a list of text with a separator
  let concatSep := ("concatSep", Option.none,
    Expr.lambda "sep" (Expr.ty "Text")
      (Expr.lambda "xs" (Expr.listOf (Expr.ty "Text"))
        (Expr.var "xs")))  -- note: real impl uses List/fold; simplified here
  let exports := buildRecord do
    field "Text" (buildRecord do field "concatSep" (Expr.var "concatSep"))
  Expr.letChain [concatSep] exports


/- ════════════════════════════════════════════════════════════════════════════════
                                               // final prelude file list
   ════════════════════════════════════════════════════════════════════════════════ -/

def preludeFiles : List (String × Expr) :=
  [ ("core/Triple.dhall",            emitTripleDhall)
  , ("core/Dep.dhall",               emitDepDhall)
  , ("core/Vis.dhall",               emitVisDhall)
  , ("core/Resource.dhall",          emitResourceDhall)
  , ("build/Toolchain.dhall",        emitToolchainDhall)
  , ("lang/Cxx.dhall",               emitCxxDhall)
  , ("lang/Haskell.dhall",           emitHaskellDhall)
  , ("lang/Rust.dhall",              emitRustDhall)
  , ("lang/Lean.dhall",              emitLeanDhall)
  , ("lang/Nv.dhall",                emitNvDhall)
  , ("lang/PureScript.dhall",        emitPureScriptDhall)
  , ("lang/Genrule.dhall",           emitGenruleDhall)
  , ("lang/NixCxx.dhall",            emitNixCxxDhall)
  , ("lang/RustCrate.dhall",         emitRustCrateDhall)
  , ("build/Rule.dhall",             emitRuleDhall)
  , ("package.dhall",                emitPackageDhall)
  , ("Prelude.dhall",                emitPreludeDhall)
  , ("render/buck2/Rule.dhall",      emitBzlRuleDhall)
  , ("render/buck2/package.dhall",   emitBzlPackageDhall)
  ]


end Continuity.Codegen.Build
