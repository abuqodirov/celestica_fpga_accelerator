#!/usr/bin/env python3
"""Run the calculator on the FPGA over JTAG and compare against the simulation.

Usage: run_hw.py [vectors.csv]
Each vector's result AND cycle count must match what the Verilator testbench
recorded, so this checks the hardware against both the C++ reference and the
simulated RTL.
"""
import csv
import sys
import time
from collections import defaultdict

from hs3_jtag import HS3Jtag, IR_USER1

DR_BITS = 112
NAMES = ["add", "mul", "gcd", "isqrt", "fib", "collatz", "divmod"]
OP_TICK = 7
EXPECTED_IDCODE = 0x23751093


class Calc:
    def __init__(self, jtag):
        self.j = jtag
        self.j.ir(IR_USER1)

    def status(self):
        v = self.j.dr(0, DR_BITS)
        return {
            "result": v & ((1 << 64) - 1),
            "cycles": (v >> 64) & 0xFFFFFFFF,
            "done": (v >> 96) & 1,
            "heartbeat": (v >> 98) & 1,
            "magic": (v >> 104) & 0xFF,
        }

    def run(self, op, a, b, timeout=2.0):
        self.j.dr(a | (b << 32) | (op << 64) | (1 << 68), DR_BITS)
        t0 = time.monotonic()
        while time.monotonic() - t0 < timeout:
            s = self.status()
            if s["done"]:
                return s
        raise TimeoutError(f"op {op}({a}, {b}) did not finish")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/vectors.csv"
    vectors = list(csv.DictReader(open(path)))

    j = HS3Jtag()
    try:
        idc = j.idcode()
        print(f"JTAG IDCODE 0x{idc:08x} ({'XC7K480T' if idc == EXPECTED_IDCODE else 'UNEXPECTED'})")
        calc = Calc(j)
        s = calc.status()
        if s["magic"] != 0xA5:
            sys.exit(f"Calculator design not found (magic 0x{s['magic']:02x}). Run `make load` first.")
        print("Calculator design is loaded and answering.")

        # Measure the internal oscillator: two timestamps two seconds apart.
        t_a = time.perf_counter(); k_a = calc.run(OP_TICK, 0, 0)["result"]; t_a = (t_a + time.perf_counter()) / 2
        time.sleep(2.0)
        t_b = time.perf_counter(); k_b = calc.run(OP_TICK, 0, 0)["result"]; t_b = (t_b + time.perf_counter()) / 2
        f_hz = (k_b - k_a) / (t_b - t_a)
        print(f"Internal clock (CFGMCLK): {f_hz / 1e6:.2f} MHz  (nominal 65 MHz; design timing estimate 70.6 MHz)")

        per_op = defaultdict(lambda: [0, 0, 0, 0])  # vectors, result ok, cycles ok, total cycles
        mismatches = []
        t0 = time.perf_counter()
        for v in vectors:
            op, a, b = int(v["op"]), int(v["a"]), int(v["b"])
            want, want_cyc = int(v["result"]), int(v["cycles"])
            s = calc.run(op, a, b)
            st = per_op[op]
            st[0] += 1
            st[1] += s["result"] == want
            st[2] += s["cycles"] == want_cyc
            st[3] += s["cycles"]
            if s["result"] != want or s["cycles"] != want_cyc:
                mismatches.append((NAMES[op], a, b, s["result"], want, s["cycles"], want_cyc))
        elapsed = time.perf_counter() - t0

        print(f"\nRan {len(vectors)} vectors on the FPGA in {elapsed:.1f} s (mostly USB round-trips)\n")
        print(f"{'op':8} {'vectors':>8} {'result ok':>10} {'cycles ok':>10} {'avg time on chip':>18}")
        for op in sorted(per_op):
            n, rok, cok, cyc = per_op[op]
            us = cyc / n / f_hz * 1e6
            print(f"{NAMES[op]:8} {n:8} {rok:10} {cok:10} {us:15.3f} µs")

        print("\nExamples computed on the FPGA:")
        examples = [(0, 1234, 5678), (1, 123456, 654321), (2, 1071, 462), (3, 1000000, 0),
                    (4, 50, 0), (4, 93, 0), (5, 27, 0), (5, 837799, 0), (6, 1000, 7)]
        for op, a, b in examples:
            s = calc.run(op, a, b)
            r = s["result"]
            if op == 6:
                text = f"{a} / {b} = {r & 0xFFFFFFFF} remainder {r >> 32}"
            else:
                text = {0: f"{a} + {b} = {r}", 1: f"{a} × {b} = {r:,}", 2: f"gcd({a}, {b}) = {r}",
                        3: f"isqrt({a:,}) = {r}", 4: f"fib({a}) = {r:,}",
                        5: f"collatz({a:,}) = {r} steps"}[op]
            print(f"  {text:42} {s['cycles']:6} cycles  {s['cycles'] / f_hz * 1e6:9.3f} µs")

        if mismatches:
            print(f"\nMISMATCHES ({len(mismatches)}):")
            for m in mismatches[:20]:
                print("  {}({}, {}): got {} want {}, cycles {} want {}".format(*m))
            sys.exit(1)
        print(f"\nALL {len(vectors)} HARDWARE RESULTS MATCH SIMULATION (results and cycle counts)")
    finally:
        j.close()


if __name__ == "__main__":
    main()
