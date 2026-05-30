# Hacking on Continuity

## Conventions

**Straylight standard**: declared axioms, derivations, zero sorry.

- `set_option autoImplicit false` at the top of every file (after imports)
- No implicit variables — say what you mean
- Label conjectures explicitly when underlying facts are not established
- `CDR` byline (Claude, DeepSeek, Reesman — alphabetical) for collaborative work

**Naming**:
- Types: `PascalCase`
- Functions: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE` for wire protocol constants, `camelCase` for everything else
- Namespaces: `Continuity.Layer.Module`

**Power hierarchy for codecs**: `Box` > `Scanner` > `Parser`. Use the least
powerful tool that gets the job done. If you can prove roundtrip, use `Box`.
If you only need boundary detection, use `Scanner`. If you only need parsing
without serialization proof, use `Parser`.

## Build

```bash
# Bootstrap (one time)
lake build

# Generate Dhall/C++/Haskell prelude
lake exe continuity output/continuity-prelude

# Buck2 build
buck2 build //:continuity
```

Or via Nix:

```bash
nix build .#                         # build continuity binary
nix build .#continuity-generated     # all generated Dhall/C++/Haskell sources
nix flake check                      # run all checks
```

## Adding a Codec

1. Create `Continuity/Codec/YourProtocol.lean`
2. Import `Continuity.Codec.Box` (or Scanner/Parser as appropriate)
3. Define types, parse/serialize functions, proofs
4. Add the import to `Continuity.lean` (root module)
5. Add the file to `BUCK` source list (explicit dep order)
6. Add a `CodecModule` to `Codegen/Codec/Spec.lean` for C++/Haskell generation
7. Run `lake build && buck2 build //:continuity` — it must compile with zero sorry

Example — adding a new wire type:

```lean
import Continuity.Codec.Box

set_option autoImplicit false

namespace Continuity.Codec.MyProto

open Continuity.Codec

-- Types
structure MyFrame where
  tag : UInt8
  payload : Bytes

-- Box (bidirectional, proven roundtrip)
def myFrame : Box MyFrame where
  parse bs := ...
  serialize f := ...
  roundtrip f := by ...
  consumption f extra := by ...

end Continuity.Codec.MyProto
```

## Adding a Language Target

The build system supports four toolchains:

| Language | Rule file | Rules |
|----------|-----------|-------|
| Lean | `toolchains/lean.bzl` | `lean_library`, `lean_binary` |
| CUDA | `toolchains/cuda.bzl` | `cuda_library`, `cuda_binary` |
| C | genrule + gcc | (no dedicated .bzl yet) |
| Haskell | genrule + ghc | (no dedicated .bzl yet) |

To add a toolchain:
1. Write `toolchains/yourlang.bzl` with compilation rules
2. Add `[yourlang]` section support to `InitBuck2.lean`
3. Add the field to `ToolPaths` and `extractTools`
4. Add copy logic for the `.bzl` file
5. Create an example in `examples/`

## Key Design Decisions

**Action is the primitive, not Derivation.** The DICE execution unit
(Action) is the true build primitive. Derivations are computed from
actions, not the other way around.

**StateMachine is top-level, not a codec.** The state machine drives
protocols; codecs parse bytes. They're different concerns. The state
machine produces intents (sendServerHello); the event loop maps intents
to io_uring submissions.

**SHA256Hash is a refinement type.** `{ bytes : ByteArray // bytes.size = 32 }`.
The 32-byte invariant is enforced by the type, not by hope. You can't
construct a digest from 7 bytes of garbage.

**The Dhall parser is self-hosted.** `Codec/Dhall/{Lexer,Parser}.lean`
parse the tool specification natively. No dhall binary, no jq, no Python.
One Lean binary does everything.

## Testing

```bash
# C property tests (326K tests, compiles in <1s)
gcc -O2 -o test/codec_test test/codec_test.c
./test/codec_test

# Haskell property tests (15K tests)
ghc -O -o test/hs_test test/CodecTest.hs
./test/hs_test
```

## What Zero Sorry Means

Every proof obligation in the codebase is discharged. `sorry` is Lean's
"trust me" escape hatch — it lets you skip a proof. We don't use it.

The axiom budget is explicit: 5 crypto assumptions (hash_injective,
signature verification functions) and 2 structural arithmetic facts
about SHA-256 that the normalizer can't close. These are documented
in the README and in `Crypto.lean`.

If you add a `sorry`, the CI should reject it. If you add an `axiom`,
document it in the axiom budget and justify why it's necessary.
