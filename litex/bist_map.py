#!/usr/bin/env python3
"""Drive the LiteDRAM BIST generator+checker directly (random data) over regions; print errors.
usage: bist_map.py [length_bytes] [offsets...]"""
import os
import sys
import time
from bios import Bios, csr

# BIST_CORE=sdram1 tests DDR3 channel 1 of a YPCB_DUAL SoC (default: the main core, channel 0)
_core = os.environ.get("BIST_CORE", "sdram")
GEN, CHK = csr(f"{_core}_generator_reset"), csr(f"{_core}_checker_reset")
# reset +0 start +4 done +8 base +0xc end +0x10 length +0x14 random +0x18 [chk: ticks +0x1c errors +0x20]


def run(b, base, length, random=1):
    for blk in (GEN, CHK):
        b.write(blk + 0x0, 1); b.write(blk + 0x18, random)
        b.write(blk + 0xC, base); b.write(blk + 0x10, base + length); b.write(blk + 0x14, length)
    b.write(GEN + 0x4, 1)
    wait_done(b, GEN)
    b.write(CHK + 0x4, 1)
    wait_done(b, CHK)
    return b.read(CHK + 0x20)[0]


def wait_done(b, blk, timeout=30):
    t0 = time.time()
    while b.read(blk + 0x8)[0] != 1:
        if time.time() - t0 > timeout:
            raise TimeoutError(f"BIST block 0x{blk:x} not done")


if __name__ == "__main__":
    length = int(sys.argv[1], 0) if len(sys.argv) > 1 else 0x10000
    offs = [int(x, 0) for x in sys.argv[2:]] or [0, 0x8000, 0x10000, 0x100000, 0x1000000, 0x10000000, 0x30000000]
    b = Bios(); b.sync()
    for off in offs:
        e = run(b, off, length)
        print(f"{length // 32:6d} bursts at 0x{off:08x} (row {off >> 15:5d}): {e} errors", flush=True)
    b.close()
