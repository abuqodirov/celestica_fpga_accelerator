#!/usr/bin/env python3
"""DFII WRITE on phase 3 with a chosen static per-phase address pattern; read back cols safely
(all four address registers = the column being read). usage: dfii_pattern.py p0 p1 p2 p3 [row]"""
import sys
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, Dfii, pi

pat = [int(x) for x in sys.argv[1:5]]
row = int(sys.argv[5]) if len(sys.argv) > 5 else 21
cand = sorted(set(pat) | {0, 64})
b = Bios(); b.sync(); d = Dfii(b)


def setall(c):
    for ph in range(4):
        b.write(pi(ph, 0x8), c)


b.write(CTRL, SW); d.issue(0, RAS | WE | CS, 0x400)
setall(row); b.write(pi(0, 0xC), 0); b.write(pi(0, 0x0), RAS | CS); b.write(pi(0, 0x4), 1)
d.set_wrdata([0xEEEEEEEE] * 8)
for c in cand:
    setall(c); b.write(pi(3, 0x0), CAS | WE | CS | WREN); b.write(pi(3, 0x4), 1)
for ph in range(4):
    b.write(pi(ph, 0x8), pat[ph])
d.set_wrdata([0xD0000000 | i for i in range(8)])
b.write(pi(3, 0x0), CAS | WE | CS | WREN); b.write(pi(3, 0x4), 1)
res = []
for c in cand:
    setall(c); b.write(pi(3, 0x0), CAS | CS | RDEN); b.write(pi(3, 0x4), 1)
    w = d.rddata()
    if any((x >> 28) == 0xD for x in w):
        res.append(c)
print(f"pattern P0..P3 = {pat}, WRITE on P3 -> landed in col {res}")
d.issue(0, RAS | WE | CS, 0x400); b.write(CTRL, HW); b.close()
