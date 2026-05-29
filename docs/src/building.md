# Building Projects

## Supported Languages

| Language | Build rule | Source |
|----------|-----------|--------|
| Lean 4 | `lean_library`, `lean_binary` | `toolchains/lean.bzl` |
| CUDA | `cuda_library`, `cuda_binary` | `toolchains/cuda.bzl` |
| C | `genrule` + gcc | Buck2 built-in |
| Haskell | `genrule` + ghc | Buck2 built-in |

## Lean Projects

```python
load("@toolchains//:lean.bzl", "lean_library", "lean_binary")

lean_library(
    name = "mylib",
    srcs = [
        "MyLib/Base.lean",    # Listed in dependency order.
        "MyLib/Utils.lean",   # Imports must come before importees.
        "MyLib/Core.lean",
    ],
)

lean_binary(
    name = "myapp",
    srcs = ["MyLib/Main.lean"],
    deps = [":mylib"],
)
```

Sources must be listed in dependency order — leaves first, root last.
Lean compiles files sequentially and needs imports to exist as `.olean`
before compiling importees. This replaces Lake's automatic import analysis.

## CUDA Projects

```python
load("@toolchains//:cuda.bzl", "cuda_library", "cuda_binary")

cuda_library(
    name = "kernels",
    srcs = ["kernels/matmul.cu", "kernels/attention.cu"],
    gpu_archs = ["90a"],  # SM 9.0a (Hopper), adjust for your GPU
)

cuda_binary(
    name = "train",
    srcs = ["main.cu"],
    deps = [":kernels"],
    link_flags = ["-lcublas"],
)
```

`gpu_archs` maps to `-gencode arch=compute_XX,code=sm_XX` flags.
Common values: `"80"` (A100), `"89"` (RTX 4090), `"90"` (H100),
`"90a"` (H100 SXM), `"100a"` (B200).

## C and Haskell

Until dedicated `.bzl` files exist, use `genrule`:

```python
genrule(
    name = "my-c-program",
    srcs = ["main.c", "util.h"],
    out = "my-program",
    bash = "SRCDIR=`dirname $SRCS | head -1` && gcc -O2 -o $OUT $SRCDIR/main.c -I$SRCDIR",
)
```

## Buck2 Caching

Buck2 caches compilation results automatically. The Lean toolchain splits
compilation into two actions (library compile, binary link) so changing
`Main.lean` doesn't recompile the library. Incremental builds are fast.

```
$ buck2 build //:myapp
[cached: 1, local: 1]   # Only Main.lean recompiled
BUILD SUCCEEDED
```
