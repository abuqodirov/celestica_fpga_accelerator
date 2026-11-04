"""LiteX integration of the matvec engine (accel/rtl/mv_engine.v) on one LiteDRAM native port.

Registers (CSR prefix given by the SoC attribute name, e.g. mvacc_*):
    base    first 64-byte DRAM word of the matrix (DRAM byte offset / 64)
    nwords  words to stream = rows * (ceil(NG/16) + NG)
    ng      groups of 128 inputs per row (K / 128)
    nrows   rows in this run (results are counted against it)
    start   write anything: (re)start the engine and the DMA
    status  bit0 busy, bit1 done, bit2 overflow (engine)
    rows    results written so far;   cycles  clocks from start to done (bandwidth measurement)
For the JTAG result reader (YPCB_JTAGREAD, ypcb_soc.py): jtag_port() adds a read port on the results in clock
domain jtagl; fin = Gray-coded count of finished runs, st = Cat(fin, ovf, busy) for the JTAG status word (one bit
changes per completion, so sampling it from another clock domain never sees a torn value).
ext_aw_en/addr/data: a second writer of the activation buffer (mv_engine aw port format, vector 0), e.g. the FFN unit
(ffnunit.py); registered here, next to the engine, and taking precedence over bus writes.
Wishbone window (32-bit words, word offset wa):
    wa[17] = 0, write: activation buffer of vector wa[15:14], engine address wa[12:0] (see mv_engine.v)
    wa[17] = 1, read : float32 result of vector wa[15:14], row wa[13:0]
"""
import os

from migen import Array, Cat, ClockSignal, If, Instance, Memory, Mux, ResetSignal, Signal

from litex.gen import LiteXModule
from litex.soc.interconnect import wishbone
from litex.soc.interconnect.csr import CSRStatus, CSRStorage

RTL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rtl", "mv_engine.v")


