// golden.h - bit-exact reference of the FPGA matrix-vector engine (header-only, C99 / C++).
//
// Weights, "Q4H" format: every 128 inputs of a row share an fp16 scale s and fp16 offset lo, weight = q*s + lo
// with a 4-bit code q in 0..15. A row of K inputs (K a multiple of 128, NG = K/128 groups) is a sequence of
// 64-byte words:
//     SW = ceil(NG/16) scale words: group 16*w+i at bytes 4i..4i+3 = s (fp16 LE), lo (fp16 LE); unused slots 0
//     NG code words: group g, byte k = element 2k (low nibble) and element 2k+1 (high nibble)
// Activations, MXINT8: per 32 inputs ("subgroup") a power-of-two exponent e in [-64, 63] and int8 a in
// [-127, 127] with x ~= a * 2^e;  S = sum of the subgroup's a.
// Dot product of one row with one activation vector, exact:
//     for every subgroup i (4 per weight group g):  D_i = sum q*a  (integer)
//     acc += (m_s * D_i) << (E_s + e_i + ACC_FRAC)  +  (m_lo * S_i) << (E_lo + e_i + ACC_FRAC)
// where s = m_s * 2^E_s, lo = m_lo * 2^E_lo exactly (m signed 12-bit), << with a negative amount is an
// arithmetic right shift (floor), acc is a 64-bit integer in units of 2^-ACC_FRAC, and the output is
// y = float(acc) * 2^-ACC_FRAC with round-to-nearest-even (the only rounding).
#ifndef GOLDEN_H
#define GOLDEN_H

#include <math.h>
#include <stdint.h>
#include <string.h>

#define ACC_FRAC 30
#define WG 128                  // weights per weight group
#define AG 32                   // activations per MXINT8 subgroup
#define E_MIN (-64)
#define E_MAX 63

// MXINT8 quantization of x[0..n): a[n], e[n/32], S[n/32]
static inline void mx_quantize(const float *x, int n, int8_t *a, int8_t *e, int16_t *S) {
    for (int g = 0; g < n / AG; g++) {
        float amax = 0;
        for (int j = 0; j < AG; j++) amax = fmaxf(amax, fabsf(x[g * AG + j]));
        int ex = 0;                                       // all-zero subgroup: e = 0, a = 0
        if (amax > 0) {
            ex = (int)ceilf(log2f(amax / 127.0f));
            while (amax > ldexpf(127.0f, ex)) ex++;
            while (amax <= ldexpf(127.0f, ex - 1)) ex--;
            ex = ex < E_MIN ? E_MIN : ex > E_MAX ? E_MAX : ex;
        }
        int sum = 0;
        for (int j = 0; j < AG; j++) {
            long q = lrintf(ldexpf(x[g * AG + j], -ex));    // round half to even
            q = q > 127 ? 127 : q < -127 ? -127 : q;
            a[g * AG + j] = (int8_t)q; sum += (int)q;
        }
        e[g] = (int8_t)ex; S[g] = (int16_t)sum;
    }
}

// fp16 -> signed mantissa * 2^ex, exactly; returns 0 for inf/nan
static inline int h2me(uint16_t h, int32_t *m, int *ex) {
    int e = (h >> 10) & 31, f = h & 1023;
    if (e == 31) return 0;
    *m = e ? (f | 1024) : f;
    *ex = (e ? e : 1) - 25;
    if (h >> 15) *m = -*m;
    return 1;
}

// v * 2^sh: left shift (sets *ovf if the result leaves the int64 range), else floor right shift
static inline int64_t shl64(int64_t v, int sh, int *ovf) {
    if (sh >= 0) {
        if (v != 0 && (sh > 62 || (v < 0 ? -v : v) >= (INT64_C(1) << (62 - sh)))) { *ovf = 1; return 0; }
        return v * (INT64_C(1) << sh);
    }
    return sh <= -63 ? (v < 0 ? -1 : 0) : (v >> -sh);
}

