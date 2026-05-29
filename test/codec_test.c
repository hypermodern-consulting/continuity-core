/* codec_test.c — roundtrip property tests for wire format primitives
   Compile: gcc -O2 -o test/codec_test test/codec_test.c
   This tests the same operations the Lean proofs cover:
     roundtrip:   parse(serialize(x)) == x
     consumption: parse(serialize(x) ++ garbage) leaves garbage untouched */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ═══════ buffer ═══════ */

typedef struct { uint8_t *data; size_t len; size_t cap; } Buf;

static void buf_init(Buf *b) { b->data = malloc(4096); b->len = 0; b->cap = 4096; }
static void buf_free(Buf *b) { free(b->data); }
static void buf_clear(Buf *b) { b->len = 0; }

static void buf_push(Buf *b, const void *src, size_t n) {
  if (b->len + n > b->cap) {
    b->cap = (b->len + n) * 2;
    b->data = realloc(b->data, b->cap);
  }
  memcpy(b->data + b->len, src, n);
  b->len += n;
}

/* ═══════ parse state ═══════ */

typedef struct { const uint8_t *data; size_t len; size_t pos; } ParseState;

/* ═══════ writers ═══════ */

static void w_u8(Buf *b, uint8_t v)   { buf_push(b, &v, 1); }
static void w_u32le(Buf *b, uint32_t v){ buf_push(b, &v, 4); }
static void w_u64le(Buf *b, uint64_t v){ buf_push(b, &v, 8); }

static void w_u32be(Buf *b, uint32_t v) {
  uint8_t t[4] = {v>>24, v>>16, v>>8, v};
  buf_push(b, t, 4);
}

static void w_bool64(Buf *b, int v) { uint64_t x = v ? 1 : 0; w_u64le(b, x); }

static void w_varint(Buf *b, uint64_t v) {
  while (v >= 128) { w_u8(b, (uint8_t)(v & 0x7F) | 0x80); v >>= 7; }
  w_u8(b, (uint8_t)v);
}

static void w_bytes(Buf *b, const uint8_t *src, size_t n) { buf_push(b, src, n); }

static void w_len_prefixed(Buf *b, const uint8_t *src, size_t n) {
  w_u64le(b, (uint64_t)n);
  w_bytes(b, src, n);
}

/* ═══════ readers ═══════ */

static int r_u8(ParseState *ps, uint8_t *out) {
  if (ps->pos + 1 > ps->len) return 0;
  *out = ps->data[ps->pos++];
  return 1;
}

static int r_u32le(ParseState *ps, uint32_t *out) {
  if (ps->pos + 4 > ps->len) return 0;
  memcpy(out, ps->data + ps->pos, 4); ps->pos += 4;
  return 1;
}

static int r_u64le(ParseState *ps, uint64_t *out) {
  if (ps->pos + 8 > ps->len) return 0;
  memcpy(out, ps->data + ps->pos, 8); ps->pos += 8;
  return 1;
}

