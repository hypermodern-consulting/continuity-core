# Examples

The `examples/` directory contains working projects for each supported language.

## Lean: Hello World

```
examples/lean-hello/
  MyLib/Greet.lean    # Library: greet function
  MyLib/Main.lean     # Binary: imports Greet, prints hello
  BUCK                # lean_library + lean_binary
```

Build and run:
```bash
continuity init-buck2 --tools-specification=tools.dhall project/
cp -r examples/lean-hello/* project/
cd project && buck2 build //:hello && buck2 run //:hello
```

## C: Varint Codec

```
examples/c-codec/
  varint.h            # Header-only varint encode/decode
  main.c              # 8 roundtrip edge-case tests
  BUCK                # genrule with gcc
```

## Haskell: Varint Codec

```
examples/hs-codec/
  Varint.hs           # ByteString.Builder varint + QuickCheck-style tests
  BUCK                # genrule with ghc
```

## CUDA: GPU Hello

```
examples/cuda-hello/
  hello.cu            # Kernel launch with device detection
  BUCK                # cuda_binary targeting SM 9.0
```

Requires NVIDIA CUDA SDK. Use `tools-with-gpu.dhall` for the tool spec.
