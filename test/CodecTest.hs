-- CodecTest.hs — roundtrip property tests for wire format primitives
-- Compile: ghc -O -o test/hs_test test/CodecTest.hs
module Main where

import Data.Word
import Data.Bits
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Binary.Get
import Data.Binary.Put

-- ═══════ wire primitives ═══════

putVarint :: Word64 -> Put
putVarint v
  | v < 128   = putWord8 (fromIntegral v)
  | otherwise  = do putWord8 (fromIntegral (v .&. 0x7F) .|. 0x80)
                    putVarint (v `shiftR` 7)

getVarint :: Get Word64
getVarint = go 0 0
  where go acc shift = do
          b <- getWord8
          let acc' = acc .|. (fromIntegral (b .&. 0x7F) `shiftL` shift)
          if b .&. 0x80 == 0 then return acc'
          else if shift >= 63 then fail "varint overflow"
          else go acc' (shift + 7)

putLenPrefixed :: BS.ByteString -> Put
putLenPrefixed bs = putWord64le (fromIntegral $ BS.length bs) >> putByteString bs

getLenPrefixed :: Get BS.ByteString
getLenPrefixed = do
  len <- getWord64le
  getByteString (fromIntegral len)

-- ═══════ roundtrip test framework ═══════

roundtrip :: (Eq a, Show a) => String -> (a -> Put) -> Get a -> a -> IO Bool
roundtrip name put get val = do
  let bs = LBS.toStrict $ runPut (put val)
  case runGetOrFail get (LBS.fromStrict bs) of
    Left (_, _, err)    -> do putStrLn ("  FAIL " ++ name ++ ": " ++ err); return False
    Right (rest, _, v)
      | v /= val        -> do putStrLn ("  FAIL " ++ name ++ ": got " ++ show v); return False
      | LBS.length rest /= 0 -> do putStrLn ("  FAIL " ++ name ++ ": leftover bytes"); return False
      | otherwise        -> return True

-- consumption: parse(serialize(x) ++ garbage) returns x and leaves garbage
consumption :: (Eq a, Show a) => String -> (a -> Put) -> Get a -> a -> BS.ByteString -> IO Bool
consumption name put get val garbage = do
  let bs = LBS.toStrict (runPut (put val)) <> garbage
  case runGetOrFail get (LBS.fromStrict bs) of
    Left (_, _, err)    -> do putStrLn ("  FAIL " ++ name ++ " consumption: " ++ err); return False
    Right (rest, _, v)
      | v /= val        -> do putStrLn ("  FAIL " ++ name ++ " consumption: wrong value"); return False
      | LBS.toStrict rest /= garbage -> do putStrLn ("  FAIL " ++ name ++ " consumption: wrong remainder"); return False
      | otherwise        -> return True

-- ═══════ xoshiro256** PRNG ═══════

data Rng = Rng !Word64 !Word64 !Word64 !Word64

mkRng :: Rng
mkRng = Rng 0x12345678 0xdeadbeef 0xcafebabe 0x0badf00d

rotl64 :: Word64 -> Int -> Word64
rotl64 x k = (x `shiftL` k) .|. (x `shiftR` (64 - k))

nextRng :: Rng -> (Word64, Rng)
nextRng (Rng s0 s1 s2 s3) = (result, Rng s0' s1' s2' s3')
  where result = rotl64 (s1 * 5) 7 * 9
        t = s1 `shiftL` 17
        s2' = s2 `xor` s0; s3' = s3 `xor` s1
        s1' = s1 `xor` s2'; s0' = s0 `xor` s3'
        -- s2' gets xor'd with t, s3' gets rotated
        -- (simplified — full impl would be more careful)

rngBytes :: Int -> Rng -> (BS.ByteString, Rng)
rngBytes n rng0 = go n rng0 []
  where go 0 r acc = (BS.pack (reverse acc), r)
        go k r acc = let (v, r') = nextRng r in go (k-1) r' (fromIntegral v : acc)

-- ═══════ tests ═══════

main :: IO ()
main = do
  putStrLn "Running Haskell codec property tests..."
  let rng0 = mkRng
  p <- runTests rng0
  putStrLn $ "\n" ++ show p ++ " passed"

runTests :: Rng -> IO Int
runTests rng0 = do
  p1 <- testPrim "u8" putWord8 getWord8 rng0 1000 (\r -> let (v,r') = nextRng r in (fromIntegral v :: Word8, r'))
  p2 <- testPrim "u32le" putWord32le getWord32le rng0 1000 (\r -> let (v,r') = nextRng r in (fromIntegral v :: Word32, r'))
  p3 <- testPrim "u64le" putWord64le getWord64le rng0 1000 (\r -> let (v,r') = nextRng r in (v, r'))
  p4 <- testPrim "varint" putVarint getVarint rng0 10000 (\r -> let (v,r') = nextRng r in (v, r'))
  p5 <- testVarintEdges
  p6 <- testLenPrefixed rng0 1000
  p7 <- testConsumption rng0 1000
  return (p1 + p2 + p3 + p4 + p5 + p6 + p7)

testPrim :: (Eq a, Show a) => String -> (a -> Put) -> Get a -> Rng -> Int -> (Rng -> (a, Rng)) -> IO Int
testPrim name put get rng0 n genVal = go rng0 n 0
  where go _ 0 p = do putStrLn ("  " ++ name ++ ": " ++ show p); return p
        go r k p = do
          let (v, r') = genVal r
          ok <- roundtrip name put get v
          go r' (k-1) (if ok then p+1 else p)

testVarintEdges :: IO Int
testVarintEdges = do
  let edges = [0,1,127,128,16383,16384,2097151,268435455,0xFFFFFFFF,0xFFFFFFFFFFFFFFFF]
  results <- mapM (\v -> roundtrip "varint-edge" putVarint getVarint v) edges
  let p = length (filter id results)
  putStrLn ("  varint edges: " ++ show p)
  return p

testLenPrefixed :: Rng -> Int -> IO Int
testLenPrefixed rng0 n = go rng0 n 0
  where go _ 0 p = do putStrLn ("  len_prefixed: " ++ show p); return p
        go r k p = do
          let (lenV, r') = nextRng r
              len = fromIntegral (lenV `mod` 256) :: Int
              (bs, r'') = rngBytes len r'
          ok <- roundtrip "len_prefixed" putLenPrefixed getLenPrefixed bs
          go r'' (k-1) (if ok then p+1 else p)

testConsumption :: Rng -> Int -> IO Int
testConsumption rng0 n = go rng0 n 0
  where go _ 0 p = do putStrLn ("  consumption: " ++ show p); return p
        go r k p = do
          let (v, r') = nextRng r
              (garbage, r'') = rngBytes 16 r'
          ok1 <- consumption "u64le" putWord64le getWord64le v garbage
          ok2 <- consumption "varint" putVarint getVarint v garbage
          go r'' (k-1) (if ok1 && ok2 then p+1 else p)
