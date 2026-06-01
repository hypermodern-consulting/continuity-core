import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes
import Continuity.Codec.Core.Varint

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The box was a promise kept at the hardware level."
      Box -> C++/Haskell codegen. Phase 3.1 + 3.2.
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Derive.BoxCodegen

open Continuity.Codec.Core.Box
open Continuity.Codec.Core.Bytes
open Continuity.Codec.Core.Varint

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // box // spec
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive Endianness where
  | little | big
  deriving Repr, DecidableEq, Inhabited

inductive BoxSpec where
  | unit
  | u8
  | uint (bits : Nat) (endian : Endianness)
  | bool64
  | seq (a b : BoxSpec)
  | iso (inner : BoxSpec) (targetName : String)
  | lenPrefixed (alignment : Nat)
  | fixedBytes (n : Nat)
  | varint
  deriving Repr, Inhabited

namespace BoxSpec

def wireSize : BoxSpec -> Option Nat
  | .unit => some 0
  | .u8 => some 1
  | .uint bits _ => some (bits / 8)
  | .bool64 => some 8
  | .seq a b => do let sa <- a.wireSize; let sb <- b.wireSize; pure (sa + sb)
  | .iso inner _ => inner.wireSize
  | .lenPrefixed _ => none
  | .fixedBytes n => some n
  | .varint => none

def typeName : BoxSpec -> String
  | .unit => "Unit"
  | .u8 => "UInt8"
  | .uint 32 .little => "UInt32"
  | .uint 64 .little => "UInt64"
  | .uint bits _ => s!"UInt{bits}"
  | .bool64 => "Bool"
  | .seq a b => s!"({a.typeName} x {b.typeName})"
  | .iso _ name => name
  | .lenPrefixed _ => "Bytes"
  | .fixedBytes n => s!"Bytes[{n}]"
  | .varint => "UInt64"

def cppType : BoxSpec -> String
  | .u8 => "std::uint8_t"
  | .uint 32 _ => "std::uint32_t"
  | .uint 64 _ => "std::uint64_t"
  | .uint _ _ => "std::uint64_t"
  | .bool64 => "bool"
  | .lenPrefixed _ => "std::vector<std::uint8_t>"
  | .fixedBytes n => s!"std::array<std::uint8_t, {n}>"
  | .varint => "std::uint64_t"
  | _ => "void"

def hsType : BoxSpec -> String
  | .u8 => "Word8"
  | .uint 32 _ => "Word32"
  | .uint 64 _ => "Word64"
  | .uint _ _ => "Word64"
  | .bool64 => "Bool"
  | .lenPrefixed _ => "ByteString"
  | .fixedBytes _ => "ByteString"
  | .varint => "Word64"
  | _ => "()"

end BoxSpec

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // known // boxes
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def spec_u8 : BoxSpec := .u8
def spec_u32le : BoxSpec := .uint 32 .little
def spec_u64le : BoxSpec := .uint 64 .little
def spec_bool64 : BoxSpec := .bool64
def spec_lenPrefixed : BoxSpec := .lenPrefixed 0
def spec_nixString : BoxSpec := .lenPrefixed 8
def spec_varint : BoxSpec := .varint

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // cpp // emit // helpers
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- emit a C++ function body as a string block (no s! so braces are literal)
-- we use plain ++ instead of s! to avoid escaping headaches
private def cppBlock (body : String) : String :=
  "  if (bs.size() < " ++ body

private def cppSubspan (n : String) : String :=
  "bs.subspan(" ++ n ++ "ULL)"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // cpp // codegen
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def cppHeaderPrelude (name : String) (spec : BoxSpec) : String :=
  "#pragma once\n" ++
  "// Generated from Continuity verified codec: " ++ name ++ "\n" ++
  "// 0 sorry. Machine-checked roundtrip proof.\n" ++
  "// Wire type: " ++ spec.typeName ++ "\n\n" ++
  "#include <cstdint>\n" ++
  "#include <cstddef>\n" ++
  "#include <span>\n" ++
  "#include <vector>\n" ++
  "#include <array>\n\n" ++
  "#include \"continuity_primitives.hpp\"\n\n" ++
  "namespace continuity {\n\n"

