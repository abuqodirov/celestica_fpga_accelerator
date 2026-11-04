// q4h_tool.c - prepare a hardware matvec test with the golden model (golden.h), so the board gets exactly the bits
// the Verilator testbench verified.
//   q4h_tool <K> <rows> <w.f32> <x.f32> <out_prefix> [nvec]      (x.f32 holds nvec vectors of K floats)
// writes  <out>.q4h  DRAM image: rows x (ceil(K/2048) scale words + K/128 code words) x 64 bytes
//         <out>.act  per vector: engine activation buffer image, K/4 words of a (little endian) then K/32 words
//                    {e<<16 | S}
//         <out>.exp  golden float32 results, row-major [rows][nvec]
#include <stdio.h>
#include <stdlib.h>

#include "golden.h"

static void *slurp(const char *path, size_t n) {
    void *p = malloc(n);
    FILE *f = fopen(path, "rb");
    if (!f || fread(p, 1, n, f) != n) { fprintf(stderr, "cannot read %zu bytes from %s\n", n, path); exit(1); }
    fclose(f);
    return p;
}

static void spit(const char *prefix, const char *ext, const void *p, size_t n) {
    char path[1024];
    snprintf(path, sizeof path, "%s%s", prefix, ext);
    FILE *f = fopen(path, "wb");
    if (!f || fwrite(p, 1, n, f) != n) { perror(path); exit(1); }
    fclose(f);
}

int main(int argc, char **argv) {
    if (argc != 6 && argc != 7) { fprintf(stderr, "usage: %s K rows w.f32 x.f32 out_prefix [nvec]\n", argv[0]); return 1; }
    int K = atoi(argv[1]), rows = atoi(argv[2]), nv = argc == 7 ? atoi(argv[6]) : 1;
    if (K % WG) { fprintf(stderr, "K must be a multiple of %d\n", WG); return 1; }
    int ng = K / WG, rw = (ng + 15) / 16 + ng;
    float *w = slurp(argv[3], (size_t)rows * K * 4), *x = slurp(argv[4], (size_t)nv * K * 4);
    uint8_t *img = malloc((size_t)rows * rw * 64);
    for (int r = 0; r < rows; r++) q4h_quantize_row(w + (size_t)r * K, K, img + (size_t)r * rw * 64);
    int aw = K / 4 + K / AG;                              // activation image words per vector
    uint32_t *act = malloc((size_t)nv * aw * 4);
    float *y = malloc((size_t)rows * nv * 4);
    int8_t *a = malloc(K), *e = malloc(K / AG);
    int16_t *S = malloc(K / AG * 2);
    int ovf = 0;
    for (int v = 0; v < nv; v++) {
        mx_quantize(x + (size_t)v * K, K, a, e, S);
        uint32_t *im = act + (size_t)v * aw;
        for (int i = 0; i < K / 4; i++)
            im[i] = (uint8_t)a[4*i] | (uint8_t)a[4*i+1] << 8 | (uint8_t)a[4*i+2] << 16 | (uint32_t)(uint8_t)a[4*i+3] << 24;
        for (int g = 0; g < K / AG; g++) im[K / 4 + g] = (uint32_t)(uint8_t)e[g] << 16 | (uint16_t)S[g];
        for (int r = 0; r < rows; r++)
            y[(size_t)r * nv + v] = acc_to_float(q4h_row_acc(img + (size_t)r * rw * 64, K, a, e, S, &ovf));
    }
    spit(argv[5], ".q4h", img, (size_t)rows * rw * 64);
    spit(argv[5], ".act", act, (size_t)nv * aw * 4);
    spit(argv[5], ".exp", y, (size_t)rows * nv * 4);
    printf("K %d, %d rows, %d vectors: %zu bytes of weights, %d words/row, golden overflow %d\n", K, rows, nv,
           (size_t)rows * rw * 64, rw, ovf);
    return 0;
}
