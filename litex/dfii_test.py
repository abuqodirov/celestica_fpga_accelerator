#!/usr/bin/env python3
"""Drive the DDR3 by hand through LiteDRAM's DFII registers (software mode), bypassing the
controller, the L2 cache and the crossbar. Writes a distinct tag to several columns of one row,
then reads them all back. If every column returns its own tag, the DRAM sees column addresses
fine and the aliasing comes from above the PHY.

usage: dfii_test.py [--row R] [--bank B] [--cols 0,8,16,...]
"""
import argparse
import time

from bios import Bios, csr

CTRL = csr("sdram_dfii_control")
SW, HW = 0x0E, 0x01                       # CKE|ODT|RESET_N, SEL
CS, WE, CAS, RAS, WREN, RDEN = 1, 2, 4, 8, 0x10, 0x20
WRPHASE = RDPHASE = 3                     # SDRAM_PHY_WRPHASE / _RDPHASE


def pi(n, off):
    # per phase: command +0, issue +4, address +8, baddress +0xc, wrdata +0x10/+0x14, rddata +0x18/+0x1c
    return csr("sdram_dfii_pi0_command") + 0x20 * n + off


class Dfii:
    def __init__(self, b):
        self.b = b
        self.addr = [None] * 4
        self.bank = [None] * 4

    def issue(self, phase, command, address=0, bank=0):
        # Load the same address/bank into all four phases: on this board an address bit that is high in
        # two or more consecutive slots after being low is misread by the DRAMs, steady lines are safe.
        for p in range(4):
            if self.addr[p] != address:
                self.b.write(pi(p, 0x8), address)
                self.addr[p] = address
            if self.bank[p] != bank:
                self.b.write(pi(p, 0xC), bank)
                self.bank[p] = bank
        self.b.write(pi(phase, 0x0), command)
        self.b.write(pi(phase, 0x4), 1)

    def set_wrdata(self, words):          # 8 words: phase0 hi, lo, phase1 hi, lo, ...
        for p in range(4):
            self.b.write(pi(p, 0x10), words[2 * p])
            self.b.write(pi(p, 0x14), words[2 * p + 1])

    def rddata(self):
        w = self.b.read(pi(0, 0x18), 0x68 // 4)      # 0x201c .. 0x2083
        return [w[(0x20 * p) // 4 + k] for p in range(4) for k in (0, 1)]


def tag(col, i):
    return 0xA0000000 | (col << 12) | (0x11 * i)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--row", type=lambda s: int(s, 0), default=0x123)
    ap.add_argument("--bank", type=int, default=0)
    ap.add_argument("--cols", default="0,8,16,32,64,128,256,512")
    ap.add_argument("--log")
    args = ap.parse_args()
    cols = [int(c, 0) for c in args.cols.split(",")]

    b = Bios(log=args.log)
    b.sync()
    d = Dfii(b)
    t0 = time.time()
    b.write(CTRL, SW)
    d.issue(0, RAS | WE | CS, 0x400)                      # precharge all
    d.issue(0, RAS | CS, args.row, args.bank)             # activate
    for c in cols:
        d.set_wrdata([tag(c, i) for i in range(8)])
        d.issue(WRPHASE, CAS | WE | CS | WREN, c, args.bank)
    print(f"wrote {len(cols)} columns in {time.time() - t0:.1f} s")
    bad = 0
    for c in cols:
        d.issue(RDPHASE, CAS | CS | RDEN, c, args.bank)
        got = d.rddata()
        srcs = sorted({(w >> 12) & 0xFFFF for w in got if (w >> 28) == 0xA})
        ok = got == [tag(c, i) for i in range(8)]
        bad += not ok
        print(f"col {c:4d}: {'OK ' if ok else 'BAD'} " + " ".join(f"{w:08x}" for w in got)
              + ("" if ok else f"  (tags from cols {srcs})"))
    d.issue(0, RAS | WE | CS, 0x400)
    b.write(CTRL, HW)
    print(f"done in {time.time() - t0:.1f} s, {bad} bad columns")
    b.close()


if __name__ == "__main__":
    main()
