import Continuity.Codec.Box
import Continuity.Codec.Protocol

set_option autoImplicit false

namespace Continuity.Codec.GitTransport

open Continuity.Codec
open Continuity.Codec.Protocol

def PKT_LINE_MAX_DATA : Nat := 65516

inductive PktLine where
  | flush | delim | responseEnd | data (payload : Bytes)
  deriving Repr

def parsePktLine (bs : Bytes) : ParseResult PktLine :=
  if h : bs.size >= 4 then
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

inductive Capability where
  | multiAck | multiAckDetailed | noDone | thinPack
  | sideBand | sideBand64k | ofsDelta | shallow
  | deepenSince | deepenNot | deepenRelative | noProgress
  | includeTag | reportStatus | reportStatusV2 | deleteRefs
  | quiet | pushOptions | filter | agent (name : String)
  | symref (from_ : String) (to_ : String)
  | objectFormat (fmt : String)
  deriving Repr

inductive SideBandChannel where
  | packData | progress | error
  deriving Repr, DecidableEq

def parseSideBand (bs : Bytes) : ParseResult (SideBandChannel × Bytes) :=
  if h : bs.size > 0 then
    let rest := bs.extract 1 bs.size
    match bs.data[0]! with
    | 1 => .ok (.packData, rest) ByteArray.empty
    | 2 => .ok (.progress, rest) ByteArray.empty
    | 3 => .ok (.error, rest) ByteArray.empty
    | _ => .fail
  else .fail

end Continuity.Codec.GitTransport
