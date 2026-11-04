// tb_silu.cpp - Verilator testbench: silu_mul (accel/rtl/ffn_unit.v) alone, every float32 h = silu(g) * u bit for bit
// against mustaqi/fpga_llm.py silu_mul_hw (vectors from mustaqi/ffn_vectors.py; a new pair every clock).
//   tb_silu <vectors.bin>
#include <cstdint>
#include <cstdio>
#include <vector>

#include "Vsilu_mul.h"
#include "verilated.h"

int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 2; }
    int ncases;
    if (fread(&ncases, 4, 1, f) != 1) return 2;
    auto *dut = new Vsilu_mul;
    auto tick = [&] { dut->clk = 0; dut->eval(); dut->clk = 1; dut->eval(); };
    dut->rst = 1; tick(); tick(); dut->rst = 0;
    long bad = 0, n_all = 0;
    for (int c = 0; c < ncases; c++) {
        int n;
        if (fread(&n, 4, 1, f) != 1) return 2;
        std::vector<uint32_t> g(n), u(n), h(n), img(n / 4 + n / 32);
        if (fread(g.data(), 4, n, f) != (size_t)n || fread(u.data(), 4, n, f) != (size_t)n ||
            fread(h.data(), 4, n, f) != (size_t)n || fread(img.data(), 4, img.size(), f) != img.size()) return 2;
        int out = 0;
        for (int t = 0; out < n && t < n + 100; t++) {
            dut->in_v = t < n; dut->g = t < n ? g[t] : 0; dut->u = t < n ? u[t] : 0;
            tick();
            if (dut->out_v) {
                if (dut->h != h[out] && bad++ < 8)
                    printf("case %d row %d: silu(%08x) * %08x = %08x, want %08x\n", c, out, g[out], u[out], dut->h, h[out]);
                out++;
            }
        }
        if (out != n) { printf("case %d: %d of %d outputs\n", c, out, n); bad++; }
        n_all += n;
    }
    printf("silu_mul: %ld rows, %ld wrong -> %s\n", n_all, bad, bad ? "FAIL" : "PASS");
    delete dut;
    return bad != 0;
}
