module Continuity.Codec.Saml where

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

data SignedPayload
  = SignedPayload
    { signedPayloadSignedBytes :: BS.ByteString
    , signedPayloadSignatureValue :: BS.ByteString
    }
  deriving (Show, Eq)

parseSignedPayload = do
    signedPayloadSignedBytes <- getLenPrefixed
    signedPayloadSignatureValue <- getLenPrefixed
    pure (SignedPayload signedPayloadSignedBytes signedPayloadSignatureValue)
data UnverifiedAssertion
  = UnverifiedAssertion
    { unverifiedAssertionIssuer :: BS.ByteString
    , unverifiedAssertionNameId :: BS.ByteString
    , unverifiedAssertionConditions :: BS.ByteString
    , unverifiedAssertionSignedPayload :: BS.ByteString
    }
  deriving (Show, Eq)

parseUnverifiedAssertion = do
    unverifiedAssertionIssuer <- getLenPrefixed
    unverifiedAssertionNameId <- getLenPrefixed
    unverifiedAssertionConditions <- getLenPrefixed
    unverifiedAssertionSignedPayload <- getLenPrefixed
    pure (UnverifiedAssertion unverifiedAssertionIssuer unverifiedAssertionNameId unverifiedAssertionConditions unverifiedAssertionSignedPayload)
data VerifiedAssertion
  = VerifiedAssertion
    { verifiedAssertionIssuer :: BS.ByteString
    , verifiedAssertionNameId :: BS.ByteString
    , verifiedAssertionConditions :: BS.ByteString
    }
  deriving (Show, Eq)

parseVerifiedAssertion = do
    verifiedAssertionIssuer <- getLenPrefixed
    verifiedAssertionNameId <- getLenPrefixed
    verifiedAssertionConditions <- getLenPrefixed
    pure (VerifiedAssertion verifiedAssertionIssuer verifiedAssertionNameId verifiedAssertionConditions)
