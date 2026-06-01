import Continuity.Algebra.Grade

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He closed his eyes and found the new geography, the one
      that described the space behind the world. In this space,
      every computation was a location, every effect a boundary,
      every coeffect a gate that had to be passed. The grade was
      not a label; it was a key. And the key either fit or it
      didn't. There was no middle ground, no 'almost opens,'
      no 'opens if you squint.' The machine was a proof checker
      that could not be lied to."

                                                                    — Count Zero

     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Cpp.Primitives

/-
  Emit the C++ primitives header — `constexpr` bitfield grade algebra,
  `ParseResult<T>` with monotonic grade, and grade lifting combinators.

  This is the C++ runtime substrate for the coeffect lattice defined in
  `Algebra/Grade.lean`. Every parse function in generated codec headers
  returns `ParseResult<T>`, initialized with `grade_unit` (pure). After
  verification passes (signature check, timestamp check, auth), helper
  functions lift the grade.

  The grade is monotonic: once tagged, it can only grow. This is enforced
  by the `Grade` type itself (no public mutation, only `operator|`).

  Pattern borrowed from `libevring-cpp/src/evring/core/` and the straylight
  0x01-continuity research pipeline.
-/

open Continuity.Algebra.Grade

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // label // serialization
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def emitLabelBit (l : Label) : String :=
  match l with
  | .Net      => "Net = 1 << 0"
  | .Auth     => "Auth = 1 << 1"
  | .Config   => "Config = 1 << 2"
  | .Log      => "Log = 1 << 3"
  | .Crypto   => "Crypto = 1 << 4"
  | .Fs       => "Fs = 1 << 5"
  | .FsCA     => "FsCA = 1 << 6"
  | .Gpu      => "Gpu = 1 << 7"
  | .Sandbox  => "Sandbox = 1 << 8"
  | .Time     => "Time = 1 << 9"
  | .Random   => "Random = 1 << 10"
  | .Env      => "Env = 1 << 11"
  | .Identity => "Identity = 1 << 12"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // emit // grade // struct
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def emitCppPrimitives : String :=
  let labels := Grade.full.map emitLabelBit
  let labelDecl := ",\n".intercalate (labels.map ("    " ++ ·))
  "#pragma once\n\n" ++
  "#include <cstdint>\n" ++
  "#include <span>\n\n" ++
  "// ── Grade labels ───────────────────────────────────────────────\n" ++
  "// Bitfield enum: each label occupies one bit. Grades compose via\n" ++
  "// bitwise OR. Operations: is_subset_of, is_pure.\n" ++
  "// Generated from Continuity.Algebra.Grade (Lean).\n\n" ++
  "enum class GradeLabel : uint16_t {\n" ++
  labelDecl ++ "\n" ++
  "};\n\n" ++
  "// ── Grade ──────────────────────────────────────────────────────\n" ++
  "// Monotonic coeffect accumulator. No public mutation — only\n" ++
  "// operator| creates a new Grade. Once tagged, a label cannot be\n" ++
  "// removed. This enforces the monotonicity invariant at compile time.\n\n" ++
  "struct Grade {\n" ++
  "    uint16_t bits = 0;\n\n" ++
  "    constexpr Grade() = default;\n" ++
  "    constexpr explicit Grade(uint16_t b) : bits(b) {}\n\n" ++
  "    constexpr Grade operator|(Grade other) const {\n" ++
  "        return Grade(bits | other.bits);\n" ++
  "    }\n\n" ++
  "    constexpr bool is_subset_of(Grade other) const {\n" ++
  "        return (bits & ~other.bits) == 0;\n" ++
  "    }\n\n" ++
  "    constexpr bool is_pure() const {\n" ++
  "        return bits == 0;\n" ++
  "    }\n" ++
  "};\n\n" ++
  "// ── Named grade constants ──────────────────────────────────────\n\n" ++
  "constexpr Grade grade_unit{};\n" ++
  "constexpr Grade grade_net{static_cast<uint16_t>(GradeLabel::Net)};\n" ++
  "constexpr Grade grade_auth{static_cast<uint16_t>(GradeLabel::Auth)};\n" ++
  "constexpr Grade grade_config{static_cast<uint16_t>(GradeLabel::Config)};\n" ++
  "constexpr Grade grade_log{static_cast<uint16_t>(GradeLabel::Log)};\n" ++
  "constexpr Grade grade_crypto{static_cast<uint16_t>(GradeLabel::Crypto)};\n" ++
  "constexpr Grade grade_fs{static_cast<uint16_t>(GradeLabel::Fs)};\n" ++
  "constexpr Grade grade_fsCA{static_cast<uint16_t>(GradeLabel::FsCA)};\n" ++
  "constexpr Grade grade_gpu{static_cast<uint16_t>(GradeLabel::Gpu)};\n" ++
  "constexpr Grade grade_sandbox{static_cast<uint16_t>(GradeLabel::Sandbox)};\n" ++
  "constexpr Grade grade_time{static_cast<uint16_t>(GradeLabel::Time)};\n" ++
  "constexpr Grade grade_random{static_cast<uint16_t>(GradeLabel::Random)};\n" ++
  "constexpr Grade grade_env{static_cast<uint16_t>(GradeLabel::Env)};\n" ++
  "constexpr Grade grade_identity{static_cast<uint16_t>(GradeLabel::Identity)};\n\n" ++
  "// ── Domain grades ──────────────────────────────────────────────\n" ++
  "// Generated from Continuity.Algebra.Grade domain grades (Lean).\n\n" ++
  "constexpr Grade grade_attest = grade_auth | grade_crypto | grade_time;\n" ++
  "constexpr Grade grade_gateway = grade_net | grade_auth | grade_config\n" ++
  "                             | grade_log | grade_crypto;\n" ++
  "constexpr Grade grade_build = grade_fs | grade_fsCA | grade_net\n" ++
  "                            | grade_env | grade_sandbox;\n\n" ++
  "// ── ParseResult ────────────────────────────────────────────────\n" ++
  "// Every parse function returns ParseResult<T>, initialized with\n" ++
  "// grade_unit (pure). After verification passes, helper functions\n" ++
  "// lift the grade. The grade field is monotonic — once tagged, it\n" ++
  "// can only grow.\n\n" ++
  "template<typename T>\n" ++
  "struct ParseResult {\n" ++
  "    T value;\n" ++
  "    std::span<const uint8_t> remaining;\n" ++
  "    Grade grade;\n" ++
  "    bool _ok = false;\n\n" ++
  "    constexpr ParseResult() = default;\n" ++
  "    constexpr ParseResult(T v, std::span<const uint8_t> r, Grade g = grade_unit)\n" ++
  "        : value(std::move(v)), remaining(r), grade(g), _ok(true) {}\n\n" ++
  "    constexpr bool has_value() const { return _ok; }\n" ++
  "    constexpr explicit operator bool() const { return _ok; }\n\n" ++
  "    T* operator->() { return &value; }\n" ++
  "    const T* operator->() const { return &value; }\n" ++
  "    T& operator*() { return value; }\n" ++
  "    const T& operator*() const { return value; }\n" ++
  "};\n\n" ++
  "// ── ok/fail helpers ────────────────────────────────────────────\n" ++
  "// CTAD-compatible constructors for ergonomic generated code.\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> ok(T value, std::span<const uint8_t> remaining, Grade g = grade_unit) {\n" ++
  "    return ParseResult<T>{std::move(value), remaining, g};\n" ++
  "}\n\n" ++
  "inline constexpr struct Fail {\n" ++
  "    template<typename T>\n" ++
  "    [[nodiscard]] constexpr operator ParseResult<T>() const {\n" ++
  "        return ParseResult<T>{};\n" ++
  "    }\n" ++
  "} fail{};\n\n" ++
  "// ── Grade lifters ──────────────────────────────────────────────\n" ++
  "// Each lifter applies a verification step and adds the\n" ++
  "// corresponding coeffect label to the ParseResult's grade.\n" ++
  "// The grade grows monotonically — labels are never removed.\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> with_grade(\n" ++
  "    ParseResult<T> r, Grade g) {\n" ++
  "    r.grade = r.grade | g;\n" ++
  "    return r;\n" ++
  "}\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> with_crypto_grade(\n" ++
  "    ParseResult<T> r) {\n" ++
  "    return with_grade(r, grade_crypto);\n" ++
  "}\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> with_time_grade(\n" ++
  "    ParseResult<T> r) {\n" ++
  "    return with_grade(r, grade_time);\n" ++
  "}\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> with_net_grade(\n" ++
  "    ParseResult<T> r) {\n" ++
  "    return with_grade(r, grade_net);\n" ++
  "}\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> with_auth_grade(\n" ++
  "    ParseResult<T> r) {\n" ++
  "    return with_grade(r, grade_auth);\n" ++
  "}\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> with_fs_grade(\n" ++
  "    ParseResult<T> r) {\n" ++
  "    return with_grade(r, grade_fs);\n" ++
  "}\n\n" ++
  "template<typename T>\n" ++
  "[[nodiscard]] constexpr ParseResult<T> with_attest_grade(\n" ++
  "    ParseResult<T> r) {\n" ++
  "    return with_grade(r, grade_attest);\n" ++
  "}\n"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // emit // header
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def emitCppPrimitivesHeader : String :=
  "- Generated by Continuity — do not edit\n" ++
  "- C++ primitives: grade algebra, ParseResult<T>, grade lifters.\n" ++
  "- Corresponds to Continuity.Algebra.Grade (Lean).\n" ++
  "-"

end Continuity.Codegen.AST.Cpp.Primitives
