#!/usr/bin/env python3
"""Full-memory BIST: random data over the whole SDRAM in 16 MiB blocks, N passes."""
import sys, time
from bios import Bios
from bist_map import run

SIZE, BLK = int(sys.argv[2], 0) if len(sys.argv) > 2 else 0x40000000, 0x1000000
passes = int(sys.argv[1]) if len(sys.argv) > 1 else 1
b = Bios(); b.sync()
t0 = time.time()
for p in range(passes):
    tot, bad = 0, []
    blocks = [(off, BLK) for off in range(0, SIZE - BLK, BLK)]
    off, size = SIZE - BLK, BLK // 2                    # 30-bit BIST end address: split the last block
    while size >= 0x8000:                               # into power-of-two pieces (odd lengths break the BIST)
        blocks.append((off, size)); off += size; size //= 2
    for off, length in blocks:
        e = run(b, off, length)
        tot += e
        if e:
            bad.append(f"0x{off:08x}:{e}")
    print(f"pass {p + 1}: {sum(l for _, l in blocks) / 2**20:.2f} MiB tested, {tot} burst errors{(' in ' + ' '.join(bad)) if bad else ''} "
          f"({time.time() - t0:.0f} s)", flush=True)
b.close()
