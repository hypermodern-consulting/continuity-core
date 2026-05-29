module Continuity.Codec.Zmtp where

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

data Greeting
  = Greeting
    { greetingVMajor :: Word8
    , greetingVMinor :: Word8
    , greetingMechanism :: BS.ByteString
    , greetingAsServer :: Word8
    , greetingFiller :: BS.ByteString
    }
  deriving (Show, Eq)

parseGreeting = do
    greetingVMajor <- getWord8
    greetingVMinor <- getWord8
    greetingMechanism <- getByteString 20
    greetingAsServer <- getWord8
    greetingFiller <- getByteString 31
    pure (Greeting greetingVMajor greetingVMinor greetingMechanism greetingAsServer greetingFiller)
data FrameFlags
  = FrameFlags
    { frameFlagsMore :: Word8
    , frameFlagsLong_ :: Word8
    , frameFlagsCommand :: Word8
    }
  deriving (Show, Eq)

parseFrameFlags = do
    frameFlagsMore <- getWord8
    frameFlagsLong_ <- getWord8
    frameFlagsCommand <- getWord8
    pure (FrameFlags frameFlagsMore frameFlagsLong_ frameFlagsCommand)
