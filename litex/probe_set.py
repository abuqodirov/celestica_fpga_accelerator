#!/usr/bin/env python3
"""HW write 1 burst to (row, col) in bank 0, then DFII-probe a set of (row, col) locations (prefilled).
usage: probe_set.py row col "r1:c1,r2:c2,..." """
import sys
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, Dfii, pi
from bist_vs_dfii import gen_write, words_to_v, decode

row, col = int(sys.argv[1]), int(sys.argv[2])
locs = [tuple(int(x) for x in s.split(":")) for s in sys.argv[3].split(",")]
b = Bios(); b.sync(); d = Dfii(b)


def setall(v, ba=0):
    for ph in range(4):
        b.write(pi(ph, 0x8), v); b.write(pi(ph, 0xC), ba)


def cmd(c, ph=0):
    b.write(pi(ph, 0x0), c); b.write(pi(ph, 0x4), 1)


b.write(CTRL, SW); d.set_wrdata([0xEEEEEEEE] * 8)
for r, c in locs:
    setall(0x400); cmd(RAS | WE | CS); setall(r); cmd(RAS | CS); setall(c); cmd(CAS | WE | CS | WREN, 3)
setall(0x400); cmd(RAS | WE | CS)
b.write(CTRL, HW)
gen_write(b, (row << 15) | (col // 8 << 5), int(sys.argv[4]) if len(sys.argv) > 4 else 2)
b.write(CTRL, SW)
for r, c in locs:
    setall(0x400); cmd(RAS | WE | CS); setall(r); cmd(RAS | CS); setall(c); cmd(CAS | CS | RDEN, 3)
    v = words_to_v(d.rddata())
    print(f"  row {r:4d} col {c:4d}: " + ("--" if v == int("ee" * 32, 16) else " ".join(decode(v, 8))))
setall(0x400); cmd(RAS | WE | CS); b.write(CTRL, HW); b.close()
