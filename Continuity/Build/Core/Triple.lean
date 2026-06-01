set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "They set a slamhound on Turner's trail in New Delhi, slotted it to
      his pheromones and the color of his hair. It was a good one, a new
      model from Braun, and it did its work well. It followed him through
      the heat-haze of Chandni Chowk, through the press of bodies in the
      Khari Baoli spice market, through the marble corridors of the
      Maurya Sheraton. It knew its target architecture intimately."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  Target Triples.

  `arch`-`vendor`-`os`-`abi` with `cpu`/`gpu` microarchitecture
  fields. Standard `LLVM`/`Rust` triple nomenclature. The `cpu`
  and `gpu` fields select `-march`/`-mtune` and `-arch=sm_XX`
  respectively — they are not part of the triple string itself.

  This is pure data: no proofs, no `IO`. Cross-compilation detection
  lives in the build system layer, not here.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // core // components
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Arch where
  | x86_64 | aarch64 | riscv64 | wasm32 | armv7
  deriving Repr, DecidableEq, Inhabited

inductive Vendor where
  | unknown | pc | apple | nvidia
  deriving Repr, DecidableEq, Inhabited

inductive OS where
  | linux | darwin | windows | wasi | none
  deriving Repr, DecidableEq, Inhabited

inductive ABI where
  | gnu | musl | eabi | eabihf | msvc | none
  deriving Repr, DecidableEq, Inhabited

inductive Cpu where
  | generic | native
  | x86_64_v2 | x86_64_v3 | x86_64_v4
  | znver3 | znver4 | znver5
  | sapphirerapids | alderlake
  | neoverse_v2 | neoverse_n2
  | cortex_a78ae | cortex_a78c
  | apple_m1 | apple_m2 | apple_m3 | apple_m4
  deriving Repr, DecidableEq, Inhabited

inductive Gpu where
  | none
  | sm_80 | sm_86
  | sm_89
  | sm_90 | sm_90a
  | sm_87
  | sm_100 | sm_100a | sm_120
  deriving Repr, DecidableEq, Inhabited

structure Triple where
  arch   : Arch
  vendor : Vendor
  os     : OS
  abi    : ABI
  cpu    : Cpu
  gpu    : Gpu
  deriving Repr, DecidableEq, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // rendering
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def Arch.render : Arch → String
  | .x86_64  => "x86_64"  | .aarch64 => "aarch64"
  | .riscv64 => "riscv64"  | .wasm32  => "wasm32"
  | .armv7   => "armv7"

def Vendor.render : Vendor → String
  | .unknown => "unknown" | .pc    => "pc"
  | .apple   => "apple"   | .nvidia => "nvidia"

def OS.render : OS → String
  | .linux   => "linux"   | .darwin  => "darwin"
  | .windows => "windows" | .wasi    => "wasi"
  | .none    => "none"

def ABI.render : ABI → String
  | .gnu    => "gnu"    | .musl   => "musl"
  | .eabi   => "eabi"   | .eabihf => "eabihf"
  | .msvc   => "msvc"   | .none   => ""

def Cpu.render : Cpu → String
  | .generic       => "generic"        | .native        => "native"
  | .x86_64_v2     => "x86-64-v2"     | .x86_64_v3     => "x86-64-v3"
  | .x86_64_v4     => "x86-64-v4"
  | .znver3        => "znver3"         | .znver4        => "znver4"
  | .znver5        => "znver5"
  | .sapphirerapids => "sapphirerapids" | .alderlake     => "alderlake"
  | .neoverse_v2   => "neoverse-v2"   | .neoverse_n2   => "neoverse-n2"
  | .cortex_a78ae  => "cortex-a78ae"  | .cortex_a78c   => "cortex-a78c"
  | .apple_m1      => "apple-m1"      | .apple_m2      => "apple-m2"
  | .apple_m3      => "apple-m3"      | .apple_m4      => "apple-m4"

def Gpu.render : Gpu → String
  | .none   => ""       | .sm_80  => "sm_80"
  | .sm_86  => "sm_86"  | .sm_87  => "sm_87"
  | .sm_89  => "sm_89"  | .sm_90  => "sm_90"
  | .sm_90a => "sm_90a" | .sm_100 => "sm_100"
  | .sm_100a => "sm_100a" | .sm_120 => "sm_120"

