#!/usr/bin/env python3
"""DFII: which phase's address does the DRAM use for a WRITE issued on phase P?
Each phase's address register holds a different column (P0=8, P1=16, P2=24, P3=32); the WRITE is
issued on phase P, then columns 0..40 are read back with all address registers set to the column."""
import sys
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, RDPHASE, Dfii, pi
from bist_vs_dfii import words_to_v

COLS = {0: 8, 1: 16, 2: 24, 3: 32}
b = Bios(); b.sync(); d = Dfii(b)
b.write(CTRL, SW)
row = int(sys.argv[1]) if len(sys.argv) > 1 else 9
for P in range(4):
    d.issue(0, RAS | WE | CS, 0x400)
    d.issue(0, RAS | CS, row, 0)
    d.set_wrdata([0xEEEEEEEE] * 8)
    for c in [0] + list(COLS.values()) + [40]:      # background
        d.issue(3, CAS | WE | CS | WREN, c, 0)
    for ph, c in COLS.items():                        # distinct address per phase
        b.write(pi(ph, 0x8), c); d.addr[ph] = c
    d.set_wrdata([0xD0000000 | P << 8 | i for i in range(8)])
    b.write(pi(P, 0x0), CAS | WE | CS | WREN); b.write(pi(P, 0x4), 1)
    landed = []
    for c in [0] + list(COLS.values()) + [40]:
        d.issue(RDPHASE, CAS | CS | RDEN, c, 0)
        w = d.rddata()
        if any((x >> 28) == 0xD for x in w):
            landed.append(f"col {c}" + ("" if all((x >> 28) == 0xD for x in w) else " (partial)"))
    print(f"WRITE issued on phase {P}: addresses P0..P3 = 8,16,24,32 -> landed in {', '.join(landed) or 'nowhere'}")
d.issue(0, RAS | WE | CS, 0x400)
b.write(CTRL, HW)
b.close()
