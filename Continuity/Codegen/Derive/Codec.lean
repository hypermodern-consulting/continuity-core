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

/-
  Derive codec codegen — unified entry point for Codec/Protocol/ type derivations.

  Walks the protocol type definitions (Git, Protobuf, Nix, HTTP, etc.)
  and produces C++ and Haskell codec AST output with renderable text.

  Currently produces empty stubs. The real derivation requires Lean
  metaprogramming to walk inductive type definitions and generate
  serializers/deserializers for each protocol format — this is Phase 3 work.

  The framework is in place: `deriveCppCodecs` and `deriveHaskellCodecs`
  return `List (String × String)` pairs of (filename, rendered text).
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // cpp // codecs
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def deriveCppCodecs : List (String × String) := []

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // haskell // codecs
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def deriveHaskellCodecs : List (String × String) := []

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                // backward-compat // aliases
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- these names match what Main.lean currently references, to minimize
-- the delta during the transition from the old Codec/ files.
def cppCodecFiles : List (String × String) := deriveCppCodecs
def hsCodecFiles : List (String × String) := deriveHaskellCodecs

end Continuity.Codegen.Derive.Codec
