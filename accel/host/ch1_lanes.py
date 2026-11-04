#!/usr/bin/env python3
"""Probe engine 1 (or 0) with one-hot activation vectors: x[j] = 1.0, all else 0. The correct output of row r is the
dequantized weight w[r][j], so a wrong activation-buffer lane / subgroup / chunk shows up directly.
Needs the qkv rows of data/qkv.q4h (rows R0..R0+63) already in the engine's DRAM (ch1_debug.py C leaves rows 0..
in channel 1). usage: ch1_lanes.py <engine 0|1> [R0]      (YPCB_BUILD = dual SoC)"""
import os
import struct
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ.setdefault("YPCB_BUILD", os.path.join(HERE, "..", "..", "litex", "build_dacc2"))
from dual_test import CH, DATA, K, RW, Bios, csr, start, upload, wait  # noqa: E402

ROOT = os.path.join(HERE, "..", "..")
ch = int(sys.argv[1]); r0 = int(sys.argv[2]) if len(sys.argv) > 2 else 0
ROWS = 64
w = np.fromfile(os.path.join(DATA, "w.f32"), np.float32).reshape(-1, K)[r0:r0 + ROWS]
w.tofile(os.path.join(DATA, "probe_w.f32"))
positions = [0, 1, 2, 3, 4, 31, 32, 33, 63, 64, 100, 127, 128, 129, 200, 255, 256, 511, 1000, 2047, 3583]
b = Bios(freq=15e6); b.sync(); b.drain(1.0)
for j in positions:
    x = np.zeros(K, np.float32); x[j] = 1.0
    x.tofile(os.path.join(DATA, "probe_x.f32"))
    subprocess.run([os.path.join(ROOT, "accel", "golden", "q4h_tool"), str(K), str(ROWS), os.path.join(DATA, "probe_w.f32"),
                    os.path.join(DATA, "probe_x.f32"), os.path.join(DATA, "probe")], check=True, capture_output=True)
    act = open(os.path.join(DATA, "probe.act"), "rb").read()
    exp = struct.unpack(f"<{ROWS}I", open(os.path.join(DATA, "probe.exp"), "rb").read())
    upload(b, CH[ch]["win"], act[:K]); upload(b, CH[ch]["win"] + 0x1000 * 4, act[K:])
    start(b, ch, CH[ch]["dram"], ROWS * RW, ROWS)
    st, cyc = wait(b, ch)
    res = b.read(CH[ch]["win"] + (1 << 17) * 4, ROWS)
    bad = sum(1 for r in range(ROWS) if res[r] != exp[r])
    f = lambda u: struct.unpack("<f", struct.pack("<I", u))[0]
    print(f"x[{j:4d}] (chunk {j // 128}, lane {(j % 128) // 4:2d}, byte {j % 4}, subgroup {j // 32}): "
          f"{'ok' if not bad else f'{bad}/{ROWS} wrong, e.g. row 0 engine {f(res[0]):.5g} golden {f(exp[0]):.5g}'}", flush=True)
b.close()
