#!/usr/bin/env python3
"""Emit the LiteDRAM controller (same settings as the card's SoC) as a standalone Verilog module
with the crossbar port and the DFI bus as top-level ports, for RTL-vs-netlist simulation."""
from migen import *
from migen.fhdl import verilog
from litedram.phy import dfi
from litedram.common import PhySettings
from litedram.modules import MT41J256M16
from litedram.core import LiteDRAMCore


class StubPHY(Module):
    def __init__(self):
        self.rdphase = Signal(2)
        self.wrphase = Signal(2)
        self.settings = PhySettings(phytype="A7DDRPHY", memtype="DDR3", databits=32, dfi_databits=64,
            nphases=4, rdphase=self.rdphase, wrphase=self.wrphase, cl=6, cwl=5,
            read_latency=8, write_latency=1, cmd_latency=0, strobes=4, with_dm=False)
        self.dfi = dfi.Interface(15, 3, 1, 64, 4)


class Top(Module):
    def __init__(self):
        self.submodules.phy = phy = StubPHY()
        mod = MT41J256M16(75e6, "1:4")
        self.submodules.core = core = LiteDRAMCore(phy, mod.geom_settings, mod.timing_settings, clk_freq=75e6)
        port = core.crossbar.get_port()
        self.ios = {phy.rdphase, phy.wrphase,
                    port.cmd.valid, port.cmd.ready, port.cmd.we, port.cmd.addr,
                    port.wdata.valid, port.wdata.ready, port.wdata.data, port.wdata.we,
                    port.rdata.valid, port.rdata.ready, port.rdata.data}
        for i, p in enumerate(phy.dfi.phases):
            for s in ("address", "bank", "cs_n", "ras_n", "cas_n", "we_n", "wrdata_en", "rddata_en"):
                sig = getattr(p, s)
                o = Signal(len(sig), name=f"p{i}_{s}")
                self.comb += o.eq(sig)
                self.ios.add(o)
            self.comb += p.rddata_valid.eq(0)
        self.port = port


top = Top()
v = verilog.convert(top, ios=top.ios, name="ctrl_top")
v.write("ctrl_rtl.v")
print("port address width", len(top.port.cmd.addr), "data", len(top.port.wdata.data))
for s in sorted(top.ios, key=lambda s: str(v.ns.get_name(s))):
    print(v.ns.get_name(s), len(s))
