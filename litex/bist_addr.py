#!/usr/bin/env python3
"""Address-line test for the high address bits that the block-wise BIST cannot see (every block starts the same
data sequence, so two aliased blocks would still compare equal). For each address bit k from 20 (1 MiB) to 30
(1 GiB): write 1 MiB at 0 with random data, 1 MiB at 1<<k with the counter pattern, then check 0 (bit stuck at 0
-> the second write landed on 0); then the reverse order and check 1<<k (stuck at 1). Bits below 20 are covered
by the BIST itself (data within a block is unique).
usage: YPCB_BUILD=<build dir> BIST_CORE=sdram|sdram1 bist_addr.py"""
import os

import bist_map
from bios import Bios

LEN = 1 << 20
CHK, GEN = bist_map.CHK, bist_map.GEN


def write(b, base, random):
    b.write(GEN + 0x0, 1); b.write(GEN + 0x18, random)
    b.write(GEN + 0xC, base); b.write(GEN + 0x10, base + LEN); b.write(GEN + 0x14, LEN)
    b.write(GEN + 0x4, 1); bist_map.wait_done(b, GEN)


def check(b, base, random):
    b.write(CHK + 0x0, 1); b.write(CHK + 0x18, random)
    b.write(CHK + 0xC, base); b.write(CHK + 0x10, base + LEN); b.write(CHK + 0x14, LEN)
    b.write(CHK + 0x4, 1); bist_map.wait_done(b, CHK)
    return b.read(CHK + 0x20)[0]


b = Bios(); b.sync()
bad = 0
for k in range(20, 31):
    hi = 1 << k
    write(b, 0, 1); write(b, hi, 0); e0 = check(b, 0, 1)
    write(b, hi, 0); write(b, 0, 1); e1 = check(b, hi, 0)
    bad += (e0 != 0) + (e1 != 0)
    print(f"bit {k:2d} ({hi >> 20:5d} MiB): stuck-0 {'ok' if not e0 else f'{e0} errors'}, "
          f"stuck-1 {'ok' if not e1 else f'{e1} errors'}", flush=True)
# positive control: 2 GiB is beyond the channel, so the address wraps to 0 and the test MUST report errors
write(b, 0, 1); write(b, 1 << 31, 0); ctl = check(b, 0, 1)
print(f"control (2 GiB, wraps to 0, must fail): {'detected, ' + str(ctl) + ' errors' if ctl else 'NOT DETECTED - test is blind'}")
bad += ctl == 0
print(f"{os.environ.get('BIST_CORE', 'sdram')}: address bits 20..30 {'ALL OK' if not bad else f'{bad} FAILED'}")
b.close()
