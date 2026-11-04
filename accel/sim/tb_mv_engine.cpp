// tb_mv_engine.cpp - Verilator testbench: mv_engine against the bit-exact golden model (accel/golden/golden.h).
//   random:  tb <K> <rows> <seed> [gap_percent]       real:  tb --real <file> [gap_percent]
// Real-data file (mustaqi/accel_vectors.py): int32 K, int32 rows, int32 nvec, float32 w[rows][K], float32 x[nvec][K]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <vector>

#include "Vmv_engine.h"
#include "verilated.h"
#include "golden.h"

#ifndef NVEC
#define NVEC 1
#endif

struct Test {
    int K = 0, rows = 0;
    std::vector<float> w;                        // rows * K
    std::vector<std::vector<float>> x;           // NVEC * K
};

static Vmv_engine *dut;
static uint64_t cycles = 0;

static void tick() {
    dut->clk = 0; dut->eval();
    dut->clk = 1; dut->eval();
    cycles++;
}

static void set_word(const uint8_t *b) {            // 64 bytes -> w_data[511:0], little endian
    for (int i = 0; i < 16; i++) dut->w_data[i] = (uint32_t)b[4*i] | b[4*i+1] << 8 | b[4*i+2] << 16 | (uint32_t)b[4*i+3] << 24;
}

