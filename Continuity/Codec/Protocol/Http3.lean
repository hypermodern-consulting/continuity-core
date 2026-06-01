import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Varint

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "A frigate bird hung overhead, tacking against the breeze,
      slid sideways, wheeled, and was gone. No single point of
      attachment to the sea below, no state retained across gusts.
      The bird reads pressure gradients and responds in real time,
      multiplexing its own weight across every shifting column of
      air. It does not land — it migrates without ever touching
      ground, each wingbeat a discrete packet of intent. The stream
      is unreliable, the bird compensates not by checking but by
      flowing, each correction a new frame on an old connection."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Http3

/-
  `HTTP/3` framing over `QUIC` transport (`rfc 9114`).

  `QUIC` variable-length integer encoding per `rfc 9000` §16
  and `QPACK` header compression per `rfc 9204`. frames carry
  `HTTP` semantics across `QUIC` streams with stream-level
  multiplexing and connection migration built into the transport.
-/

open Continuity.Codec.Core.Box Continuity.Codec.Core.Varint

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // transport // quic
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `QUIC` variable-length integer (`rfc 9000` §16)
-- 2-bit length prefix: 00=1byte, 01=2bytes, 10=4bytes, 11=8bytes
def parseQuicVarint (bs : Bytes) : ParseResult UInt64 :=
  if _ : bs.size > 0 then
    let b0 := bs.data[0]!
    let pfx := b0.toNat >>> 6
    
    match pfx with
    | 0 =>
      .ok (b0.toNat &&& 0x3F).toUInt64 (bs.extract 1 bs.size)
    | 1 =>
      if bs.size >= 2 then
        let v := ((b0.toNat &&& 0x3F) * 256 + bs.data[1]!.toNat).toUInt64
        .ok v (bs.extract 2 bs.size)
      else .fail
    | 2 =>
      if bs.size >= 4 then
        let v := ((b0.toNat &&& 0x3F) * 16777216 + bs.data[1]!.toNat * 65536 +
                  bs.data[2]!.toNat * 256 + bs.data[3]!.toNat).toUInt64
        .ok v (bs.extract 4 bs.size)
      else .fail
    | _ =>
      if bs.size >= 8 then
        u64le.parse bs |>.bind fun v rest =>
          .ok (v &&& 0x3FFFFFFFFFFFFFFF) rest
      else .fail
      
  else .fail

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // framing // http3
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive FrameType where
  | data | headers | cancelPush | settings
  | pushPromise | goaway | maxPushId
  deriving Repr, DecidableEq

def FrameType.toCode : FrameType → UInt64
  | .data => 0x00 | .headers => 0x01 | .cancelPush => 0x03
  | .settings => 0x04 | .pushPromise => 0x05 | .goaway => 0x07
  | .maxPushId => 0x0D

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // compression // qpack
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `QPACK` static table (`rfc 9204` appendix A, first entries)
def qpackStaticTable : List (String × String) :=
  [ (":authority", ""), (":path", "/"), ("age", "0")
  , ("content-disposition", ""), ("content-length", "0")
  , ("cookie", ""), ("date", ""), ("etag", "")
  , ("if-modified-since", ""), ("if-none-match", "")
  , ("last-modified", ""), ("link", ""), ("location", "")
  , ("referer", ""), ("set-cookie", "")
  , (":method", "CONNECT"), (":method", "DELETE"), (":method", "GET")
  , (":method", "HEAD"), (":method", "OPTIONS"), (":method", "POST")
  , (":method", "PUT"), (":scheme", "http"), (":scheme", "https")
  ]

end Continuity.Codec.Protocol.Http3
