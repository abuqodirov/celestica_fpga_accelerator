#!/usr/bin/env python3
"""Post-build check for SoCs with matvec engines (single or dual channel), used by litex/build_good.sh CHECK=...:
for every engine, upload 512 rows of layer-0 qkv (data/qkv.*, acc_test.py prep), check the CPU's CRC of the
upload TWICE (catches a flaky CPU/L2 path), run the engine TWICE, require bit-exact results both times.
Exit 0 only if everything passes. Channel 1 must already be initialised (build_good.sh runs ch1_init.py first).
usage: YPCB_BUILD=<build dir> engine_selftest.py"""
import os
import random
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from dual_test import CH, DATA, K, RW, Bios, check, csr, start, upload, wait  # noqa: E402

ROWS = 512


def main():
    build = os.environ["YPCB_BUILD"]
    dual = "csr_base,mvacc1," in open(os.path.join(build, "csr.csv")).read()
    q4h = open(os.path.join(DATA, "qkv.q4h"), "rb").read()
    act = open(os.path.join(DATA, "qkv.act"), "rb").read()
    exp = struct.unpack("<4608I", open(os.path.join(DATA, "qkv.exp"), "rb").read())
    b = Bios(freq=15e6); b.sync(); b.drain(1.0)
    ok, notes = True, []
    if dual:
        b.write(csr("ddr1_page"), 0)
    for ch in ([0, 1] if dual else [0]):
        r0 = ch * 2304
        img = q4h[r0 * RW * 64:(r0 + ROWS) * RW * 64]
        # a random place each run: DRAM keeps its contents across FPGA reloads, and with a fixed address the data
        # of earlier runs made a broken write path look 511/512 correct (build_dacc7 s1, 2026-10-17)
        off = random.randrange(0, 32 << 20, 64)
        w, dram = CH[ch]["w"] + off, CH[ch]["dram"] + off // 64
        upload(b, w, img)
        crcs = [int(b.cmd(f"crc 0x{w:08x} {len(img)}", timeout=120).split()[-1], 16) for _ in range(2)]
        if ch == 1:
            b.cmd("crc 0xa0000000 65536", timeout=60)                 # evict the ddr1 window cache
        crc_ok = all(c == zlib.crc32(img) for c in crcs)
        upload(b, CH[ch]["win"], act[:K]); upload(b, CH[ch]["win"] + 0x1000 * 4, act[K:])
        bads = []
        for _ in range(2):
            start(b, ch, dram, ROWS * RW, ROWS)
            st, cyc = wait(b, ch)
            bads.append(check(b, ch, ROWS, exp[r0:r0 + ROWS]) if cyc else -1)
        good = crc_ok and bads == [0, 0]
        ok &= good
        notes.append(f"ch{ch} @+{off >> 10}K crc {'ok' if crc_ok else 'BAD'} engine {'ok' if bads == [0, 0] else bads}")
    print("engine selftest:", "PASS" if ok else "FAIL", "|", "; ".join(notes))
    b.close()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