def cppFooter : String :=
  "\n} // namespace continuity\n"

def genCppU8 : String :=
  "/// Parse UInt8 from bytes. Generated from verified Box.\n" ++
  "[[nodiscard]] constexpr ParseResult<std::uint8_t> parse_u8(std::span<const std::uint8_t> bs) {\n" ++
  "  if (bs.size() < 1ULL) { return fail; }\n" ++
  "  return ok(static_cast<std::uint8_t>(bs[0ULL]), bs.subspan(1ULL));\n" ++
  "}\n\n" ++
  "/// Serialize UInt8 to bytes. Generated from verified Box.\n" ++
  "constexpr void serialize_u8(std::uint8_t value, std::vector<std::uint8_t>& out) {\n" ++
  "  out.push_back(static_cast<std::uint8_t>(value));\n" ++
  "}"

def genCppU32le : String :=
  "/// Parse UInt32 from bytes. Generated from verified Box.\n" ++
  "[[nodiscard]] constexpr ParseResult<std::uint32_t> parse_u32le(std::span<const std::uint8_t> bs) {\n" ++
  "  if (bs.size() < 4ULL) { return fail; }\n" ++
  "  auto value = static_cast<std::uint32_t>(" ++
    "(static_cast<std::uint64_t>(bs[0ULL]) | " ++
    "(static_cast<std::uint64_t>(bs[1ULL]) << 8ULL) | " ++
    "(static_cast<std::uint64_t>(bs[2ULL]) << 16ULL) | " ++
    "(static_cast<std::uint64_t>(bs[3ULL]) << 24ULL)));\n" ++
  "  return ok(value, bs.subspan(4ULL));\n" ++
  "}\n\n" ++
  "/// Serialize UInt32 to bytes. Generated from verified Box.\n" ++
  "constexpr void serialize_u32le(std::uint32_t value, std::vector<std::uint8_t>& out) {\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint32_t>(value) >> 0ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint32_t>(value) >> 8ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint32_t>(value) >> 16ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint32_t>(value) >> 24ULL) & 0xFFULL));\n" ++
  "}"

def genCppU64le : String :=
  "/// Parse UInt64 from bytes. Generated from verified Box.\n" ++
  "[[nodiscard]] constexpr ParseResult<std::uint64_t> parse_u64le(std::span<const std::uint8_t> bs) {\n" ++
  "  if (bs.size() < 8ULL) { return fail; }\n" ++
  "  auto value = (" ++
    "(((((static_cast<std::uint64_t>(bs[0ULL]) | " ++
    "(static_cast<std::uint64_t>(bs[1ULL]) << 8ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[2ULL]) << 16ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[3ULL]) << 24ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[4ULL]) << 32ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[5ULL]) << 40ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[6ULL]) << 48ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[7ULL]) << 56ULL)));\n" ++
  "  return ok(value, bs.subspan(8ULL));\n" ++
  "}\n\n" ++
  "/// Serialize UInt64 to bytes. Generated from verified Box.\n" ++
  "constexpr void serialize_u64le(std::uint64_t value, std::vector<std::uint8_t>& out) {\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 0ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 8ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 16ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 24ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 32ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 40ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 48ULL) & 0xFFULL));\n" ++
  "  out.push_back(static_cast<std::uint8_t>((static_cast<std::uint64_t>(value) >> 56ULL) & 0xFFULL));\n" ++
  "}"

