#!/usr/bin/env python3
"""Both matvec engines (YPCB_DUAL + YPCB_ACCEL SoC): layer-0 qkv rows split across the two DDR3 channels.
  1. each engine alone on its half, bit-exact against the golden results (data/qkv.*, see acc_test.py prep)
  2. the same while the OTHER channel streams 512 MiB (both channels busy at once)
  3. bandwidth of both
Channel 1 is initialised first (ch1_init.py); its weights go through the ddr1 window (0x80000000, write-back
cache), which is evicted before the engine reads DRAM directly.   env YPCB_BUILD (default litex/build_dacc)"""
import os
import struct
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
os.environ.setdefault("YPCB_BUILD", os.path.join(ROOT, "litex", "build_dacc"))
sys.path.insert(0, os.path.join(ROOT, "litex"))
sys.path.insert(0, os.path.join(ROOT, "llm"))
from bios import Bios, csr  # noqa: E402
from chat import upload  # noqa: E402

DATA = os.path.join(HERE, "data")
K, SYS_HZ = 3584, 75e6
NG = K // 128
RW = (NG + 15) // 16 + NG
CH = [  # cpu address of the weights, DRAM word address seen by the engine, engine CSR prefix, engine window
    dict(w=0x48000000, dram=(0x48000000 - 0x40000000) // 64, eng="mvacc", win=0xC0000000),
    dict(w=0x88000000, dram=(0x88000000 - 0x80000000) // 64, eng="mvacc1", win=0xC0100000),
]


def f32(u):
    return struct.unpack("<f", struct.pack("<I", u))[0]


def start(b, ch, base, nwords, nrows):
    e = CH[ch]["eng"]
    b.write(csr(f"{e}_base"), base); b.write(csr(f"{e}_nwords"), nwords)
    b.write(csr(f"{e}_ng"), NG); b.write(csr(f"{e}_nrows"), nrows); b.write(csr(f"{e}_start"), 1)


def wait(b, ch, timeout=20):
    e, t0 = CH[ch]["eng"], time.time()
    while time.time() - t0 < timeout:
        st = b.read(csr(f"{e}_status"))[0]
        if st & 2:
            return st, b.read(csr(f"{e}_cycles"))[0]
    return st, None


def jtag_results(b, eng, rows):
    """engine results over the JTAG result reader (YPCB_JTAGREAD builds, litex/jtag_shift.py): one chain-2 read
    scan (mustaqi/fpga_link.py read_scan_cmd: read-only clocks, no FT232H deadlock)"""
    sys.path.insert(0, os.path.join(ROOT, "mustaqi"))
    from fpga_link import read_scan_cmd, read_scan_result
    b.j.ir(0x03)
    b.j.ftdi.write_data(read_scan_cmd(1 | eng << 1, rows + 2))
    w = read_scan_result(b.j.ftdi, rows + 2)
    b.j.ir(0x02)
    return [int(x) for x in w[2:]]


def check(b, ch, rows, exp):
    res = []
    if os.path.exists(os.path.join(os.environ["YPCB_BUILD"], "jtagread")):   # YPCB_JTAGREAD=2: no bus reads
        res = jtag_results(b, ch, rows)
    for off in range(0, rows if not res else 0, 256):
        res += b.read(CH[ch]["win"] + (1 << 17) * 4 + 4 * off, min(256, rows - off))
    bad = [r for r in range(rows) if res[r] != exp[r]]
    for r in bad[:4]:
        print(f"    row {r}: engine {res[r]:08x} ({f32(res[r]):.7g}) golden {exp[r]:08x} ({f32(exp[r]):.7g})")
    return len(bad)


def main():
    q4h = open(os.path.join(DATA, "qkv.q4h"), "rb").read()
    act = open(os.path.join(DATA, "qkv.act"), "rb").read()
    rows = len(q4h) // (RW * 64)
    exp = struct.unpack(f"<{rows}I", open(os.path.join(DATA, "qkv.exp"), "rb").read())
    half = rows // 2
    parts = [(0, half), (half, rows - half)]
    print(subprocess.run([sys.executable, os.path.join(ROOT, "litex", "ch1_init.py")], capture_output=True,
                         text=True, env=dict(os.environ)).stdout.strip().splitlines()[-1])
    b = Bios(freq=15e6); b.sync(); b.drain(1.0)
    b.write(csr("ddr1_page"), 0)
    for ch, (r0, n) in enumerate(parts):
        img = q4h[r0 * RW * 64:(r0 + n) * RW * 64]
        upload(b, CH[ch]["w"], img)
        got = int(b.cmd(f"crc 0x{CH[ch]['w']:08x} {len(img)}", timeout=120).split()[-1], 16)
        print(f"channel {ch}: rows {r0}..{r0 + n - 1}, {len(img)} B, crc {'OK' if got == zlib.crc32(img) else 'MISMATCH'}")
        upload(b, CH[ch]["win"], act[:K]); upload(b, CH[ch]["win"] + 0x1000 * 4, act[K:])
    b.cmd("crc 0xa0000000 65536", timeout=60)          # evict the ddr1 window cache (8 KiB) -> channel 1 DRAM
    total_bad = 0
    for ch, (r0, n) in enumerate(parts):
        start(b, ch, CH[ch]["dram"], n * RW, n)
        st, cyc = wait(b, ch)
        bad = check(b, ch, n, exp[r0:r0 + n])
        total_bad += bad
        print(f"  alone : channel {ch} engine {n} rows, {cyc} cycles = {n * RW * 64 / (cyc / SYS_HZ) / 1e9:.2f} GB/s, "
              f"overflow {st >> 2 & 1}, {'BIT-EXACT' if not bad else f'{bad} mismatches'}")
    for ch, (r0, n) in enumerate(parts):
        other = 1 - ch
        start(b, other, 0, (512 << 20) // 64, 0xFFFF)           # long stream on the other channel (~130 ms)
        start(b, ch, CH[ch]["dram"], n * RW, n)
        st, cyc = wait(b, ch)
        busy_other = b.read(csr(f"{CH[other]['eng']}_status"))[0] & 1
        bad = check(b, ch, n, exp[r0:r0 + n])
        total_bad += bad
        print(f"  loaded: channel {ch} while channel {other} streams (still busy: {busy_other}): {cyc} cycles, "
              f"{'BIT-EXACT' if not bad else f'{bad} mismatches'}")
        time.sleep(0.3)
    print(f"both channels: {rows} rows, {'ALL BIT-EXACT' if not total_bad else f'{total_bad} mismatches'}")
    b.close()


if __name__ == "__main__":
    main()
