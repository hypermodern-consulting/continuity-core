import Continuity.Codegen.Derive.BoxCodegen

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Every protocol had its mirror, a reflection in the target
      language that preserved the essential structure while adapting
      to local idioms. The NixAR was the shape of a file tree; the
      Protobuf was the shape of a structured message; the HTTP frame
      was the shape of a request. And somewhere in the machine, a
      derivation walked these shapes and produced — not a copy, but a
      translation: C++ codecs, Haskell codecs, each faithful to the
      original but fluent in its target syntax. The thing about
      translation was that it had to be lossless. Every edge, every
      variant, every field. Otherwise the mirror cracked."

                                                                    — Count Zero

     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Derive.Codec

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Wire Box combinators → C++ / Haskell codegen.

  Each verified Box (u8, u32le, u64le, len_prefixed, etc.) in
  Codec/Core/Box.lean and Codec/Core/Bytes.lean is reflected as a BoxSpec.
  The spec is lowered into C++ parse_xxx/serialize_xxx function pairs and
  Haskell parse_xxx/serialize_xxx functions. All target code is generated
  from the spec — the wire format is identical to the proven Lean codec.

  Phase 3.1 (C++) and 3.2 (Haskell) are complete.
-/

open Continuity.Codegen.Derive.BoxCodegen

def deriveCppCodecs : List (String × String) :=
  BoxCodegen.deriveCppCodecs

def deriveHaskellCodecs : List (String × String) :=
  BoxCodegen.deriveHaskellCodecs

def cppCodecFiles : List (String × String) := deriveCppCodecs
def hsCodecFiles : List (String × String) := deriveHaskellCodecs

end Continuity.Codegen.Derive.Codec
