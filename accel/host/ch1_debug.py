#!/usr/bin/env python3
"""Isolate the channel-1 engine failure (YPCB_BUILD = dual SoC, channel 1 initialised):
  A  engine 0 on rows 2304.. (the half engine 1 got wrong), weights uploaded to channel 0
  B  engine 1 on rows 2304.. again, after a fresh activation upload
  C  engine 1 on rows 0.. (the half engine 0 gets right), weights uploaded to channel 1"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ.setdefault("YPCB_BUILD", os.path.join(HERE, "..", "..", "litex", "build_dacc2"))
from dual_test import CH, DATA, K, RW, Bios, check, csr, start, upload, wait  # noqa: E402

q4h = open(os.path.join(DATA, "qkv.q4h"), "rb").read()
act = open(os.path.join(DATA, "qkv.act"), "rb").read()
exp = struct.unpack("<4608I", open(os.path.join(DATA, "qkv.exp"), "rb").read())
H = 2304


def put(b, ch, r0):
    img = q4h[r0 * RW * 64:(r0 + H) * RW * 64]
    upload(b, CH[ch]["w"], img)
    got = int(b.cmd(f"crc 0x{CH[ch]['w']:08x} {len(img)}", timeout=120).split()[-1], 16)
    if ch == 1:
        b.cmd("crc 0xa0000000 65536", timeout=60)            # evict the ddr1 window cache
    upload(b, CH[ch]["win"], act[:K]); upload(b, CH[ch]["win"] + 0x1000 * 4, act[K:])
    return got == zlib.crc32(img)


def go(b, ch, r0, label):
    start(b, ch, CH[ch]["dram"], H * RW, H)
    st, cyc = wait(b, ch)
    bad = check(b, ch, H, exp[r0:r0 + H])
    print(f"{label}: {cyc} cycles, {'BIT-EXACT' if not bad else f'{bad} mismatches'}", flush=True)


b = Bios(freq=15e6); b.sync(); b.drain(1.0)
b.write(csr("ddr1_page"), 0)
print("A upload ok:", put(b, 0, H)); go(b, 0, H, "A engine 0, rows 2304..")
print("B upload ok:", put(b, 1, H)); go(b, 1, H, "B engine 1, rows 2304..")
print("C upload ok:", put(b, 1, 0)); go(b, 1, 0, "C engine 1, rows 0..")
b.close()
