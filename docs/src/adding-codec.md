# Adding a Codec

## Step by Step

### 1. Create the Lean file

```lean
-- Continuity/Codec/MyProtocol.lean
import Continuity.Codec.Box

set_option autoImplicit false

namespace Continuity.Codec.MyProtocol

open Continuity.Codec

-- Define your types
structure MyMessage where
  tag : UInt8
  payload : Bytes

-- Build a Box if you can prove roundtrip
def myMessage : Box MyMessage where
  parse bs := ...
  serialize m := ...
  roundtrip m := by ...
  consumption m extra := by ...

end Continuity.Codec.MyProtocol
```

### 2. Register in root module

Add `import Continuity.Codec.MyProtocol` to `Continuity.lean`.

### 3. Add to BUCK sources

Add `"Continuity/Codec/MyProtocol.lean"` to the `srcs` list in `BUCK`,
in dependency order (after any files it imports).

### 4. Add CodecSpec for codegen

In `Codegen/Codec/Spec.lean`, add a module definition:

```lean
def myProtocolModule : CodecModule where
  name := "MyProtocol"
  namespace_ := "continuity::my_protocol"
  doc := "My protocol wire format"
  enums := [ ... ]
  structs := [ ... ]
  constants := [ ... ]
```

Add it to `allModules`.

### 5. Build and test

```bash
lake build                     # bootstrap
buck2 build //:continuity      # must compile with zero sorry
gcc -O2 ...                    # run C property tests
ghc -O ...                     # run Haskell property tests
```

## Guidelines

- Use `Box` when you can prove roundtrip. Use `Scanner` for boundary detection.
  Use `Parser` only when roundtrip isn't possible (stateful protocols, ambiguous formats).
- Every constant belongs in `Limits.lean` with a positivity proof.
- Every bounded value uses `Guards.bounded` to connect to the resource exhaustion theorem.
- Test vectors go in the codec file as `#eval` assertions.
