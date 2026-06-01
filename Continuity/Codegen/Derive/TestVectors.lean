import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes
import Continuity.Codegen.Derive.BoxCodegen

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He'd operated on an almost permanent adrenaline high..."
      Phase 3.5: Test vector generation from Lean evaluation.

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Derive.TestVectors

open Continuity.Codec.Core.Box
open Continuity.Codec.Core.Bytes
open Continuity.Codegen.Derive.BoxCodegen

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // hex // helpers
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def byteToHex (b : UInt8) : String :=
  let n := b.toNat
  let hi := n / 16
  let lo := n % 16
  let dig (d : Nat) : Char := if d < 10 then Char.ofNat (48 + d) else Char.ofNat (87 + d)
  s!"{dig hi}{dig lo}"

def bytesToHex (bs : ByteArray) : String :=
  String.join (bs.toList.map byteToHex)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // concrete // vectors
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure VectorEntry where
  boxName : String
  valueDesc : String
  cppBytes : String
  wireSize : Nat
  deriving Repr, Inhabited

def vector (boxName : String) (desc : String) (_cppVal : String)
    (bytes : ByteArray) : VectorEntry :=
  { boxName := boxName
  , valueDesc := desc
  , cppBytes := bytesToHex bytes
  , wireSize := bytes.size
  }

def vectors_u8 : List VectorEntry :=
  [ vector "u8" "zero"   "0"    (u8.serialize (0 : UInt8))
  , vector "u8" "one"    "1"    (u8.serialize (1 : UInt8))
  , vector "u8" "0x42"   "66"   (u8.serialize (0x42 : UInt8))
  , vector "u8" "0xFF"   "255"  (u8.serialize (0xFF : UInt8))
  ]

def vectors_u32le : List VectorEntry :=
  [ vector "u32le" "zero"       "0"            (u32le.serialize (0 : UInt32))
  , vector "u32le" "one"        "1"            (u32le.serialize (1 : UInt32))
  , vector "u32le" "max"        "4294967295"   (u32le.serialize (0xFFFFFFFF : UInt32))
  ]

def vectors_u64le : List VectorEntry :=
  [ vector "u64le" "zero"      "0"                    (u64le.serialize (0 : UInt64))
  , vector "u64le" "one"       "1"                    (u64le.serialize (1 : UInt64))
  , vector "u64le" "max"       "18446744073709551615" (u64le.serialize (0xFFFFFFFFFFFFFFFF : UInt64))
  ]

def vectors_bool64 : List VectorEntry :=
  [ vector "bool64" "false" "false" (bool64.serialize false)
  , vector "bool64" "true"  "true"  (bool64.serialize true)
  ]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                // cpp // bytes // literal
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def hexToCppBytes (hex : String) (n : Nat) : String :=
  let chars := hex.toList
  if chars.length = 2 * n then
    let byteStrs : List String :=
      (List.range n).map fun i =>
        let idx := 2 * i
        let hi := (chars)[idx]?.getD '0'
        let lo := (chars)[(idx+1)]?.getD '0'
        s!"0x{hi}{lo}"
    "{ " ++ String.intercalate ", " byteStrs ++ " }"
  else
    "{ /* hex mismatch */ }"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                 // cpp // test // generation
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def genCppIncludes : String :=
  "#include <catch2/catch_test_macros.hpp>\n" ++
  "#include <cstdint>\n" ++
  "#include <vector>\n" ++
  "#include <span>\n" ++
  "#include <array>\n" ++
  "#include \"continuity_primitives.hpp\"\n"

def genCppInclude (boxName : String) : String :=
  "#include \"codec/" ++ boxName ++ ".hpp\""

def genCppRoundtripTest (v : VectorEntry) : String :=
  let testName := v.boxName ++ "_" ++ v.valueDesc
  let byteLiteral := hexToCppBytes v.cppBytes v.wireSize
  "-- Test vector for " ++ v.boxName ++ ": " ++ v.valueDesc ++ "\n" ++
  "TEST_CASE(\"" ++ testName ++ "_roundtrip\", \"[codec][generated]\") {\n" ++
  "    const std::vector<std::uint8_t> expected_bytes = " ++ byteLiteral ++ ";\n" ++
  "\n" ++
  "    auto parsed = parse_" ++ v.boxName ++ "(std::span(expected_bytes));\n" ++
  "    REQUIRE(parsed.has_value());\n" ++
  "    REQUIRE(parsed->remaining.empty());\n" ++
  "\n" ++
  "    std::vector<std::uint8_t> serialized;\n" ++
  "    serialize_" ++ v.boxName ++ "(parsed->value, serialized);\n" ++
  "    REQUIRE(serialized == expected_bytes);\n" ++
  "}\n"

