#!/usr/bin/env python3
"""Write tags through the normal bus path (CPU -> L2 cache -> LiteDRAM controller), then look at the
DRAM directly with DFII software-mode reads to see where each write really landed.

Byte address map (ROW_BANK_COL, 32-byte bursts): bits 5-11 = column A3-A9, 12-14 = bank, 15+ = row.
"""
import argparse

from bios import Bios
from dfii_test import CTRL, SW, HW, CS, WE, CAS, RAS, RDEN, RDPHASE, Dfii

BASE = 0x40000000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offsets", default="0x0,0x20,0x40,0x80,0x100,0x200,0x400,0x800")
    ap.add_argument("--evict", type=lambda s: int(s, 0), default=0x40100000)
    ap.add_argument("--log")
    args = ap.parse_args()
    offs = [int(o, 0) for o in args.offsets.split(",")]

    b = Bios(log=args.log)
    b.sync()
    b.write(CTRL, HW)
    # 1. writes through the bus: tag = 0xB0000000 | offset, in the first word of each burst
    for o in offs:
        b.write(BASE + o, 0xB0000000 | o)
    # 2. push them out of the L2 cache (8 KiB) by writing 32 KiB elsewhere
    b.cmd(f"mem_write 0x{args.evict:08x} 0 8192")
    # 3. read back through the bus
    print("bus readback:")
    for o in offs:
        v = b.read(BASE + o)[0]
        print(f"  0x{BASE + o:08x}: {v:08x} {'OK' if v == (0xB0000000 | o) else 'BAD'}")
    # 4. look at the DRAM directly: every column of row 0, bank 0
    b.write(CTRL, SW)
    d = Dfii(b)
    d.issue(0, RAS | WE | CS, 0x400)
    d.issue(0, RAS | CS, 0, 0)
    print("DRAM row 0 bank 0 (DFII), columns holding a 0xB tag:")
    found = {}
    for col in range(0, 1024, 8):
        d.issue(RDPHASE, CAS | CS | RDEN, col, 0)
        w = d.rddata()
        tags = [x for x in w if (x >> 28) == 0xB]
        if tags:
            found[col] = tags
            print(f"  col {col:4d} (byte offset 0x{col * 4:04x}): " + " ".join(f"{x:08x}" for x in w))
    d.issue(0, RAS | WE | CS, 0x400)
    b.write(CTRL, HW)
    if not found:
        print("  none")
    b.close()


if __name__ == "__main__":
    main()