def Triple.render (t : Triple) : String :=
  let base := s!"{t.arch.render}-{t.vendor.render}-{t.os.render}"
  match t.abi with
  | ABI.none => base
  | abi      => s!"{base}-{abi.render}"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // common triples
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def Triple.x86_64_linux_gnu : Triple :=
  ⟨.x86_64, .unknown, .linux, .gnu, .generic, .none⟩

def Triple.x86_64_linux_musl : Triple :=
  ⟨.x86_64, .unknown, .linux, .musl, .generic, .none⟩

def Triple.aarch64_linux_gnu : Triple :=
  ⟨.aarch64, .unknown, .linux, .gnu, .generic, .none⟩

def Triple.aarch64_apple_darwin : Triple :=
  ⟨.aarch64, .apple, .darwin, .none, .apple_m1, .none⟩

def Triple.wasm32_wasi : Triple :=
  ⟨.wasm32, .unknown, .wasi, .none, .generic, .none⟩

def Triple.grace_hopper : Triple :=
  ⟨.aarch64, .nvidia, .linux, .gnu, .neoverse_v2, .sm_90a⟩

def Triple.jetson_orin : Triple :=
  ⟨.aarch64, .nvidia, .linux, .gnu, .cortex_a78ae, .sm_87⟩

def Triple.dgx_blackwell : Triple :=
  ⟨.aarch64, .nvidia, .linux, .gnu, .neoverse_v2, .sm_100a⟩

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                   // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#guard Triple.x86_64_linux_gnu.render == "x86_64-unknown-linux-gnu"
#guard Triple.aarch64_apple_darwin.render == "aarch64-apple-darwin"
#guard Triple.wasm32_wasi.render == "wasm32-unknown-wasi"
#guard Triple.grace_hopper.render == "aarch64-nvidia-linux-gnu"
#guard Triple.grace_hopper.gpu.render == "sm_90a"
#guard Triple.grace_hopper.cpu.render == "neoverse-v2"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // codegen // names
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def Arch.name : Arch → String
  | .x86_64 => "x86_64" | .aarch64 => "aarch64"
  | .riscv64 => "riscv64" | .wasm32 => "wasm32" | .armv7 => "armv7"

def Vendor.name : Vendor → String
  | .unknown => "unknown" | .pc => "pc"
  | .apple => "apple" | .nvidia => "nvidia"

def OS.name : OS → String
  | .linux => "linux" | .darwin => "darwin"
  | .windows => "windows" | .wasi => "wasi" | .none => "none"

def ABI.name : ABI → String
  | .gnu => "gnu" | .musl => "musl" | .eabi => "eabi"
  | .eabihf => "eabihf" | .msvc => "msvc" | .none => "none"

def Cpu.name : Cpu → String
  | .generic => "generic" | .native => "native"
  | .x86_64_v2 => "x86_64_v2" | .x86_64_v3 => "x86_64_v3" | .x86_64_v4 => "x86_64_v4"
  | .znver3 => "znver3" | .znver4 => "znver4" | .znver5 => "znver5"
  | .sapphirerapids => "sapphirerapids" | .alderlake => "alderlake"
  | .neoverse_v2 => "neoverse_v2" | .neoverse_n2 => "neoverse_n2"
  | .cortex_a78ae => "cortex_a78ae" | .cortex_a78c => "cortex_a78c"
  | .apple_m1 => "apple_m1" | .apple_m2 => "apple_m2"
  | .apple_m3 => "apple_m3" | .apple_m4 => "apple_m4"

def Gpu.name : Gpu → String
  | .none => "none" | .sm_80 => "sm_80" | .sm_86 => "sm_86"
  | .sm_87 => "sm_87" | .sm_89 => "sm_89" | .sm_90 => "sm_90"
  | .sm_90a => "sm_90a" | .sm_100 => "sm_100"
  | .sm_100a => "sm_100a" | .sm_120 => "sm_120"

end Continuity.Build
