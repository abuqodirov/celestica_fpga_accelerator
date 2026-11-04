#!/usr/bin/env python3
"""Sweep the PHY's rdphase/wrphase at runtime (the controller steers READ/WRITE with them),
recalibrate, and run the BIST hardware memtest for each combination."""
import re
import sys

from bios import Bios

b = Bios(log=sys.argv[1] if len(sys.argv) > 1 else None)
b.sync()
for wr in range(4):
    for rd in range(4):
        b.cmd(f"sdram_force_wrphase {wr}")
        b.cmd(f"sdram_force_rdphase {rd}")
        cal = b.cmd("sdram_cal", timeout=120)
        best = re.findall(r"best: m(\d), b(\d\d) delays: (\d+)", cal)
        res = []
        for size, burst in (("0x1000", 1), ("0x10000", 2048)):
            out = b.cmd(f"sdram_hw_test 0 {size} {burst}", timeout=120)
            m = re.search(r"(\d+) errors found", out)
            res.append(m.group(1) if m else "?")
        lv = " ".join(f"m{m}:b{s}/{d}" for m, s, d in best)
        print(f"wr={wr} rd={rd}  leveling {lv or 'FAILED'}  hw_test 4K/burst1: {res[0]:>4}/128   64K/burst2048: {res[1]:>4}/2048", flush=True)
b.close()
