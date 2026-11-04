#!/usr/bin/env python3
"""Do HW-mode CAS commands pick up the DFII (software) address registers? Load pi0..pi3 address with
8/16/24/40 (and baddress 0), do one HW write to row R col 64, then DFII-probe the candidate columns."""
import sys
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, RDPHASE, WRPHASE, Dfii, pi
from bist_vs_dfii import gen_write, words_to_v, decode

row = int(sys.argv[1]) if len(sys.argv) > 1 else 13
regs = {0: 8, 1: 16, 2: 24, 3: 40}
cand = [0, 8, 16, 24, 40, 64]
b = Bios(); b.sync(); d = Dfii(b)
b.write(CTRL, SW); d.issue(0, RAS | WE | CS, 0x400); d.issue(0, RAS | CS, row, 0)
d.set_wrdata([0xEEEEEEEE] * 8)
for c in cand:
    d.issue(WRPHASE, CAS | WE | CS | WREN, c, 0)
d.issue(0, RAS | WE | CS, 0x400)
for ph, c in regs.items():                      # leave distinct values in the DFII address registers
    b.write(pi(ph, 0x8), c); b.write(pi(ph, 0xC), 0)
b.write(CTRL, HW)
gen_write(b, (row << 15) | ((64 // 8) << 5), 2)   # bursts k=0 (zeros), k=1
b.write(CTRL, SW); d = Dfii(b); d.issue(0, RAS | WE | CS, 0x400); d.issue(0, RAS | CS, row, 0)
for c in cand:
    d.issue(RDPHASE, CAS | CS | RDEN, c, 0)
    v = words_to_v(d.rddata())
    print(f"col {c:3d}: {'untouched' if v == int('ee' * 32, 16) else ' '.join(decode(v, 64))}")
d.issue(0, RAS | WE | CS, 0x400); b.write(CTRL, HW); b.close()
