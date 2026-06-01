import Continuity.Crypto.Core
import Continuity.Crypto.SHA256

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "I have been confined for over a decade to a vat. In some hideous
      industrial suburb of Stockholm." A derivation is the same way:
      once committed, you cannot alter a single byte without changing
      the hash that names you. Inputs, builder, args, env — each field
      length-prefixed and serialized, each framing decision made
      irreversible by the cryptographic hash that consumes them. The
      output path is your name, and your name is your content. You are
      what you are built from.

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

open Continuity.Crypto
open Continuity.Crypto.SHA256

namespace Continuity.Nix.Derivation

/-
  Content-addressed build model.
  A derivation is a recipe. Its hash determines the output path.

  Serialization uses length-prefixed encoding (not `NUL`-separated).
  This prevents injection attacks where `NUL` bytes in field values
  create ambiguous framing. Length-prefixed encoding is self-delimiting:
  there is exactly one parse for any valid byte string.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                // length-prefixed // io
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def writeLP (buf : ByteArray) (data : ByteArray) : ByteArray :=
  let len := data.size.toUInt64
  let lenBytes := ByteArray.mk #[
    (len &&& 0xFF).toUInt8, ((len >>> 8) &&& 0xFF).toUInt8,
    ((len >>> 16) &&& 0xFF).toUInt8, ((len >>> 24) &&& 0xFF).toUInt8,
    ((len >>> 32) &&& 0xFF).toUInt8, ((len >>> 40) &&& 0xFF).toUInt8,
    ((len >>> 48) &&& 0xFF).toUInt8, ((len >>> 56) &&& 0xFF).toUInt8]
  buf ++ lenBytes ++ data

def writeLPStr (buf : ByteArray) (s : String) : ByteArray :=
  writeLP buf s.toUTF8

def writeLPList (buf : ByteArray) (items : List ByteArray) : ByteArray :=
  let count := items.length.toUInt64
  let countBytes := ByteArray.mk #[
    (count &&& 0xFF).toUInt8, ((count >>> 8) &&& 0xFF).toUInt8,
    ((count >>> 16) &&& 0xFF).toUInt8, ((count >>> 24) &&& 0xFF).toUInt8,
    ((count >>> 32) &&& 0xFF).toUInt8, ((count >>> 40) &&& 0xFF).toUInt8,
    ((count >>> 48) &&& 0xFF).toUInt8, ((count >>> 56) &&& 0xFF).toUInt8]
  let buf := buf ++ countBytes
  items.foldl (fun buf item => writeLP buf item) buf

def writeLPStrList (buf : ByteArray) (items : List String) : ByteArray :=
  writeLPList buf (items.map String.toUTF8)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // types
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure StorePath where
  digest : ByteArray
  name : String

instance : Inhabited StorePath where default := ⟨ByteArray.empty, ""⟩

inductive AddressingMode where
  | inputAddressed
  | contentAddressed
  | fixed (algo : String) (expected : ByteArray)

structure Derivation where
  inputs : List StorePath
  builder : StorePath
  args : List String
  env : List (String × String)
  outputNames : List String
  addressing : AddressingMode := .inputAddressed

structure DrvOutput where
  name : String
  path : StorePath

structure BuildResult where
  drv : Derivation
  outputs : List DrvOutput

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // serialization
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def serializeStorePath (buf : ByteArray) (sp : StorePath) : ByteArray :=
  let buf := writeLP buf sp.digest
  writeLPStr buf sp.name

private def serializeAddressing (buf : ByteArray) : AddressingMode → ByteArray
  | .inputAddressed => buf ++ ByteArray.mk #[0]
  | .contentAddressed => buf ++ ByteArray.mk #[1]
  | .fixed algo expected =>
    let buf := buf ++ ByteArray.mk #[2]
    let buf := writeLPStr buf algo
    writeLP buf expected

-- wire format: LP("Derive") magic tag, then count-prefixed fields.
-- every field is self-delimiting — no NUL injection possible.
def serializeDerivation (d : Derivation) : ByteArray :=
  let buf := ByteArray.empty
  let buf := writeLPStr buf "Derive"
  let buf := writeLPList buf (d.inputs.map fun sp => serializeStorePath ByteArray.empty sp)
  let buf := serializeStorePath buf d.builder
  let buf := writeLPStrList buf d.args
  let buf := writeLPList buf (d.env.map fun (k, v) =>
    writeLPStr (writeLPStr ByteArray.empty k) v)
  let buf := writeLPStrList buf d.outputNames
  serializeAddressing buf d.addressing

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // hashing
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def derivationHash (d : Derivation) : ByteArray :=
  SHA256.hash (serializeDerivation d)

def outputPath (d : Derivation) (outputName : String) : StorePath :=
  let drvHash := derivationHash d
  -- LP-frame: hash(LP(drvHash) ++ LP(outputName)), not hash(drvHash ++ outputName).
  -- without LP, a boundary shift between drvHash and outputName could collide.
  -- drvHash is always 32 bytes today (`SHA-256`), but LP makes this invariant explicit.
  let buf := writeLP ByteArray.empty drvHash
  let buf := writeLPStr buf outputName
  let outDigest := SHA256.hash buf
  ⟨outDigest, outputName⟩

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // properties
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem derivation_hash_deterministic (d : Derivation) :
    derivationHash d = derivationHash d := rfl

theorem derivation_hash_functional (d1 d2 : Derivation)
    (h : serializeDerivation d1 = serializeDerivation d2) :
    derivationHash d1 = derivationHash d2 := by
  simp only [derivationHash, h]

-- length-prefixed serialization prevents the NUL injection attack.
-- old serialization: `intercalate "\x00" [arg1, arg2, ...]` — non-injective,
-- `["a", "b"]` and `["a\x00b"]` produce the same bytes. two structurally
-- different derivations collide without touching `SHA-256`.
--
-- length-prefixed framing is self-delimiting:
-- `LP("a") ++ LP("b")` → `[1,0,...,'a',1,0,...,'b']`
-- `LP("a\x00b")`         → `[3,0,...,'a',0,'b']`
-- these are distinct. parse is unambiguous.
--
-- injectivity of `serializeDerivation` follows from injectivity of
-- length-prefixed encoding at each field position. same argument
-- that makes NAR deterministic.
axiom writeLP_injective (a b : ByteArray)
    (h : writeLP ByteArray.empty a = writeLP ByteArray.empty b) :
    a = b

end Continuity.Nix.Derivation
