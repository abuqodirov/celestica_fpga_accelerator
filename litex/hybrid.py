#!/usr/bin/env python3
"""H1: DFII ACT, then HW write.  H2: HW write (HW ACT), then DFII write into the still-open row (no ACT)."""
from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, Dfii, pi
from bist_vs_dfii import gen_write, words_to_v, decode

ROW = 25
COLS = [0, 64, 72]
b = Bios(); b.sync()


def setall(c):
    for ph in range(4):
        b.write(pi(ph, 0x8), c); b.write(pi(ph, 0xC), 0)


def wr(c, data):
    setall(c); d.set_wrdata(data); b.write(pi(3, 0x0), CAS | WE | CS | WREN); b.write(pi(3, 0x4), 1)


def prefill():
    b.write(CTRL, SW); setall(0x400); b.write(pi(0, 0x0), RAS | WE | CS); b.write(pi(0, 0x4), 1)
    setall(ROW); b.write(pi(0, 0x0), RAS | CS); b.write(pi(0, 0x4), 1)
    for c in COLS:
        wr(c, [0xEEEEEEEE] * 8)
    setall(0x400); b.write(pi(0, 0x0), RAS | WE | CS); b.write(pi(0, 0x4), 1)


def probe(title):
    b.write(CTRL, SW)
    setall(0x400); b.write(pi(0, 0x0), RAS | WE | CS); b.write(pi(0, 0x4), 1)
    setall(ROW); b.write(pi(0, 0x0), RAS | CS); b.write(pi(0, 0x4), 1)
    out = []
    for c in COLS:
        setall(c); b.write(pi(3, 0x0), CAS | CS | RDEN); b.write(pi(3, 0x4), 1)
        w = d.rddata(); v = words_to_v(w)
        out.append(f"col {c}: " + ("--" if v == int("ee" * 32, 16) else
                   ("DFII-tag" if (w[0] >> 28) == 0xD else "gen k=" + "/".join(decode(v, 8)).replace(" ", ""))))
    setall(0x400); b.write(pi(0, 0x0), RAS | WE | CS); b.write(pi(0, 0x4), 1)
    b.write(CTRL, HW)
    print(title + ": " + "; ".join(out))


d = Dfii(b)
# H1: DFII ACT, switch to HW, HW write to col 64
prefill()
b.write(CTRL, SW); setall(ROW); b.write(pi(0, 0x0), RAS | CS); b.write(pi(0, 0x4), 1)
b.write(CTRL, HW); gen_write(b, (ROW << 15) | (64 // 8 << 5), 2)
probe("H1 DFII-ACT + HW write col 64")
# H2: HW write col 64 (controller ACT), then SW mode, DFII WR col 72 without ACT
prefill()
b.write(CTRL, HW); gen_write(b, (ROW << 15) | (64 // 8 << 5), 2)
b.write(CTRL, SW); wr(72, [0xD0000000 | i for i in range(8)])
probe("H2 HW write col 64, then DFII WR col 72 (no ACT)")
b.close()