static int r_u32be(ParseState *ps, uint32_t *out) {
  if (ps->pos + 4 > ps->len) return 0;
  const uint8_t *p = ps->data + ps->pos;
  *out = ((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];
  ps->pos += 4;
  return 1;
}

static int r_bool64(ParseState *ps, int *out) {
  uint64_t v;
  if (!r_u64le(ps, &v)) return 0;
  *out = v != 0;
  return 1;
}

static int r_varint(ParseState *ps, uint64_t *out) {
  uint64_t acc = 0; unsigned shift = 0;
  for (int i = 0; i < 10; i++) {
    if (ps->pos >= ps->len) return 0;
    uint8_t b = ps->data[ps->pos++];
    acc |= (uint64_t)(b & 0x7F) << shift;
    if ((b & 0x80) == 0) { *out = acc; return 1; }
    shift += 7;
  }
  return 0;
}

static int r_bytes(ParseState *ps, uint8_t *out, size_t n) {
  if (ps->pos + n > ps->len) return 0;
  memcpy(out, ps->data + ps->pos, n); ps->pos += n;
  return 1;
}

static int r_len_prefixed(ParseState *ps, uint8_t *out, size_t *out_len, size_t max) {
  uint64_t len;
  if (!r_u64le(ps, &len)) return 0;
  if (len > max || ps->pos + len > ps->len) return 0;
  memcpy(out, ps->data + ps->pos, (size_t)len);
  *out_len = (size_t)len;
  ps->pos += (size_t)len;
  return 1;
}

/* ═══════ xoshiro256** PRNG ═══════ */

static uint64_t s[4] = {0x12345678, 0xdeadbeef, 0xcafebabe, 0x0badf00d};

static inline uint64_t rotl(uint64_t x, int k) { return (x << k) | (x >> (64 - k)); }

static uint64_t xrand(void) {
  uint64_t result = rotl(s[1] * 5, 7) * 9;
  uint64_t t = s[1] << 17;
  s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3];
  s[2] ^= t; s[3] = rotl(s[3], 45);
  return result;
}

static uint8_t  xrand_u8(void)  { return (uint8_t)xrand(); }
static uint32_t xrand_u32(void) { return (uint32_t)xrand(); }
static uint64_t xrand_u64(void) { return xrand(); }

/* ═══════ test harness ═══════ */

static int pass = 0, fail_count = 0;

#define N_ITER 10000

#define CHECK(cond, msg) do { \
  if (!(cond)) { fprintf(stderr, "  FAIL: %s\n", msg); fail_count++; } \
  else { pass++; } \
} while(0)

/* ═══════ primitive roundtrip tests ═══════ */

static void test_u8(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < N_ITER; i++) {
    uint8_t v = xrand_u8(), out;
    buf_clear(&b); w_u8(&b, v);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_u8(&ps, &out) && out == v, "u8 roundtrip");
    CHECK(ps.pos == b.len, "u8 consumption");
  }
  buf_free(&b);
}

static void test_u32le(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < N_ITER; i++) {
    uint32_t v = xrand_u32(), out;
    buf_clear(&b); w_u32le(&b, v);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_u32le(&ps, &out) && out == v, "u32le roundtrip");
  }
  buf_free(&b);
}

static void test_u64le(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < N_ITER; i++) {
    uint64_t v = xrand_u64(), out;
    buf_clear(&b); w_u64le(&b, v);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_u64le(&ps, &out) && out == v, "u64le roundtrip");
  }
  buf_free(&b);
}

static void test_u32be(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < N_ITER; i++) {
    uint32_t v = xrand_u32(), out;
    buf_clear(&b); w_u32be(&b, v);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_u32be(&ps, &out) && out == v, "u32be roundtrip");
  }
  buf_free(&b);
}

static void test_bool64(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < N_ITER; i++) {
    int v = xrand() & 1, out;
    buf_clear(&b); w_bool64(&b, v);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_bool64(&ps, &out) && out == v, "bool64 roundtrip");
  }
  buf_free(&b);
}

static void test_varint(void) {
  Buf b; buf_init(&b);
  /* Edge cases */
  uint64_t edges[] = {0,1,127,128,16383,16384,2097151,268435455,
                      0xFFFFFFFF,0xFFFFFFFFFFFFFFFFULL};
  for (int i = 0; i < 10; i++) {
    uint64_t v = edges[i], out;
    buf_clear(&b); w_varint(&b, v);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_varint(&ps, &out) && out == v, "varint edge");
    CHECK(ps.pos == b.len, "varint edge consumption");
  }
  /* Random */
  for (int i = 0; i < N_ITER; i++) {
    uint64_t v = xrand_u64(), out;
    buf_clear(&b); w_varint(&b, v);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_varint(&ps, &out) && out == v, "varint random");
    CHECK(ps.pos == b.len, "varint random consumption");
  }
  buf_free(&b);
}

