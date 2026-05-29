module Continuity.Codec.Json where

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

data ValueType
  = Null
  | Bool
  | Number
  | String
  | Array
  | Object
  deriving (Show, Eq, Ord, Bounded)

valuetypeToCode Null = 0
valuetypeToCode Bool = 1
valuetypeToCode Number = 2
valuetypeToCode String = 3
valuetypeToCode Array = 4
valuetypeToCode Object = 5
valuetypeFromCode 0 = Just Null
valuetypeFromCode 1 = Just Bool
valuetypeFromCode 2 = Just Number
valuetypeFromCode 3 = Just String
valuetypeFromCode 4 = Just Array
valuetypeFromCode 5 = Just Object
valuetypeFromCode _ = Nothing

