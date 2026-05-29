// codec_test.cpp — roundtrip property tests for all generated codecs
// Compile: g++-13 -std=c++20 -O2 -I test -o test/codec_test test/codec_test.cpp
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>

#include "codec_runtime.hpp"

using namespace continuity;

// ═══════════════════════════════════════════════════════════════════════════════
// PRNG
// ═══════════════════════════════════════════════════════════════════════════════

static std::mt19937_64 rng(42);

uint8_t rand_u8() {
  return std::uniform_int_distribution<uint16_t>(0, 255)(rng);
}
uint16_t rand_u16() {
  return std::uniform_int_distribution<uint16_t>()(rng);
}
uint32_t rand_u32() {
  return std::uniform_int_distribution<uint32_t>()(rng);
}
uint64_t rand_u64() {
  return std::uniform_int_distribution<uint64_t>()(rng);
}
bool rand_bool() {
  return rng() & 1;
}

std::vector<uint8_t> rand_bytes(size_t maxlen = 256) {
  size_t n = rng() % (maxlen + 1);
  std::vector<uint8_t> v(n);
  for (auto& b : v)
    b = rand_u8();
  return v;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIMITIVE ROUNDTRIP TESTS
// ═══════════════════════════════════════════════════════════════════════════════

static int pass = 0, fail = 0;

#define CHECK(cond, msg)                                                                           \
  do {                                                                                             \
    if (!(cond)) {                                                                                 \
      fprintf(stderr, "FAIL: %s\n", msg);                                                          \
      fail++;                                                                                      \
    } else {                                                                                       \
      pass++;                                                                                      \
    }                                                                                              \
  } while (0)

void test_u8_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    uint8_t v = rand_u8();
    std::vector<uint8_t> buf;
    write_u8(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_u8(ps);
    CHECK(r.has_value() && *r == v, "u8 roundtrip");
    CHECK(ps.pos == buf.size(), "u8 consumption");
  }
}

void test_u32le_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    uint32_t v = rand_u32();
    std::vector<uint8_t> buf;
    write_u32le(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_u32le(ps);
    CHECK(r.has_value() && *r == v, "u32le roundtrip");
    CHECK(ps.pos == 4, "u32le consumption");
  }
}

void test_u64le_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    uint64_t v = rand_u64();
    std::vector<uint8_t> buf;
    write_u64le(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_u64le(ps);
    CHECK(r.has_value() && *r == v, "u64le roundtrip");
    CHECK(ps.pos == 8, "u64le consumption");
  }
}

void test_u32be_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    uint32_t v = rand_u32();
    std::vector<uint8_t> buf;
    write_u32be(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_u32be(ps);
    CHECK(r.has_value() && *r == v, "u32be roundtrip");
    CHECK(ps.pos == 4, "u32be consumption");
  }
}

void test_bool64_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    bool v = rand_bool();
    std::vector<uint8_t> buf;
    write_bool64(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_bool64(ps);
    CHECK(r.has_value() && *r == v, "bool64 roundtrip");
  }
}

void test_varint_roundtrip() {
  // Specific edge cases
  uint64_t edges[] = {
      0, 1, 127, 128, 16383, 16384, 2097151, 2097152, 268435455, 0xFFFFFFFF, 0xFFFFFFFFFFFFFFFFULL};
  for (auto v : edges) {
    std::vector<uint8_t> buf;
    write_varint(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_varint(ps);
    CHECK(r.has_value() && *r == v, "varint edge roundtrip");
    CHECK(ps.pos == buf.size(), "varint edge consumption");
  }
  // Random
  for (int i = 0; i < 10000; i++) {
    uint64_t v = rand_u64();
    std::vector<uint8_t> buf;
    write_varint(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_varint(ps);
    CHECK(r.has_value() && *r == v, "varint random roundtrip");
    CHECK(ps.pos == buf.size(), "varint random consumption");
  }
}

void test_len_prefixed_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    auto v = rand_bytes(512);
    std::vector<uint8_t> buf;
    write_len_prefixed(buf, v);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_len_prefixed(ps);
    CHECK(r.has_value() && *r == v, "len_prefixed roundtrip");
    CHECK(ps.pos == buf.size(), "len_prefixed consumption");
  }
}