static inline float acc_to_float(int64_t acc) { return ldexpf((float)acc, -ACC_FRAC); }

// One Q4H row (SW + NG 64-byte words) times one MXINT8 vector -> accumulator
static inline int64_t q4h_row_acc(const uint8_t *row, int K, const int8_t *a, const int8_t *e, const int16_t *S,
                                  int *ovf) {
    int ng = K / WG, sw = (ng + 15) / 16;
    int64_t acc = 0;
    for (int g = 0; g < ng; g++) {
        const uint8_t *sc = row + 64 * (g / 16) + 4 * (g % 16), *c = row + 64 * (sw + g);
        uint16_t s16 = (uint16_t)(sc[0] | sc[1] << 8), lo16 = (uint16_t)(sc[2] | sc[3] << 8);
        int32_t ms = 0, ml = 0; int es = 0, el = 0;
        if (!h2me(s16, &ms, &es) || !h2me(lo16, &ml, &el)) { *ovf = 1; continue; }
        for (int i = 0; i < WG / AG; i++) {
            int sg = g * (WG / AG) + i;
            int32_t d = 0;
            for (int j = 0; j < AG; j++) {
                int k = i * AG + j, q = (c[k / 2] >> (4 * (k & 1))) & 15;
                d += q * a[sg * AG + j];
            }
            acc += shl64((int64_t)ms * d, es + e[sg] + ACC_FRAC, ovf);
            acc += shl64((int64_t)ml * S[sg], el + e[sg] + ACC_FRAC, ovf);
        }
    }
    return acc;
}

// Quantize a [rows, K] float matrix to Q4H (asymmetric, scale/offset chosen against their fp16 values)
static inline uint16_t f2h(float f) {                     // round to nearest even, normal + subnormal range
    uint32_t u; memcpy(&u, &f, 4);
    uint32_t sign = (u >> 16) & 0x8000; float a = fabsf(f);
    if (a >= 65520.0f) return (uint16_t)(sign | 0x7c00);
    if (a < ldexpf(1.0f, -14)) return (uint16_t)(sign | (uint32_t)lrintf(ldexpf(a, 24)));
    int ex; float mnt = frexpf(a, &ex);                   // a = mnt * 2^ex, mnt in [0.5, 1)
    uint32_t m = (uint32_t)lrintf(ldexpf(mnt, 11));       // 11 bits incl. hidden, may round up to 2048
    if (m == 2048) { m = 1024; ex++; }
    return (uint16_t)(sign | (uint32_t)(ex + 14) << 10 | (m & 1023));
}
static inline float h2f_exact(uint16_t h) {
    int32_t m = 0; int ex = 0;
    if (!h2me(h, &m, &ex)) return (h >> 15) ? -INFINITY : INFINITY;
    return ldexpf((float)m, ex);
}

static inline void q4h_quantize_row(const float *w, int K, uint8_t *row) {
    int ng = K / WG, sw = (ng + 15) / 16;
    memset(row, 0, 64 * (size_t)(sw + ng));
    for (int g = 0; g < ng; g++) {
        float lo = w[g * WG], hi = lo;
        for (int j = 1; j < WG; j++) { lo = fminf(lo, w[g * WG + j]); hi = fmaxf(hi, w[g * WG + j]); }
        uint16_t s16 = f2h((hi - lo) / 15.0f), lo16 = f2h(lo);
        float s = h2f_exact(s16), l = h2f_exact(lo16);
        uint8_t *sc = row + 64 * (g / 16) + 4 * (g % 16), *c = row + 64 * (sw + g);
        sc[0] = s16 & 255; sc[1] = s16 >> 8; sc[2] = lo16 & 255; sc[3] = lo16 >> 8;
        for (int j = 0; j < WG; j++) {
            long q = s > 0 ? lrintf((w[g * WG + j] - l) / s) : 0;
            q = q < 0 ? 0 : q > 15 ? 15 : q;
            c[j / 2] |= (uint8_t)(q << (4 * (j & 1)));
        }
    }
}

#endif
