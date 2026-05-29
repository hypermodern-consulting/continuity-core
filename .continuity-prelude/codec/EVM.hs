module Continuity.Codec.EVM where

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

data AttestCalldata
  = AttestCalldata
    { attestCalldataSelector :: BS.ByteString
    , attestCalldataContentHash :: BS.ByteString
    , attestCalldataSignerIdentity :: BS.ByteString
    , attestCalldataIssuedAt :: BS.ByteString
    , attestCalldataExpiresAt :: BS.ByteString
    , attestCalldataVouchChainRoot :: BS.ByteString
    }
  deriving (Show, Eq)

parseAttestCalldata = do
    attestCalldataSelector <- getByteString 4
    attestCalldataContentHash <- getByteString 32
    attestCalldataSignerIdentity <- getByteString 32
    attestCalldataIssuedAt <- getByteString 32
    attestCalldataExpiresAt <- getByteString 32
    attestCalldataVouchChainRoot <- getByteString 32
    pure (AttestCalldata attestCalldataSelector attestCalldataContentHash attestCalldataSignerIdentity attestCalldataIssuedAt attestCalldataExpiresAt attestCalldataVouchChainRoot)