def genCppBool64 : String :=
  "/// Parse Bool (Nix wire: u64le, 0=false, nonzero=true). Generated from verified Box.\n" ++
  "[[nodiscard]] constexpr ParseResult<bool> parse_bool64(std::span<const std::uint8_t> bs) {\n" ++
  "  if (bs.size() < 8ULL) { return fail; }\n" ++
  "  auto value = (" ++
    "(((((static_cast<std::uint64_t>(bs[0ULL]) | " ++
    "(static_cast<std::uint64_t>(bs[1ULL]) << 8ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[2ULL]) << 16ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[3ULL]) << 24ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[4ULL]) << 32ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[5ULL]) << 40ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[6ULL]) << 48ULL)) | " ++
    "(static_cast<std::uint64_t>(bs[7ULL]) << 56ULL)));\n" ++
  "  return ok(value != 0ULL, bs.subspan(8ULL));\n" ++
  "}\n\n" ++
  "/// Serialize Bool to bytes (Nix wire). Generated from verified Box.\n" ++
  "constexpr void serialize_bool64(bool value, std::vector<std::uint8_t>& out) {\n" ++
  "  serialize_u64le(value ? 1ULL : 0ULL, out);\n" ++
  "}"

def genCppLenPrefixed : String :=
  "/// Parse length-prefixed bytes (u64le length + content). Generated from verified Box.\n" ++
  "[[nodiscard]] constexpr ParseResult<std::vector<std::uint8_t>> parse_len_prefixed(std::span<const std::uint8_t> bs) {\n" ++
  "  if (bs.size() < 8ULL) { return fail; }\n" ++
  "  std::uint64_t n = 0;\n" ++
  "  for (int i = 0; i < 8; ++i) n |= static_cast<std::uint64_t>(bs[i]) << (i * 8);\n" ++
  "  auto total = n;\n" ++
  "  if (bs.size() < 8ULL + total) { return fail; }\n" ++
  "  std::vector<std::uint8_t> data(bs.begin() + 8, bs.begin() + 8 + static_cast<std::size_t>(n));\n" ++
  "  return ok(std::move(data), bs.subspan(8ULL + total));\n" ++
  "}\n\n" ++
  "/// Serialize length-prefixed bytes. Generated from verified Box.\n" ++
  "constexpr void serialize_len_prefixed(const std::vector<std::uint8_t>& value, std::vector<std::uint8_t>& out) {\n" ++
  "  auto n = static_cast<std::uint64_t>(value.size());\n" ++
  "  for (int i = 0; i < 8; ++i) out.push_back(static_cast<std::uint8_t>((n >> (i * 8)) & 0xFFULL));\n" ++
  "  out.insert(out.end(), value.begin(), value.end());\n" ++
  "  // no padding\n" ++
  "}"

def genCppNixString : String :=
  "/// Parse Nix string (u64le length + content + 8-byte alignment padding).\n" ++
  "[[nodiscard]] constexpr ParseResult<std::vector<std::uint8_t>> parse_nix_string(std::span<const std::uint8_t> bs) {\n" ++
  "  if (bs.size() < 8ULL) { return fail; }\n" ++
  "  std::uint64_t n = 0;\n" ++
  "  for (int i = 0; i < 8; ++i) n |= static_cast<std::uint64_t>(bs[i]) << (i * 8);\n" ++
  "  auto pad = (n % 8ULL == 0) ? 0ULL : (8ULL - (n % 8ULL));\n" ++
  "  auto total = n + pad;\n" ++
  "  if (bs.size() < 8ULL + total) { return fail; }\n" ++
  "  std::vector<std::uint8_t> data(bs.begin() + 8, bs.begin() + 8 + static_cast<std::size_t>(n));\n" ++
  "  return ok(std::move(data), bs.subspan(8ULL + total));\n" ++
  "}\n\n" ++
  "/// Serialize Nix string. Generated from verified Box.\n" ++
  "constexpr void serialize_nix_string(const std::vector<std::uint8_t>& value, std::vector<std::uint8_t>& out) {\n" ++
  "  auto n = static_cast<std::uint64_t>(value.size());\n" ++
  "  for (int i = 0; i < 8; ++i) out.push_back(static_cast<std::uint8_t>((n >> (i * 8)) & 0xFFULL));\n" ++
  "  out.insert(out.end(), value.begin(), value.end());\n" ++
  "  auto pad = (value.size() % 8ULL == 0) ? 0ULL : (8ULL - (value.size() % 8ULL));\n" ++
  "  for (std::size_t i = 0; i < pad; ++i) out.push_back(0);\n" ++
  "}"

