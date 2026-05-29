#pragma once
#include <stddef.h>
#include <stdint.h>

static inline int encode_varint(uint64_t v, uint8_t* buf, size_t cap) {
  int i = 0;
  while (v >= 128 && i < (int)cap - 1) {
    buf[i++] = (uint8_t)(v & 0x7F) | 0x80;
    v >>= 7;
  }
  if (i < (int)cap) {
    buf[i++] = (uint8_t)v;
    return i;
  }
  return -1;
}

static inline int decode_varint(const uint8_t* buf, size_t len, uint64_t* out) {
  uint64_t acc = 0;
  int shift = 0;
  for (int i = 0; i < 10 && i < (int)len; i++) {
    acc |= (uint64_t)(buf[i] & 0x7F) << shift;
    if ((buf[i] & 0x80) == 0) {
      *out = acc;
      return i + 1;
    }
    shift += 7;
  }
  return -1;
}
