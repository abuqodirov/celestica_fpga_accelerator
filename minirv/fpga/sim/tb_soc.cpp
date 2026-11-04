// Verilator testbench for minirv_soc: loads a program through the debug port (the
// same commands the FPGA receives over JTAG), runs it, and prints the results as JSON.
// Usage: Vminirv_soc <prog.bin> [max_cycles] [addr:words ...]  (regions to dump, hex addr)
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "Vminirv_soc.h"
#include "verilated.h"

enum { CMD_WRITE = 1, CMD_READ = 2, CMD_CTRL = 3, CMD_POP = 4 };
static Vminirv_soc* soc;

static void tick() {
    soc->clk = 0; soc->eval();
    soc->clk = 1; soc->eval();
}

static uint32_t command(int cmd, uint32_t word_addr, uint32_t wdata) {
    soc->dbg_valid = 1; soc->dbg_cmd = cmd; soc->dbg_addr = word_addr; soc->dbg_wdata = wdata;
    tick();
    soc->dbg_valid = 0;
    for (int i = 0; i < 16; i++) {
        if (soc->dbg_done) return soc->dbg_result;
        tick();
    }
    fprintf(stderr, "debug command %d timed out\n", cmd);
    exit(2);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 2) { fprintf(stderr, "usage: %s prog.bin [max_cycles] [addr:words ...]\n", argv[0]); return 1; }
    FILE* f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 1; }
    std::vector<uint8_t> img;
    for (int c; (c = fgetc(f)) != EOF;) img.push_back((uint8_t)c);
    fclose(f);
    while (img.size() % 4) img.push_back(0);
    uint64_t max_cycles = argc > 2 ? strtoull(argv[2], nullptr, 0) : 10000000;

    soc = new Vminirv_soc;
    for (int i = 0; i < 4; i++) tick();
    command(CMD_CTRL, 0, 0);                                   // hold the CPU
    for (size_t i = 0; i < img.size(); i += 4)
        command(CMD_WRITE, i / 4, img[i] | img[i + 1] << 8 | img[i + 2] << 16 | (uint32_t)img[i + 3] << 24);
    command(CMD_CTRL, 0, 1);                                   // run
    uint64_t n = 0;
    while (!soc->halted && n < max_cycles) { tick(); n++; }

    std::string console;
    for (;;) {
        uint32_t r = command(CMD_POP, 0, 0);
        if (!(r & 0x100)) break;
        console += (char)(r & 0xFF);
    }
    printf("{\"halted\": %s, \"console\": \"", soc->halted ? "true" : "false");
    for (char c : console) {
        if (c == '\n') printf("\\n"); else if (c == '"' || c == '\\') printf("\\%c", c); else putchar(c);
    }
    printf("\", \"a0\": %u, \"pc\": %u, \"instret\": %u, \"cycles\": %u, \"leds\": %u, \"regions\": {",
           soc->a0, soc->pc, soc->instret, soc->cycles, soc->leds);
    command(CMD_CTRL, 0, 0);                                   // hold the CPU so RAM can be read
    for (int a = 3; a < argc; a++) {
        unsigned addr = 0, words = 0;
        sscanf(argv[a], "%x:%u", &addr, &words);
        printf("%s\"%08x\": [", a > 3 ? ", " : "", addr);
        for (unsigned w = 0; w < words; w++)
            printf("%s%u", w ? ", " : "", command(CMD_READ, ((addr - 0x30000000u) >> 2) + w, 0));
        printf("]");
    }
    printf("}}\n");
    delete soc;
    return 0;
}