void test_fixed_bytes_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    // Test 20-byte (SHA-1) and 32-byte (SHA-256) fixed arrays
    for (size_t n : {4, 20, 32}) {
      std::vector<uint8_t> v(n);
      for (auto& b : v)
        b = rand_u8();
      std::vector<uint8_t> buf;
      write_bytes(buf, v);
      ParseState ps{buf.data(), buf.size()};
      auto r = read_bytes(ps, n);
      CHECK(r.has_value() && *r == v, "fixed bytes roundtrip");
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRUCT ROUNDTRIP TESTS (matching generated codec specs)
// ═══════════════════════════════════════════════════════════════════════════════

// Nix: ServerHello = {magic: u64le, protocolVersion: u64le}
void test_server_hello_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    uint64_t magic = rand_u64(), ver = rand_u64();
    std::vector<uint8_t> buf;
    write_u64le(buf, magic);
    write_u64le(buf, ver);
    ParseState ps{buf.data(), buf.size()};
    auto m = read_u64le(ps);
    auto v = read_u64le(ps);
    CHECK(m && v && *m == magic && *v == ver, "ServerHello roundtrip");
    CHECK(ps.pos == 16, "ServerHello consumption");
  }
}

// Git: PackHeader = {version: u32be, objectCount: u32be}
void test_pack_header_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    uint32_t ver = rand_u32(), cnt = rand_u32();
    std::vector<uint8_t> buf;
    write_u32be(buf, ver);
    write_u32be(buf, cnt);
    ParseState ps{buf.data(), buf.size()};
    auto v = read_u32be(ps);
    auto c = read_u32be(ps);
    CHECK(v && c && *v == ver && *c == cnt, "PackHeader roundtrip");
    CHECK(ps.pos == 8, "PackHeader consumption");
  }
}

// EVM: AttestCalldata = {selector: 4, contentHash: 32, signerIdentity: 32,
//                        issuedAt: 32, expiresAt: 32, vouchChainRoot: 32}
void test_attest_calldata_roundtrip() {
  for (int i = 0; i < 100; i++) {
    std::vector<uint8_t> sel(4), ch(32), si(32), ia(32), ea(32), vcr(32);
    for (auto* v : {&sel, &ch, &si, &ia, &ea, &vcr})
      for (auto& b : *v)
        b = rand_u8();
    std::vector<uint8_t> buf;
    write_bytes(buf, sel);
    write_bytes(buf, ch);
    write_bytes(buf, si);
    write_bytes(buf, ia);
    write_bytes(buf, ea);
    write_bytes(buf, vcr);
    CHECK(buf.size() == 164, "AttestCalldata size");
    ParseState ps{buf.data(), buf.size()};
    auto r_sel = read_bytes(ps, 4);
    auto r_ch = read_bytes(ps, 32);
    auto r_si = read_bytes(ps, 32);
    auto r_ia = read_bytes(ps, 32);
    auto r_ea = read_bytes(ps, 32);
    auto r_vcr = read_bytes(ps, 32);
    CHECK(r_sel && r_ch && r_si && r_ia && r_ea && r_vcr, "AttestCalldata parse");
    CHECK(*r_sel == sel && *r_ch == ch && *r_si == si, "AttestCalldata fields 1-3");
    CHECK(*r_ia == ia && *r_ea == ea && *r_vcr == vcr, "AttestCalldata fields 4-6");
    CHECK(ps.pos == 164, "AttestCalldata consumption");
  }
}

