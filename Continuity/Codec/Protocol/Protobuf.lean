import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Varint

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "COUNT ZERO INTERRUPT — On receiving an interrupt,
      decrement the counter to zero. The instruction does not
      carry meaning in itself; meaning is encoded in the field
      number and the wire type that precede it. A varint slides
      off the wire, 7 bits at a time, the high bit signalling
      continuation until the stream terminates of its own accord.
      Fixed-width fields follow, then length-delimited blocks
      whose boundaries are known before their contents. Every
      field is a tagged value; every tag compresses a field
      number and a wire shape into a single varint. When the
      counter reaches zero, the message is done."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Protobuf

/-
  `Protocol Buffers` wire format encoding (`proto3`).

  Varint-based field encoding: each field is a `Tag` (field number
  + wire type) followed by a `Value` in the declared wire format.
  `zigzag` encoding maps signed integers into unsigned varints for
  efficient representation. the `Field` codec handles all four
  `WireType` variants: `varint`, `fixed64`, `lengthDelim`, `fixed32`.
-/

open Continuity.Codec.Core.Box Continuity.Codec.Core.Varint

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // wire // type
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive WireType where
  | varint | fixed64 | lengthDelim | fixed32
  deriving Repr, DecidableEq

def WireType.toNat : WireType → Nat
  | .varint => 0 | .fixed64 => 1 | .lengthDelim => 2 | .fixed32 => 5

def WireType.fromNat : Nat → Option WireType
  | 0 => some .varint | 1 => some .fixed64 | 2 => some .lengthDelim
  | 5 => some .fixed32 | _ => none

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // tag // codec
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure Tag where
  fieldNumber : Nat
  wireType : WireType

def encodeTag (t : Tag) : UInt64 :=
  (t.fieldNumber * 8 + t.wireType.toNat).toUInt64

def decodeTag (v : UInt64) : Option Tag :=
  match WireType.fromNat (v.toNat % 8) with
  | some w => some ⟨v.toNat / 8, w⟩
  | none => none

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // field // algebra
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Value where
  | varintVal  (v : UInt64)
  | fixed64Val (v : UInt64)
  | fixed32Val (v : UInt32)
  | bytesVal   (bs : Bytes)

structure Field where
  tag : Tag
  value : Value

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // field // codec
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def parseField (bs : Bytes) : ParseResult Field :=
  parseVarint bs |>.bind fun tagVal rest =>
    match decodeTag tagVal with
    | none => .fail
    | some tag =>
      match tag.wireType with
      | .varint =>
        parseVarint rest |>.bind fun v rest2 => .ok ⟨tag, .varintVal v⟩ rest2
      | .fixed64 =>
        u64le.parse rest |>.bind fun v rest2 => .ok ⟨tag, .fixed64Val v⟩ rest2
      | .fixed32 =>
        u32le.parse rest |>.bind fun v rest2 => .ok ⟨tag, .fixed32Val v⟩ rest2
      | .lengthDelim =>
        parseVarint rest |>.bind fun len rest2 =>
          let n := len.toNat
          if rest2.size ≥ n then
            .ok ⟨tag, .bytesVal (rest2.extract 0 n)⟩ (rest2.extract n rest2.size)
          else .fail

def serializeField (f : Field) : Bytes :=
  let tagBytes := serializeVarint (encodeTag f.tag)
  match f.value with
  | .varintVal v  => tagBytes ++ serializeVarint v
  | .fixed64Val v => tagBytes ++ u64le.serialize v
  | .fixed32Val v => tagBytes ++ u32le.serialize v
  | .bytesVal bs  => tagBytes ++ serializeVarint bs.size.toUInt64 ++ bs

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // varint // zigzag
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def zigzagEncode (n : Int) : Nat :=
  if n >= 0 then n.toNat * 2 else ((-n).toNat * 2 - 1)

def zigzagDecode (n : Nat) : Int :=
  if n % 2 == 0 then (n / 2 : Int) else -((n / 2 + 1 : Nat) : Int)

theorem zigzag_roundtrip (n : Int) : zigzagDecode (zigzagEncode n) = n := by
  simp [zigzagEncode, zigzagDecode]; split <;> omega

end Continuity.Codec.Protocol.Protobuf
