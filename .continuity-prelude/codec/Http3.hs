module Continuity.Codec.Http3 where

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
  | CancelPush
  | Settings
  | PushPromise
  | Goaway
  | MaxPushId
  deriving (Show, Eq, Ord, Bounded)

frametypeToCode Data = 0
frametypeToCode Headers = 1
frametypeToCode CancelPush = 3
frametypeToCode Settings = 4
frametypeToCode PushPromise = 5
frametypeToCode Goaway = 7
frametypeToCode MaxPushId = 13
frametypeFromCode 0 = Just Data
frametypeFromCode 1 = Just Headers
frametypeFromCode 3 = Just CancelPush
frametypeFromCode 4 = Just Settings
frametypeFromCode 5 = Just PushPromise
frametypeFromCode 7 = Just Goaway
frametypeFromCode 13 = Just MaxPushId
frametypeFromCode _ = Nothing

data QUICFrame
  = QUICFrame
    { qUICFrameFrameType :: Word64
    , qUICFrameLength :: Word64
    , qUICFramePayload :: BS.ByteString
    }
  deriving (Show, Eq)

parseQUICFrame = do
    qUICFrameFrameType <- getVarint
    qUICFrameLength <- getVarint
    qUICFramePayload <- getLenPrefixed
    pure (QUICFrame qUICFrameFrameType qUICFrameLength qUICFramePayload)
