#!/usr/bin/env python3
"""Hardware test of the FFN unit (YPCB_FFN builds, accel/rtl/ffn_unit.v) without the full weight upload: layer 0's
gate_up and down weights (~56 MB, both channels' halves) go into a test area above the weights, then for random
input vectors the whole FFN runs on the card - gate_up on both engines, SiLU(gate) * up + MXINT8 in the FFN unit,
down on the activations the unit wrote - and down's results (bfloat16 reads) must equal the PC reference
(CpuBackend.ffn_q: the same arithmetic) bit for bit. Also times the fused FFN against gate_up/down over the cable.
Channel 1 must be initialised (ch1_init.py).   usage: ffn_test.py [--vectors 20]"""
import argparse
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fpga_link  # noqa: E402
import fpga_llm as F  # noqa: E402
import dram  # noqa: E402
from chat import upload  # noqa: E402

TEST_AREA = 0x70000000          # 1.75 GiB into each channel, above the weights


class TestIndex:
    """layer 0's gate_up and down halves, as uploaded into the test area (offsets relative to F.W_OFF)"""

    def __init__(self, ix):
        self.mats, pos = {}, [0, 0]
        for name in ("0.gate_up", "0.down"):
            for h in ix.halves(name):
                size = h["rows"] * F.row_words(h["K"]) * 64
                self.mats[f"{name}.{h['ch']}"] = dict(h, off=TEST_AREA - F.W_OFF + pos[h["ch"]], src=h["off"], size=size)
                pos[h["ch"]] += size

    def halves(self, name):
        return [self.mats[f"{name}.{ch}"] for ch in (0, 1)]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--vectors", type=int, default=20)
    args = ap.parse_args()
    L = fpga_link.Link(read_freq=30e6, read_neg=True)
    assert L.has_ffn and L.packed, "this FPGA design has no FFN unit"
    ix = F.Index()
    tix = TestIndex(ix)
    b = L.console()
    t0 = time.time()
    total = 0
    for m in tix.mats.values():
        with open(os.path.join(F.OUT, f"q4h_ch{m['ch']}.bin"), "rb") as f:
            f.seek(m["src"])
            data = f.read(m["size"])
        for page, addr, o, n in dram._pieces(m["ch"], F.W_OFF + m["off"], len(data)):
            dram.set_page(b, m["ch"], page)
            L.set_tck(30e6)
            upload(b, addr, data[o:o + n])
            L.set_tck(L.freq)
        total += len(data)
    for ch in (0, 1):
        dram.evict(b, ch)
        dram.set_page(b, ch, 0)
    print(f"uploaded layer 0 gate_up + down ({total / 1e6:.0f} MB) in {time.time() - t0:.0f} s")

    fpga = F.FpgaBackend(tix, L, packed=True)
    cpu = F.CpuBackend(ix, packed=True)
    rng = np.random.default_rng(7)
    bad_vec, t_fused, t_cable = 0, 0.0, 0.0
    for v in range(args.vectors):
        x = (rng.standard_normal(F.DIM) * (1 + 3 * (v % 3))).astype(np.float32)   # rmsnorm-like, varied scale
        q = F.quantize(x)
        t = time.time()
        y = fpga.ffn_q(0, q)
        t_fused += time.time() - t
        ref = cpu.ffn_q(0, q)
        nbad = int((y.view(np.uint32) != ref.view(np.uint32)).sum())
        if nbad:
            bad_vec += 1
            i = int(np.nonzero(y.view(np.uint32) != ref.view(np.uint32))[0][0])
            print(f"  vector {v}: {nbad} of {y.size} down results differ (row {i}: {y[i]} vs {ref[i]})")
        # the same FFN with gate_up's results over the cable and SiLU on the PC (the pre-FFN-unit way)
        t = time.time()
        hb = fpga.mv_q("0.gate_up", q)
        fpga.mv_q("0.down", F.quantize(F.silu_mul_hw(hb[:F.FFN], hb[F.FFN:])))
        t_cable += time.time() - t
    st = L.status()
    ok = bad_vec == 0 and not st["ffn"]["err"]
    print(f"FFN unit: {args.vectors} vectors, {bad_vec} with differences, err flag {st['ffn']['err']} -> "
          f"{'BIT-EXACT' if ok else 'BAD'}")
    print(f"per layer FFN: {t_fused / args.vectors * 1e3:.1f} ms with the FFN unit, "
          f"{t_cable / args.vectors * 1e3:.1f} ms with gate_up over the cable")
    print("ffn test:", "PASS" if ok else "FAIL")
    L.close()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