def genCppSizeCheckTest (boxName : String) (minSize : Nat) : String :=
  if minSize == 0 then "" else
  "TEST_CASE(\"" ++ boxName ++ "_truncation_fails\", \"[codec][generated]\") {\n" ++
  "    SECTION(\"short inputs must fail\") {\n" ++
  "        for (std::size_t len = 0; len < " ++ toString minSize ++ "; ++len) {\n" ++
  "            std::vector<std::uint8_t> short_buf(len, 0x42);\n" ++
  "            auto result = parse_" ++ boxName ++ "(std::span(short_buf));\n" ++
  "            REQUIRE_FALSE(result.has_value());\n" ++
  "        }\n" ++
  "    }\n" ++
  "}\n"

def genCppConsumptionTest (boxName : String) (minSize : Nat) : String :=
  if minSize == 0 then "" else
  "TEST_CASE(\"" ++ boxName ++ "_consumption_extra_bytes\", \"[codec][generated]\") {\n" ++
  "    std::vector<std::uint8_t> buf(" ++ toString minSize ++ ", 0);\n" ++
  "    buf.push_back(0xDE);\n" ++
  "    buf.push_back(0xAD);\n" ++
  "    buf.push_back(0xBE);\n" ++
  "    buf.push_back(0xEF);\n" ++
  "    auto result = parse_" ++ boxName ++ "(std::span(buf));\n" ++
  "    REQUIRE(result.has_value());\n" ++
  "    REQUIRE(result->remaining.size() == 4);\n" ++
  "    REQUIRE(result->remaining[0] == 0xDE);\n" ++
  "    REQUIRE(result->remaining[1] == 0xAD);\n" ++
  "    REQUIRE(result->remaining[2] == 0xBE);\n" ++
  "    REQUIRE(result->remaining[3] == 0xEF);\n" ++
  "}\n"

private def getMinSize (spec : BoxSpec) : Nat :=
  match spec with
  | .u8 => 1
  | .uint b _ => b / 8
  | .bool64 => 8
  | .varint => 0
  | .lenPrefixed _ => 8
  | _ => 0

def genCppTestFile : String :=
  let allVectors := vectors_u8 ++ vectors_u32le ++ vectors_u64le ++ vectors_bool64
  let boxNames : List String := allVectors.map (·.boxName) |> (fun xs => xs.eraseDups)
  let includes := boxNames.map genCppInclude
  let roundtripTests := allVectors.map genCppRoundtripTest
  let sizeTests : List String := boxNames.map fun name =>
    match codecRegistry.find? (fun e => e.name == name) with
    | some entry => genCppSizeCheckTest name (getMinSize entry.spec)
    | none => ""
  let consumptionTests : List String := boxNames.map fun name =>
    match codecRegistry.find? (fun e => e.name == name) with
    | some entry => genCppConsumptionTest name (getMinSize entry.spec)
    | none => ""
  genCppIncludes ++ "\n" ++
  String.intercalate "\n" includes ++ "\n\n" ++
  "// =================================================================\n" ++
  "// ROUNDTRIP TESTS (Oracle: Lean #eval)\n" ++
  "// =================================================================\n\n" ++
  String.intercalate "\n" roundtripTests ++ "\n" ++
  "// =================================================================\n" ++
  "// SIZE CHECK TESTS (truncation must fail)\n" ++
  "// =================================================================\n\n" ++
  String.intercalate "\n" (sizeTests.filter (· ≠ "")) ++ "\n" ++
  "// =================================================================\n" ++
  "// CONSUMPTION TESTS (extra bytes preserved)\n" ++
  "// =================================================================\n\n" ++
  String.intercalate "\n" (consumptionTests.filter (· ≠ ""))

def deriveCppTests : String := genCppTestFile

end Continuity.Codegen.Derive.TestVectors