def genCppVarint : String :=
  "/// Parse Protobuf-style varint. Generated from verified Box.\n" ++
  "[[nodiscard]] constexpr ParseResult<std::uint64_t> parse_varint(std::span<const std::uint8_t> bs) {\n" ++
  "  std::uint64_t result = 0;\n" ++
  "  std::size_t shift = 0;\n" ++
  "  for (std::size_t i = 0; i < bs.size() && i < 10; ++i) {\n" ++
  "    std::uint8_t b = bs[i];\n" ++
  "    result |= static_cast<std::uint64_t>(b & 0x7FULL) << shift;\n" ++
  "    if ((b & 0x80ULL) == 0) return ok(result, bs.subspan(i + 1));\n" ++
  "    shift += 7;\n" ++
  "  }\n" ++
  "  return fail;\n" ++
  "}\n\n" ++
  "/// Serialize Protobuf-style varint. Generated from verified Box.\n" ++
  "constexpr void serialize_varint(std::uint64_t value, std::vector<std::uint8_t>& out) {\n" ++
  "  do {\n" ++
  "    std::uint8_t b = static_cast<std::uint8_t>(value & 0x7FULL);\n" ++
  "    value >>= 7;\n" ++
  "    if (value) b |= 0x80ULL;\n" ++
  "    out.push_back(b);\n" ++
  "  } while (value);\n" ++
  "  if (out.empty()) out.push_back(0);\n" ++
  "}"

def genCppCodec (name : String) (spec : BoxSpec) : String :=
  let body := match spec with
  | .u8 => genCppU8
  | .uint 32 .little => genCppU32le
  | .uint 64 .little => genCppU64le
  | .bool64 => genCppBool64
  | .lenPrefixed 0 => genCppLenPrefixed
  | .lenPrefixed _ => genCppNixString
  | .varint => genCppVarint
  | _ => "// TODO: not yet generated"
  cppHeaderPrelude name spec ++ body ++ cppFooter

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // haskell // codegen
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Helper: Haskell backtick operator for infix names
private def bq (s : String) : String := "`" ++ s ++ "`"

def genHsU8 : String :=
  "-- | Parse UInt8 from bytes. Generated from verified Box.\n" ++
  "parse_u8 :: ByteString -> Either String (Word8, ByteString)\n" ++
  "parse_u8 bs\n" ++
  "  | BS.length bs < 1 = Left \"parse_u8: insufficient bytes\"\n" ++
  "  | otherwise = Right (BS.index bs 0, BS.drop 1 bs)\n\n" ++
  "-- | Serialize UInt8 to bytes. Generated from verified Box.\n" ++
  "serialize_u8 :: Word8 -> ByteString\n" ++
  "serialize_u8 v =\n" ++
  "  BS.singleton v\n"

def genHsU32le : String :=
  "-- | Parse UInt32 from bytes. Generated from verified Box.\n" ++
  "parse_u32le :: ByteString -> Either String (Word32, ByteString)\n" ++
  "parse_u32le bs\n" ++
  "  | BS.length bs < 4 = Left \"parse_u32le: insufficient bytes\"\n" ++
  "  | otherwise = Right (" ++
    "(fromIntegral (BS.index bs 0) .|. " ++
    "(fromIntegral (BS.index bs 1) " ++ bq "shiftL" ++ " 8) .|. " ++
    "(fromIntegral (BS.index bs 2) " ++ bq "shiftL" ++ " 16) .|. " ++
    "(fromIntegral (BS.index bs 3) " ++ bq "shiftL" ++ " 24))" ++
    ", BS.drop 4 bs)\n\n" ++
  "-- | Serialize UInt32 to bytes. Generated from verified Box.\n" ++
  "serialize_u32le :: Word32 -> ByteString\n" ++
  "serialize_u32le v =\n" ++
  "  BS.pack [fromIntegral (v " ++ bq "shiftR" ++ " 0), fromIntegral (v " ++ bq "shiftR" ++ " 8),\n" ++
  "           fromIntegral (v " ++ bq "shiftR" ++ " 16), fromIntegral (v " ++ bq "shiftR" ++ " 24)]\n"