class MVAccel(LiteXModule):
    def __init__(self, platform, port, B=1, max_rows=8192, fifo_depth=64, jtag_results=False, results_domain="jtagl",
                 port1=None, split_fifo=128, engine=None):
        """jtag_results: the result memory's read port is clocked by the JTAG domain (jtagl) for the JTAG result
        reader instead of serving bus reads (bus reads of results then return 0) - no extra block RAM.
        results_domain: that port's clock domain ("sys" for the PCIe bridge, litex/pcie_bridge.py).
        port1: a second native port on the same DRAM: weights are then streamed by dramsplit.BankSplitReader (even /
        odd banks on the two ports, split_fifo words of FIFO each) instead of one LiteDRAMDMAReader - hides the
        crossbar's bank-change stall (simulated 90.3 -> 94.0 % of 64 B/clock, litex/sim/test_dram_split.py).
        engine: test hook - a callable taking the mv_engine port dict (i_*/o_* names) and returning a Migen module
        used instead of the Verilog instance (accel/litex/test_mvaccel_split.py)."""
        from litedram.frontend.dma import LiteDRAMDMAReader
        assert port.data_width == 512, f"engine expects 64-byte native words, port is {port.data_width} bits"
        if platform is not None:
            platform.add_source(os.path.abspath(RTL))
        self.base = CSRStorage(32)
        self.nwords = CSRStorage(32)
        self.ng = CSRStorage(7)
        self.nrows = CSRStorage(16)
        self.start = CSRStorage(1)
        self.status = CSRStatus(3)
        self.rows = CSRStatus(16)
        self.cycles = CSRStatus(32)

        # DMA: addresses base .. base + nwords - 1, data straight into the engine (it never back-pressures)
        go = self.start.re
        addr, left, busy, done = Signal(32), Signal(32), Signal(), Signal()
        written, cycles = Signal(16), Signal(32)
        nfin, nfin1, self.fin = Signal(4), Signal(4), Signal(4)     # nfin1 = nfin + 1 wrapped to 4 bits
        w_valid, w_data, issued = Signal(), Signal(512), Signal()   # issued: every word requested
        if port1 is None:
            self.dma = dma = LiteDRAMDMAReader(port, fifo_depth=fifo_depth, fifo_buffered=True)
            self.comb += [
                dma.sink.valid.eq(busy & (left != 0)),
                dma.sink.address.eq(addr),
                dma.source.ready.eq(1),
                w_valid.eq(dma.source.valid), w_data.eq(dma.source.data),
                issued.eq(left == 0),
            ]
            ack = dma.sink.valid & dma.sink.ready
        else:
            from dramsplit import BankSplitReader
            self.rdr = rdr = BankSplitReader(port, port1, fifo_depth=split_fifo)
            self.comb += [
                rdr.go.eq(go), rdr.base.eq(self.base.storage), rdr.nwords.eq(self.nwords.storage),
                rdr.source.ready.eq(1),
                w_valid.eq(rdr.source.valid), w_data.eq(rdr.source.data),
                issued.eq(rdr.gen_done),
            ]
            ack = 0
        r_valid, r_row, r_data, ovf, rows_done = Signal(), Signal(16), Signal(32 * B), Signal(), Signal(16)
        self.sync += [
            If(go,
                addr.eq(self.base.storage), left.eq(self.nwords.storage),
                busy.eq(1), done.eq(0), written.eq(0), cycles.eq(0)
            ).Else(
                If(ack, addr.eq(addr + 1), left.eq(left - 1)),
                If(r_valid, written.eq(written + 1)),
                If(busy, cycles.eq(cycles + 1)),
                If(busy & (written == self.nrows.storage) & issued, busy.eq(0), done.eq(1),
                   nfin.eq(nfin1), self.fin.eq(nfin1 ^ (nfin1 >> 1))),
            ),
        ]
        self.comb += [
            nfin1.eq(nfin + 1),
            self.status.status.eq(Cat(busy, done, ovf)),
            self.rows.status.eq(written),
            self.cycles.status.eq(cycles),
        ]

        # Wishbone: activation writes in, results out
        self.bus = bus = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        wa = bus.adr[:18]
        aw_en = Signal()
        self.comb += aw_en.eq(bus.cyc & bus.stb & bus.we & ~bus.ack & ~wa[17])
        self.sync += bus.ack.eq(bus.cyc & bus.stb & ~bus.ack)

        # external activation writer (FFN unit), one register stage beside the engine
        self.ext_aw_en, self.ext_aw_addr, self.ext_aw_data = Signal(), Signal(13), Signal(32)
        xe, xa, xd = Signal(), Signal(13), Signal(32)
        self.sync += [xe.eq(self.ext_aw_en), xa.eq(self.ext_aw_addr), xd.eq(self.ext_aw_data)]
        # PCIe bridge activation fast path (litex/pcie_bridge.py; vector, address, data as a bus write), registered
        # here from the bridge's own registers by connect_pcie_aw(); unconnected = 0 (no logic). Priority: FFN unit >
        # PCIe > bus (never used at the same time). NOT input signals assigned from the bridge: such an alias gave the
        # bridge's register net an mvacc name, the floorplan put it in the engine region, away from the address adder
        # it packs with ("Unable to find legal placement", build_pcie2 try 1).
        self._pcie_aw = pe, pa, pv, pd = Signal(), Signal(13), Signal(2), Signal(32)

        reads = []
        self.res_mems = []
        for v in range(B):
            mem = Memory(32, max_rows)
            self.res_mems.append(mem)
            wp = mem.get_port(write_capable=True)
            rp = mem.get_port(clock_domain=results_domain) if jtag_results else mem.get_port()
            self.specials += mem, wp, rp
            self.comb += [wp.adr.eq(r_row), wp.dat_w.eq(r_data[32 * v:32 * (v + 1)]), wp.we.eq(r_valid)]
            if jtag_results:
                assert B == 1
                self._jport = (rp.adr, rp.dat_r)
            else:
                self.comb += rp.adr.eq(wa[:14])
            reads.append(rp.dat_r)
        sel = Signal(2)
        self.sync += sel.eq(wa[14:16])
        self.comb += bus.dat_r.eq(0 if jtag_results else reads[0] if B == 1 else Array(reads)[sel])
        self.jtag_results = jtag_results

        eports = dict(
            i_clk=ClockSignal(), i_rst=ResetSignal(),
            i_cfg_ng=self.ng.storage, i_start=go,
            i_w_valid=w_valid, i_w_data=w_data,
            i_aw_en=aw_en | xe | pe, i_aw_vec=Mux(xe, 0, Mux(pe, pv, wa[14:16])),
            i_aw_addr=Mux(xe, xa, Mux(pe, pa, wa[:13])), i_aw_data=Mux(xe, xd, Mux(pe, pd, bus.dat_w)),
            o_r_valid=r_valid, o_r_row=r_row, o_r_data=r_data, o_ovf=ovf, o_rows_done=rows_done)
        if engine is None:
            self.specials += Instance("mv_engine", p_B=B, **eports)
        else:
            self.submodules.engine_model = engine(eports)
        self._r, self.max_rows = (r_row, r_data, r_valid), max_rows
        self.st = Signal(6)
        self.comb += self.st.eq(Cat(self.fin, ovf, busy))

    def connect_pcie_aw(self, en, addr, vec, data):
        """activation fast-path write port: the PCIe bridge's registered outputs (one engine's enable bit)"""
        pe, pa, pv, pd = self._pcie_aw
        self.sync += [pe.eq(en), pa.eq(addr), pv.eq(vec), pd.eq(data)]

    def jtag_port(self):
        """Read port on vector 0's results, clocked by the JTAG TCK domain (jtagl). Returns (adr, dat_r).
        A separate copy of the result memory (written like the first): a third port on the first one made yosys
        put both engines' results into ~24K LUTs of distributed RAM instead of block RAM (build_dacc9 try 1)."""
        if self.jtag_results:
            return self._jport
        r_row, r_data, r_valid = self._r
        mem = Memory(32, self.max_rows)
        wp = mem.get_port(write_capable=True)
        rp = mem.get_port(clock_domain="jtagl")
        self.specials += mem, wp, rp
        self.comb += [wp.adr.eq(r_row), wp.dat_w.eq(r_data[:32]), wp.we.eq(r_valid)]
        return rp.adr, rp.dat_r

