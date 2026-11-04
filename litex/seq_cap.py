#!/usr/bin/env python3
"""Separate single HW writes to cols in SEQ (row R) with a pad capture of each; then where they landed."""
import sys
from bios import Bios, csr
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, Dfii, pi
from bist_vs_dfii import gen_write, words_to_v

PINS = ["cs_n", "ras_n", "cas_n", "we_n", "ba0", "ba1", "ba2"] + [f"a{i}" for i in range(10)]
NCYC, W = 12, 8 * len(PINS)
row = int(sys.argv[1]); seq = [int(c) for c in sys.argv[2].split(",")]
probe = sorted(set(seq) | {0, 8, 16, 32, 64, 72, 128, 256, 512})
b = Bios(); b.sync(); d = Dfii(b)


def setall(v):
    for ph in range(4):
        b.write(pi(ph, 0x8), v); b.write(pi(ph, 0xC), 0)


def cmd(c, ph=0):
    b.write(pi(ph, 0x0), c); b.write(pi(ph, 0x4), 1)


def addr_slots():
    v = 0
    for w in b.read(csr("ddrphy_padloop_snap"), NCYC * W // 32):
        v = (v << 32) | w
    hist = [(v >> (k * W)) & ((1 << W) - 1) for k in range(NCYC)][::-1]   # oldest first
    bit = lambda k, pin, s: (hist[k] >> (8 * PINS.index(pin) + s)) & 1
    # slots are sample pairs (1,2),(3,4),(5,6),(7,0'); report the column (a3..a9) in each slot + command
    out = []
    for k in range(NCYC - 1):
        for s0 in (1, 3, 5, 7):
            s1 = (s0 + 1) % 8; k1 = k + (s0 == 7)
            col = sum(bit(k, f"a{i}", s0) << i for i in range(10))
            col2 = sum(bit(k1, f"a{i}", s1) << i for i in range(10))
            cs = bit(k, "cs_n", s0)
            out.append(("WR" if not cs and not bit(k, "cas_n", s0) else ("ACT" if not cs and not bit(k, "ras_n", s0) else "")) +
                       (f"{col}" if col == col2 else f"{col}/{col2}"))
    return out


b.write(CTRL, SW); d.set_wrdata([0xEEEEEEEE] * 8)
setall(0x400); cmd(RAS | WE | CS); setall(row); cmd(RAS | CS)
for c in probe:
    setall(c); cmd(CAS | WE | CS | WREN, 3)
setall(0x400); cmd(RAS | WE | CS)
b.write(CTRL, HW)
for c in seq:
    b.write(csr("ddrphy_padloop_mode"), 0); b.write(csr("ddrphy_padloop_arm"), 1)
    gen_write(b, (row << 15) | (c // 8 << 5), 1)
    sl = addr_slots()
    i = next(j for j, x in enumerate(sl) if x.startswith("WR"))
    print(f"write col {c:4d}: pin slots around WR: " + " ".join(sl[max(0, i - 6):i + 4]))
b.write(CTRL, SW)
setall(0x400); cmd(RAS | WE | CS); setall(row); cmd(RAS | CS)
hit = []
for c in probe:
    setall(c); cmd(CAS | CS | RDEN, 3)
    if words_to_v(d.rddata()) != int("ee" * 32, 16):
        hit.append(c)
setall(0x400); cmd(RAS | WE | CS); b.write(CTRL, HW); b.close()
print(f"-> written cols: {hit}")
