# Quick Start

## Prerequisites

- [Lean 4](https://leanprover.github.io/lean4/doc/) (via elan, one time)
- [Buck2](https://buck2.build/) (build system)
- GCC and/or GHC (target compilers)

## Bootstrap

Continuity builds itself with Lake (Lean's built-in build tool) exactly once.
After that, everything uses Buck2.

```bash
git clone https://github.com/b7r6/continuity
cd continuity
lake build
```

This produces the `continuity` binary.

## Initialize a Project

Create a tool specification for your machine:

```dhall
-- tools.dhall
{
  lean = Some { root = "/home/you/.elan/toolchains/leanprover--lean4---v4.30.0" },
  cxx  = Some { cc = "/usr/bin/gcc", cxx = "/usr/bin/g++" },
  haskell = Some { ghc = "/usr/bin/ghc", cabal = "/usr/bin/cabal" },
  rust = None { rustc : Text, cargo : Text },
  nv   = None { nvcc : Text, cuda_root : Text },
  reapi = None { endpoint : Text, instance_name : Text }
}
```

Then initialize:

```bash
lake exe continuity init-buck2 --tools-specification=tools.dhall ~/src/my-project
```

This writes `.buckconfig`, `toolchains/`, and `.buckroot`.

## Write a BUCK File

```python
# BUCK
load("@toolchains//:lean.bzl", "lean_library", "lean_binary")

lean_library(
    name = "mylib",
    srcs = ["MyLib/Greet.lean"],
)

lean_binary(
    name = "hello",
    srcs = ["MyLib/Main.lean"],
    deps = [":mylib"],
)
```

## Build

```bash
cd ~/src/my-project
buck2 build //...
```

No Lake. No elan. No Nix. Just Buck2 and tool paths.
