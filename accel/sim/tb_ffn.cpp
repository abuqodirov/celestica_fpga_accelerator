// tb_ffn.cpp - Verilator testbench: accel/rtl/ffn_unit.v against its bit-exact spec (vectors from
// mustaqi/ffn_vectors.py: gate/up rows -> the activation image silu_mul_hw + golden MXINT8 quantization give;
// tb_silu.cpp checks the float32 h of every row directly).
// The two result streams are fed like two engines: independent random gaps (mean row period `period` clocks,
// sometimes back-to-back), one stream starting later than the other. Every activation word the unit writes must
// arrive exactly once with the expected value, busy must fall, err must stay 0.
//   tb_ffn <vectors.bin> [period] [seed]
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>

#include "Vffn_unit.h"
#include "verilated.h"

static Vffn_unit *dut;
static void tick() { dut->clk = 0; dut->eval(); dut->clk = 1; dut->eval(); }

int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 2; }
    int period = argc > 2 ? atoi(argv[2]) : 8;
    std::mt19937 rng(argc > 3 ? atoi(argv[3]) : 1);
    int ncases;
    if (fread(&ncases, 4, 1, f) != 1) return 2;
    dut = new Vffn_unit;
    dut->rst = 1; dut->arm = 0; dut->g_valid = 0; dut->u_valid = 0;
    for (int i = 0; i < 4; i++) tick();
    dut->rst = 0;
    long bad = 0, words = 0, cycles = 0;
    for (int c = 0; c < ncases; c++) {
        int n;
        if (fread(&n, 4, 1, f) != 1) return 2;
        int na = n / 4, ns = n / 32;
        std::vector<uint32_t> g(n), u(n), h(n), want(na + ns), got(na + ns, 0xDEADBEEF);
        std::vector<int> hits(na + ns, 0);
        if (fread(g.data(), 4, n, f) != (size_t)n || fread(u.data(), 4, n, f) != (size_t)n ||
            fread(h.data(), 4, n, f) != (size_t)n || fread(want.data(), 4, na + ns, f) != (size_t)(na + ns)) return 2;
        dut->nrows = n; dut->arm = 1; tick(); dut->arm = 0;
        int gi = 0, ui = 0, skew = rng() % 200, t = 0;
        while (gi < n || ui < n || dut->busy) {
            dut->g_valid = gi < n && rng() % period == 0;
            dut->u_valid = ui < n && t > skew && rng() % period == 0;
            if (rng() % 1000 == 0) dut->u_valid = ui < n;          // occasional bursts
            dut->g_data = dut->g_valid ? g[gi] : 0;
            dut->u_data = dut->u_valid ? u[ui] : 0;
            gi += dut->g_valid; ui += dut->u_valid;
            tick(); t++;
            if (dut->aw_en) {
                int a = dut->aw_addr, k = (a >> 12) ? na + (a & 0x1FF) : (a & 0xFFF);
                if (k >= na + ns) { if (bad++ < 5) printf("case %d: write to %04x out of range\n", c, a); }
                else { got[k] = dut->aw_data; hits[k]++; }
            }
            if (t > 100 * n + 100000) { printf("case %d: timeout (busy %d)\n", c, dut->busy); bad++; break; }
        }
        dut->g_valid = dut->u_valid = 0;
        for (int i = 0; i < 4; i++) tick();
        for (int k = 0; k < na + ns; k++) {
            words++;
            if (hits[k] != 1 || got[k] != want[k]) {
                if (bad++ < 8)
                    printf("case %d (%d rows): %s word %d: got %08x want %08x (written %d x)\n", c, n,
                           k < na ? "a" : "subgroup", k < na ? k : k - na, got[k], want[k], hits[k]);
            }
        }
        if (dut->err) { printf("case %d: err set\n", c); bad++; }
        cycles += t;
    }
    printf("ffn_unit: %d cases, %ld activation words compared, %ld wrong, %ld clocks (period %d) -> %s\n",
           ncases, words, bad, cycles, period, bad ? "FAIL" : "PASS");
    delete dut;
    return bad != 0;
}
