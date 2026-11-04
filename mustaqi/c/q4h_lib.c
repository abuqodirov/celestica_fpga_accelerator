// q4h_lib.c - the FPGA matvec engine's arithmetic (accel/golden/golden.h) as a shared library for fpga_chat.py:
// the exact MXINT8 activation quantizer the engines expect, the engines' activation-buffer image, and a CPU
// reference matvec (bit-exact with the hardware) used by --check and --backend cpu.
// build: gcc -O3 -march=native -fopenmp -shared -fPIC -I../../accel/golden q4h_lib.c -o q4h_lib.so
#include <stdint.h>
#include <string.h>

#include "golden.h"

// x[K] -> a[K], e[K/32], S[K/32] and the engine's activation image: K/4 words of a, then K/32 words {e<<16 | S}
void q4h_quantize(const float *x, int K, int8_t *a, int8_t *e, int16_t *S, uint32_t *img) {
    mx_quantize(x, K, a, e, S);
    for (int i = 0; i < K / 4; i++)
        img[i] = (uint8_t)a[4 * i] | (uint8_t)a[4 * i + 1] << 8 | (uint8_t)a[4 * i + 2] << 16 |
                 (uint32_t)(uint8_t)a[4 * i + 3] << 24;
    for (int g = 0; g < K / AG; g++) img[K / 4 + g] = (uint32_t)(uint8_t)e[g] << 16 | (uint16_t)S[g];
}

// y[r] (float32 bits) for rows 0..rows-1 of a Q4H matrix at w; returns 1 if the accumulator overflowed
int q4h_mv(const uint8_t *w, int rows, int K, const int8_t *a, const int8_t *e, const int16_t *S, float *y) {
    int ng = K / WG, rw = (ng + 15) / 16 + ng, any = 0;
#pragma omp parallel for schedule(static) reduction(| : any)
    for (int r = 0; r < rows; r++) {
        int ovf = 0;
        y[r] = acc_to_float(q4h_row_acc(w + (size_t)r * rw * 64, K, a, e, S, &ovf));
        any |= ovf;
    }
    return any;
}