static void test_len_prefixed(void) {
  Buf b; buf_init(&b);
  uint8_t payload[512], out[512];
  for (int i = 0; i < N_ITER; i++) {
    size_t n = xrand() % 256;
    for (size_t j = 0; j < n; j++) payload[j] = xrand_u8();
    buf_clear(&b); w_len_prefixed(&b, payload, n);
    ParseState ps = {b.data, b.len, 0};
    size_t out_len;
    CHECK(r_len_prefixed(&ps, out, &out_len, 512), "len_prefixed parse");
    CHECK(out_len == n && memcmp(out, payload, n) == 0, "len_prefixed roundtrip");
    CHECK(ps.pos == b.len, "len_prefixed consumption");
  }
  buf_free(&b);
}

/* ═══════ consumption property: parse(serialize(x) ++ garbage) ═══════ */

static void test_consumption(void) {
  Buf b; buf_init(&b);
  uint8_t garbage[32];
  for (int i = 0; i < N_ITER; i++) {
    for (int j = 0; j < 32; j++) garbage[j] = xrand_u8();
    /* u64le */
    uint64_t v = xrand_u64(), out64;
    buf_clear(&b); w_u64le(&b, v);
    size_t slen = b.len;
    buf_push(&b, garbage, 32);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_u64le(&ps, &out64) && out64 == v, "consumption u64le value");
    CHECK(ps.pos == slen, "consumption u64le pos");
    CHECK(b.len - ps.pos == 32, "consumption u64le remaining");

    /* varint */
    buf_clear(&b); w_varint(&b, v);
    slen = b.len;
    buf_push(&b, garbage, 32);
    ps = (ParseState){b.data, b.len, 0};
    CHECK(r_varint(&ps, &out64) && out64 == v, "consumption varint value");
    CHECK(ps.pos == slen, "consumption varint pos");
  }
  buf_free(&b);
}

/* ═══════ varint encoding size property ═══════ */

static void test_varint_size(void) {
  Buf b; buf_init(&b);
  for (uint64_t v = 0; v < 128; v++) {
    buf_clear(&b); w_varint(&b, v);
    CHECK(b.len == 1, "varint <128 = 1 byte");
  }
  for (int i = 0; i < 1000; i++) {
    uint64_t v = 128 + (xrand() % (16384 - 128));
    buf_clear(&b); w_varint(&b, v);
    CHECK(b.len == 2, "varint 128..16383 = 2 bytes");
  }
  buf_clear(&b); w_varint(&b, UINT64_MAX);
  CHECK(b.len == 10, "varint max = 10 bytes");
  buf_free(&b);
}

/* ═══════ struct-level roundtrips ═══════ */

static void test_server_hello(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < N_ITER; i++) {
    uint64_t magic = xrand_u64(), ver = xrand_u64();
    uint64_t om, ov;
    buf_clear(&b); w_u64le(&b, magic); w_u64le(&b, ver);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_u64le(&ps, &om) && r_u64le(&ps, &ov), "ServerHello parse");
    CHECK(om == magic && ov == ver, "ServerHello roundtrip");
    CHECK(ps.pos == 16, "ServerHello consumption");
  }
  buf_free(&b);
}

static void test_pack_header(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < N_ITER; i++) {
    uint32_t ver = xrand_u32(), cnt = xrand_u32();
    uint32_t ov, oc;
    buf_clear(&b); w_u32be(&b, ver); w_u32be(&b, cnt);
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_u32be(&ps, &ov) && r_u32be(&ps, &oc), "PackHeader parse");
    CHECK(ov == ver && oc == cnt, "PackHeader roundtrip");
    CHECK(ps.pos == 8, "PackHeader consumption");
  }
  buf_free(&b);
}

