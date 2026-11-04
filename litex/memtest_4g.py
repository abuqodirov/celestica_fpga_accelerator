#!/usr/bin/env python3
"""CPU memtest (BIOS mem_test: unique LFSR data per word, so aliasing shows) over ALL 4 GiB of a YPCB_DUAL +
YPCB_DDR0WIN SoC through the paged windows: channel 0 = 8 pages x 256 MiB at 0xD0000000, channel 1 = 2 pages x
1 GiB at 0x80000000. ~20 min. Channel 1 must be initialised first. usage: YPCB_BUILD=<build> memtest_4g.py"""
import time

import dram
from bios import Bios

b = Bios(freq=15e6); b.sync(); b.drain(0.5)
bad = 0
for ch in (0, 1):
    w = dram.WIN[ch]
    for page in range(dram.CH_SIZE // w["size"]):
        dram.set_page(b, ch, page)
        t = time.time()
        r = b.cmd(f"mem_test 0x{w['base']:08x} 0x{w['size']:x}", timeout=1200)
        ok = "Memtest OK" in r
        bad += not ok
        tail = [l.strip() for l in r.replace("\r", "\n").split("\n") if "error" in l.lower() or "Memtest" in l]
        print(f"ch{ch} page {page} ({w['size'] >> 20} MiB at ch offset {page * w['size'] >> 20} MiB): "
              f"{'OK' if ok else 'FAIL ' + ' | '.join(tail[-3:])} ({time.time() - t:.0f} s)", flush=True)
dram.set_page(b, 0, 0); dram.set_page(b, 1, 0)
print("memtest 4 GiB:", "PASS" if not bad else f"FAIL ({bad} pages)")
b.close()
