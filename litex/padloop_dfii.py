#!/usr/bin/env python3
"""Capture the serializer output (OFB padloop) for a DFII-issued WRITE on phase 3 with distinct
per-phase addresses (P0..P3 = 8,16,24,32), to compare with a hardware-mode WRITE."""
from bios import Bios, csr
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, Dfii, pi

PINS = ["cs_n", "ras_n", "cas_n", "we_n", "ba0", "ba1", "ba2"] + [f"a{i}" for i in range(10)]
NCYC, W = 12, 8 * len(PINS)
b = Bios(); b.sync(); d = Dfii(b)
b.write(CTRL, SW); d.issue(0, RAS | WE | CS, 0x400); d.issue(0, RAS | CS, 9, 0)
for ph, c in {0: 8, 1: 16, 2: 24, 3: 32}.items():
    b.write(pi(ph, 0x8), c)
b.write(csr("ddrphy_padloop_mode"), 0); b.write(csr("ddrphy_padloop_arm"), 1)
b.write(pi(3, 0x0), CAS | WE | CS | WREN); b.write(pi(3, 0x4), 1)
print("padloop done:", b.read(csr("ddrphy_padloop_done"))[0])
v = 0
for w in b.read(csr("ddrphy_padloop_snap"), NCYC * W // 32):
    v = (v << 32) | w
hist = [(v >> (k * W)) & ((1 << W) - 1) for k in range(NCYC)]
for i, name in enumerate(PINS):
    print(f"{name:6s} " + " ".join("".join("1" if (hist[k] >> (8 * i + s)) & 1 else "." for s in range(8))
                                   for k in reversed(range(NCYC))))
d.issue(0, RAS | WE | CS, 0x400); b.write(CTRL, HW); b.close()
