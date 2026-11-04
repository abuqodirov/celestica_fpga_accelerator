#!/usr/bin/env python3
"""DFII-write a distinct tag into every column of one row, then read them back in hardware mode
(CPU -> L2 refill = one controller READ per 32-byte line) with READ on phase 3 and then phase 2.
Usage: hw_read_test.py [row]   (row must not have been read through the caches before)"""
import re
import sys

from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, WRPHASE, Dfii

row = int(sys.argv[1]) if len(sys.argv) > 1 else 7
cols = list(range(0, 128, 8))
b = Bios()
b.sync()
d = Dfii(b)
b.write(CTRL, SW)
d.issue(0, RAS | WE | CS, 0x400)
d.issue(0, RAS | CS, row, 0)
for c in cols:
    d.set_wrdata([0xC0000000 | (row << 16) | c << 4 | i for i in range(8)])
    d.issue(WRPHASE, CAS | WE | CS | WREN, c, 0)
d.issue(0, RAS | WE | CS, 0x400)
b.write(CTRL, HW)

for rd, sub in ((3, 0), (2, 0x400)):    # second pass reads the next row up so the caches miss again
    b.cmd(f"sdram_force_rdphase {rd}")
    cal = b.cmd("sdram_cal", timeout=120)
    lv = re.findall(r"best: m(\d), b(\d\d) delays: (\d+)", cal)
    print(f"rdphase {rd}: leveling " + " ".join(f"m{m}:b{s}/{dl}" for m, s, dl in lv))
    if rd == 2:  # write the same tags again into row+1 (fresh for the caches)
        row2 = row + 1
        b.write(CTRL, SW); d = Dfii(b)
        d.issue(0, RAS | WE | CS, 0x400); d.issue(0, RAS | CS, row2, 0)
        for c in cols:
            d.set_wrdata([0xC0000000 | (row2 << 16) | c << 4 | i for i in range(8)])
            d.issue(WRPHASE, CAS | WE | CS | WREN, c, 0)
        d.issue(0, RAS | WE | CS, 0x400); b.write(CTRL, HW)
    r = row if rd == 3 else row + 1
    line = []
    for c in cols:
        addr = 0x40000000 + (r << 15) + c * 4
        w = b.read(addr, 1)[0]
        got_col = (w >> 4) & 0xFFF if (w >> 28) == 0xC else None
        line.append(f"{c}:{'ok' if got_col == c else ('c' + str(got_col) if got_col is not None else hex(w))}")
    print("   col:result  " + " ".join(line))
b.close()