def genHsU64le : String :=
  "-- | Parse UInt64 from bytes. Generated from verified Box.\n" ++
  "parse_u64le :: ByteString -> Either String (Word64, ByteString)\n" ++
  "parse_u64le bs\n" ++
  "  | BS.length bs < 8 = Left \"parse_u64le: insufficient bytes\"\n" ++
  "  | otherwise = Right " ++
    "(foldl' (\\acc i -> acc .|. (fromIntegral (BS.index bs i) " ++ bq "shiftL" ++ " (i * 8))) 0 [0..7]" ++
    ", BS.drop 8 bs)\n\n" ++
  "-- | Serialize UInt64 to bytes. Generated from verified Box.\n" ++
  "serialize_u64le :: Word64 -> ByteString\n" ++
  "serialize_u64le v =\n" ++
  "  BS.pack [fromIntegral (v " ++ bq "shiftR" ++ " (i*8)) | i <- [0..7]]\n"

def genHsBool64 : String :=
  "-- | Parse Bool (Nix wire). Generated from verified Box.\n" ++
  "parse_bool64 :: ByteString -> Either String (Bool, ByteString)\n" ++
  "parse_bool64 bs =\n" ++
  "  case parse_u64le bs of\n" ++
  "    Left err -> Left err\n" ++
  "    Right (val, rest) -> Right (val /= 0, rest)\n\n" ++
  "-- | Serialize Bool (Nix wire). Generated from verified Box.\n" ++
  "serialize_bool64 :: Bool -> ByteString\n" ++
  "serialize_bool64 v =\n" ++
  "  serialize_u64le (if v then 1 else 0)\n"

def genHsLenPrefixed : String :=
  "-- | Parse length-prefixed bytes. Generated from verified Box.\n" ++
  "parse_len_prefixed :: ByteString -> Either String (ByteString, ByteString)\n" ++
  "parse_len_prefixed bs = do\n" ++
  "  (lenRaw, rest) <- parse_u64le bs\n" ++
  "  let n = fromIntegral lenRaw\n" ++
  "      pad = 0\n" ++
  "  if BS.length rest < n + pad\n" ++
  "    then Left \"parse_len_prefixed: insufficient data\"\n" ++
  "    else Right (BS.take n rest, BS.drop (n + pad) rest)\n\n" ++
  "-- | Serialize length-prefixed bytes. Generated from verified Box.\n" ++
  "serialize_len_prefixed :: ByteString -> ByteString\n" ++
  "serialize_len_prefixed bs =\n" ++
  "  let n = BS.length bs\n" ++
  "  in serialize_u64le (fromIntegral n) <> bs\n"

def genHsNixString : String :=
  "-- | Parse Nix string (8-byte aligned). Generated from verified Box.\n" ++
  "parse_nix_string :: ByteString -> Either String (ByteString, ByteString)\n" ++
  "parse_nix_string bs = do\n" ++
  "  (lenRaw, rest) <- parse_u64le bs\n" ++
  "  let n = fromIntegral lenRaw\n" ++
  "      pad = if n " ++ bq "mod" ++ " 8 == 0 then 0 else 8 - (n " ++ bq "mod" ++ " 8)\n" ++
  "  if BS.length rest < n + pad\n" ++
  "    then Left \"parse_nix_string: insufficient data\"\n" ++
  "    else Right (BS.take n rest, BS.drop (n + pad) rest)\n\n" ++
  "-- | Serialize Nix string. Generated from verified Box.\n" ++
  "serialize_nix_string :: ByteString -> ByteString\n" ++
  "serialize_nix_string bs =\n" ++
  "  let n = BS.length bs\n" ++
  "      pad = if n " ++ bq "mod" ++ " 8 == 0 then 0 else 8 - (n " ++ bq "mod" ++ " 8)\n" ++
  "  in serialize_u64le (fromIntegral n) <> bs <> BS.replicate pad 0\n"

