#!/usr/bin/env python3
"""HW-mode generator writes (2 bursts) to col 0 of each given row (bank 0); then DFII-probe col 0 of
those rows and of row 0, after prefilling them with 0xEE.  usage: probe_rows.py 8 64 ..."""
import sys
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, RDPHASE, WRPHASE, Dfii
from bist_vs_dfii import gen_write, words_to_v, decode

rows = [int(r) for r in sys.argv[1:]]
probe = sorted(set(rows) | {0})
b = Bios(); b.sync()
for r in rows:
    d = Dfii(b)
    b.write(CTRL, SW); d.issue(0, RAS | WE | CS, 0x400); d.set_wrdata([0xEEEEEEEE] * 8)
    for pr in probe:
        d.issue(0, RAS | CS, pr, 0); d.issue(WRPHASE, CAS | WE | CS | WREN, 0, 0); d.issue(0, RAS | WE | CS, 0x400)
    b.write(CTRL, HW)
    gen_write(b, r << 15, 2)
    b.write(CTRL, SW); d = Dfii(b); d.issue(0, RAS | WE | CS, 0x400)
    found = []
    for pr in probe:
        d.issue(0, RAS | CS, pr, 0); d.issue(RDPHASE, CAS | CS | RDEN, 0, 0)
        v = words_to_v(d.rddata()); d.issue(0, RAS | WE | CS, 0x400)
        if v != int("ee" * 32, 16):
            found.append(f"row {pr}: " + " ".join(decode(v, 66)).replace("  ", " "))
    b.write(CTRL, HW)
    print(f"HW write -> row {r:5d} (bits {[i for i in range(15) if r >> i & 1]}): landed in " + ("; ".join(found) or "none of " + str(probe)))
b.close()
