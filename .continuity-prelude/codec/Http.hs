module Continuity.Codec.Http where

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

data Method
  = Get
  | Head
  | Post
  | Put
  | Delete
  | Connect
  | Options
  | Trace
  | Patch
  deriving (Show, Eq, Ord, Bounded)

methodToCode Get = 0
methodToCode Head = 1
methodToCode Post = 2
methodToCode Put = 3
methodToCode Delete = 4
methodToCode Connect = 5
methodToCode Options = 6
methodToCode Trace = 7
methodToCode Patch = 8
methodFromCode 0 = Just Get
methodFromCode 1 = Just Head
methodFromCode 2 = Just Post
methodFromCode 3 = Just Put
methodFromCode 4 = Just Delete
methodFromCode 5 = Just Connect
methodFromCode 6 = Just Options
methodFromCode 7 = Just Trace
methodFromCode 8 = Just Patch
methodFromCode _ = Nothing
data TransferEncoding
  = Identity
  | Chunked
  | Gzip
  | Deflate
  | Compress
  deriving (Show, Eq, Ord, Bounded)

transferencodingToCode Identity = 0
transferencodingToCode Chunked = 1
transferencodingToCode Gzip = 2
transferencodingToCode Deflate = 3
transferencodingToCode Compress = 4
transferencodingFromCode 0 = Just Identity
transferencodingFromCode 1 = Just Chunked
transferencodingFromCode 2 = Just Gzip
transferencodingFromCode 3 = Just Deflate
transferencodingFromCode 4 = Just Compress
transferencodingFromCode _ = Nothing

data Header
  = Header
    { headerName :: BS.ByteString
    , headerValue :: BS.ByteString
    }
  deriving (Show, Eq)

parseHeader = do
    headerName <- getLenPrefixed
    headerValue <- getLenPrefixed
    pure (Header headerName headerValue)
data RequestLine
  = RequestLine
    { requestLineMethod :: Word8
    , requestLineTarget :: BS.ByteString
    , requestLineVersion :: BS.ByteString
    }
  deriving (Show, Eq)

parseRequestLine = do
    requestLineMethod <- getWord8
    requestLineTarget <- getLenPrefixed
    requestLineVersion <- getLenPrefixed
    pure (RequestLine requestLineMethod requestLineTarget requestLineVersion)
data StatusLine
  = StatusLine
    { statusLineVersion :: BS.ByteString
    , statusLineStatusCode :: Word16
    , statusLineReasonPhrase :: BS.ByteString
    }
  deriving (Show, Eq)

parseStatusLine = do
    statusLineVersion <- getLenPrefixed
    statusLineStatusCode <- getWord16le
    statusLineReasonPhrase <- getLenPrefixed
    pure (StatusLine statusLineVersion statusLineStatusCode statusLineReasonPhrase)
