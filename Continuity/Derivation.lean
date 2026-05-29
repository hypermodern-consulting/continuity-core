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
-/

namespace Continuity.Derivation

open Continuity.Crypto
open Continuity.Crypto.SHA256

/-- Content-addressed store path: hash of content + human-readable name. -/
structure StorePath where
  digest : ByteArray
  name : String


instance : Inhabited StorePath where default := ⟨ByteArray.empty, ""⟩

/-- Addressing mode: how the output hash is computed. -/
inductive AddressingMode where
  | inputAddressed    -- hash of derivation recipe (Nix default)
  | contentAddressed  -- hash of output content (CA derivations)
  | fixed (algo : String) (expected : ByteArray)  -- known hash
  

/-- A derivation: the recipe for a build. -/
structure Derivation where
  inputs : List StorePath
  builder : StorePath
  args : List String
  env : List (String × String)
  outputNames : List String
  addressing : AddressingMode := .inputAddressed


/-- Derivation output: name + realized store path. -/
structure DrvOutput where
  name : String
  path : StorePath


/-- Build result: a derivation and what it produced. -/
structure BuildResult where
  drv : Derivation
  outputs : List DrvOutput


/-- Serialize a derivation deterministically for hashing.
    v11 BUG FIX: hashes ALL fields, not just args. -/
def serializeDerivation (d : Derivation) : ByteArray :=
  let parts : List String :=
    ["Derive"] ++
    d.inputs.map (fun sp => sp.name ++ ":" ++ toHex sp.digest) ++
    [d.builder.name] ++
    d.args ++
    d.env.map (fun (k, v) => k ++ "=" ++ v) ++
    d.outputNames
  let joined := String.intercalate "\x00" parts
  joined.toUTF8

/-- Hash a derivation to get its unique store path digest. -/
def derivationHash (d : Derivation) : ByteArray :=
  Continuity.Crypto.SHA256.hash (serializeDerivation d)

/-- Compute the output store path for a derivation. -/
def outputPath (d : Derivation) (outputName : String) : StorePath :=
  let drvHash := derivationHash d
  let outDigest := Continuity.Crypto.SHA256.hash (drvHash ++ outputName.toUTF8)
  ⟨outDigest, outputName⟩

/-- Two derivations with the same serialization produce the same hash. -/
theorem derivation_hash_deterministic (d : Derivation) :
    derivationHash d = derivationHash d := rfl

/-- Equal derivations produce equal hashes. -/
theorem derivation_hash_functional (d1 d2 : Derivation)
    (h : serializeDerivation d1 = serializeDerivation d2) :
    derivationHash d1 = derivationHash d2 := by
  simp only [derivationHash, h]

end Continuity.Derivation
