#!/usr/bin/env python3
"""minirv test programs. Writes build/progs/<name>.bin and <name>.ref.json (reference results).

  hello     prints a greeting, lights all LEDs, exits with a0 = 0
  selftest  exercises every instruction; results land in RAM at RESULTS for comparison
  ledcount  prints a line, then shows mcycle bits 24-26 on the LEDs forever

minirv has no branches, so loops use a jump table: target = TABLE[counter], then jalr.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from rvasm import Program, Sim, CONSOLE, LEDS  # noqa: E402

RESULTS = 0x3000_8000      # selftest result words
N_RESULTS = 32
FIB = 0x3000_8100          # selftest Fibonacci table
N_FIB = 40


def puts(p, text, ptr="t0", tmp="t1"):
    p.li(ptr, CONSOLE)
    for ch in text.encode():
        p.addi(tmp, "zero", ch)
        p.sb(tmp, 0, ptr)


def hello():
    p = Program()
    puts(p, "Hello from minirv on a Kintex-7 XC7K480T!\n")
    p.li("t0", LEDS)
    p.addi("t1", "zero", 7)
    p.sw("t1", 0, "t0")
    p.addi("a0", "zero", 0)
    p.ebreak()
    return p, None


def table_loop(p, name, count, body):
    """for (s1 = 0; s1 < count; s1++) body(): branch-free, via a jump table."""
    p.addi("s1", "zero", 0)
    p.label(f"{name}_top")
    p.add("t0", "s1", "s1")
    p.add("t0", "t0", "t0")             # t0 = 4 * s1
    p.li("t1", f"{name}_table")
    p.add("t0", "t0", "t1")
    p.lw("t0", 0, "t0")                 # t0 = table[s1]
    p.jalr("zero", "t0", 0)
    p.label(f"{name}_body")
    body()
    p.addi("s1", "s1", 1)
    p.jump(f"{name}_top")
    p.label(f"{name}_table")
    for _ in range(count):
        p.word(f"{name}_body")
    p.word(f"{name}_done")
    p.label(f"{name}_done")


def selftest():
    p = Program()
    R = lambda i: 4 * i                  # result slot offsets from s0
    p.li("s0", RESULTS)
    # constants: lui/addi, negative immediates
    p.li("t0", 0x12345678);   p.sw("t0", R(0), "s0")
    p.li("t1", -2048);        p.sw("t1", R(1), "s0")
    p.addi("t2", "zero", -1); p.sw("t2", R(2), "s0")
    p.lui("t3", 0xABCDE);     p.sw("t3", R(3), "s0")
    # add/sub, overflow wrap, negation
    p.add("t4", "t0", "t1");  p.sw("t4", R(4), "s0")
    p.sub("t5", "t0", "t1");  p.sw("t5", R(5), "s0")
    p.li("a1", 0x7FFFFFFF); p.addi("a1", "a1", 1); p.sw("a1", R(6), "s0")
    p.sub("a2", "zero", "t0"); p.sw("a2", R(7), "s0")
    # word store, byte loads from every lane
    p.li("t0", 0xA1B2C3D4); p.sw("t0", R(8), "s0")
    for k in range(4):
        p.lbu("t1", R(8) + k, "s0"); p.sw("t1", R(9 + k), "s0")
    # byte stores into every lane, then one word load
    p.sw("zero", R(13), "s0")
    for k, v in enumerate((0x11, 0x22, 0x33, 0x44)):
        p.addi("t1", "zero", v); p.sb("t1", R(13) + k, "s0")
    p.lw("t2", R(13), "s0"); p.sw("t2", R(14), "s0")
    p.sw("zero", R(15), "s0"); p.li("t1", 0x1FF); p.sb("t1", R(15), "s0")     # only the low byte lands
    # x0 stays zero
    p.addi("zero", "zero", 5); p.add("t1", "zero", "zero"); p.sw("t1", R(16), "s0")
    # call and return with jalr
    p.li("t0", "func"); p.jalr("ra", "t0", 0)
    p.sw("a3", R(17), "s0"); p.sw("ra", R(18), "s0")
    # CSRs: vendor id, arch id, and the cycle distance between two reads
    p.csrr("t1", "mvendorid"); p.sw("t1", R(19), "s0")
    p.csrr("t2", "marchid");   p.sw("t2", R(20), "s0")
    p.csrr("t3", "mcycle"); p.csrr("t4", "mcycle"); p.sub("t5", "t4", "t3"); p.sw("t5", R(21), "s0")
    # loop 1: sum 1..100 into s2
    p.addi("s2", "zero", 0)
    table_loop(p, "sum", 100, lambda: (p.add("s2", "s2", "s1"), p.addi("s2", "s2", 1)))
    p.sw("s2", R(22), "s0")
    # loop 2: Fibonacci numbers into FIB[0..39]
    p.li("s3", FIB); p.addi("s4", "zero", 0); p.addi("s5", "zero", 1)
    table_loop(p, "fib", N_FIB, lambda: (p.sw("s4", 0, "s3"), p.add("t2", "s4", "s5"),
                                         p.add("s4", "s5", "zero"), p.add("s5", "t2", "zero"),
                                         p.addi("s3", "s3", 4)))
    p.sw("s4", R(23), "s0")
    # a0 = sum of all result words (a checksum the host can see without reading RAM)
    p.addi("a0", "zero", 0)
    for i in range(24):
        p.lw("t1", R(i), "s0"); p.add("a0", "a0", "t1")
    p.ebreak()
    p.label("func")
    p.addi("a3", "zero", 0x5A)
    p.jalr("zero", "ra", 0)
    return p, [(RESULTS, N_RESULTS), (FIB, N_FIB)]


def ledcount():
    p = Program()
    puts(p, "minirv running from the 50 MHz oscillator: LEDs show mcycle bits 24-26\n")
    p.li("s0", 0x3000_8000)
    p.li("s1", LEDS)
    p.label("loop")
    p.csrr("t0", "mcycle")
    p.sw("t0", 0, "s0")
    p.lbu("t1", 3, "s0")                # bits 24..31 of mcycle
    p.sb("t1", 0, "s1")                 # LEDs take bits 24..26
    p.jump("loop")
    return p, None


PROGRAMS = {"hello": hello, "selftest": selftest, "ledcount": ledcount}


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "build", "progs")
    os.makedirs(out, exist_ok=True)
    for name, make in PROGRAMS.items():
        prog, regions = make()
        image = prog.image()
        open(os.path.join(out, f"{name}.bin"), "wb").write(image)
        if name == "ledcount":
            print(f"{name:9} {len(image):5} bytes (runs forever; no reference run)")
            continue
        sim = Sim(image).run()
        ref = {"console": sim.console.decode(), "a0": sim.x[10], "pc": sim.pc - 4,
               "instret": sim.instret, "cycles_model": sim.cycles, "leds": sim.leds,
               "regions": {f"{a:08x}": sim.read_words(a, n) for a, n in (regions or [])}}
        json.dump(ref, open(os.path.join(out, f"{name}.ref.json"), "w"), indent=1)
        print(f"{name:9} {len(image):5} bytes  reference: {sim.instret} instructions, "
              f"~{sim.cycles} cycles, a0=0x{sim.x[10]:08x}, console {len(sim.console)} chars")


if __name__ == "__main__":
    main()
