#!/usr/bin/env python3
"""PCIe stage 3a, PC side: talk to the card's BAR0 window (design: ../bar0.v). Needs root.

  sudo python3 bar_test.py            writes only: scratch register, scratch RAM, bulk write + checksum
  sudo python3 bar_test.py --read     also reads back (enable first on the card: s2.py set bar_rd=1)
  options: --bulk MB (default 64)  --dev 0000:01:00.0
The card's own view of the writes: host/s2.py bar (JTAG, no root needed).
"""
import argparse
import ctypes
import mmap
import os
import random
import struct
import sys
import time

ap = argparse.ArgumentParser()
ap.add_argument("--read", action="store_true")
ap.add_argument("--bulk", type=float, default=64)
ap.add_argument("--dev", default="0000:01:00.0")
a = ap.parse_args()
dev = f"/sys/bus/pci/devices/{a.dev}"
if not os.path.exists(dev):
    sys.exit(f"{dev} missing: run `echo 1 | sudo tee /sys/bus/pci/rescan` first")
ids = open(f"{dev}/vendor").read().strip(), open(f"{dev}/device").read().strip()
if ids != ("0x10ee", "0x7028"):
    sys.exit(f"unexpected device {ids}")
open(f"{dev}/enable", "w").write("1")          # memory decoding on (no driver is bound)
fd = os.open(f"{dev}/resource0", os.O_RDWR | os.O_SYNC)
m = mmap.mmap(fd, 2 << 20, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)

def wr32(off, v):
    ctypes.c_uint32.from_buffer(m, off).value = v

def rd32(off):
    return ctypes.c_uint32.from_buffer(m, off).value

print(f"BAR0 of {a.dev} mapped ({open(f'{dev}/resource').readline().split()[0]})")
# 1. scratch register and 16 scratch-RAM words
wr32(0x4, 0x11223344)
ram = [random.getrandbits(32) for _ in range(16)]
for i, v in enumerate(ram):
    wr32(0x1000 + 4 * i, v)
print("wrote scratch register = 0x11223344 and 16 scratch-RAM words")
# 2. bulk writes into the unmapped area (the card only counts bytes and sums the 32-bit words)
n = int(a.bulk * (1 << 20)) // (1 << 20) * (1 << 20)
chunk = os.urandom(1 << 20)
words = struct.unpack(f"<{len(chunk) // 4}I", chunk)
csum = sum(words) * (n >> 20) + 0x11223344 + sum(ram)
# one 32-bit store per word (ctypes array slice assignment). A plain m[a:b] = chunk goes through memcpy, which on
# this uncached mapping sends ONE BYTE per packet and re-writes 64 bytes per call (seen on the card 2026-11-02).
win = (ctypes.c_uint32 * (len(chunk) // 4)).from_buffer(m, 0x100000)
b0 = s0 = None
if a.read:
    b0, s0 = rd32(0xC), rd32(0x10)
t0 = time.time()
for k in range(n >> 20):
    win[:] = words
dt = time.time() - t0
del win
total = n + 4 + 64
print(f"bulk: {n >> 20} MB in {dt:.2f} s = {n / dt / 1e6:.1f} MB/s  (32-bit stores)")
print(f"this run added: bytes {total}  sum {csum & 0xFFFFFFFF:#010x}  (s2.py bar shows totals since the card was loaded)")
if a.read:
    db, ds = (rd32(0xC) - b0) & 0xFFFFFFFF, (rd32(0x10) - s0) & 0xFFFFFFFF
    want = (sum(words) * (n >> 20)) & 0xFFFFFFFF
    print(f"card says the bulk added: bytes {db} (expect {n})  sum {ds:#010x} (expect {want:#010x})  -> "
          f"{'OK' if (db, ds) == (n, want) else 'MISMATCH'}")
if a.read:
    print(f"magic   {rd32(0x0):#010x} (expect 0xc0de5303)")
    print(f"scratch {rd32(0x4):#010x} (expect 0x11223344)")
    print(f"bytes   {rd32(0xC)}  sum {rd32(0x10):#010x}  write TLPs {rd32(0x8)}  read TLPs {rd32(0x14)}")
    back = [rd32(0x1000 + 4 * i) for i in range(16)]
    print(f"scratch RAM read back: {'OK' if back == ram else 'MISMATCH'}" +
          ("" if back == ram else f"\n  wrote {[hex(x) for x in ram]}\n  read  {[hex(x) for x in back]}"))
    print(f"unmapped 0x12340 reads {rd32(0x12340):#x} (expect 0x12340)")
    t0 = time.time()
    for _ in range(20000):
        rd32(0x18)
    dt = time.time() - t0
    print(f"20000 single reads: {dt / 20000 * 1e6:.2f} us each ({4 * 20000 / dt / 1e6:.2f} MB/s)")
m.close()
os.close(fd)
