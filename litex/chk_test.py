#!/usr/bin/env python3
"""DFII-write the BIST counter pattern (burst k = 31-bit k replicated) into N bursts of one row, then
run the BIST *checker* (hardware-mode READs, no CPU/L2) for rdphase 3 and 2 and report its errors."""
import re, sys
from bios import Bios, csr
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, WRPHASE, Dfii
from bist_vs_dfii import rep

row, n = int(sys.argv[1]) if len(sys.argv) > 1 else 11, int(sys.argv[2]) if len(sys.argv) > 2 else 16
CHK = csr("sdram_checker_reset")   # reset +0 start +4 done +8 base +0xc end +0x10 length +0x14 random +0x18 ticks +0x1c errors +0x20


def v_to_words(v):  # inverse of words_to_v: p0 hi, p0 lo, p1 hi, ...
    w = []
    for p in range(4):
        sl = (v >> (64 * p)) & ((1 << 64) - 1)
        w += [sl >> 32, sl & 0xFFFFFFFF]
    return w


b = Bios(); b.sync()
for rd in (3, 2):
    b.cmd(f"sdram_force_rdphase {rd}")
    cal = b.cmd("sdram_cal", timeout=120)
    lv = " ".join(f"m{m}:b{s}" for m, s in re.findall(r"best: m(\d), b(\d\d)", cal))
    d = Dfii(b)
    b.write(CTRL, SW)
    d.issue(0, RAS | WE | CS, 0x400); d.issue(0, RAS | CS, row, 0)
    for k in range(n):
        d.set_wrdata(v_to_words(rep(k)))
        d.issue(WRPHASE, CAS | WE | CS | WREN, 8 * k, 0)
    d.issue(0, RAS | WE | CS, 0x400)
    b.write(CTRL, HW)
    base = row << 15
    b.write(CHK + 0x0, 1); b.write(CHK + 0x18, 0)
    b.write(CHK + 0xC, base); b.write(CHK + 0x10, base + 32 * n); b.write(CHK + 0x14, 32 * n)
    b.write(CHK + 0x4, 1)
    print(f"rdphase {rd} (leveling {lv}): checker done={b.read(CHK + 0x8)[0]} errors={b.read(CHK + 0x20)[0]}/{n} bursts")
b.close()
