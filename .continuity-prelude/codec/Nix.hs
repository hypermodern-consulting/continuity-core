module Continuity.Codec.Nix where

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

wORKER_MAGIC_1 = 1852405859
wORKER_MAGIC_2 = 1685612911
sTDERR_NEXT = 1869376871
sTDERR_READ = 1684108385
sTDERR_WRITE = 1684108310
sTDERR_LAST = 1634497651
sTDERR_ERROR = 1668838512

data WorkerOp
  = IsValidPath
  | HasSubstitutes
  | QueryPathHash
  | QueryReferences
  | QueryReferrers
  | AddToStore
  | BuildPaths
  | EnsurePath
  | AddTempRoot
  | SetOptions
  | CollectGarbage
  | QueryPathInfo
  | NarFromPath
  | AddToStoreNar
  | QueryMissing
  | BuildPathsWithResults
  deriving (Show, Eq, Ord, Bounded)

workeropToCode IsValidPath = 1
workeropToCode HasSubstitutes = 3
workeropToCode QueryPathHash = 4
workeropToCode QueryReferences = 5
workeropToCode QueryReferrers = 6
workeropToCode AddToStore = 7
workeropToCode BuildPaths = 9
workeropToCode EnsurePath = 10
workeropToCode AddTempRoot = 11
workeropToCode SetOptions = 19
workeropToCode CollectGarbage = 20
workeropToCode QueryPathInfo = 26
workeropToCode NarFromPath = 38
workeropToCode AddToStoreNar = 39
workeropToCode QueryMissing = 40
workeropToCode BuildPathsWithResults = 46
workeropFromCode 1 = Just IsValidPath
workeropFromCode 3 = Just HasSubstitutes
workeropFromCode 4 = Just QueryPathHash
workeropFromCode 5 = Just QueryReferences
workeropFromCode 6 = Just QueryReferrers
workeropFromCode 7 = Just AddToStore
workeropFromCode 9 = Just BuildPaths
workeropFromCode 10 = Just EnsurePath
workeropFromCode 11 = Just AddTempRoot
workeropFromCode 19 = Just SetOptions
workeropFromCode 20 = Just CollectGarbage
workeropFromCode 26 = Just QueryPathInfo
workeropFromCode 38 = Just NarFromPath
workeropFromCode 39 = Just AddToStoreNar
workeropFromCode 40 = Just QueryMissing
workeropFromCode 46 = Just BuildPathsWithResults
workeropFromCode _ = Nothing

data NixString
  = NixString
    { nixStringData_ :: BS.ByteString
    }
  deriving (Show, Eq)

parseNixString = do
    nixStringData_ <- getLenPrefixed
    pure (NixString nixStringData_)
data StorePath
  = StorePath
    { storePathPath :: BS.ByteString
    }
  deriving (Show, Eq)

parseStorePath = do
    storePathPath <- getLenPrefixed
    pure (StorePath storePathPath)
data ClientHello
  = ClientHello
    { clientHelloMagic :: Word64
    }
  deriving (Show, Eq)

parseClientHello = do
    clientHelloMagic <- getWord64le
    pure (ClientHello clientHelloMagic)
data ServerHello
  = ServerHello
    { serverHelloMagic :: Word64
    , serverHelloProtocolVersion :: Word64
    }
  deriving (Show, Eq)

parseServerHello = do
    serverHelloMagic <- getWord64le
    serverHelloProtocolVersion <- getWord64le
    pure (ServerHello serverHelloMagic serverHelloProtocolVersion)
