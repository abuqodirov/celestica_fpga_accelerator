// Verilator testbench for bigmul.
// The reference is grade-school multiplication done directly on decimal strings,
// so it shares nothing with the hardware's binary limb algorithm.
#include <cstdint>
#include <cstdio>
#include <random>
#include <string>
#include <vector>

#include "Vbigmul.h"
#include "verilated.h"

static const int LIMBS = 32;                 // must match the RTL parameter
static const int MAX_DIGITS = 308;           // every 308-digit number fits in 1024 bits

// Grade-school multiplication on decimal strings.
static std::string mul_strings(const std::string& x, const std::string& y) {
    std::vector<int> r(x.size() + y.size(), 0);
    for (int i = (int)x.size() - 1; i >= 0; i--)
        for (int j = (int)y.size() - 1; j >= 0; j--) {
            int sum = (x[i] - '0') * (y[j] - '0') + r[i + j + 1];
            r[i + j + 1] = sum % 10;
            r[i + j] += sum / 10;
        }
    std::string s;
    for (int d : r) s.push_back('0' + d);
    size_t nz = s.find_first_not_of('0');
    return nz == std::string::npos ? "0" : s.substr(nz);
}

static std::vector<uint32_t> dec_to_limbs(const std::string& s, int n) {
    std::vector<uint32_t> v(n, 0);
    for (char c : s) {  // v = v * 10 + digit
        uint64_t carry = c - '0';
        for (auto& w : v) {
            uint64_t t = (uint64_t)w * 10 + carry;
            w = (uint32_t)t;
            carry = t >> 32;
        }
    }
    return v;
}

static std::string limbs_to_dec(std::vector<uint32_t> v) {
    std::string out;
    auto zero = [&] { for (auto w : v) if (w) return false; return true; };
    while (!zero()) {  // peel off nine decimal digits at a time
        uint64_t rem = 0;
        for (int i = (int)v.size() - 1; i >= 0; i--) {
            uint64_t cur = (rem << 32) | v[i];
            v[i] = (uint32_t)(cur / 1000000000u);
            rem = cur % 1000000000u;
        }
        char buf[16];
        snprintf(buf, sizeof buf, "%09u", (unsigned)rem);
        out = buf + out;
    }
    size_t nz = out.find_first_not_of('0');
    return nz == std::string::npos ? "0" : out.substr(nz);
}

static Vbigmul* dut;

static void tick() {
    dut->clk = 0; dut->eval();
    dut->clk = 1; dut->eval();
}

static bool hw_multiply(const std::string& x, const std::string& y, std::string& prod, uint32_t& cycles) {
    auto a = dec_to_limbs(x, LIMBS), b = dec_to_limbs(y, LIMBS);
    for (int i = 0; i < LIMBS; i++) { dut->a[i] = a[i]; dut->b[i] = b[i]; }
    dut->start = 1;
    tick();
    dut->start = 0;
    for (int n = 0; n < 1000; n++) {
        tick();
        if (dut->done) {
            std::vector<uint32_t> p(2 * LIMBS);
            for (int i = 0; i < 2 * LIMBS; i++) p[i] = dut->product[i];
            prod = limbs_to_dec(p);
            cycles = dut->cycles;
            return true;
        }
    }
    return false;
}

static std::string random_number(std::mt19937& rng, int digits) {
    std::uniform_int_distribution<int> d09(0, 9), d19(1, 9);
    std::string s(1, '0' + d19(rng));
    for (int i = 1; i < digits; i++) s.push_back('0' + d09(rng));
    return s;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vbigmul;
    dut->rst = 1;
    for (int i = 0; i < 4; i++) tick();
    dut->rst = 0;
    tick();

    std::mt19937 rng(20261005);
    std::vector<std::pair<std::string, std::string>> tests;
    std::vector<uint32_t> all_ones(LIMBS, 0xFFFFFFFFu);
    std::string max1024 = limbs_to_dec(all_ones);
    tests.push_back({"0", random_number(rng, 200)});
    tests.push_back({"1", random_number(rng, 200)});
    tests.push_back({std::string(200, '9'), std::string(200, '9')});
    tests.push_back({max1024, max1024});
    for (int i = 0; i < 1000; i++) tests.push_back({random_number(rng, 200), random_number(rng, 200)});
    std::uniform_int_distribution<int> len(1, MAX_DIGITS);
    for (int i = 0; i < 1000; i++) tests.push_back({random_number(rng, len(rng)), random_number(rng, len(rng))});

    int fails = 0;
    uint32_t cyc_min = ~0u, cyc_max = 0;
    for (size_t t = 0; t < tests.size(); t++) {
        const auto& [x, y] = tests[t];
        std::string got, want = mul_strings(x, y);
        uint32_t cyc = 0;
        if (!hw_multiply(x, y, got, cyc)) { printf("TIMEOUT on test %zu\n", t); fails++; continue; }
        if (cyc < cyc_min) cyc_min = cyc;
        if (cyc > cyc_max) cyc_max = cyc;
        if (got != want) {
            if (fails < 5) printf("FAIL test %zu:\n  a=%s\n  b=%s\n  got  %s\n  want %s\n",
                                  t, x.c_str(), y.c_str(), got.c_str(), want.c_str());
            fails++;
        }
        if (t == 4)
            printf("Example (200 x 200 digits, %u cycles):\n  a = %s\n  b = %s\n  a*b = %s  (%zu digits)\n\n",
                   cyc, x.c_str(), y.c_str(), got.c_str(), got.size());
    }
    printf("%zu multiplications (incl. 1000 random 200x200-digit, 1000 random 1..308-digit, "
           "0, 1, 9...9^2, (2^1024-1)^2)\ncycles per multiply: %u..%u\n%s: %d failure(s)\n",
           tests.size(), cyc_min, cyc_max, fails ? "FAILED" : "ALL PASS", fails);
    delete dut;
    return fails ? 1 : 0;
}
