module Continuity.Codec.Protobuf where

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

data WireType
  = Varint
  | Fixed64
  | LengthDelimited
  | Fixed32
  deriving (Show, Eq, Ord, Bounded)

wiretypeToCode Varint = 0
wiretypeToCode Fixed64 = 1
wiretypeToCode LengthDelimited = 2
wiretypeToCode Fixed32 = 5
wiretypeFromCode 0 = Just Varint
wiretypeFromCode 1 = Just Fixed64
wiretypeFromCode 2 = Just LengthDelimited
wiretypeFromCode 5 = Just Fixed32
wiretypeFromCode _ = Nothing

data Tag
  = Tag
    { tagFieldNumber :: Word64
    , tagWireType :: Word8
    }
  deriving (Show, Eq)

parseTag = do
    tagFieldNumber <- getVarint
    tagWireType <- getWord8
    pure (Tag tagFieldNumber tagWireType)
data Field
  = Field
    { fieldTag :: Word8
    , fieldValue :: BS.ByteString
    }
  deriving (Show, Eq)

parseField = do
    fieldTag <- getWord8
    fieldValue <- getLenPrefixed
    pure (Field fieldTag fieldValue)
