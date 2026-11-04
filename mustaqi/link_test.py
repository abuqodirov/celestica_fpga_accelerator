#!/usr/bin/env python3
"""Hardware test of the JTAG result reader (build_dacc10, YPCB_JTAGREAD) through fpga_link.Link:
  1. status word alignment: after a write scan of n words to address A the status must say A + 4n
  2. both engines on layer-0 qkv (golden data accel/host/data/qkv.*, half the rows per channel, uploaded at a
     random place in a test area above the weights): engine runs started with loader writes, results read over
     JTAG must be bit-exact with the golden results, and equal to what the CPU reads over the bus
  3. read speed at 15 MHz, and whether reads also work at 30 MHz: rising-edge TDO sampling (fails) and falling-edge
     sampling (Link(read_neg=True), half a clock later)
  build_dacc11+ (Link.packed): activations go out once for both engines (so step 2 tests that), and packed reads
     (bfloat16) must equal the golden results rounded to bfloat16, bit for bit
Channel 1 must be initialised (ch1_init.py). usage: link_test.py"""
import os
import random
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fpga_link  # noqa: E402
from fpga_llm import bf16_round  # noqa: E402
from fpga_link import WIN, Link  # noqa: E402
import dram  # noqa: E402

DATA = os.path.join(HERE, "..", "accel", "host", "data")
K, RW = 3584, 30
TEST_AREA = 0x70000000          # 1.75 GiB into each channel: above the weights (64 MiB .. ~1.31 GiB)


def main():
    q4h = open(os.path.join(DATA, "qkv.q4h"), "rb").read()
    act = np.fromfile(os.path.join(DATA, "qkv.act"), np.uint32)
    exp = np.fromfile(os.path.join(DATA, "qkv.exp"), np.uint32)
    rows = len(exp) // 2
    L = Link()
    ok = True

    # 1. status alignment
    L.write(WIN[0] + 0x100, bytes(12))
    st = L.status()
    good = st["addr"] == WIN[0] + 0x100 + 12
    ok &= good
    print(f"status: addr 0x{st['addr']:08x} (want 0x{WIN[0] + 0x10c:08x}), words {st['nwords']}, overflow "
          f"{st['overflow']}, engines {st['eng']} -> {'OK' if good else 'BAD'}")

    # 2. engines
    off = TEST_AREA + random.randrange(0, 64 << 20, 64)
    b = L.console()
    for ch in (0, 1):
        dram.write(b, ch, off, q4h[ch * rows * RW * 64:(ch + 1) * rows * RW * 64])
    for ch in (0, 1):
        dram.evict(b, ch)
        dram.set_page(b, ch, 0)
    L.set_activation(act)
    for e in (0, 1):
        L.start(e, off // 64, rows, K)
    t = time.time()
    res = [L.results(e, rows).view(np.uint32).copy() for e in (0, 1)]
    dt = time.time() - t
    bad = [int((res[e] != exp[e * rows:(e + 1) * rows]).sum()) for e in (0, 1)]
    ok &= bad == [0, 0]
    print(f"engines @ +{off >> 20} MiB: {rows} rows each, mismatches vs golden {bad} -> "
          f"{'BIT-EXACT' if bad == [0, 0] else 'BAD'}; read {2 * rows * 4} B in {dt * 1e3:.0f} ms")
    if L.packed:
        L.set_activation(act)
        for e in (0, 1):
            L.start(e, off // 64, rows, K)
        L.wait()
        rp = [L.results(e, rows, packed=True).view(np.uint32) for e in (0, 1)]
        want = [bf16_round(exp[e * rows:(e + 1) * rows].view(np.float32)).view(np.uint32) for e in (0, 1)]
        badp = [int((rp[e] != want[e]).sum()) for e in (0, 1)]
        ok &= badp == [0, 0]
        print(f"packed (bfloat16) reads: mismatches vs golden rounded to bfloat16 {badp} -> "
              f"{'BIT-EXACT' if badp == [0, 0] else 'BAD'} (activations sent once for both engines)")
    else:
        print("(this FPGA design has no packed reads / both-engine writes)")
    # the CPU's view over the bus (results window) must agree - unless the build reads results only over JTAG
    b = L.console()
    for e in (() if os.path.exists(os.path.join(fpga_link.BUILD, "jtagread")) else (0, 1)):
        busv = np.array(b.read(WIN[e] + (1 << 17) * 4 + 4 * 100, 16), np.uint32)
        same = (busv == res[e][100:116]).all()
        ok &= bool(same)
        print(f"  engine {e} rows 100..115 over the bus: {'same' if same else 'DIFFERENT'}")

    # 3. speed: repeated runs + full reads, both engines
    n_rep, t = 10, time.time()
    for _ in range(n_rep):
        L.set_activation(act)
        for e in (0, 1):
            L.start(e, off // 64, rows, K)
        for e in (0, 1):
            r = L.results(e, rows).view(np.uint32)
            if (r != exp[e * rows:(e + 1) * rows]).any():
                ok = False
                print("  repeat run: MISMATCH")
    dt = time.time() - t
    print(f"15 MHz: {n_rep} x (activations + 2 engine runs + {2 * rows} results): {dt / n_rep * 1e3:.0f} ms each, "
          f"{n_rep * 2 * rows * 4 / dt / 1e6:.2f} MB/s of results")
    neg_ok = None
    configs = [(15, True, 3, False), (30, True, 50, False), (30, False, 1, False)]   # 30 MHz rising: expected to fail
    if L.packed:
        configs.insert(2, (30, True, 50, True))
    for mhz, neg, n_rep, packed in configs:
        L.read_freq, L.read_neg = mhz * 1e6, neg
        name = f"{mhz} MHz {'falling' if neg else 'rising'} edge{' packed' if packed else ''}"
        want = [bf16_round(exp[e * rows:(e + 1) * rows].view(np.float32)).view(np.uint32) if packed
                else exp[e * rows:(e + 1) * rows] for e in (0, 1)]
        try:
            badf, t = [0, 0], time.time()
            for _ in range(n_rep):
                L.set_activation(act)
                for e in (0, 1):
                    L.start(e, off // 64, rows, K)
                L.wait(timeout=2)
                r = [L.results(e, rows, timeout=2, packed=packed).view(np.uint32) for e in (0, 1)]
                for e in (0, 1):
                    badf[e] += int((r[e] != want[e]).sum())
            dt = (time.time() - t) / n_rep
            good = badf == [0, 0]
            print(f"{name}: {n_rep} x {2 * rows} results, mismatches {badf}, {dt * 1e3:.0f} ms each "
                  f"({'works' if good else 'NOT usable'})")
        except Exception as ex:
            good = False
            print(f"{name}: failed ({ex})")
        if neg and mhz == 30 and not packed:
            neg_ok = good
        ok &= good or not neg
        L.read_freq, L.read_neg = 15e6, False
        L.resync()
    print(f"30 MHz falling-edge reads: {'USABLE' if neg_ok else 'not usable'}")
    print(f"stats {L.stats}")
    print("link test:", "PASS" if ok else "FAIL")
    L.close()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
