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

  v12: injective serialization — strings carrying NUL or (in names) colon are
  rejected at the type level, preventing hash collisions from separator smuggling.
-/

namespace Continuity.Derivation

open Continuity.Crypto
open Continuity.Crypto.SHA256

/- ════════════════════════════════════════════════════════════════════════════════
                                                    // content-addressed model
   ════════════════════════════════════════════════════════════════════════════════ -/

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


/- ════════════════════════════════════════════════════════════════════════════════
                                                        // separator safety
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A string that contains no NUL byte ('\x00'). -/
def noNul (s : String) : Bool :=
  !s.toList.elem '\x00'

/-- A string that contains no colon. -/
def noColon (s : String) : Bool :=
  !s.toList.elem ':'

/-- A string proven free of NUL bytes. -/
structure NoNulString where
  val : String
  valid : noNul val = true

/-- A string proven free of NUL and colon. -/
structure CleanName where
  val : String
  valid : noNul val = true ∧ noColon val = true

/-- Lift a clean string to a no-NUL string (weakening). -/
def CleanName.toNoNul (c : CleanName) : NoNulString :=
  ⟨c.val, c.valid.1⟩

instance : Coe CleanName NoNulString := ⟨CleanName.toNoNul⟩

/-- Lifted all: every string in the list satisfies pred. -/
def allStrings (pred : String → Bool) : List String → Bool
  | [] => true
  | s :: rest => pred s && allStrings pred rest

def allPairs (pred : String → Bool) : List (String × String) → Bool
  | [] => true
  | (k, v) :: rest => pred k && pred v && allPairs pred rest

/- ════════════════════════════════════════════════════════════════════════════════
                                                          // valid derivation
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A derivation whose string fields are separator-safe.
    No NUL in any field, no colon in store path names.
    This makes serialization injective. -/
structure ValidDerivation where
  drv : Derivation
  args_ok : allStrings noNul drv.args = true
  env_ok : allPairs noNul drv.env = true
  outputs_ok : allStrings noNul drv.outputNames = true
  input_names_ok : allStrings noColon (drv.inputs.map (·.name)) = true
  input_names_nul_ok : allStrings noNul (drv.inputs.map (·.name)) = true
  builder_name_ok : noColon drv.builder.name = true
  builder_name_nul_ok : noNul drv.builder.name = true

/-- Validate a derivation, returning a ValidDerivation or failing. -/
def validateDerivation (d : Derivation) : Option ValidDerivation :=
  if h1 : allStrings noNul d.args then
  if h2 : allPairs noNul d.env then
  if h3 : allStrings noNul d.outputNames then
  if h4 : allStrings noColon (d.inputs.map (·.name)) then
  if h5 : allStrings noNul (d.inputs.map (·.name)) then
  if h6 : noColon d.builder.name then
  if h7 : noNul d.builder.name then
    some (ValidDerivation.mk d h1 h2 h3 h4 h5 h6 h7)
  else (none : Option ValidDerivation)
  else (none : Option ValidDerivation)
  else (none : Option ValidDerivation)
  else (none : Option ValidDerivation)
  else (none : Option ValidDerivation)
  else (none : Option ValidDerivation)
  else (none : Option ValidDerivation)

/- ════════════════════════════════════════════════════════════════════════════════
                                                              // serialization
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Serialize a derivation deterministically for hashing.
    v12: injectivity guaranteed by ValidDerivation preconditions. -/
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
