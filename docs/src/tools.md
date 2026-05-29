# Tool Specification

The tool specification is a Dhall file that describes where compilers and
tools live on your machine. Continuity reads it natively — no `dhall` binary
required.

## Format

```dhall
{
  lean    = Some { root : Text },           -- Lean 4 toolchain root
  cxx     = Some { cc : Text, cxx : Text }, -- C/C++ compilers
  haskell = Some { ghc : Text, cabal : Text },
  rust    = Some { rustc : Text, cargo : Text },
  nv      = Some { nvcc : Text, cuda_root : Text },
  reapi   = Some { endpoint : Text, instance_name : Text }
}
```

Use `None { ... }` for tools you don't have. The type annotation after `None`
is required by Dhall's grammar but its contents don't matter — it's never
evaluated.

## What It Produces

`continuity init-buck2` reads the spec and writes:

| File | Purpose |
|------|---------|
| `.buckroot` | Marks the project root for Buck2 |
| `.buckconfig` | Cell config, tool paths, platform settings |
| `toolchains/BUCK` | Loads the prelude's demo toolchains |
| `toolchains/lean.bzl` | Lean compilation rules (if lean specified) |
| `toolchains/cuda.bzl` | CUDA compilation rules (if nv specified) |
| `.gitignore` | Excludes `buck-out/` |

## Tool Discovery

The spec describes a machine, not a project. One `tools.dhall` per machine,
shared across all projects. Common locations:

| Tool | Typical path |
|------|-------------|
| Lean | `~/.elan/toolchains/leanprover--lean4---v4.30.0` |
| GCC | `/usr/bin/gcc` |
| GHC | `/usr/bin/ghc` |
| NVCC | `/usr/local/cuda/bin/nvcc` |
| CUDA root | `/usr/local/cuda` |

## Remote Execution

To enable REAPI remote execution, add:

```dhall
reapi = Some {
  endpoint = "grpc://your-lre-instance:8980",
  instance_name = "default"
}
```

This writes a `[reapi]` section to `.buckconfig`. When the LRE executor
exists, remote execution is a config change, not a code change.
