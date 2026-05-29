module Continuity.Codec.GitTransport where

import Data.Word
import qualified Data.ByteString as BS (ByteString)
import Data.Binary.Get (Get, getWord8, getWord16le, getWord32le, getWord64le, getWord16be, getWord32be, getWord64be, getByteString, getRemainingLazyByteString)
import Data.Binary.Put (Put, putWord8, putWord64le, putByteString)
import Data.Bits ((.&.), (.|.), shiftL, shiftR, testBit)



-- Wire format helpers
getVarint = getWord64le
getLenPrefixed = do
    len <- getWord64le
    getByteString (fromIntegral len)
getBool64 = do
    v <- getWord64le
    pure (v /= 0)

pKT_LINE_MAX_DATA = 65516

data PktLineType
  = Flush
  | Delim
  | ResponseEnd
  | Data
  deriving (Show, Eq, Ord, Bounded)

pktlinetypeToCode Flush = 0
pktlinetypeToCode Delim = 1
pktlinetypeToCode ResponseEnd = 2
pktlinetypeToCode Data = 3
pktlinetypeFromCode 0 = Just Flush
pktlinetypeFromCode 1 = Just Delim
pktlinetypeFromCode 2 = Just ResponseEnd
pktlinetypeFromCode 3 = Just Data
pktlinetypeFromCode _ = Nothing
data SideBandChannel
  = PackData
  | Progress
  | Error
  deriving (Show, Eq, Ord, Bounded)

sidebandchannelToCode PackData = 1
sidebandchannelToCode Progress = 2
sidebandchannelToCode Error = 3
sidebandchannelFromCode 1 = Just PackData
sidebandchannelFromCode 2 = Just Progress
sidebandchannelFromCode 3 = Just Error
sidebandchannelFromCode _ = Nothing
data Capability
  = MultiAck
  | MultiAckDetailed
  | NoDone
  | ThinPack
  | SideBand
  | SideBand64k
  | OfsDelta
  | Shallow
  | DeepenSince
  | DeepenNot
  | NoProgress
  | IncludeTag
  | ReportStatus
  | DeleteRefs
  | Quiet
  | Filter
  deriving (Show, Eq, Ord, Bounded)

capabilityToCode MultiAck = 0
capabilityToCode MultiAckDetailed = 1
capabilityToCode NoDone = 2
capabilityToCode ThinPack = 3
capabilityToCode SideBand = 4
capabilityToCode SideBand64k = 5
capabilityToCode OfsDelta = 6
capabilityToCode Shallow = 7
capabilityToCode DeepenSince = 8
capabilityToCode DeepenNot = 9
capabilityToCode NoProgress = 10
capabilityToCode IncludeTag = 11
capabilityToCode ReportStatus = 12
capabilityToCode DeleteRefs = 13
capabilityToCode Quiet = 14
capabilityToCode Filter = 15
capabilityFromCode 0 = Just MultiAck
capabilityFromCode 1 = Just MultiAckDetailed
capabilityFromCode 2 = Just NoDone
capabilityFromCode 3 = Just ThinPack
capabilityFromCode 4 = Just SideBand
capabilityFromCode 5 = Just SideBand64k
capabilityFromCode 6 = Just OfsDelta
capabilityFromCode 7 = Just Shallow
capabilityFromCode 8 = Just DeepenSince
capabilityFromCode 9 = Just DeepenNot
capabilityFromCode 10 = Just NoProgress
capabilityFromCode 11 = Just IncludeTag
capabilityFromCode 12 = Just ReportStatus
capabilityFromCode 13 = Just DeleteRefs
capabilityFromCode 14 = Just Quiet
capabilityFromCode 15 = Just Filter
capabilityFromCode _ = Nothing

