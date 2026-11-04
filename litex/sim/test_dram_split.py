#!/usr/bin/env python3
"""DRAM streaming efficiency in simulation: LiteDRAM controller (same module/timings as the card: MT41J256M16 at
75 MHz, 1:4, refresh included) + litedram's SDRAMPHYModel, one sequential LiteDRAMDMAReader (today's engine feed,
accel/litex/mvaccel.py) vs accel/litex/dramsplit.BankSplitReader (two ports, even/odd banks).
Checks that every word arrives in address order (the model memory holds word index = address) and prints words per
clock.   python3 test_dram_split.py [nwords] [base ...]"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "accel", "litex"))

from migen import If, Module, Signal, run_simulation  # noqa: E402

from litedram.core import LiteDRAMCore  # noqa: E402
from litedram.core.controller import ControllerSettings  # noqa: E402
from litedram.frontend.dma import LiteDRAMDMAReader  # noqa: E402
from litedram.modules import MT41J256M16  # noqa: E402
from litedram.phy.model import SDRAMPHYModel, get_sdram_phy_settings  # noqa: E402

from dramsplit import BankSplitReader  # noqa: E402

sys.path.insert(0, os.path.join(HERE, ".."))
from ddr3_module import MT41J256M16_ns  # noqa: E402

FIX = os.environ.get("FIX") == "1"                  # tRFC in ns (ddr3_module.py) instead of DDR3-1600 clocks
POSTPONE = int(os.environ.get("POSTPONE", "1"))     # LiteDRAM refresh_postponing (1..8)


class Small(MT41J256M16_ns if FIX else MT41J256M16):
    nrows = 8                   # TINY simulated memory: 8 rows x 8 banks x 128 words = 8192 words (512 KiB), timings
                                # unchanged. Migen's simulator makes every memory word its own Signal: 2048 rows
                                # (8 M words) took 14 GB and OOM-killed the session on 2026-11-03. Run capped:
                                # systemd-run --user --scope -p MemoryMax=2G -p MemorySwapMax=0 ...


MEMWORDS = 8 * 8 * 128


class DUT(Module):
    def __init__(self, split):
        mod = Small(75e6, "1:4")
        mod.geom_settings.addressbits = 15     # as the real chip (A10 = auto-precharge), despite the 3 row bits
        settings = get_sdram_phy_settings("DDR3", 64, 75e6)
        self.submodules.phy = SDRAMPHYModel(mod, settings, init=list(range(16 * MEMWORDS)))
        self.submodules.core = core = LiteDRAMCore(self.phy, mod.geom_settings, mod.timing_settings, clk_freq=75e6,
                                                   controller_settings=ControllerSettings(refresh_postponing=POSTPONE))
        self.go, self.base, self.nwords = Signal(), Signal(32), Signal(32)
        self.valid, self.data = Signal(), Signal(32)
        if split:
            self.submodules.rd = rd = BankSplitReader(core.crossbar.get_port(), core.crossbar.get_port(),
                                                       fifo_depth=int(os.environ.get("SPLIT_DEPTH", "64")))
            self.comb += [rd.go.eq(self.go), rd.base.eq(self.base), rd.nwords.eq(self.nwords),
                          rd.source.ready.eq(1), self.valid.eq(rd.source.valid), self.data.eq(rd.source.data[:32])]
        else:                    # as mvaccel.py
            self.submodules.dma = dma = LiteDRAMDMAReader(core.crossbar.get_port(), fifo_depth=64,
                                                          fifo_buffered=True)
            addr, left = Signal(32), Signal(32)
            self.sync += If(self.go, addr.eq(self.base), left.eq(self.nwords)
                            ).Elif(dma.sink.valid & dma.sink.ready, addr.eq(addr + 1), left.eq(left - 1))
            self.comb += [dma.sink.valid.eq(left != 0), dma.sink.address.eq(addr), dma.source.ready.eq(1),
                          self.valid.eq(dma.source.valid), self.data.eq(dma.source.data[:32])]


def run(split, runs):
    dut = DUT(split)
    res = []

    def gen():
        for _ in range(200):     # controller settles
            yield
        for base, n in runs:
            yield dut.base.eq(base)
            yield dut.nwords.eq(n)
            yield dut.go.eq(1)
            yield
            yield dut.go.eq(0)
            t, got, bad = 0, 0, 0
            while got < n:
                yield
                t += 1
                if (yield dut.valid):
                    d = yield dut.data
                    if d != 16 * (base + got):     # init holds 32-bit values, 16 per 64-byte word
                        bad += 1
                        if bad <= 3:
                            print(f"   word {got}: got {d // 16} expected {base + got}")
                    got += 1
                if t > 20 * n + 1000:
                    print("   TIMEOUT")
                    break
            res.append((base, n, t, bad))

    run_simulation(dut, gen())
    return res


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 4096
    bases = [int(b, 0) for b in sys.argv[2:]] or [0, 1000]
    runs = [(b, n) for b in bases]
    for split in (False, True):
        for base, n, t, bad in run(split, runs):
            print(f"{'split ' if split else 'single'} base {base:6d} words {n:6d}: {t} clocks = "
                  f"{n / t * 100:5.1f} % of one word per clock, {bad} out of order")
