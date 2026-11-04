#!/usr/bin/env python3
"""Multiply big decimal numbers on the FPGA's 1024-bit multiplier (JTAG USER2).

Usage: run_bigmul.py [A B]
With no arguments: multiplies two random 200-digit numbers and shows them, then
checks a batch of random multiplications (1..308 digits) against Python.
"""
import random
import sys
import time
import timeit

from hs3_jtag import HS3Jtag
from run_hw import Calc, OP_TICK

IR_USER2 = 0x03
BIG_BITS = 1024
DR2_BITS = 2 * BIG_BITS + 48
MAX_VALUE = (1 << BIG_BITS) - 1


class BigMul:
    def __init__(self, jtag):
        self.j = jtag
        self.j.ir(IR_USER2)

    def status(self):
        v = self.j.dr(0, DR2_BITS)
        return {
            "product": v & ((1 << 2 * BIG_BITS) - 1),
            "cycles": (v >> 2 * BIG_BITS) & 0xFFFFFFFF,
            "done": (v >> (2 * BIG_BITS + 32)) & 1,
            "magic": (v >> (2 * BIG_BITS + 40)) & 0xFF,
        }

    def multiply(self, a, b):
        if not (0 <= a <= MAX_VALUE and 0 <= b <= MAX_VALUE):
            raise ValueError("operands must fit in 1024 bits (308 decimal digits)")
        self.j.dr(a | (b << BIG_BITS) | (1 << 2 * BIG_BITS), DR2_BITS)
        for _ in range(1000):
            s = self.status()
            if s["done"]:
                return s
        raise TimeoutError("multiplier did not finish")


def measure_clock(jtag):
    calc = Calc(jtag)
    t_a = time.perf_counter(); k_a = calc.run(OP_TICK, 0, 0)["result"]; t_a = (t_a + time.perf_counter()) / 2
    time.sleep(1.0)
    t_b = time.perf_counter(); k_b = calc.run(OP_TICK, 0, 0)["result"]; t_b = (t_b + time.perf_counter()) / 2
    return (k_b - k_a) / (t_b - t_a)


def show(label, n, width=100):
    s = str(n)
    print(f"{label} ({len(s)} digits):")
    for i in range(0, len(s), width):
        print("    " + s[i:i + width])


def main():
    j = HS3Jtag()
    try:
        f_hz = measure_clock(j)
        big = BigMul(j)
        if big.status()["magic"] != 0x5A:
            sys.exit("Big multiplier not found. Run `make load` first.")

        if len(sys.argv) == 3:
            a, b = int(sys.argv[1]), int(sys.argv[2])
        else:
            rng = random.Random()
            a = rng.randrange(10 ** 199, 10 ** 200)
            b = rng.randrange(10 ** 199, 10 ** 200)

        s = big.multiply(a, b)
        show("A", a)
        show("B", b)
        show("A × B computed on the FPGA", s["product"])
        ok = s["product"] == a * b
        print(f"\nPython check: {'MATCH' if ok else 'MISMATCH'}")
        on_chip = s["cycles"] / f_hz
        py = min(timeit.repeat(lambda: a * b, number=10000, repeat=5)) / 10000
        print(f"FPGA: {s['cycles']} clock cycles at {f_hz / 1e6:.2f} MHz = {on_chip * 1e6:.2f} µs on the chip")
        print(f"(Python on this PC: {py * 1e6:.2f} µs for the same multiply)")
        if not ok:
            sys.exit(1)

        if len(sys.argv) != 3:
            rng = random.Random(2026)
            n, bad = 300, 0
            t0 = time.perf_counter()
            for _ in range(n):
                x = rng.randrange(min(10 ** rng.randint(1, 308), MAX_VALUE + 1))
                y = rng.randrange(min(10 ** rng.randint(1, 308), MAX_VALUE + 1))
                bad += big.multiply(x, y)["product"] != x * y
            dt = time.perf_counter() - t0
            print(f"\nBatch: {n} random multiplications (1..308 digits): "
                  f"{n - bad}/{n} correct, {dt / n * 1e3:.1f} ms each incl. JTAG transfer")
            if bad:
                sys.exit(1)
    finally:
        j.close()


if __name__ == "__main__":
    main()
