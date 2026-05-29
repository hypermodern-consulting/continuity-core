# Examples

## Quick start

```bash
# One-time: point continuity at your tools
continuity init-buck2 --tools-specification=tools.json my-project/

# Build
cd my-project
buck2 build //...
```

## tools.json

```json
{
  "lean": { "root": "/path/to/lean-toolchain" },
  "cxx":  { "cc": "/usr/bin/gcc", "cxx": "/usr/bin/g++" },
  "haskell": { "ghc": "/usr/bin/ghc" },
  "rust": null,
  "nv": null,
  "reapi": null
}
```

## What init-buck2 produces

```
my-project/
  .buckroot
  .buckconfig          # tool paths from your spec
  .gitignore           # buck-out excluded
  toolchains/
    lean.bzl           # lean_library, lean_binary rules
    BUCK               # system_demo_toolchains
```

After that, write BUCK files and build. No lake, no elan, no nix.
