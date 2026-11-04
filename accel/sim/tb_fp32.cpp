// tb_fp32.cpp - Verilator test of accel/rtl/fp32.v: fp_mul and fp_add against the PC's own float32 multiply/add
// (IEEE, round to nearest even) on random operands: random exponents, close exponents (cancellation), b = -a,
// rounding ties. Results whose magnitude is below 2^-125 are not compared (the units flush subnormals to zero).
//   tb_fp32 [n_million] [seed]
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>

#include "Vtb_fp32_top.h"
#include "verilated.h"

static float f(uint32_t u) { float x; memcpy(&x, &u, 4); return x; }
static uint32_t u(float x) { uint32_t v; memcpy(&v, &x, 4); return v; }

int main(int argc, char **argv) {
    long n = (argc > 1 ? atol(argv[1]) : 10) * 1000000L;
    std::mt19937_64 rng(argc > 2 ? atol(argv[2]) : 1);
    auto *dut = new Vtb_fp32_top;
    const int LM = 3, LA = 5, L = 8;
    uint32_t qa[L] = {0}, qb[L] = {0};
    long bad_m = 0, bad_a = 0, cmp_m = 0, cmp_a = 0;
    for (long t = 0; t < n + L; t++) {
        uint64_t r = rng();
        uint32_t a = (uint32_t)r, b = (uint32_t)(r >> 32);
        int kind = rng() % 8;
        uint32_t ea = 1 + rng() % 254;
        a = (a & 0x807FFFFF) | ea << 23;
        if (kind < 3) {                                      // b's exponent close to a's
            int eb = (int)ea + (int)(rng() % 7) - 3;
            eb = eb < 1 ? 1 : eb > 254 ? 254 : eb;
            b = (b & 0x807FFFFF) | (uint32_t)eb << 23;
        } else if (kind == 3) {
            b = a ^ 0x80000000;                              // exact cancellation
        } else if (kind == 4) {
            b = (a & 0xFFFFFF00) | (b & 0x800000FF);        // nearly equal: deep cancellation
            b = (b & 0x7FFFFFFF) | ((rng() & 1) << 31);
        } else if (kind == 5) {
            b = (b & 0x807FFFFF) | (uint32_t)(1 + rng() % 254) << 23;
            if (rng() % 4 == 0) b &= 0x80000000;            // zeros
        } else {
            int eb = 1 + (int)(rng() % 254);
            b = (b & 0x807FFFFF) | (uint32_t)eb << 23;
        }
        if (rng() % 64 == 0) a &= 0x80000000;               // +-0
        dut->a = a; dut->b = b;
        dut->clk = 0; dut->eval(); dut->clk = 1; dut->eval();
        for (int i = L - 1; i > 0; i--) { qa[i] = qa[i - 1]; qb[i] = qb[i - 1]; }
        qa[0] = a; qb[0] = b;
        if (t >= L) {
            // after the edge: output registers hold the result of the operands applied LM (LA) edges ago
            uint32_t ma = qa[LM - 1], mb = qb[LM - 1];
            float rp = f(ma) * f(mb);
            if (std::isinf(rp) || std::fabs(rp) >= 0x1p-125f || rp == 0.0f) {
                uint32_t want = u(rp);
                if (rp == 0.0f) want = (ma ^ mb) & 0x80000000;  // exact zero product (a or b zero)
                cmp_m++;
                if (dut->p != want && bad_m++ < 5)
                    printf("mul %08x * %08x = %08x, want %08x\n", ma, mb, dut->p, want);
            }
            uint32_t aa = qa[LA - 1], ab = qb[LA - 1];
            float rs = f(aa) + f(ab);
            if (std::isinf(rs) || std::fabs(rs) >= 0x1p-125f || rs == 0.0f) {
                cmp_a++;
                if (dut->s != u(rs) && bad_a++ < 5)
                    printf("add %08x + %08x = %08x, want %08x\n", aa, ab, dut->s, u(rs));
            }
        }
    }
    printf("fp_mul: %ld compared, %ld wrong   fp_add: %ld compared, %ld wrong -> %s\n", cmp_m, bad_m, cmp_a, bad_a,
           bad_m || bad_a ? "FAIL" : "PASS");
    delete dut;
    return bad_m || bad_a;
}