// NixString: LenPrefixed = {data: len_prefixed}
void test_nix_string_roundtrip() {
  for (int i = 0; i < 1000; i++) {
    auto data = rand_bytes(512);
    std::vector<uint8_t> buf;
    write_len_prefixed(buf, data);
    ParseState ps{buf.data(), buf.size()};
    auto r = read_len_prefixed(ps);
    CHECK(r.has_value() && *r == data, "NixString roundtrip");
    CHECK(ps.pos == buf.size(), "NixString consumption");
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUZZ: feed random bytes to parsers, ensure no crashes
// ═══════════════════════════════════════════════════════════════════════════════

void fuzz_parsers() {
  for (int i = 0; i < 100000; i++) {
    auto garbage = rand_bytes(64);
    ParseState ps{garbage.data(), garbage.size()};

    // These should all either return a value or nullopt, never crash
    read_u8(ps);
    ps.pos = 0;
    read_u16le(ps);
    ps.pos = 0;
    read_u32le(ps);
    ps.pos = 0;
    read_u64le(ps);
    ps.pos = 0;
    read_u32be(ps);
    ps.pos = 0;
    read_u64be(ps);
    ps.pos = 0;
    read_bool64(ps);
    ps.pos = 0;
    read_varint(ps);
    ps.pos = 0;
    read_len_prefixed(ps);
    ps.pos = 0;
    read_bytes(ps, 20);
  }
  pass += 100000;
}

// ═══════════════════════════════════════════════════════════════════════════════
// VARINT ENCODING SIZE PROPERTY
// ═══════════════════════════════════════════════════════════════════════════════

void test_varint_encoding_size() {
  // Values < 128 should encode as 1 byte
  for (uint64_t v = 0; v < 128; v++) {
    std::vector<uint8_t> buf;
    write_varint(buf, v);
    CHECK(buf.size() == 1, "varint < 128 is 1 byte");
  }
  // Values 128..16383 should encode as 2 bytes
  for (int i = 0; i < 1000; i++) {
    uint64_t v = 128 + (rng() % (16384 - 128));
    std::vector<uint8_t> buf;
    write_varint(buf, v);
    CHECK(buf.size() == 2, "varint 128..16383 is 2 bytes");
  }
  // Max u64 should encode as 10 bytes
  {
    std::vector<uint8_t> buf;
    write_varint(buf, UINT64_MAX);
    CHECK(buf.size() == 10, "varint max is 10 bytes");
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSUMPTION: parse(serialize(x) ++ garbage) leaves garbage untouched
// ═══════════════════════════════════════════════════════════════════════════════

void test_consumption_property() {
  for (int i = 0; i < 1000; i++) {
    uint64_t v = rand_u64();
    auto garbage = rand_bytes(32);

    // u64le
    std::vector<uint8_t> buf;
    write_u64le(buf, v);
    size_t serialized_len = buf.size();
    buf.insert(buf.end(), garbage.begin(), garbage.end());
    ParseState ps{buf.data(), buf.size()};
    auto r = read_u64le(ps);
    CHECK(r && *r == v, "consumption: u64le value");
    CHECK(ps.pos == serialized_len, "consumption: u64le position");
    // Remaining bytes should be exactly garbage
    CHECK(ps.size - ps.pos == garbage.size(), "consumption: u64le remaining");

    // varint
    buf.clear();
    write_varint(buf, v);
    serialized_len = buf.size();
    buf.insert(buf.end(), garbage.begin(), garbage.end());
    ps = {buf.data(), buf.size()};
    r = read_varint(ps);
    CHECK(r && *r == v, "consumption: varint value");
    CHECK(ps.pos == serialized_len, "consumption: varint position");

    // len_prefixed
    auto data = rand_bytes(64);
    buf.clear();
    write_len_prefixed(buf, data);
    serialized_len = buf.size();
    buf.insert(buf.end(), garbage.begin(), garbage.end());
    ps = {buf.data(), buf.size()};
    auto rd = read_len_prefixed(ps);
    CHECK(rd && *rd == data, "consumption: len_prefixed value");
    CHECK(ps.pos == serialized_len, "consumption: len_prefixed position");
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

int main() {
  test_u8_roundtrip();
  test_u32le_roundtrip();
  test_u64le_roundtrip();
  test_u32be_roundtrip();
  test_bool64_roundtrip();
  test_varint_roundtrip();
  test_len_prefixed_roundtrip();
  test_fixed_bytes_roundtrip();
  test_varint_encoding_size();
  test_consumption_property();

  // Struct-level roundtrips
  test_server_hello_roundtrip();
  test_pack_header_roundtrip();
  test_attest_calldata_roundtrip();
  test_nix_string_roundtrip();

  // Fuzz
  fuzz_parsers();

  printf("\n%d passed, %d failed\n", pass, fail);
  return fail > 0 ? 1 : 0;
}
