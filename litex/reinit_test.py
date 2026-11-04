#!/usr/bin/env python3
"""Re-run the BIOS DDR3 init (PHY reset + read leveling) N times on the loaded bitstream; one summary line per run.
Tells apart a lane failure fixed by the bitstream (same every run) from one decided at reset (changes).
usage: [YPCB_BUILD=dir] reinit_test.py [N]"""
import re
import sys

from bios import Bios

n = int(sys.argv[1]) if len(sys.argv) > 1 else 5
b = Bios(freq=15e6); b.sync(); b.drain(1.0)
for i in range(n):
    out = b.cmd("sdram_init", timeout=240)
    best = re.findall(r"best: (m\d), (b\d\d) delays: (\S+)", out)
    mt = "Memtest OK" if "Memtest OK" in out else "Memtest KO"
    print(f"run {i + 1}: " + " ".join(f"{m}:{d}" if d != "-" else f"{m}:----" for m, bs, d in best) + f" | {mt}", flush=True)
b.close()
