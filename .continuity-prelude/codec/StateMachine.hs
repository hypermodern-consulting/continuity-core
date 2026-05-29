module Continuity.Codec.StateMachine where

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

data ServerState
  = Init
  | Versioned
  | Features
  | Upgrading
  | NixReady
  | ReapiReady
  | Failed
  deriving (Show, Eq, Ord, Bounded)

serverstateToCode Init = 0
serverstateToCode Versioned = 1
serverstateToCode Features = 2
serverstateToCode Upgrading = 3
serverstateToCode NixReady = 4
serverstateToCode ReapiReady = 5
serverstateToCode Failed = 6
serverstateFromCode 0 = Just Init
serverstateFromCode 1 = Just Versioned
serverstateFromCode 2 = Just Features
serverstateFromCode 3 = Just Upgrading
serverstateFromCode 4 = Just NixReady
serverstateFromCode 5 = Just ReapiReady
serverstateFromCode 6 = Just Failed
serverstateFromCode _ = Nothing
data ServerAction
  = SendServerHello
  | SendDaemonVersion
  | SendTrustLevel
  | SendFeatures
  | SendUpgradeOffer
  | SendReapiConfig
  | Ready
  | Fail
  deriving (Show, Eq, Ord, Bounded)

serveractionToCode SendServerHello = 0
serveractionToCode SendDaemonVersion = 1
serveractionToCode SendTrustLevel = 2
serveractionToCode SendFeatures = 3
serveractionToCode SendUpgradeOffer = 4
serveractionToCode SendReapiConfig = 5
serveractionToCode Ready = 6
serveractionToCode Fail = 7
serveractionFromCode 0 = Just SendServerHello
serveractionFromCode 1 = Just SendDaemonVersion
serveractionFromCode 2 = Just SendTrustLevel
serveractionFromCode 3 = Just SendFeatures
serveractionFromCode 4 = Just SendUpgradeOffer
serveractionFromCode 5 = Just SendReapiConfig
serveractionFromCode 6 = Just Ready
serveractionFromCode 7 = Just Fail
serveractionFromCode _ = Nothing
data DaemonOpState
  = AwaitingOp
  | Processing
  | SendingStderr
  | SendingResult
  | OpComplete
  | OpFailed
  deriving (Show, Eq, Ord, Bounded)

daemonopstateToCode AwaitingOp = 0
daemonopstateToCode Processing = 1
daemonopstateToCode SendingStderr = 2
daemonopstateToCode SendingResult = 3
daemonopstateToCode OpComplete = 4
daemonopstateToCode OpFailed = 5
daemonopstateFromCode 0 = Just AwaitingOp
daemonopstateFromCode 1 = Just Processing
daemonopstateFromCode 2 = Just SendingStderr
daemonopstateFromCode 3 = Just SendingResult
daemonopstateFromCode 4 = Just OpComplete
daemonopstateFromCode 5 = Just OpFailed
daemonopstateFromCode _ = Nothing
data Feature
  = ReapiV2
  | CasSha256
  | StreamingNar
  | SignedNarinfo
  deriving (Show, Eq, Ord, Bounded)

featureToCode ReapiV2 = 0
featureToCode CasSha256 = 1
featureToCode StreamingNar = 2
featureToCode SignedNarinfo = 3
featureFromCode 0 = Just ReapiV2
featureFromCode 1 = Just CasSha256
featureFromCode 2 = Just StreamingNar
featureFromCode 3 = Just SignedNarinfo
featureFromCode _ = Nothing
data TrustLevel
  = Unknown
  | Trusted
  | Untrusted
  deriving (Show, Eq, Ord, Bounded)

trustlevelToCode Unknown = 0
trustlevelToCode Trusted = 1
trustlevelToCode Untrusted = 2
trustlevelFromCode 0 = Just Unknown
trustlevelFromCode 1 = Just Trusted
trustlevelFromCode 2 = Just Untrusted
trustlevelFromCode _ = Nothing

data ProtocolVersion
  = ProtocolVersion
    { protocolVersionValue :: Word64
    }
  deriving (Show, Eq)

parseProtocolVersion = do
    protocolVersionValue <- getWord64le
    pure (ProtocolVersion protocolVersionValue)
data ReapiConfig
  = ReapiConfig
    { reapiConfigInstanceName :: BS.ByteString
    , reapiConfigDigestFunction :: Word32
    }
  deriving (Show, Eq)

parseReapiConfig = do
    reapiConfigInstanceName <- getLenPrefixed
    reapiConfigDigestFunction <- getWord32le
    pure (ReapiConfig reapiConfigInstanceName reapiConfigDigestFunction)