static int run(const Test &t, int gap_pct, unsigned seed) {
    int K = t.K, ng = K / WG, sw = (ng + 15) / 16, rw = sw + ng;
    std::mt19937 rng(seed * 7 + 1);
    // golden quantization
    std::vector<uint8_t> words((size_t)t.rows * rw * 64);
    for (int r = 0; r < t.rows; r++) q4h_quantize_row(&t.w[(size_t)r * K], K, &words[(size_t)r * rw * 64]);
    std::vector<std::vector<int8_t>> a(NVEC, std::vector<int8_t>(K)), e(NVEC, std::vector<int8_t>(K / AG));
    std::vector<std::vector<int16_t>> S(NVEC, std::vector<int16_t>(K / AG));
    for (int v = 0; v < NVEC; v++) mx_quantize(t.x[v].data(), K, a[v].data(), e[v].data(), S[v].data());
    std::vector<uint32_t> expect((size_t)t.rows * NVEC);
    int exp_ovf = 0;
    for (int r = 0; r < t.rows; r++)
        for (int v = 0; v < NVEC; v++) {
            float f = acc_to_float(q4h_row_acc(&words[(size_t)r * rw * 64], K, a[v].data(), e[v].data(), S[v].data(), &exp_ovf));
            memcpy(&expect[(size_t)r * NVEC + v], &f, 4);
        }
    // reset, load activations
    dut->rst = 1; dut->start = 0; dut->w_valid = 0; dut->aw_en = 0; dut->cfg_ng = ng;
    for (int i = 0; i < 4; i++) tick();
    dut->rst = 0;
    for (int v = 0; v < NVEC; v++) {
        for (int w = 0; w < K / 4; w++) {
            dut->aw_en = 1; dut->aw_vec = v; dut->aw_addr = w;
            dut->aw_data = (uint8_t)a[v][4*w] | (uint8_t)a[v][4*w+1] << 8 | (uint8_t)a[v][4*w+2] << 16 | (uint32_t)(uint8_t)a[v][4*w+3] << 24;
            tick();
        }
        for (int g = 0; g < K / AG; g++) {
            dut->aw_en = 1; dut->aw_vec = v; dut->aw_addr = 0x1000 | g;
            dut->aw_data = (uint32_t)(uint8_t)e[v][g] << 16 | (uint16_t)S[v][g];
            tick();
        }
    }
    dut->aw_en = 0;
    dut->start = 1; tick(); dut->start = 0;
    // stream, collect
    std::vector<int> seen(t.rows, 0);
    int bad = 0, shown = 0, got_rows = 0;
    auto collect = [&]() {
        if (!dut->r_valid) return;
        int r = dut->r_row;
        if (r >= t.rows || seen[r]) { if (shown++ < 5) printf("  unexpected result row %d\n", r); bad++; return; }
        seen[r] = 1; got_rows++;
        for (int v = 0; v < NVEC; v++) {
#if NVEC == 1
            uint32_t g = dut->r_data;
#else
            uint32_t g = dut->r_data[v];
#endif
            uint32_t x = expect[(size_t)r * NVEC + v];
            if (g != x) {
                bad++;
                if (shown++ < 8) {
                    float fg, fx; memcpy(&fg, &g, 4); memcpy(&fx, &x, 4);
                    printf("  row %d vec %d: engine %08x (%.9g) golden %08x (%.9g)\n", r, v, g, fg, x, fx);
                }
            }
        }
    };
    size_t n = (size_t)t.rows * rw;
    for (size_t i = 0; i < n;) {
        if (gap_pct && (int)(rng() % 100) < gap_pct) dut->w_valid = 0;
        else { dut->w_valid = 1; set_word(&words[i * 64]); i++; }
        tick(); collect();
    }
    dut->w_valid = 0;
    for (int i = 0; i < 32; i++) { tick(); collect(); }
    if (got_rows != t.rows) { printf("  only %d of %d rows came out\n", got_rows, t.rows); bad++; }
    if (!!dut->ovf != !!exp_ovf) { printf("  overflow flag: engine %d golden %d\n", dut->ovf, exp_ovf); bad++; }
    printf("K %d rows %d vectors %d gaps %d%%: %s (%d mismatches, %llu cycles)\n", K, t.rows, NVEC, gap_pct,
           bad ? "FAIL" : "bit-exact", bad, (unsigned long long)cycles);
    return bad;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vmv_engine;
    Test t;
    int gap = 0, fails = 0;
    if (argc >= 3 && !strcmp(argv[1], "--real")) {
        FILE *f = fopen(argv[2], "rb");
        if (!f) { perror(argv[2]); return 2; }
        int hdr[3];
        if (fread(hdr, 4, 3, f) != 3) return 2;
        t.K = hdr[0]; t.rows = hdr[1];
        t.w.resize((size_t)t.rows * t.K);
        if (fread(t.w.data(), 4, t.w.size(), f) != t.w.size()) return 2;
        std::vector<float> xs((size_t)hdr[2] * t.K);
        if (fread(xs.data(), 4, xs.size(), f) != xs.size()) return 2;
        fclose(f);
        for (int v = 0; v < NVEC; v++) t.x.emplace_back(&xs[(size_t)(v % hdr[2]) * t.K], &xs[(size_t)(v % hdr[2] + 1) * t.K]);
        gap = argc > 3 ? atoi(argv[3]) : 0;
        fails = run(t, gap, 1);
    } else {
        int K = argc > 1 ? atoi(argv[1]) : 512, rows = argc > 2 ? atoi(argv[2]) : 16;
        unsigned seed = argc > 3 ? atoi(argv[3]) : 1;
        gap = argc > 4 ? atoi(argv[4]) : 0;
        std::mt19937 rng(seed);
        std::normal_distribution<float> nd(0.0f, 1.0f);
        t.K = K; t.rows = rows; t.w.resize((size_t)rows * K);
        for (int r = 0; r < rows; r++) {
            float scale = std::ldexp(1.0f, (int)(rng() % 12) - 10);      // per-row magnitude 2^-10 .. 2^1
            for (int i = 0; i < K; i++) t.w[(size_t)r * K + i] = nd(rng) * scale;
            if (r % 7 == 3) for (int i = 0; i < WG; i++) t.w[(size_t)r * K + i] = 0.25f;   // flat group: s = 0
            if (r % 11 == 5) for (int i = WG; i < 2 * WG && i < K; i++) t.w[(size_t)r * K + i] *= 1e-6f;  // subnormal s
        }
        for (int v = 0; v < NVEC; v++) {
            std::vector<float> x(K);
            for (int i = 0; i < K; i++) x[i] = nd(rng) * std::ldexp(1.0f, (int)(rng() % 9) - 4);
            for (int i = 0; i < K; i += 97) x[i] *= 60.0f;                      // outliers
            for (int i = 0; i < AG && 2 * AG <= K; i++) x[AG + i] = 0.0f;         // an all-zero subgroup
            t.x.push_back(x);
        }
        fails = run(t, gap, seed);
    }
    delete dut;
    return fails ? 1 : 0;
}
