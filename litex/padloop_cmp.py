#!/usr/bin/env python3
"""One HW access, then print side by side: the DFI window (spy: what the controller handed the PHY)
and the serializer output captured through OFB (padloop). usage: padloop_cmp.py cas|act row col"""
import sys
from bios import Bios, csr
from bist_vs_dfii import gen_write
from window_read import dec

PINS = ["cs_n", "ras_n", "cas_n", "we_n", "ba0", "ba1", "ba2"] + [f"a{i}" for i in range(10)]
NCYC, W = 12, 8 * len(PINS)
mode, row, col = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
b = Bios(); b.sync()
b.write(csr("ddrphy_padloop_mode"), 1 if mode == "act" else 0)
b.write(csr("ddrphy_padloop_arm"), 1)
gen_write(b, (row << 15) | ((col // 8) << 5), 1)
print("padloop done:", b.read(csr("ddrphy_padloop_done"))[0])
v = 0
for w in b.read(csr("ddrphy_padloop_snap"), NCYC * W // 32):
    v = (v << 32) | w
hist = [(v >> (k * W)) & ((1 << W) - 1) for k in range(NCYC)]
for i, name in enumerate(PINS):
    print(f"{name:6s} " + " ".join("".join("1" if (hist[k] >> (8 * i + s)) & 1 else "." for s in range(8))
                                   for k in reversed(range(NCYC))))
print(f"DFI window around last {mode.upper()} (spy):")
for t in ("m1", "t0", "p1"):
    print(f"  {t}: " + " | ".join(dec(b.read(csr(f'dramspy_w{mode}_{t}_p{i}'))[0]) for i in range(4)))
b.close()
