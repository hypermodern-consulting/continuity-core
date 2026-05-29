module Continuity.Codec.Git where

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

pACK_SIGNATURE = 1346454347

data ObjectType
  = Commit
  | Tree
  | Blob
  | Tag
  | OfsDelta
  | RefDelta
  deriving (Show, Eq, Ord, Bounded)

objecttypeToCode Commit = 1
objecttypeToCode Tree = 2
objecttypeToCode Blob = 3
objecttypeToCode Tag = 4
objecttypeToCode OfsDelta = 6
objecttypeToCode RefDelta = 7
objecttypeFromCode 1 = Just Commit
objecttypeFromCode 2 = Just Tree
objecttypeFromCode 3 = Just Blob
objecttypeFromCode 4 = Just Tag
objecttypeFromCode 6 = Just OfsDelta
objecttypeFromCode 7 = Just RefDelta
objecttypeFromCode _ = Nothing

data PackHeader
  = PackHeader
    { packHeaderVersion :: Word32
    , packHeaderObjectCount :: Word32
    }
  deriving (Show, Eq)

parsePackHeader = do
    packHeaderVersion <- getWord32be
    packHeaderObjectCount <- getWord32be
    pure (PackHeader packHeaderVersion packHeaderObjectCount)
data ObjectId
  = ObjectId
    { objectIdBytes :: BS.ByteString
    }
  deriving (Show, Eq)

parseObjectId = do
    objectIdBytes <- getByteString 20
    pure (ObjectId objectIdBytes)
