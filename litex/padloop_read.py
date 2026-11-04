#!/usr/bin/env python3
"""Arm the pad-loopback analyzer, do one BIST write (or read), print what was on the pads.
usage: padloop_read.py [cas|act] [nbursts] [row] [col]"""
import sys, time
from bios import Bios, csr
from bist_vs_dfii import gen_write

PINS = ["cs_n", "ras_n", "cas_n", "we_n", "ba0", "ba1", "ba2"] + [f"a{i}" for i in range(10)]
NCYC, W = 12, 8 * len(PINS)

mode = sys.argv[1] if len(sys.argv) > 1 else "cas"
nb = int(sys.argv[2]) if len(sys.argv) > 2 else 1
row = int(sys.argv[3]) if len(sys.argv) > 3 else 5
col = int(sys.argv[4]) if len(sys.argv) > 4 else 64
b = Bios(); b.sync()
b.write(csr("ddrphy_padloop_mode"), 1 if mode == "act" else 0)
b.write(csr("ddrphy_padloop_arm"), 1)
gen_write(b, (row << 15) | ((col // 8) << 5), nb)
print("done:", b.read(csr("ddrphy_padloop_done"))[0])
words = b.read(csr("ddrphy_padloop_snap"), NCYC * W // 32)
v = 0
for w in words:
    v = (v << 32) | w
hist = [(v >> (k * W)) & ((1 << W) - 1) for k in range(NCYC)]   # hist[0] newest
for pi_, name in enumerate(PINS):
    line = ""
    for k in reversed(range(NCYC)):
        byte = (hist[k] >> (8 * pi_)) & 0xFF
        line += "".join("1" if byte >> s & 1 else "." for s in range(8)) + " "
    print(f"{name:6s} {line}")
b.close()
