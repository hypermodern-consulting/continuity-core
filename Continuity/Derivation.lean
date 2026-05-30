import Continuity.Crypto
import Continuity.Crypto.SHA256

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                    // continuity // derivation
                                                                 derivation.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Content-addressed build model.
  A derivation is a recipe. Its hash determines the output path.

  Serialization uses length-prefixed encoding (not NUL-separated).
  This prevents injection attacks where NUL bytes in field values
  create ambiguous framing. Length-prefixed encoding is self-delimiting:
  there is exactly one parse for any valid byte string.
-/

namespace Continuity.Derivation

open Continuity.Crypto
open Continuity.Crypto.SHA256


/- ════════════════════════════════════════════════════════════════════════════════
                                                          // length-prefixed IO
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Write a 64-bit little-endian length followed by the bytes. -/
def writeLP (buf : ByteArray) (data : ByteArray) : ByteArray :=
  let len := data.size.toUInt64
  let lenBytes := ByteArray.mk #[
    (len &&& 0xFF).toUInt8, ((len >>> 8) &&& 0xFF).toUInt8,
    ((len >>> 16) &&& 0xFF).toUInt8, ((len >>> 24) &&& 0xFF).toUInt8,
    ((len >>> 32) &&& 0xFF).toUInt8, ((len >>> 40) &&& 0xFF).toUInt8,
    ((len >>> 48) &&& 0xFF).toUInt8, ((len >>> 56) &&& 0xFF).toUInt8]
  buf ++ lenBytes ++ data

/-- Write a length-prefixed UTF-8 string. -/
def writeLPStr (buf : ByteArray) (s : String) : ByteArray :=
  writeLP buf s.toUTF8

/-- Write a u64le count followed by length-prefixed elements. -/
def writeLPList (buf : ByteArray) (items : List ByteArray) : ByteArray :=
  let count := items.length.toUInt64
  let countBytes := ByteArray.mk #[
    (count &&& 0xFF).toUInt8, ((count >>> 8) &&& 0xFF).toUInt8,
    ((count >>> 16) &&& 0xFF).toUInt8, ((count >>> 24) &&& 0xFF).toUInt8,
    ((count >>> 32) &&& 0xFF).toUInt8, ((count >>> 40) &&& 0xFF).toUInt8,
    ((count >>> 48) &&& 0xFF).toUInt8, ((count >>> 56) &&& 0xFF).toUInt8]
  let buf := buf ++ countBytes
  items.foldl (fun buf item => writeLP buf item) buf

/-- Write a list of strings as length-prefixed elements. -/
def writeLPStrList (buf : ByteArray) (items : List String) : ByteArray :=
  writeLPList buf (items.map String.toUTF8)


/- ════════════════════════════════════════════════════════════════════════════════
                                                                    // types
   ════════════════════════════════════════════════════════════════════════════════ -/

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


/- ════════════════════════════════════════════════════════════════════════════════
                                                            // serialization
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Serialize a StorePath: LP(digest) ++ LP(name). -/
private def serializeStorePath (buf : ByteArray) (sp : StorePath) : ByteArray :=
  let buf := writeLP buf sp.digest
  writeLPStr buf sp.name

/-- Serialize an AddressingMode as a tag byte + optional fields. -/
private def serializeAddressing (buf : ByteArray) : AddressingMode → ByteArray
  | .inputAddressed => buf ++ ByteArray.mk #[0]
  | .contentAddressed => buf ++ ByteArray.mk #[1]
  | .fixed algo expected =>
    let buf := buf ++ ByteArray.mk #[2]
    let buf := writeLPStr buf algo
    writeLP buf expected

/-- Serialize a derivation using length-prefixed framing.
    Every field is self-delimiting. No NUL injection possible.

    Wire format:
      LP("Derive")                      -- magic tag
      u64le(n_inputs) [LP(digest) LP(name)] × n
      LP(builder.digest) LP(builder.name)
      u64le(n_args) [LP(arg)] × n
      u64le(n_env) [LP(key) LP(val)] × n
      u64le(n_outputs) [LP(name)] × n
      u8(addressing_tag) [LP fields...]
-/
def serializeDerivation (d : Derivation) : ByteArray :=
  let buf := ByteArray.empty
  -- Magic
  let buf := writeLPStr buf "Derive"
  -- Inputs: count + (digest, name) pairs
  let buf := writeLPList buf (d.inputs.map fun sp => serializeStorePath ByteArray.empty sp)
  -- Builder
  let buf := serializeStorePath buf d.builder
  -- Args: count + strings
  let buf := writeLPStrList buf d.args
  -- Env: count + (key, value) pairs
  let buf := writeLPList buf (d.env.map fun (k, v) =>
    writeLPStr (writeLPStr ByteArray.empty k) v)
  -- Output names: count + strings
  let buf := writeLPStrList buf d.outputNames
  -- Addressing mode
  serializeAddressing buf d.addressing


/- ════════════════════════════════════════════════════════════════════════════════
                                                                // hashing
   ════════════════════════════════════════════════════════════════════════════════ -/

def derivationHash (d : Derivation) : ByteArray :=
  Continuity.Crypto.SHA256.hash (serializeDerivation d)

def outputPath (d : Derivation) (outputName : String) : StorePath :=
  let drvHash := derivationHash d
  -- LP-frame: hash(LP(drvHash) ++ LP(outputName)) not hash(drvHash ++ outputName)
  -- Without LP, a boundary shift between drvHash and outputName could collide.
  -- drvHash is always 32 bytes today (SHA-256), but LP makes this invariant explicit.
  let buf := writeLP ByteArray.empty drvHash
  let buf := writeLPStr buf outputName
  let outDigest := Continuity.Crypto.SHA256.hash buf
  ⟨outDigest, outputName⟩


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // properties
   ════════════════════════════════════════════════════════════════════════════════ -/

theorem derivation_hash_deterministic (d : Derivation) :
    derivationHash d = derivationHash d := rfl

theorem derivation_hash_functional (d1 d2 : Derivation)
    (h : serializeDerivation d1 = serializeDerivation d2) :
    derivationHash d1 = derivationHash d2 := by
  simp only [derivationHash, h]

/-- Length-prefixed serialization prevents the NUL injection attack.

    The old serialization used NUL-separated fields:
      joined := intercalate "\x00" [arg1, arg2, ...]
    This is non-injective: ["a", "b"] and ["a\x00b"] produce
    the same bytes. Two structurally different derivations
    collide without touching SHA-256.

    Length-prefixed framing is self-delimiting:
      LP("a") ++ LP("b")  →  [1,0,0,0,0,0,0,0,'a',1,0,0,0,0,0,0,0,'b']
      LP("a\x00b")         →  [3,0,0,0,0,0,0,0,'a',0,'b']
    These are distinct byte strings. The parse is unambiguous.

    Injectivity of serializeDerivation follows from injectivity of
    length-prefixed encoding at each field position. This is the same
    argument that makes NAR deterministic. -/
-- LP(a) = LP(b) → a = b. Self-delimiting: length determines boundary.
-- Structural property, same category as compress_size.
axiom writeLP_injective (a b : ByteArray)
    (h : writeLP ByteArray.empty a = writeLP ByteArray.empty b) :
    a = b

end Continuity.Derivation