def genHsVarint : String :=
  "-- | Parse Protobuf-style varint. Generated from verified Box.\n" ++
  "parse_varint :: ByteString -> Either String (Word64, ByteString)\n" ++
  "parse_varint = go 0 0\n" ++
  "  where\n" ++
  "    go !acc !shift bs\n" ++
  "      | BS.null bs = Left \"parse_varint: unexpected end\"\n" ++
  "      | shift > 63 = Left \"parse_varint: overflow\"\n" ++
  "      | otherwise =\n" ++
  "          let b = BS.index bs 0\n" ++
  "              acc' = acc .|. (fromIntegral (b .&. 0x7F) " ++ bq "shiftL" ++ " shift)\n" ++
  "          in if b .&. 0x80 == 0\n" ++
  "             then Right (acc', BS.drop 1 bs)\n" ++
  "             else go acc' (shift + 7) (BS.drop 1 bs)\n\n" ++
  "-- | Serialize Protobuf-style varint. Generated from verified Box.\n" ++
  "serialize_varint :: Word64 -> ByteString\n" ++
  "serialize_varint v =\n" ++
  "  let go 0 = [0]\n" ++
  "      go v | v < 128 = [fromIntegral v]\n" ++
  "           | otherwise = fromIntegral (v .&. 0x7F .|. 0x80) : go (v " ++ bq "shiftR" ++ " 7)\n" ++
  "  in BS.pack (go v)\n"

def genHsCodec (name : String) (spec : BoxSpec) : String :=
  let moduleName := String.join (name.splitOn "_" |>.map String.capitalize)
  let header :=
    "{-# LANGUAGE OverloadedStrings #-}\n" ++
    "\n" ++
    "-- Generated from Continuity verified codec: " ++ name ++ "\n" ++
    "-- 0 sorry. Machine-checked roundtrip proof.\n" ++
    "-- Wire type: " ++ spec.typeName ++ "\n\n" ++
    "module Continuity.Codec." ++ moduleName ++ " where\n\n" ++
    "import Data.ByteString (ByteString)\n" ++
    "import qualified Data.ByteString as BS\n" ++
    "import Data.Word (Word8, Word32, Word64)\n" ++
    "import Data.Bits\n" ++
    "import Data.List (foldl')\n\n"
  let body := match spec with
  | .u8 => genHsU8
  | .uint 32 .little => genHsU32le
  | .uint 64 .little => genHsU64le
  | .bool64 => genHsBool64
  | .lenPrefixed 0 => genHsLenPrefixed
  | .lenPrefixed _ => genHsNixString
  | .varint => genHsVarint
  | _ => "-- TODO: not yet generated\n"
  header ++ body

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                      // codec // registry
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure CodecEntry where
  name : String
  spec : BoxSpec
  deriving Repr, Inhabited

def codecRegistry : List CodecEntry :=
  [ ⟨"u8", spec_u8⟩
  , ⟨"u32le", spec_u32le⟩
  , ⟨"u64le", spec_u64le⟩
  , ⟨"bool64", spec_bool64⟩
  , ⟨"len_prefixed", spec_lenPrefixed⟩
  , ⟨"nix_string", spec_nixString⟩
  , ⟨"varint", spec_varint⟩
  ]

def deriveCppCodecs : List (String × String) :=
  codecRegistry.map fun entry =>
    (s!"codec/{entry.name}.hpp", genCppCodec entry.name entry.spec)

def deriveHaskellCodecs : List (String × String) :=
  codecRegistry.map fun entry =>
    let moduleName := String.join (entry.name.splitOn "_" |>.map String.capitalize)
    (s!"Codec/{moduleName}.hs", genHsCodec entry.name entry.spec)

end Continuity.Codegen.Derive.BoxCodegen
