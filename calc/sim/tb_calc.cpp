// Verilator testbench for calc_core.
// 1. Runs one demo vector per operation with waveform tracing (calc.vcd, open in GTKWave).
// 2. Runs edge cases and random vectors for every operation against a C++ reference.
// 3. Writes vectors.csv (op, a, b, expected result, cycle count) for the hardware run.
#include <cinttypes>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <numeric>
#include <random>
#include <vector>

#include "Vcalc_core.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

enum { OP_ADD, OP_MUL, OP_GCD, OP_ISQRT, OP_FIB, OP_COLLATZ, OP_DIVMOD, NUM_OPS };
static const char* const NAMES[NUM_OPS] = {"add", "mul", "gcd", "isqrt", "fib", "collatz", "divmod"};

static uint64_t reference(int op, uint32_t a, uint32_t b) {
    switch (op) {
    case OP_ADD: return (uint64_t)a + b;
    case OP_MUL: return (uint64_t)a * b;
    case OP_GCD: return std::gcd(a, b);
    case OP_ISQRT: {
        uint64_t r = (uint64_t)std::sqrt((double)a);
        while (r * r > a) r--;
        while ((r + 1) * (r + 1) <= a) r++;
        return r;
    }
    case OP_FIB: {
        uint64_t x = 0, y = 1;
        for (uint32_t i = 0; i < (a & 0xFFFF); i++) { uint64_t t = x + y; x = y; y = t; }
        return x;
    }
    case OP_COLLATZ: {
        uint64_t v = a, steps = 0;
        while (v > 1) { v = (v & 1) ? 3 * v + 1 : v >> 1; steps++; }
        return steps;
    }
    case OP_DIVMOD:
        return b ? ((uint64_t)(a % b) << 32) | (a / b) : ((uint64_t)a << 32) | 0xFFFFFFFFu;
    }
    return 0;
}

static Vcalc_core* dut;
static VerilatedVcdC* vcd;
static uint64_t sim_time;

static void tick() {
    dut->clk = 0; dut->eval(); if (vcd) vcd->dump(sim_time++);
    dut->clk = 1; dut->eval(); if (vcd) vcd->dump(sim_time++);
}

static bool run_op(int op, uint32_t a, uint32_t b, uint64_t& result, uint32_t& cycles) {
    dut->op = op; dut->a = a; dut->b = b; dut->start = 1;
    tick();
    dut->start = 0;
    for (int i = 0; i < (1 << 22); i++) {
        tick();
        if (dut->done) { result = dut->result; cycles = dut->cycles; return true; }
    }
    return false;
}

struct Vec { int op; uint32_t a, b; };

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    dut = new Vcalc_core;
    vcd = new VerilatedVcdC;
    dut->trace(vcd, 99);
    vcd->open("calc.vcd");

    dut->rst = 1;
    for (int i = 0; i < 4; i++) tick();
    dut->rst = 0;
    tick();

    FILE* csv = fopen("vectors.csv", "w");
    fprintf(csv, "op,a,b,result,cycles\n");
    int fails = 0;

    auto check = [&](const Vec& v, bool to_csv) {
        uint64_t got; uint32_t cyc;
        uint64_t want = reference(v.op, v.a, v.b);
        if (!run_op(v.op, v.a, v.b, got, cyc)) {
            printf("TIMEOUT %s(%u, %u)\n", NAMES[v.op], v.a, v.b);
            fails++;
            return 0u;
        }
        if (got != want) {
            if (fails < 20)
                printf("FAIL %s(%u, %u): got %" PRIu64 " want %" PRIu64 "\n", NAMES[v.op], v.a, v.b, got, want);
            fails++;
        } else if (to_csv) {
            fprintf(csv, "%d,%u,%u,%" PRIu64 ",%u\n", v.op, v.a, v.b, got, cyc);
        }
        return cyc;
    };

    // 1. Traced demo: one readable example per operation.
    const Vec demo[] = {{OP_ADD, 1234, 5678},   {OP_MUL, 123456, 654321}, {OP_GCD, 1071, 462},
                        {OP_ISQRT, 1000000, 0}, {OP_FIB, 50, 0},          {OP_COLLATZ, 27, 0},
                        {OP_DIVMOD, 1000, 7}};
    printf("Demo (traced to calc.vcd):\n");
    for (const Vec& v : demo) {
        uint32_t cyc = check(v, true);
        printf("  %-8s a=%-8u b=%-8u -> %-12" PRIu64 " %4u cycles\n", NAMES[v.op], v.a, v.b,
               reference(v.op, v.a, v.b), cyc);
    }
    vcd->close();
    vcd = nullptr;

    // 2. Edge cases + random vectors for every op.
    std::mt19937 rng(20261005);
    std::uniform_int_distribution<uint32_t> any32;
    const uint32_t edges[][2] = {{0, 0}, {0, 1}, {1, 0}, {1, 1}, {0xFFFFFFFF, 0xFFFFFFFF},
                                 {0xFFFFFFFF, 1}, {1, 0xFFFFFFFF}, {0x80000000, 2}, {12, 18}};
    printf("\n%-8s %8s %8s %10s %10s\n", "op", "vectors", "failed", "avg cyc", "max cyc");
    for (int op = 0; op < NUM_OPS; op++) {
        int fails_before = fails, count = 0;
        uint64_t cyc_sum = 0;
        uint32_t cyc_max = 0;
        int n_random = (op == OP_FIB) ? 300 : 3000;
        std::vector<Vec> vecs;
        for (auto& e : edges) vecs.push_back({op, e[0], e[1]});
        for (int i = 0; i < n_random; i++) {
            uint32_t a = any32(rng), b = any32(rng);
            if (op == OP_FIB) a = (i % 10 == 0) ? (a & 0xFFFF) : (a % 2000);
            if (op == OP_GCD && i % 2) {  // give half the pairs a large common factor
                uint32_t c = 1 + any32(rng) % 50000;
                a = c * (1 + a % 80000);
                b = c * (1 + b % 80000);
            }
            if (op == OP_DIVMOD && i % 3 == 0) b &= 0xFFFF;  // small divisors too
            vecs.push_back({op, a, b});
        }
        for (size_t i = 0; i < vecs.size(); i++) {
            uint32_t cyc = check(vecs[i], i < 40);  // first 40 per op go to the hardware run
            cyc_sum += cyc;
            if (cyc > cyc_max) cyc_max = cyc;
            count++;
        }
        printf("%-8s %8d %8d %10.1f %10u\n", NAMES[op], count, fails - fails_before,
               (double)cyc_sum / count, cyc_max);
    }
    fclose(csv);
    printf("\n%s: %d failure(s)\n", fails ? "FAILED" : "ALL PASS", fails);
    delete dut;
    return fails ? 1 : 0;
}
