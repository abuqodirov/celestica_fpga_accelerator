#!/usr/bin/env python3
"""Hardware-mode writes by the BIST generator (counter data: burst k = 31-bit k replicated over 256 bits),
then a raw look at the DRAM through DFII. Each 64-bit DFI phase slice of every burst is decoded back
to the k it came from, so misplaced or shifted data shows up directly.

Row 0 / bank 0 is first filled with 0xEEEEEEEE by DFII so untouched bursts are recognisable.
"""
import argparse

from bios import Bios, csr
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, WREN, RDEN, RDPHASE, WRPHASE, Dfii

GEN = csr("sdram_generator_reset")  # reset +0, start +4, done +8, base +0xc, end +0x10, length +0x14, random +0x18
M256 = (1 << 256) - 1


def rep(k):
    v = 0
    for j in range(9):
        v |= k << (31 * j)
    return v & M256


def words_to_v(w):  # rddata order: p0 hi, p0 lo, p1 hi, p1 lo, ...
    v = 0
    for p in range(4):
        v |= w[2 * p + 1] << (64 * p) | w[2 * p] << (64 * p + 32)
    return v


def decode(v, kmax):
    out = []
    for p in range(4):
        sl = (v >> (64 * p)) & ((1 << 64) - 1)
        if sl == 0xEEEEEEEEEEEEEEEE:
            out.append("  ----")
            continue
        hit = [k for k in range(kmax) if (rep(k) >> (64 * p)) & ((1 << 64) - 1) == sl]
        out.append(f"{hit[0]:6d}" if hit else "     ?")
    return out


def prefill(b, d, rows, bank, ncols):
    b.write(CTRL, SW)
    d.issue(0, RAS | WE | CS, 0x400)
    d.set_wrdata([0xEEEEEEEE] * 8)
    for r in rows:
        d.issue(0, RAS | CS, r, bank)
        for i in range(ncols):
            d.issue(WRPHASE, CAS | WE | CS | WREN, 8 * i, bank)
        d.issue(0, RAS | WE | CS, 0x400)
    b.write(CTRL, HW)


def gen_write(b, addr, nbursts):
    b.write(GEN + 0x0, 1)
    b.write(GEN + 0x18, 0)                   # counter data, sequential addresses
    b.write(GEN + 0xC, addr)
    b.write(GEN + 0x10, addr + 32 * nbursts)
    b.write(GEN + 0x14, 32 * nbursts)
    b.write(GEN + 0x4, 1)
    return b.read(GEN + 0x8)[0]


def scan(b, d, rows, bank, ncols, kmax):
    b.write(CTRL, SW)
    d.issue(0, RAS | WE | CS, 0x400)
    for r in rows:
        d.issue(0, RAS | CS, r, bank)
        for i in range(ncols):
            d.issue(RDPHASE, CAS | CS | RDEN, 8 * i, bank)
            v = words_to_v(d.rddata())
            if v != rep(0xEEEEEEEE) and v != int("ee" * 32, 16):
                print(f"  row {r:5d} bank {bank} col {8 * i:4d}: " + " ".join(decode(v, kmax)))
        d.issue(0, RAS | WE | CS, 0x400)
    b.write(CTRL, HW)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--row", type=int, default=5)
    ap.add_argument("--bank", type=int, default=0)
    ap.add_argument("--col", type=int, default=64)
    ap.add_argument("--bursts", type=int, default=4)
    ap.add_argument("--rows", default="0,5")
    ap.add_argument("--ncols", type=int, default=128)
    args = ap.parse_args()
    rows = [int(r) for r in args.rows.split(",")]

    b = Bios()
    b.sync()
    d = Dfii(b)
    prefill(b, d, rows, args.bank, args.ncols)
    addr = (args.row << 15) | (args.bank << 12) | ((args.col // 8) << 5)
    print(f"generator: {args.bursts} bursts (k = 0..{args.bursts - 1}) at byte 0x{addr:x} = row {args.row} "
          f"bank {args.bank} col {args.col}; done={gen_write(b, addr, args.bursts)}")
    print("bursts that changed (k per 64-bit phase slice; k=0 is all-zero data):")
    scan(b, Dfii(b), rows, args.bank, args.ncols, 4 * args.bursts + 64)
    b.close()


if __name__ == "__main__":
    main()
