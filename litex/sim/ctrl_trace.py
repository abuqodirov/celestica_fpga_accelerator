#!/usr/bin/env python3
"""Simulate the real LiteDRAM controller with this board's A7DDRPHY settings and print the DFI
command/address on each of the 4 phases per sys clock, for a few writes. The PHY is a stub that only
records the DFI bus, so this shows what the address/command pins *should* carry."""
from migen import *
from litedram.phy import dfi
from litedram.common import PhySettings
from litedram.modules import MT41J256M16
from litedram.core import LiteDRAMCore


class StubPHY(Module):
    def __init__(self, rdphase=3, wrphase=3):
        self.settings = PhySettings(phytype="A7DDRPHY", memtype="DDR3", databits=32, dfi_databits=64,
            nphases=4, rdphase=Signal(2, reset=rdphase), wrphase=Signal(2, reset=wrphase), cl=6, cwl=5,
            read_latency=8, write_latency=1, cmd_latency=0, strobes=4, with_dm=False)
        self.dfi = dfi.Interface(15, 3, 1, 64, 4)


def name(p):
    cs, ras, cas, we = p
    if cs: return "    "
    return {(1, 1, 1): "NOP ", (0, 1, 1): "ACT ", (1, 0, 1): "RD  ", (1, 0, 0): "WR  ",
            (0, 1, 0): "PRE ", (0, 0, 1): "REF ", (0, 0, 0): "MRS ", (1, 1, 0): "ZQ  "}[(ras, cas, we)]


def main():
    phy = StubPHY()
    mod = MT41J256M16(75e6, "1:4")
    core = LiteDRAMCore(phy, mod.geom_settings, mod.timing_settings, clk_freq=75e6)
    port = core.crossbar.get_port()
    dut = Module()
    dut.submodules += phy, core

    # row 5, bank 0, col 64 -> port address (ROW_BANK_COL): col>>3 | bank<<7 | row<<10
    addrs = [(5 << 10) | (0 << 7) | (64 >> 3) + i for i in range(4)]

    def gen():
        yield core.dfii._control.storage.eq(1)        # hardware control
        for _ in range(40):                           # let the refresher settle
            yield
        for i, a in enumerate(addrs):
            yield port.cmd.valid.eq(1)
            yield port.cmd.we.eq(1)
            yield port.cmd.addr.eq(a)
            yield
            while not (yield port.cmd.ready):
                yield
        yield port.cmd.valid.eq(0)

    def wdata():
        n = 0
        while n < len(addrs):
            yield port.wdata.valid.eq(1)
            yield port.wdata.data.eq(n + 1)
            yield
            if (yield port.wdata.ready):
                n += 1
        yield port.wdata.valid.eq(0)

    def mon():
        for cyc in range(160):
            row = []
            busy = False
            for p in phy.dfi.phases:
                c = name(((yield p.cs_n), (yield p.ras_n), (yield p.cas_n), (yield p.we_n)))
                a = yield p.address
                ba = yield p.bank
                busy |= c.strip() not in ("NOP", "")
                row.append(f"{c}a={a:5d} ba={ba}{' wen' if (yield p.wrdata_en) else '    '}")
            if 42 <= cyc <= 62:
                print(f"{cyc:4d} | " + " | ".join(row))
            yield

    run_simulation(dut, [gen(), wdata(), mon()])


if __name__ == "__main__":
    main()
