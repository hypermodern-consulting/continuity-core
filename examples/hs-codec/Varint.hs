module Main where

import Data.Bits
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as B
import qualified Data.ByteString.Lazy as LBS
import Data.Word

encodeVarint :: Word64 -> BS.ByteString
encodeVarint = LBS.toStrict . B.toLazyByteString . go
  where
    go v
        | v < 128 = B.word8 (fromIntegral v)
        | otherwise = B.word8 (fromIntegral (v .&. 0x7F) .|. 0x80) <> go (v `shiftR` 7)

decodeVarint :: BS.ByteString -> Maybe (Word64, Int)
decodeVarint bs = go 0 0 0
  where
    go acc shift i
        | i >= BS.length bs = Nothing
        | otherwise =
            let b = BS.index bs i
                acc' = acc .|. (fromIntegral (b .&. 0x7F) `shiftL` shift)
             in if b .&. 0x80 == 0
                    then Just (acc', i + 1)
                    else
                        if shift >= 63
                            then Nothing
                            else go acc' (shift + 7) (i + 1)

main :: IO ()
main = do
    putStrLn "Haskell varint roundtrip tests:"

    let values = [0, 1, 127, 128, 16383, 300, 0xFFFFFFFF, maxBound :: Word64]
    let results = map test values
    let passed = length (filter id results)

    putStrLn $ "  " ++ show passed ++ "/" ++ show (length values) ++ " passed"
  where
    test v = case decodeVarint (encodeVarint v) of
        Just (v', _) -> v == v'
        Nothing -> False
