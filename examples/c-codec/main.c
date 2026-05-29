#include "varint.h"
#include <stdio.h>
#include <string.h>

int main(void) {
    uint8_t buf[16];
    uint64_t values[] = {0, 1, 127, 128, 16383, 300, 0xFFFFFFFF, 0xFFFFFFFFFFFFFFFFULL};
    int n = sizeof(values)/sizeof(values[0]);

    printf("Varint roundtrip tests:\n");
    int pass = 0;
    for (int i = 0; i < n; i++) {
        int len = encode_varint(values[i], buf, sizeof(buf));
        uint64_t decoded;
        int dlen = decode_varint(buf, len, &decoded);
        if (dlen == len && decoded == values[i]) {
            pass++;
        } else {
            printf("  FAIL: %llu\n", (unsigned long long)values[i]);
        }
    }
    printf("  %d/%d passed\n", pass, n);
    return pass == n ? 0 : 1;
}
