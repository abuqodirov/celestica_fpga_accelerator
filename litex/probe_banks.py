#!/usr/bin/env python3
"""HW-mode generator write of N bursts at (row, bank, col); then DFII-probe col 0 and the target col of
rows {0, row} in every bank (each probed location prefilled with 0xEE first)."""
import sys
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, RDPHASE, WRPHASE, Dfii
from bist_vs_dfii import gen_write, words_to_v, decode

row, col, nb = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
bank = int(sys.argv[4]) if len(sys.argv) > 4 else 0
locs = sorted({(bk, r, c) for bk in range(8) for r in (0, row) for c in (0, col)})
b = Bios(); b.sync(); d = Dfii(b)
b.write(CTRL, SW); d.issue(0, RAS | WE | CS, 0x400); d.set_wrdata([0xEEEEEEEE] * 8)
for bk, r, c in locs:
    d.issue(0, RAS | CS, r, bk); d.issue(WRPHASE, CAS | WE | CS | WREN, c, bk); d.issue(0, RAS | WE | CS, 0x400)
b.write(CTRL, HW)
addr = (row << 15) | (bank << 12) | ((col // 8) << 5)
print(f"generator {nb} bursts at row {row} bank {bank} col {col} (0x{addr:x}): done={gen_write(b, addr, nb)}")
b.write(CTRL, SW); d = Dfii(b); d.issue(0, RAS | WE | CS, 0x400)
for bk, r, c in locs:
    d.issue(0, RAS | CS, r, bk); d.issue(RDPHASE, CAS | CS | RDEN, c, bk)
    v = words_to_v(d.rddata()); d.issue(0, RAS | WE | CS, 0x400)
    if v != int("ee" * 32, 16):
        print(f"  bank {bk} row {r:5d} col {c:4d}: " + " ".join(decode(v, nb + 64)))
b.write(CTRL, HW); b.close()
