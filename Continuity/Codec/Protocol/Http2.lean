import Continuity.Codec.Core.Box

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Silicon's on the way out, Turner. What comes next
      is smaller and faster, a language of frames
      multiplexed across a single connection — no more
      text, no more waves, just binary tables and state
      machines negotiating compression in the space
      between SYN and ACK. The old protocol was a
      conversation; this one is a kind of possession. Same
      words, different bones, and the ghosts of the old
      headers live on in a static table, indexed by
      number, stripped of their names."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/
namespace Continuity.Codec.Protocol.Http2
/-
  The HTTP/2 Protocol (RFC 7540, RFC 7541).

  Multiplexed binary framing layer with header compression
  via `HPACK`. Each frame carries a type, stream identifier,
  and flags; settings are exchanged during connection preface.
  The `HPACK` static table pre-defines 61 header name/value
  pairs; integer encoding uses variable-length prefix
  representation from RFC 7541 §5.1.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // core // frame types
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

open Continuity.Codec.Core.Box

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // parse // frame header
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure FrameHeader where
  length : Nat
  frameType : FrameType
  flags : UInt8
  streamId : UInt32
  deriving Repr

def parseFrameHeader (bs : Bytes) : ParseResult FrameHeader :=
  if _ : bs.size >= 9 then
    let len := bs.data[0]!.toNat * 65536 + bs.data[1]!.toNat * 256 + bs.data[2]!.toNat
    match FrameType.fromUInt8 bs.data[3]! with
    | none => .fail
    | some ft =>
      let flags := bs.data[4]!
      let sid := (bs.data[5]!.toNat &&& 0x7F) * 16777216 + bs.data[6]!.toNat * 65536 +
                 bs.data[7]!.toNat * 256 + bs.data[8]!.toNat
      .ok ⟨len, ft, flags, sid.toUInt32⟩ (bs.extract 9 bs.size)
  else .fail

def serializeFrameHeader (h : FrameHeader) : Bytes :=
  let len0 := (h.length / 65536 % 256).toUInt8
  let len1 := (h.length / 256 % 256).toUInt8
  let len2 := (h.length % 256).toUInt8
  let typeByte := h.frameType.toUInt8
  let sid := h.streamId.toNat
  let sid0 := ((sid / 16777216) % 128).toUInt8
  let sid1 := ((sid / 65536) % 256).toUInt8
  let sid2 := ((sid / 256) % 256).toUInt8
  let sid3 := (sid % 256).toUInt8
  ⟨#[len0, len1, len2, typeByte, h.flags, sid0, sid1, sid2, sid3]⟩

theorem frameHeader_roundtrip (h : FrameHeader) :
    parseFrameHeader (serializeFrameHeader h) = ParseResult.ok h ByteArray.empty := by
  -- TODO[b7r6]: !! proof needed !!
  sorry

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // core // hpack
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `HPACK` static table (first 15 entries)
def hpackStaticTable : List (String × String) :=
  [ (":authority", ""), (":method", "GET"), (":method", "POST")
  , (":path", "/"), (":path", "/index.html"), (":scheme", "http")
  , (":scheme", "https"), (":status", "200"), (":status", "204")
  , (":status", "206"), (":status", "304"), (":status", "400")
  , (":status", "404"), (":status", "500"), ("accept-charset", "")
  ]

-- `HPACK` integer encoding (`rfc 7541` §5.1)
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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // settings
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive SettingsParam where
  | headerTableSize | enablePush | maxConcurrentStreams
  | initialWindowSize | maxFrameSize | maxHeaderListSize
  deriving Repr, DecidableEq

def SettingsParam.toId : SettingsParam → UInt16
  | .headerTableSize => 1 | .enablePush => 2 | .maxConcurrentStreams => 3
  | .initialWindowSize => 4 | .maxFrameSize => 5 | .maxHeaderListSize => 6

def CONNECTION_PREFACE : Bytes := "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".toUTF8

end Continuity.Codec.Protocol.Http2
