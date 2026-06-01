import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Machine dreams hold a special vertigo. Not the simple binary
      of awake and asleep, but something denser — a file folded
      into files, each layer a delta compressed against the last,
      until the origin is nothing more than a rumor encoded at
      the bottom of the stack. The machines do not forget; they
      merely accumulate, history pressing down like gravity, each
      object a commitment that cannot be unwound. To read them
      is to fall backward through a chain of packed intentions."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/
namespace Continuity.Codec.Protocol.Git
/-
  The Git Pack Format.

  A binary protocol for storing objects in a compressed,
  self-contained archive. Packs use deltified representation:
  objects reference prior objects via offset or hash, with
  the full graph reconstructed on inflation by `Zlib`.

  Targets `git pack-objects` and `git index-pack` wire format:
    `.pack` — compressed object data with trailing checksum
    `.idx`  — fanout table mapping object ids to pack offsets
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // core // pack
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

open Continuity.Codec.Core.Box Continuity.Codec.Core.Bytes

def PACK_SIGNATURE : UInt32 := 0x5041434B
def PACK_VERSION_2 : UInt32 := 2
def PACK_VERSION_3 : UInt32 := 3

inductive ObjectType where
  | commit | tree | blob | tag | ofsDelta | refDelta
  deriving Repr, DecidableEq

def ObjectType.toNat : ObjectType → Nat
  | .commit => 1 | .tree => 2 | .blob => 3 | .tag => 4
  | .ofsDelta => 6 | .refDelta => 7

def ObjectType.fromNat : Nat → Option ObjectType
  | 1 => some .commit | 2 => some .tree | 3 => some .blob | 4 => some .tag
  | 6 => some .ofsDelta | 7 => some .refDelta | _ => none

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // parse // type and size
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def parseTypeSize (bs : Bytes) : ParseResult (ObjectType × Nat) :=
  if _ : bs.size > 0 then
    let b0 := bs.data[0]!
    let typ := (b0.toNat >>> 4) &&& 0x7
    let size := b0.toNat &&& 0x0F
    match ObjectType.fromNat typ with
    | none => .fail
    | some objType =>
      if b0 &&& 0x80 == 0 then .ok (objType, size) (bs.extract 1 bs.size)
      else
        let rec go (i : Nat) (acc : Nat) (shift : Nat) : ParseResult Nat :=
          if h2 : i < bs.size then
            let b := bs.data[i]!
            let acc' := acc ||| ((b.toNat &&& 0x7F) <<< shift)
            if b &&& 0x80 == 0 then .ok acc' (bs.extract (i + 1) bs.size)
            else if shift > 56 then .fail
            else go (i + 1) acc' (shift + 7)
          else .fail
        termination_by bs.size - i
        match go 1 size 4 with
        | .ok finalSize rest => .ok (objType, finalSize) rest
        | .fail => .fail
  else .fail

def parseOfsOffset (bs : Bytes) : ParseResult Nat :=
  if _ : bs.size > 0 then
    let b0 := bs.data[0]!
    let acc0 := b0.toNat &&& 0x7F

    if b0 &&& 0x80 == 0 then .ok acc0 (bs.extract 1 bs.size)
    else
      let rec go (i : Nat) (acc : Nat) : ParseResult Nat :=
        if h2 : i < bs.size then
          let b := bs.data[i]!
          let acc' := ((acc + 1) <<< 7) ||| (b.toNat &&& 0x7F)
          if b &&& 0x80 == 0 then .ok acc' (bs.extract (i + 1) bs.size)
          else if i > 8 then .fail
          else go (i + 1) acc'
        else .fail
      termination_by bs.size - i
      go 1 acc0

  else .fail

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // core // object identity
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure ObjectId where
  bytes : Bytes
  valid : bytes.size = 20 ∨ bytes.size = 32
  deriving Repr

def parseObjectId20 (bs : Bytes) : ParseResult ObjectId :=
  if h : bs.size >= 20 then
    .ok ⟨bs.extract 0 20, Or.inl (by rw [ByteArray.size_extract]; omega)⟩
        (bs.extract 20 bs.size)
  else .fail

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                      // structures // metadata
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure ZlibDecompressor where
  inflate : Bytes → Option (Bytes × Nat)
  consumption_bound : ∀ bs data consumed,
    inflate bs = some (data, consumed) → consumed ≤ bs.size

theorem zlib_option_some_inj (z : ZlibDecompressor) (bs : Bytes) :
    ∀ r1 r2, z.inflate bs = some r1 → z.inflate bs = some r2 → r1 = r2 := by
  intro r1 r2 h1 h2; rw [h1] at h2; exact Option.some.inj h2

structure PackHeader where
  version : UInt32
  objectCount : UInt32
  deriving Repr

structure PackEntry where
  objType : ObjectType
  uncompressedSize : Nat
  deriving Repr

end Continuity.Codec.Protocol.Git
