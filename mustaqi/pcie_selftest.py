#!/usr/bin/env python3
"""Check the PCIe link of a YPCB_PCIE design (build_pcie1) before chatting over it. No sudo (after pcie_rescan.sh).
  1. bridge registers: magic, link state (LTSSM / width / speed), counters, engine status
  2. DDR3 through the paged windows: write N MiB of random data into a free area of each channel (above the
     weights), write the window caches back, read it back over PCIe, compare; upload / read speeds
  3. a single-DW write + read round trip through a CSR (scratch: the ddr page register, restored)
    python3 pcie_selftest.py [--mib 16]"""
import argparse
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pcie_link as P  # noqa: E402

TEST_OFF = 0x7000_0000          # 1.75 GiB into each 2 GiB channel: above the weights (~1.25 GiB per channel)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mib", type=int, default=16)
    a = ap.parse_args()
    L = P.PcieLink()
    r = [L.reg(i) for i in range(28)]
    link = r[22]
    print(f"bridge: magic {r[0]:#010x}  LTSSM {link & 0x3f:#x}  width x{(link >> 6) & 0xf}  "
          f"speed {'2.5' if ((link >> 10) & 3) == 1 else '5' if ((link >> 10) & 3) == 2 else '?'} GT/s  "
          f"bus master {(link >> 12) & 1}  mem {(link >> 13) & 1}  link up {(link >> 14) & 1}")
    print(f"        TLP writes {r[16]}  TLP reads {r[17]}  completions {r[18]}  write DWs {r[19]}  "
          f"UR {r[20] & 0xffff}  stale {r[20] >> 16}  other {r[21] & 0xffff}  dsc {r[21] >> 16}  bus errors {r[5]}")
    ev = [(r[24 + i // 2] >> (16 * (i % 2))) & 0xffff for i in range(8)]
    names = "badtlp baddllp replayro replayto ll2_rx pl2_rx malformed recovery".split()
    print("        link errors: " + "  ".join(f"{n} {v}" for n, v in zip(names, ev)))
    print(f"        engines/FFN status: {L.parse_est(r[1])}")
    ok = True
    # 3. CSR round trip (ddr1 page register)
    import dram
    pc = P.S_CSR * P.SLOT + (P.csr(dram.WIN[1]["page"]) - 0xF0000000)
    old = L.rd32(pc)
    L.wr32(pc, 1)
    v1 = L.rd32(pc)
    L.wr32(pc, old)
    print(f"CSR round trip: wrote 1, read {v1}, restored {L.rd32(pc)} -> {'OK' if v1 == 1 else 'FAIL'}")
    ok &= v1 == 1
    # 2. DDR
    n = a.mib << 20
    rng = np.random.default_rng(int(time.time()))
    for ch in (0, 1):
        data = rng.integers(0, 2**32, n // 4, dtype=np.uint32)
        t0 = time.time()
        L.upload(ch, TEST_OFF, data.tobytes())
        L.evict(ch)
        tw = time.time() - t0
        back = np.empty_like(data)
        t0 = time.time()
        pos = 0
        for page, addr, o, m in dram._pieces(ch, TEST_OFF, n):
            L.wr32(P.S_CSR * P.SLOT + (P.csr(dram.WIN[ch]["page"]) - 0xF0000000), page)
            for x in range(addr, addr + m, P.SLOT):
                k = min(P.SLOT, addr + m - x)
                s = (P.S_D0, P.S_D1)[ch]
                L.set_base(s, x)
                back[(o + x - addr) // 4:(o + x - addr + k) // 4] = L.bar_read(s * P.SLOT, k)
        L.wr32(P.S_CSR * P.SLOT + (P.csr(dram.WIN[ch]["page"]) - 0xF0000000), 0)
        tr = time.time() - t0
        bad = int((back != data).sum())
        print(f"DDR channel {ch}: {a.mib} MiB written {n / tw / 1e6:.1f} MB/s, read back {n / tr / 1e6:.1f} MB/s, "
              f"{bad} words differ -> {'OK' if bad == 0 else 'FAIL'}")
        if bad:
            i = np.nonzero(back != data)[0][:4]
            print("   first differences (word, wrote, read):", [(int(j), hex(data[j]), hex(back[j])) for j in i])
        ok &= bad == 0
    r2 = [L.reg(i) for i in (5, 20, 21)]
    print(f"after: bus errors {r2[0]}  UR {r2[1] & 0xffff}  stale {r2[1] >> 16}")
    print("ALL OK" if ok else "FAIL")
    L.close()


if __name__ == "__main__":
    main()
