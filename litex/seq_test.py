#!/usr/bin/env python3
"""Separate single-burst HW writes (all-zero data) to cols A, B, C... of row R.
Probe columns are prefilled with 0xEE by DFII and read back first (baseline); a column counts as
written only if it changed from its baseline to all-zero. Glitchy prefill columns are reported."""
import sys
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, Dfii, pi
from bist_vs_dfii import gen_write, words_to_v

row = int(sys.argv[1]); seq = [int(c) for c in sys.argv[2].split(",")]
probe = sorted(set(seq) | {0, 8, 16, 24, 48, 56, 64, 72, 80, 88, 104, 112, 120, 512})
b = Bios(); b.sync(); d = Dfii(b)


def setall(v):
    for ph in range(4):
        b.write(pi(ph, 0x8), v); b.write(pi(ph, 0xC), 0)


def cmd(c, ph=0):
    b.write(pi(ph, 0x0), c); b.write(pi(ph, 0x4), 1)


def readall():
    setall(0x400); cmd(RAS | WE | CS); setall(row); cmd(RAS | CS)
    out = {}
    for c in probe:
        setall(c); cmd(CAS | CS | RDEN, 3)
        out[c] = words_to_v(d.rddata())
    setall(0x400); cmd(RAS | WE | CS)
    return out


b.write(CTRL, SW); d.set_wrdata([0xEEEEEEEE] * 8)
setall(0x400); cmd(RAS | WE | CS); setall(row); cmd(RAS | CS)
for c in probe:
    setall(c); cmd(CAS | WE | CS | WREN, 3)
base = readall()
glitch = [c for c in probe if base[c] != int("ee" * 32, 16)]
b.write(CTRL, HW)
for c in seq:
    gen_write(b, (row << 15) | (c // 8 << 5), 1)
b.write(CTRL, SW)
after = readall()
b.write(CTRL, HW); b.close()
hit = [c for c in probe if after[c] != base[c] and after[c] == 0]
odd = [c for c in probe if after[c] != base[c] and after[c] != 0]
print(f"HW single writes to cols {seq} (in that order) -> written cols: {hit}"
      + (f"  partial: {odd}" if odd else "") + (f"  (glitchy prefill: {glitch})" if glitch else ""))
