#!/usr/bin/env python3
"""Whole-4-GiB access test for the CPU / JTAG-loader path of a YPCB_DUAL + YPCB_DDR0WIN SoC (the BIST only proves
the controllers' own ports). For each channel, 256 KiB of random data is written through the JTAG loader and the
paged window at 17 offsets spread over the 2 GiB (every 128 MiB + the last 256 KiB), all written first, then the
window cache is evicted and every block is checked by the CPU's CRC (so a page/address aliasing bug that makes two
blocks land on the same DRAM shows up as a mismatch). Channel 0's first block is also read back through main RAM
(0x40000000, a different path: L2 cache) after the eviction. Channel 1 must be initialised first (ch1_init.py).
usage: YPCB_BUILD=<build dir> loader_test.py"""
import os
import random
import time
import zlib

import dram
from bios import Bios

BLK = 256 << 10
offsets = [i << 27 for i in range(16)] + [dram.CH_SIZE - BLK]
rng = random.Random(1017)
b = Bios(freq=15e6); b.sync(); b.drain(0.5)
bad = 0
for ch in (0, 1):
    t = time.time()
    blocks = {off: rng.randbytes(BLK) for off in offsets}
    for off, data in blocks.items():
        dram.write(b, ch, off, data)
    dram.evict(b, ch, page=0)
    res = []
    for off, data in blocks.items():
        ok = dram.crc(b, ch, off, BLK) == zlib.crc32(data)
        bad += not ok
        res.append(f"{off >> 20}M:{'ok' if ok else 'BAD'}")
    if ch == 0:
        b.cmd("flush_l2_cache", timeout=10)
        out = b.cmd(f"crc 0x40000000 {BLK}", timeout=30).strip().split()[-1]
        ok = int(out, 16) == zlib.crc32(blocks[0])
        bad += not ok
        res.append(f"via-main-RAM:{'ok' if ok else 'BAD'}")
    print(f"ch{ch} ({time.time() - t:.0f} s): " + " ".join(res), flush=True)
dram.set_page(b, 0, 0); dram.set_page(b, 1, 0)
print("loader test:", "PASS" if not bad else f"FAIL ({bad} bad)")
b.close()
