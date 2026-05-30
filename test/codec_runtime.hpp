// codec_runtime.hpp — wire-type primitives for generated codecs
// Generated code calls these; hand-written, tested once.
#pragma once
#include <cstdint>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

namespace continuity {

struct ParseState {
  const uint8_t* data;
  size_t size;
  size_t pos = 0;

  bool has(size_t n) const { return pos + n <= size; }
  const uint8_t* cur() const { return data + pos; }
  void advance(size_t n) { pos += n; }
};

// ── readers ─────────────────────────────────────────────────────────────

inline std::optional<uint8_t> read_u8(ParseState& ps) {
  if (!ps.has(1))
    return std::nullopt;
  uint8_t v = ps.data[ps.pos++];
  return v;
}

inline std::optional<uint16_t> read_u16le(ParseState& ps) {
  if (!ps.has(2))
    return std::nullopt;
  uint16_t v;
  std::memcpy(&v, ps.cur(), 2);
  ps.advance(2);
  return v;
}

inline std::optional<uint32_t> read_u32le(ParseState& ps) {
  if (!ps.has(4))
    return std::nullopt;
  uint32_t v;
  std::memcpy(&v, ps.cur(), 4);
  ps.advance(4);
  return v;
}

inline std::optional<uint64_t> read_u64le(ParseState& ps) {
  if (!ps.has(8))
    return std::nullopt;
  uint64_t v;
  std::memcpy(&v, ps.cur(), 8);
  ps.advance(8);
  return v;
}

inline std::optional<uint32_t> read_u32be(ParseState& ps) {
  if (!ps.has(4))
    return std::nullopt;
  uint32_t v = (uint32_t(ps.data[ps.pos]) << 24) | (uint32_t(ps.data[ps.pos + 1]) << 16) |
               (uint32_t(ps.data[ps.pos + 2]) << 8) | ps.data[ps.pos + 3];
  ps.advance(4);
  return v;
}

inline std::optional<uint64_t> read_u64be(ParseState& ps) {
  if (!ps.has(8))
    return std::nullopt;
  uint64_t v = 0;
  for (int i = 0; i < 8; i++)
    v = (v << 8) | ps.data[ps.pos + i];
  ps.advance(8);
  return v;
}

inline std::optional<bool> read_bool64(ParseState& ps) {
  auto v = read_u64le(ps);
  if (!v)
    return std::nullopt;
  return *v != 0;
}

inline std::optional<uint64_t> read_varint(ParseState& ps) {
  uint64_t acc = 0;
  unsigned shift = 0;
  for (int i = 0; i < 10; i++) {
    if (!ps.has(1))
      return std::nullopt;
    uint8_t b = ps.data[ps.pos++];
    acc |= uint64_t(b & 0x7F) << shift;
    if ((b & 0x80) == 0)
      return acc;
    shift += 7;
  }
  return std::nullopt;
}

inline std::optional<std::vector<uint8_t>> read_bytes(ParseState& ps, size_t n) {
  if (!ps.has(n))
    return std::nullopt;
  std::vector<uint8_t> v(ps.cur(), ps.cur() + n);
  ps.advance(n);
  return v;
}

inline std::optional<std::vector<uint8_t>> read_len_prefixed(ParseState& ps) {
  auto len = read_u64le(ps);
  if (!len)
    return std::nullopt;
  return read_bytes(ps, *len);
}

// ── writers ─────────────────────────────────────────────────────────────

inline void write_u8(std::vector<uint8_t>& buf, uint8_t v) {
  buf.push_back(v);
}

inline void write_u16le(std::vector<uint8_t>& buf, uint16_t v) {
  buf.resize(buf.size() + 2);
  std::memcpy(buf.data() + buf.size() - 2, &v, 2);
}

inline void write_u32le(std::vector<uint8_t>& buf, uint32_t v) {
  buf.resize(buf.size() + 4);
  std::memcpy(buf.data() + buf.size() - 4, &v, 4);
}

inline void write_u64le(std::vector<uint8_t>& buf, uint64_t v) {
  buf.resize(buf.size() + 8);
  std::memcpy(buf.data() + buf.size() - 8, &v, 8);
}

inline void write_u32be(std::vector<uint8_t>& buf, uint32_t v) {
  buf.push_back((v >> 24) & 0xFF);
  buf.push_back((v >> 16) & 0xFF);
  buf.push_back((v >> 8) & 0xFF);
  buf.push_back(v & 0xFF);
}

inline void write_u64be(std::vector<uint8_t>& buf, uint64_t v) {
  for (int i = 7; i >= 0; i--)
    buf.push_back((v >> (i * 8)) & 0xFF);
}

inline void write_bool64(std::vector<uint8_t>& buf, bool v) {
  write_u64le(buf, v ? 1 : 0);
}

inline void write_varint(std::vector<uint8_t>& buf, uint64_t v) {
  while (v >= 128) {
    buf.push_back(uint8_t(v & 0x7F) | 0x80);
    v >>= 7;
  }
  buf.push_back(uint8_t(v));
}

inline void write_bytes(std::vector<uint8_t>& buf, const std::vector<uint8_t>& v) {
  buf.insert(buf.end(), v.begin(), v.end());
}

inline void write_bytes(std::vector<uint8_t>& buf, const uint8_t* v, size_t n) {
  buf.insert(buf.end(), v, v + n);
}

inline void write_len_prefixed(std::vector<uint8_t>& buf, const std::vector<uint8_t>& v) {
  write_u64le(buf, v.size());
  write_bytes(buf, v);
}

} // namespace continuity