static void test_attest_calldata(void) {
  Buf b; buf_init(&b);
  for (int i = 0; i < 1000; i++) {
    uint8_t sel[4], ch[32], si[32], ia[32], ea[32], vcr[32];
    uint8_t o_sel[4], o_ch[32], o_si[32], o_ia[32], o_ea[32], o_vcr[32];
    for (int j=0;j<4;j++) sel[j]=xrand_u8();
    for (int j=0;j<32;j++) { ch[j]=xrand_u8(); si[j]=xrand_u8(); ia[j]=xrand_u8();
                              ea[j]=xrand_u8(); vcr[j]=xrand_u8(); }
    buf_clear(&b);
    w_bytes(&b,sel,4); w_bytes(&b,ch,32); w_bytes(&b,si,32);
    w_bytes(&b,ia,32); w_bytes(&b,ea,32); w_bytes(&b,vcr,32);
    CHECK(b.len == 164, "AttestCalldata size");
    ParseState ps = {b.data, b.len, 0};
    CHECK(r_bytes(&ps,o_sel,4) && r_bytes(&ps,o_ch,32) && r_bytes(&ps,o_si,32) &&
          r_bytes(&ps,o_ia,32) && r_bytes(&ps,o_ea,32) && r_bytes(&ps,o_vcr,32),
          "AttestCalldata parse");
    CHECK(memcmp(sel,o_sel,4)==0 && memcmp(ch,o_ch,32)==0 && memcmp(si,o_si,32)==0,
          "AttestCalldata fields 1-3");
    CHECK(memcmp(ia,o_ia,32)==0 && memcmp(ea,o_ea,32)==0 && memcmp(vcr,o_vcr,32)==0,
          "AttestCalldata fields 4-6");
    CHECK(ps.pos == 164, "AttestCalldata consumption");
  }
  buf_free(&b);
}

/* ═══════ fuzz: random bytes into parsers, no crashes ═══════ */

static void test_fuzz(void) {
  uint8_t garbage[64]; uint64_t out64; uint32_t out32; uint8_t out8; int outb;
  uint8_t outbuf[512]; size_t outlen;
  for (int i = 0; i < 100000; i++) {
    size_t glen = xrand() % 64;
    for (size_t j = 0; j < glen; j++) garbage[j] = xrand_u8();
    ParseState ps = {garbage, glen, 0};
    r_u8(&ps, &out8);
    ps.pos=0; r_u32le(&ps, &out32);
    ps.pos=0; r_u64le(&ps, &out64);
    ps.pos=0; r_u32be(&ps, &out32);
    ps.pos=0; r_bool64(&ps, &outb);
    ps.pos=0; r_varint(&ps, &out64);
    ps.pos=0; r_len_prefixed(&ps, outbuf, &outlen, 512);
    ps.pos=0; r_bytes(&ps, outbuf, 20);
  }
  pass += 100000;
}

int main(void) {
  printf("Running codec property tests...\n");
  test_u8();       printf("  u8:             %d\n", pass);
  test_u32le();    printf("  u32le:          %d\n", pass);
  test_u64le();    printf("  u64le:          %d\n", pass);
  test_u32be();    printf("  u32be:          %d\n", pass);
  test_bool64();   printf("  bool64:         %d\n", pass);
  test_varint();   printf("  varint:         %d\n", pass);
  test_len_prefixed(); printf("  len_prefixed:   %d\n", pass);
  test_varint_size();  printf("  varint_size:    %d\n", pass);
  test_consumption();  printf("  consumption:    %d\n", pass);
  test_server_hello(); printf("  ServerHello:    %d\n", pass);
  test_pack_header();  printf("  PackHeader:     %d\n", pass);
  test_attest_calldata(); printf("  AttestCalldata: %d\n", pass);
  test_fuzz();     printf("  fuzz:           %d\n", pass);
  printf("\n%d passed, %d failed\n", pass, fail_count);
  return fail_count > 0 ? 1 : 0;
}
