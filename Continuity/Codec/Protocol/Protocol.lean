import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

namespace Continuity.Codec.Protocol.Protocol

open Continuity.Codec.Core.Box Continuity.Codec.Core.Bytes

@[ext] structure Frame where
  payload : Bytes
  deriving Repr, DecidableEq

def Frame.flush : Frame := ⟨ByteArray.empty⟩
def Frame.isFlush (f : Frame) : Bool := f.payload.size == 0

structure LengthCodec where
  fixedSize : Nat
  maxPayload : Nat
  encode : Nat → Bytes
  decode : Bytes → Option (Nat × Nat)
  roundtrip : ∀ n, n ≤ maxPayload → decode (encode n) = some (n, fixedSize)
  encode_size : ∀ n, (encode n).size = fixedSize
  decode_append : ∀ n extra, n ≤ maxPayload →
    decode (encode n ++ extra) = some (n, fixedSize)

structure BoundedFrame (codec : LengthCodec) where
  frame : Frame
  bound : frame.payload.size ≤ codec.maxPayload

-- Hex encoding for Git pkt-line
def toHexChar (n : Nat) : UInt8 :=
  if n < 10 then (48 + n).toUInt8 else (87 + n).toUInt8

def fromHexChar (c : UInt8) : Option Nat :=
  if c >= 48 && c <= 57 then some (c.toNat - 48)
  else if c >= 97 && c <= 102 then some (c.toNat - 87)
  else if c >= 65 && c <= 70 then some (c.toNat - 55)
  else none

theorem fromHexChar_toHexChar (n : Nat) (h : n < 16) :
    fromHexChar (toHexChar n) = some n := by
  match n, h with
  | 0, _ => rfl | 1, _ => rfl | 2, _ => rfl | 3, _ => rfl
  | 4, _ => rfl | 5, _ => rfl | 6, _ => rfl | 7, _ => rfl
  | 8, _ => rfl | 9, _ => rfl | 10, _ => rfl | 11, _ => rfl
  | 12, _ => rfl | 13, _ => rfl | 14, _ => rfl | 15, _ => rfl
  | n + 16, h => nomatch (Nat.not_lt.mpr (Nat.le_add_left 16 n) h)

def gitEncodeLength (payloadLen : Nat) : Bytes :=
  let totalLen := payloadLen + 4
  [toHexChar ((totalLen / 4096) % 16), toHexChar ((totalLen / 256) % 16),
   toHexChar ((totalLen / 16) % 16), toHexChar (totalLen % 16)].toByteArray

def nixEncodeLength (n : Nat) : Bytes := u64le.serialize n.toUInt64

def nixDecodeLength (bs : Bytes) : Option (Nat × Nat) :=
  match u64le.parse bs with
  | .ok len _ => some (len.toNat, 8)
  | .fail => none

def zmtpEncodeLength (n : Nat) : Bytes :=
  if n < 255 then ⟨#[n.toUInt8]⟩
  else ⟨#[0xFF]⟩ ++ u64le.serialize n.toUInt64

def gitDecodeLength (bs : Bytes) : Option (Nat × Nat) :=
  if bs.size >= 4 then
    match fromHexChar bs.data[0]!, fromHexChar bs.data[1]!,
          fromHexChar bs.data[2]!, fromHexChar bs.data[3]! with
    | some d0, some d1, some d2, some d3 =>
      let totalLen := d0 * 4096 + d1 * 256 + d2 * 16 + d3
      if totalLen >= 4 then some (totalLen - 4, 4)
      else if totalLen == 0 then some (0, 4)
      else none
    | _, _, _, _ => none
  else none

end Continuity.Codec.Protocol.Protocol
