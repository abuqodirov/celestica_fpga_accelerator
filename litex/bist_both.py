#!/usr/bin/env python3
"""Stress test of a YPCB_DUAL SoC: LiteDRAM BIST on BOTH DDR3 channels at the same time (both write together,
then both check together), over the whole 2 GiB of each channel in 16 MiB blocks, N passes. Odd passes use
random data, even passes the BIST's counter pattern. Channel 1 must be initialised first (ch1_init.py).
usage: YPCB_BUILD=<build dir> bist_both.py [passes]"""
import sys
import time

from bios import Bios, csr
from bist_map import wait_done

CORES = ("sdram", "sdram1")
SIZE, BLK = 0x80000000, 0x1000000


def blocks():
    out = [(off, BLK) for off in range(0, SIZE - BLK, BLK)]
    off, size = SIZE - BLK, BLK // 2                    # the BIST end address is 31-bit: split the last block
    while size >= 0x8000:                               # into power-of-two pieces
        out.append((off, size)); off += size; size //= 2
    return out


def run_both(b, base, length, random):
    regs = [(csr(f"{c}_generator_reset"), csr(f"{c}_checker_reset")) for c in CORES]
    for gen, chk in regs:
        for blk in (gen, chk):
            b.write(blk + 0x0, 1); b.write(blk + 0x18, random)
            b.write(blk + 0xC, base); b.write(blk + 0x10, base + length); b.write(blk + 0x14, length)
    for gen, _ in regs:
        b.write(gen + 0x4, 1)
    for gen, _ in regs:
        wait_done(b, gen)
    for _, chk in regs:
        b.write(chk + 0x4, 1)
    for _, chk in regs:
        wait_done(b, chk)
    return [b.read(chk + 0x20)[0] for _, chk in regs]


passes = int(sys.argv[1]) if len(sys.argv) > 1 else 1
b = Bios(); b.sync()
t0 = time.time()
total = [0, 0]
for p in range(passes):
    random = 1 if p % 2 == 0 else 0
    errs, bad = [0, 0], []
    for off, length in blocks():
        e = run_both(b, off, length, random)
        for i in (0, 1):
            errs[i] += e[i]
            if e[i]:
                bad.append(f"ch{i}@0x{off:08x}:{e[i]}")
    total = [total[i] + errs[i] for i in (0, 1)]
    print(f"pass {p + 1} ({'random' if random else 'counter'}): ch0 {errs[0]} ch1 {errs[1]} burst errors"
          f"{(' in ' + ' '.join(bad[:8])) if bad else ''} ({time.time() - t0:.0f} s)", flush=True)
print(f"TOTAL over {passes} passes x 2 x 2 GiB: ch0 {total[0]} ch1 {total[1]} burst errors")
b.close()
