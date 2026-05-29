module Continuity.Codec.Http2 where

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

data FrameType
  = Data
  | Headers
  | Priority
  | RstStream
  | Settings
  | PushPromise
  | Ping
  | Goaway
  | WindowUpdate
  | Continuation
  deriving (Show, Eq, Ord, Bounded)

frametypeToCode Data = 0
frametypeToCode Headers = 1
frametypeToCode Priority = 2
frametypeToCode RstStream = 3
frametypeToCode Settings = 4
frametypeToCode PushPromise = 5
frametypeToCode Ping = 6
frametypeToCode Goaway = 7
frametypeToCode WindowUpdate = 8
frametypeToCode Continuation = 9
frametypeFromCode 0 = Just Data
frametypeFromCode 1 = Just Headers
frametypeFromCode 2 = Just Priority
frametypeFromCode 3 = Just RstStream
frametypeFromCode 4 = Just Settings
frametypeFromCode 5 = Just PushPromise
frametypeFromCode 6 = Just Ping
frametypeFromCode 7 = Just Goaway
frametypeFromCode 8 = Just WindowUpdate
frametypeFromCode 9 = Just Continuation
frametypeFromCode _ = Nothing

data FrameHeader
  = FrameHeader
    { frameHeaderLength :: Word32
    , frameHeaderFrameType :: Word8
    , frameHeaderFlags :: Word8
    , frameHeaderStreamId :: Word32
    }
  deriving (Show, Eq)

parseFrameHeader = do
    frameHeaderLength <- getWord32be
    frameHeaderFrameType <- getWord8
    frameHeaderFlags <- getWord8
    frameHeaderStreamId <- getWord32be
    pure (FrameHeader frameHeaderLength frameHeaderFrameType frameHeaderFlags frameHeaderStreamId)
