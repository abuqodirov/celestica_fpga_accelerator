#!/usr/bin/env python3
"""MVAccel's weight feed in simulation, single LiteDRAMDMAReader vs BankSplitReader (port1=...): LiteDRAM controller
+ SDRAMPHYModel (tiny memory, card timings incl. the refresh fix) and a stand-in for mv_engine.v that turns every
row into an order-sensitive checksum (sum of word_value * (position in row + 1)), so a word out of order, missing or
duplicated changes the result. Checks every result row, the run-finished logic (busy/done/fin/rows) over several
back-to-back runs, and prints the efficiency (words / cycles CSR).
MEMORY: run capped (Migen's simulator makes every memory word a Signal):
    systemd-run --user --scope -q -p MemoryMax=2G -p MemorySwapMax=0 python3 test_mvaccel_split.py [split|single]"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "litex"))

from migen import If, Module, Signal, run_simulation  # noqa: E402

from litedram.core import LiteDRAMCore  # noqa: E402
from litedram.core.controller import ControllerSettings  # noqa: E402
from litedram.phy.model import SDRAMPHYModel, get_sdram_phy_settings  # noqa: E402

from ddr3_module import MT41J256M16_ns  # noqa: E402
from mvaccel import MVAccel  # noqa: E402


class Small(MT41J256M16_ns):
    nrows = 8                   # 8192 words of 64 B (512 KiB) - keep tiny, see MEMORY above


MEMWORDS = 8 * 8 * 128


class FakeEngine(Module):
    """mv_engine.v stand-in: rows of rw = ceil(ng/16) + ng words; result = sum(word[31:0] * (j + 1)) mod 2^32"""
    def __init__(self, p):
        ng, start, wv, wd = p["i_cfg_ng"], p["i_start"], p["i_w_valid"], p["i_w_data"]
        rv, rrow, rdat, ovf, rdone = p["o_r_valid"], p["o_r_row"], p["o_r_data"], p["o_ovf"], p["o_rows_done"]
        rw, j, acc, row = Signal(8), Signal(8), Signal(32), Signal(16)
        self.comb += [rw.eq(((ng + 15) >> 4) + ng), ovf.eq(0), rdone.eq(row)]
        self.sync += [
            rv.eq(0),
            If(start,
                j.eq(0), acc.eq(0), row.eq(0)
            ).Elif(wv,
                If(j == rw - 1,
                    rv.eq(1), rrow.eq(row), rdat.eq(acc + wd[:32] * (j + 1)),
                    row.eq(row + 1), j.eq(0), acc.eq(0)
                ).Else(
                    j.eq(j + 1), acc.eq(acc + wd[:32] * (j + 1)))),
        ]


class Top(Module):
    def __init__(self, split):
        mod = Small(75e6, "1:4")
        mod.geom_settings.addressbits = 15
        self.submodules.phy = SDRAMPHYModel(mod, get_sdram_phy_settings("DDR3", 64, 75e6),
                                            init=list(range(16 * MEMWORDS)))
        self.submodules.core = core = LiteDRAMCore(self.phy, mod.geom_settings, mod.timing_settings, clk_freq=75e6,
                                                   controller_settings=ControllerSettings(refresh_postponing=8))
        # EXTRA=n: n idle native ports created first, like channel 0 on the card (main RAM / L2 port, ddr0 window)
        self.extra = [core.crossbar.get_port() for _ in range(int(os.environ.get("EXTRA", "0")))]
        p0 = core.crossbar.get_port()
        p1 = core.crossbar.get_port() if split else None
        self.submodules.mv = MVAccel(None, p0, B=1, max_rows=512, port1=p1, engine=FakeEngine)


def expected(base, ng, nrows):
    rw = (ng + 15) // 16 + ng
    out = []
    for i in range(nrows):
        out.append(sum(16 * (base + i * rw + j) * (j + 1) for j in range(rw)) & 0xFFFFFFFF)
    return out


def main():
    split = (sys.argv[1:] or ["split"])[0] == "split"
    top = Top(split)
    mv = top.mv
    # (base word, ng, nrows): K=3584 (30 words/row) and K=9728 (81 words/row), odd bases, back to back
    runs = [(37, 28, 180), (0, 76, 60), (1000, 28, 100), (129, 2, 300)]
    errors, report = [], []

    def gen():
        for _ in range(300):
            yield
        fin_expect = 0
        for base, ng, nrows in runs:
            rw = (ng + 15) // 16 + ng
            yield mv.base.storage.eq(base)
            yield mv.nwords.storage.eq(nrows * rw)
            yield mv.ng.storage.eq(ng)
            yield mv.nrows.storage.eq(nrows)
            yield
            yield mv.start.re.eq(1)
            yield
            yield mv.start.re.eq(0)
            t = 0
            while True:
                yield
                t += 1
                st = yield mv.status.status
                if not (st & 1):
                    break
                if t > 40 * nrows * rw:
                    errors.append(f"run {base},{ng},{nrows}: TIMEOUT")
                    break
            fin_expect = (fin_expect + 1) & 15
            fin = yield mv.fin
            g2b = fin
            b = 0
            while g2b:
                b ^= g2b
                g2b >>= 1
            rows = yield mv.rows.status
            cyc = yield mv.cycles.status
            if b != fin_expect:
                errors.append(f"run {base},{ng},{nrows}: fin {b}, expected {fin_expect}")
            if rows != nrows:
                errors.append(f"run {base},{ng},{nrows}: rows {rows}, expected {nrows}")
            exp = expected(base, ng, nrows)
            bad = 0
            for i in range(nrows):
                v = yield mv.res_mems[0][i]
                if v != exp[i]:
                    bad += 1
                    if bad <= 3:
                        errors.append(f"run {base},{ng},{nrows}: row {i} = {v:#x}, expected {exp[i]:#x}")
            report.append(f"base {base:5d} ng {ng:2d} rows {nrows:3d}: {nrows * rw:5d} words in {cyc} cycles = "
                          f"{nrows * rw / cyc * 100:5.1f} %, {bad} rows wrong")
            for _ in range(20):           # idle gap between runs
                yield

    run_simulation(top, gen())
    print(("split (BankSplitReader)" if split else "single (LiteDRAMDMAReader)"))
    for r in report:
        print("  " + r)
    for e in errors[:10]:
        print("  ERROR", e)
    print("PASS" if not errors and len(report) == len(runs) else "FAIL")


if __name__ == "__main__":
    main()
