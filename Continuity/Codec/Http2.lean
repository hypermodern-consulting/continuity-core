import Continuity.Codec.Box

set_option autoImplicit false

namespace Continuity.Codec.Http2

open Continuity.Codec

-- RFC 7540: HTTP/2, RFC 7541: HPACK

inductive FrameType where
  | data | headers | priority | rstStream | settings
  | pushPromise | ping | goaway | windowUpdate | continuation
  deriving Repr, DecidableEq

def FrameType.toUInt8 : FrameType → UInt8
  | .data => 0x0 | .headers => 0x1 | .priority => 0x2 | .rstStream => 0x3
  | .settings => 0x4 | .pushPromise => 0x5 | .ping => 0x6 | .goaway => 0x7
  | .windowUpdate => 0x8 | .continuation => 0x9

def FrameType.fromUInt8 : UInt8 → Option FrameType
  | 0x0 => some .data | 0x1 => some .headers | 0x2 => some .priority
  | 0x3 => some .rstStream | 0x4 => some .settings | 0x5 => some .pushPromise
  | 0x6 => some .ping | 0x7 => some .goaway | 0x8 => some .windowUpdate
  | 0x9 => some .continuation | _ => none

theorem frameType_roundtrip (ft : FrameType) : FrameType.fromUInt8 ft.toUInt8 = some ft := by
  cases ft <;> rfl

structure FrameHeader where
  length : Nat
  frameType : FrameType
  flags : UInt8
  streamId : UInt32
  deriving Repr

def parseFrameHeader (bs : Bytes) : ParseResult FrameHeader :=
  if h : bs.size >= 9 then
    let len := bs.data[0]!.toNat * 65536 + bs.data[1]!.toNat * 256 + bs.data[2]!.toNat
    match FrameType.fromUInt8 bs.data[3]! with
    | none => .fail
    | some ft =>
      let flags := bs.data[4]!
      let sid := (bs.data[5]!.toNat &&& 0x7F) * 16777216 + bs.data[6]!.toNat * 65536 +
                 bs.data[7]!.toNat * 256 + bs.data[8]!.toNat
      .ok ⟨len, ft, flags, sid.toUInt32⟩ (bs.extract 9 bs.size)
  else .fail

-- HPACK static table (first 15 entries)
def hpackStaticTable : List (String × String) :=
  [ (":authority", ""), (":method", "GET"), (":method", "POST")
  , (":path", "/"), (":path", "/index.html"), (":scheme", "http")
  , (":scheme", "https"), (":status", "200"), (":status", "204")
  , (":status", "206"), (":status", "304"), (":status", "400")
  , (":status", "404"), (":status", "500"), ("accept-charset", "")
  ]

-- HPACK integer encoding (RFC 7541 §5.1)
def hpackEncodeInt (pfx : Nat) (pfxBits : Nat) (n : Nat) : Bytes :=
  let maxPfx := (1 <<< pfxBits) - 1
  if n < maxPfx then ⟨#[(pfx ||| n).toUInt8]⟩
  else
    let first := (pfx ||| maxPfx).toUInt8
    let rec go (remaining : Nat) (acc : List UInt8) : List UInt8 :=
      if remaining < 128 then acc ++ [remaining.toUInt8]
      else go (remaining / 128) (acc ++ [(remaining % 128 + 128).toUInt8])
    termination_by remaining
    ⟨(first :: go (n - maxPfx) []).toArray⟩

inductive SettingsParam where
  | headerTableSize | enablePush | maxConcurrentStreams
  | initialWindowSize | maxFrameSize | maxHeaderListSize
  deriving Repr, DecidableEq

def SettingsParam.toId : SettingsParam → UInt16
  | .headerTableSize => 1 | .enablePush => 2 | .maxConcurrentStreams => 3
  | .initialWindowSize => 4 | .maxFrameSize => 5 | .maxHeaderListSize => 6

def CONNECTION_PREFACE : Bytes := "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".toUTF8

end Continuity.Codec.Http2
