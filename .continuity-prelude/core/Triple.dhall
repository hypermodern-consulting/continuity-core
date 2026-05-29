let Arch : Type = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >

in  let Vendor : Type = < unknown | pc | apple | nvidia >

in  let OS : Type = < linux | darwin | windows | wasi | none >

in  let ABI : Type = < gnu | musl | eabi | eabihf | msvc | none >

in  let Cpu : Type = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >

in  let Gpu : Type = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >

in  let Triple : Type = { arch : Arch
            , vendor : Vendor
            , os : OS
            , abi : ABI
            , cpu : Cpu
            , gpu : Gpu
            }

in  let renderArch = λ(a : Arch) → merge { x86_64 = "x86_64"
                , aarch64 = "aarch64"
                , riscv64 = "riscv64"
                , wasm32 = "wasm32"
                , armv7 = "armv7"
                } a

in  let renderVendor = λ(v : Vendor) → merge { unknown = "unknown"
                  , pc = "pc"
                  , apple = "apple"
                  , nvidia = "nvidia"
                  } v

in  let renderOS = λ(o : OS) → merge { linux = "linux"
              , darwin = "darwin"
              , windows = "windows"
              , wasi = "wasi"
              , none = "none"
              } o

in  let renderABI = λ(a : ABI) → merge { gnu = Some "gnu"
               , musl = Some "musl"
               , eabi = Some "eabi"
               , eabihf = Some "eabihf"
               , msvc = Some "msvc"
               , none = None Text
               } a

in  let renderCpu = λ(c : Cpu) → merge { generic = "generic"
               , native = "native"
               , x86_64_v2 = "x86-64-v2"
               , x86_64_v3 = "x86-64-v3"
               , x86_64_v4 = "x86-64-v4"
               , znver3 = "znver3"
               , znver4 = "znver4"
               , znver5 = "znver5"
               , sapphirerapids = "sapphirerapids"
               , alderlake = "alderlake"
               , neoverse_v2 = "neoverse-v2"
               , neoverse_n2 = "neoverse-n2"
               , cortex_a78ae = "cortex-a78ae"
               , cortex_a78c = "cortex-a78c"
               , apple_m1 = "apple-m1"
               , apple_m2 = "apple-m2"
               , apple_m3 = "apple-m3"
               , apple_m4 = "apple-m4"
               } c

in  let renderGpu = λ(g : Gpu) → merge { none = None Text
               , sm_80 = Some "sm_80"
               , sm_86 = Some "sm_86"
               , sm_87 = Some "sm_87"
               , sm_89 = Some "sm_89"
               , sm_90 = Some "sm_90"
               , sm_90a = Some "sm_90a"
               , sm_100 = Some "sm_100"
               , sm_100a = Some "sm_100a"
               , sm_120 = Some "sm_120"
               } g

in  let abiIsNone = λ(a : ABI) → merge { gnu = False
               , musl = False
               , eabi = False
               , eabihf = False
               , msvc = False
               , none = True
               } a

in  let gpuIsNone = λ(g : Gpu) → merge { none = True
               , sm_80 = False
               , sm_86 = False
               , sm_87 = False
               , sm_89 = False
               , sm_90 = False
               , sm_90a = False
               , sm_100 = False
               , sm_100a = False
               , sm_120 = False
               } g

in  let x86_64-linux-gnu : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.x86_64
                      , vendor = < unknown | pc | apple | nvidia >.unknown
                      , os = < linux | darwin | windows | wasi | none >.linux
                      , abi = < gnu | musl | eabi | eabihf | msvc | none >.gnu
                      , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.generic
                      , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.none
                      }

in  let x86_64-linux-musl : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.x86_64
                       , vendor = < unknown | pc | apple | nvidia >.unknown
                       , os = < linux | darwin | windows | wasi | none >.linux
                       , abi = < gnu | musl | eabi | eabihf | msvc | none >.musl
                       , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.generic
                       , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.none
                       }

in  let aarch64-linux-gnu : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.aarch64
                       , vendor = < unknown | pc | apple | nvidia >.unknown
                       , os = < linux | darwin | windows | wasi | none >.linux
                       , abi = < gnu | musl | eabi | eabihf | msvc | none >.gnu
                       , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.generic
                       , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.none
                       }

in  let aarch64-apple-darwin : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.aarch64
                          , vendor = < unknown | pc | apple | nvidia >.apple
                          , os = < linux | darwin | windows | wasi | none >.darwin
                          , abi = < gnu | musl | eabi | eabihf | msvc | none >.none
                          , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.apple_m1
                          , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.none
                          }

in  let wasm32-wasi : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.wasm32
                 , vendor = < unknown | pc | apple | nvidia >.unknown
                 , os = < linux | darwin | windows | wasi | none >.wasi
                 , abi = < gnu | musl | eabi | eabihf | msvc | none >.none
                 , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.generic
                 , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.none
                 }

in  let grace-hopper : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.aarch64
                  , vendor = < unknown | pc | apple | nvidia >.nvidia
                  , os = < linux | darwin | windows | wasi | none >.linux
                  , abi = < gnu | musl | eabi | eabihf | msvc | none >.gnu
                  , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.neoverse_v2
                  , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.sm_90a
                  }

in  let jetson-orin : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.aarch64
                 , vendor = < unknown | pc | apple | nvidia >.nvidia
                 , os = < linux | darwin | windows | wasi | none >.linux
                 , abi = < gnu | musl | eabi | eabihf | msvc | none >.gnu
                 , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.cortex_a78ae
                 , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.sm_87
                 }

in  let dgx-blackwell : Triple = { arch = < x86_64 | aarch64 | riscv64 | wasm32 | armv7 >.aarch64
                   , vendor = < unknown | pc | apple | nvidia >.nvidia
                   , os = < linux | darwin | windows | wasi | none >.linux
                   , abi = < gnu | musl | eabi | eabihf | msvc | none >.gnu
                   , cpu = < generic | native | x86_64_v2 | x86_64_v3 | x86_64_v4 | znver3 | znver4 | znver5 | sapphirerapids | alderlake | neoverse_v2 | neoverse_n2 | cortex_a78ae | cortex_a78c | apple_m1 | apple_m2 | apple_m3 | apple_m4 >.neoverse_v2
                   , gpu = < none | sm_80 | sm_86 | sm_87 | sm_89 | sm_90 | sm_90a | sm_100 | sm_100a | sm_120 >.sm_100a
                   }

in  { Arch = Arch
, Vendor = Vendor
, OS = OS
, ABI = ABI
, Cpu = Cpu
, Gpu = Gpu
, Triple = Triple
, renderArch = renderArch
, renderVendor = renderVendor
, renderOS = renderOS
, renderABI = renderABI
, renderCpu = renderCpu
, renderGpu = renderGpu
, abiIsNone = abiIsNone
, gpuIsNone = gpuIsNone
, x86_64-linux-gnu = x86_64-linux-gnu
, aarch64-linux-gnu = aarch64-linux-gnu
, aarch64-apple-darwin = aarch64-apple-darwin
, grace-hopper = grace-hopper
, jetson-orin = jetson-orin
, dgx-blackwell = dgx-blackwell
}
