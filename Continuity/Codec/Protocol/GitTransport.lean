import Continuity.Codec.Core.Box
import Continuity.Codec.Protocol.Protocol

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He flew on. His credit chip was a rectangle of black mirror,
      edged with gold, and the data moved beneath its surface like
      something alive in dark water. Packets broke apart and reformed,
      each one carrying its own small negotiation — an ACK, a NAK,
      a sideband of meaning threading through the static. In the
      thin space between sender and receiver, everything was
      capability, everything was a request to speak or to listen,
      to push or to pull, a conversation compressed into lines
      of hexadecimal intent."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/
namespace Continuity.Codec.Protocol.GitTransport
/-
  The Git Transport Protocol.

  Negotiation layer for reference advertisement and pack
  transfer over a streaming channel. Uses `PktLine` framing
  with special flush, delim, and response-end markers to
  delineate messages. Multiplexes pack data, progress,
  and error output via `SideBand`.

  Capability declarations in the first pkt-line of a
  `Ref` advertisement negotiate optional features:
  multi-ack, thin packs, shallow clones, and more.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // parse // pkt-line
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

open Continuity.Codec.Core.Box
open Continuity.Codec.Protocol.Protocol

def PKT_LINE_MAX_DATA : Nat := 65516

inductive PktLine where
  | flush | delim | responseEnd | data (payload : Bytes)
  deriving Repr

def parsePktLine (bs : Bytes) : ParseResult PktLine :=
  if _ : bs.size >= 4 then
    let hex := bs.extract 0 4

    if hex.data == #[0x30, 0x30, 0x30, 0x30] then
      .ok .flush (bs.extract 4 bs.size)
    else if hex.data == #[0x30, 0x30, 0x30, 0x31] then
      .ok .delim (bs.extract 4 bs.size)
    else if hex.data == #[0x30, 0x30, 0x30, 0x32] then
      .ok .responseEnd (bs.extract 4 bs.size)
    else
      match gitDecodeLength bs with
      | none => .fail
      | some (len, _) =>
        if 4 + len ≤ bs.size then
          .ok (.data (bs.extract 4 (4 + len))) (bs.extract (4 + len) bs.size)
        else .fail

  else .fail

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // core // capability
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Capability where
  | multiAck | multiAckDetailed | noDone | thinPack
  | sideBand | sideBand64k | ofsDelta | shallow
  | deepenSince | deepenNot | deepenRelative | noProgress
  | includeTag | reportStatus | reportStatusV2 | deleteRefs
  | quiet | pushOptions | filter | agent (name : String)
  | symref (from_ : String) (to_ : String)
  | objectFormat (fmt : String)
  deriving Repr

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // parse // sideband
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive SideBandChannel where
  | packData | progress | error
  deriving Repr, DecidableEq

def parseSideBand (bs : Bytes) : ParseResult (SideBandChannel × Bytes) :=
  if _ : bs.size > 0 then
    let rest := bs.extract 1 bs.size

    match bs.data[0]! with
    | 1 => .ok (.packData, rest) ByteArray.empty
    | 2 => .ok (.progress, rest) ByteArray.empty
    | 3 => .ok (.error, rest) ByteArray.empty
    | _ => .fail

  else .fail

end Continuity.Codec.Protocol.GitTransport
