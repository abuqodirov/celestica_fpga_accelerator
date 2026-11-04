#!/usr/bin/env python3
"""Run litex-boards' ypcb_00338_1p1 target with the openXC7 toolchain, with board fixes.

1. The upstream target builds its Platform without passing --toolchain, so it always
   used Vivado. Here the platform defaults to openxc7.
2. Phase-shifted MMCM outputs come out dead with nextpnr-xilinx on this chip (measured:
   any non-zero CLKOUTn_PHASE stops that output), but PLLE2 phase shifts work. The CRG is
   replaced by the same design using S7PLL. YPCB_DQS_PHASE sets the DQS clock phase
   (default 90 degrees, the usual A7DDRPHY value; upstream used 135).
3. YPCB_BIST=1 adds LiteDRAM's BIST generator/checker (BIOS: sdram_bist, sdram_hw_test), which
   drive the DRAM controller from their own crossbar ports, bypassing the CPU and the L2 cache.
4. YPCB_SPY=1 adds debug CSRs (dramspy_*) that latch the address of the last command at each stage of
   the controller: bank machine 0 request in, bank machine 0 command out, the CAS command chooser,
   the controller's DFI output and the PHY's DFI input.
5. YPCB_CSNOP=1 makes the controller deselect the DRAM (cs_n=1) on DFI phases without a command, the
   way DFII software mode does; upstream holds cs_n low on every phase for single-rank memories.
6. YPCB_LOOP=1 feeds each DDR3 command/address OSERDES output back through its OFB port into an ISERDESE2
   in the same IOI (8 samples per sys clock), i.e. what the serializer really emits. YPCB_LOOP=pad instead
   drives those pads through IOBUFs with an explicit tristate (OSERDES T1=0 -> TQ -> IOBUF.T) and samples
   the pad itself through the IOBUF input. A one-shot trigger
   on a DFI CAS (or ACT) freezes 12 clocks of that history into padloop_snap; padloop_arm re-arms it.
7. YPCB_DQOE_EARLY=1 turns the DQ output drivers on one sys cycle earlier (turn-off unchanged; LiteDRAM keeps
   >= CL+5 sys cycles between a read and the next write). Tried against the build-dependent 8-lane failure
   (m6/m7 beats 0-1 wrong on writes) - it does NOT help: 2/15 seeds still fail with it, 1/15 without
   (litex/sweep_results.txt). Kept only as a record; don't use it as a fix.
8. YPCB_DRAM_CHANNEL=1 uses the second DDR3 channel (banks 16-18; pins checked against the factory design
   readback, pins/factory_pins.txt) instead of channel 0 (banks 11-13). Same clocks and PLL.
9. YPCB_DUAL=1 adds channel 1 as a second DDR3 core next to channel 0 (main RAM): PHY ddrphy1 (lanes
   YPCB_LANES1, default 0-7), controller sdram1 (its DFII = CSRs sdram1_dfii_*), a 1 GiB CPU/loader window at
   0x80000000 paged by CSR ddr1_page, and with YPCB_BIST a second BIST (sdram1_generator/_checker). The BIOS
   only initialises channel 0; channel 1 is initialised from the host (ch1_init.py).
10. YPCB_ACCEL=B adds the matvec engine (accel/rtl/mv_engine.v, B activation vectors per weight pass) on a
   native port of channel 0 (accel/litex/mvaccel.py): CSRs mvacc_*, buffers/results window at 0xC0000000;
   with YPCB_DUAL a second engine on channel 1: CSRs mvacc1_*, window 0xC0100000.
11. YPCB_DDR0WIN=1 (with YPCB_DUAL) adds a paged window onto ALL of channel 0: 256 MiB at 0xD0000000, CSR
   ddr0_page (0..7) selects which 256 MiB. Main RAM (0x40000000) only maps channel 0's first 512 MiB, so without
   it the CPU and the JTAG loader cannot reach 1.5 GiB of channel 0. The window has its own 8 KiB cache: don't mix
   main-RAM and window accesses to the same DRAM without evicting (see _DDR1Window).
12. YPCB_BUSPIPE=1 puts a Wishbone register slice (wb_slice.py, +2 cycles per access) in front of main RAM,
   ddr0/ddr1, the engines' windows and the CSR bridge: the CPU's single-cycle round trips to the far end of the die
   (the few-word memtest errors of big dual builds) become two one-way hops.
13. YPCB_JTAGREAD=1 (with YPCB_JTAGLOAD and YPCB_ACCEL) adds a result reader to the JTAG loader (jtag_shift.py): a
   scan whose header word has bit 0 set streams engine results (float32 rows) out on TDO at the JTAG clock rate
   (~1.9 MB/s at 15 MHz vs a few KB/s through the console), and every scan's status word carries each engine's
   finished-run counter. Used by mustaqi/fpga_chat.py. YPCB_JTAGREAD=1 gives the reader its own copy of each
   engine's result memory (+16 RAMB36; build_dacc9 routed badly); YPCB_JTAGREAD=2 clocks the existing result
   memory's read port from JTAG instead (no extra RAM; the CPU can then no longer read results over the bus).
   Since build_dacc11 the reader also has packed reads (two results per word as bfloat16: half the JTAG bits) and
   'both' writes (one loader word written to both engines' windows: activations cross the cable once).
14. YPCB_FFN=1 (with YPCB_DUAL, YPCB_ACCEL=1) adds the FFN unit (accel/litex/ffnunit.py, accel/rtl/ffn_unit.v):
   SiLU(gate) * up computed from the two engines' result streams and written, quantized, into both engines'
   activation buffers - gate_up's results and down_proj's input no longer cross the JTAG cable. CSRs ffn_*;
   with YPCB_JTAGREAD its busy/err bits are in the JTAG status word (bits 61, 62).
Then the target's own main() runs unchanged.
15. YPCB_PCIE=1 (with YPCB_ACCEL; replaces YPCB_JTAGREAD) adds the PCIe Gen1 x8 endpoint and bus bridge
   (pcie_bridge.py, ../pcie/core): the PC's BAR0 (2 MB) = 7 movable windows onto the SoC bus + bridge registers;
   engine results / status read directly. The engines' result memory read port moves to the bridge (sys clock).
   Bitstream post-processing for the transceivers: build_pcie.sh.
16. YPCB_REFRESH_FIX=1: DDR3 refresh as the chips need it, both channels. LiteDRAM's MT41J256M16 gives tRFC in
   DDR3-1600 clocks (208 = 260 ns) and converts clocks, so at our DDR3-600 every refresh blocked the DRAM for 52 sys
   clocks (693 ns) every 7.8 us; ddr3_module.MT41J256M16_ns uses 350 ns (safe for 4 and 8 Gbit chips: 27 clocks).
   Plus refresh_postponing=8 (JEDEC allows 8 postponed REFs): 8 refreshes back to back, one precharge-all/re-open
   per 62 us instead of per 7.8 us. Simulated (sim/test_dram_split.py): engine stream 84.9 % -> 90.3 % of 64 B/clk.
17. YPCB_SPLITDMA=1 (with YPCB_ACCEL): each engine streams its weights over TWO native ports of its DRAM channel
   (accel/litex/dramsplit.BankSplitReader, even / odd 8 KiB banks, 128-word FIFO each) instead of one: LiteDRAM's
   crossbar stalls a port at every bank change; with two ports the next bank opens while the other port reads.
   Simulated 90.3 -> 94.0 % (with item 16); accel/litex/test_mvaccel_split.py PASS (rows, done logic).
"""
import os
from functools import reduce
from operator import or_

from litex.gen import LiteXModule
from migen import ClockDomain, ClockDomainsRenamer, Signal, If, Cat, Constant, Instance, Mux, ClockSignal, ResetSignal, Case, Array
from litex.soc.cores.clock import S7PLL, S7IDELAYCTRL

from litex_boards.platforms import ypcb_00338_1p1 as plat
from litex_boards.targets import ypcb_00338_1p1 as target

_orig_init = plat.Platform.__init__


def _init(self, *args, toolchain="openxc7", **kwargs):
    _orig_init(self, *args, toolchain=toolchain, **kwargs)


plat.Platform.__init__ = _init


class _PLLCRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.rst          = Signal()
        self.cd_sys       = ClockDomain()
        self.cd_sys4x     = ClockDomain()
        self.cd_sys4x_dqs = ClockDomain()
        self.cd_idelay    = ClockDomain()

        clk200 = platform.request("clk200")
        rst_n  = platform.request("rst_n")

        self.pll = pll = S7PLL(speedgrade=-2)
        self.comb += pll.reset.eq(~rst_n | self.rst)
        pll.register_clkin(clk200, 200e6)
        pll.create_clkout(self.cd_sys,       sys_clk_freq)
        pll.create_clkout(self.cd_sys4x,     4 * sys_clk_freq)
        pll.create_clkout(self.cd_sys4x_dqs, 4 * sys_clk_freq, phase=float(os.environ.get("YPCB_DQS_PHASE", 90)))
        pll.create_clkout(self.cd_idelay,    200e6)
        if os.environ.get("YPCB_CK_PHASE") is not None:
            self.cd_sys4x_ck = ClockDomain()
            pll.create_clkout(self.cd_sys4x_ck, 4 * sys_clk_freq, phase=float(os.environ["YPCB_CK_PHASE"]))
        if os.environ.get("YPCB_CMD_PHASE") is not None:
            self.cd_sys4x_cmd = ClockDomain()
            pll.create_clkout(self.cd_sys4x_cmd, 4 * sys_clk_freq, phase=float(os.environ["YPCB_CMD_PHASE"]))
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin)

        self.idelayctrl = S7IDELAYCTRL(self.cd_idelay)


target._CRG = _PLLCRG

if os.environ.get("YPCB_BIST"):
    from litex.soc.integration.soc import LiteXSoC as SoC
    _orig_add_sdram = SoC.add_sdram

    def _add_sdram(self, *args, **kwargs):
        kwargs.setdefault("with_bist", True)
        return _orig_add_sdram(self, *args, **kwargs)

    SoC.add_sdram = _add_sdram


class _DRAMSpy(LiteXModule):
    """Latch the address of the most recent command at each stage of the LiteDRAM controller."""
    def __init__(self, sdram):
        from litex.soc.interconnect.csr import CSRStatus
        from litedram.core.bankmachine import BankMachine
        ctrl = sdram.controller
        bm0  = [m for _, m in ctrl._submodules if isinstance(m, BankMachine)][0]
        mux  = ctrl.multiplexer

        def latch(name, cond, value):
            st  = CSRStatus(32, name=name)
            cnt = CSRStatus(32, name=name + "_n")
            setattr(self, name, st)
            setattr(self, name + "_n", cnt)
            self.sync += If(cond, st.status.eq(value), cnt.status.eq(cnt.status + 1))

        req = bm0.req
        latch("bm0_req", req.valid & req.ready, Cat(req.addr, req.we))
        c = bm0.cmd
        latch("bm0_cas", c.valid & c.ready & c.cas, c.a)
        latch("bm0_act", c.valid & c.ready & c.ras & ~c.cas, c.a)
        r = mux.choose_req.cmd
        latch("chreq_cas", r.valid & r.ready & r.cas, Cat(r.a, r.ba))
        for tag, dfi_if in (("ctl", sdram.dfii.slave), ("phy", sdram.dfii.master)):
            for kind, ras, cas in (("cas", 1, 0), ("act", 0, 1)):
                conds = [(p.cs_n == 0) & (p.ras_n == ras) & (p.cas_n == cas) & ((p.we_n == 1) if kind == "act" else 1)
                         for p in dfi_if.phases]
                val = Signal(32)
                self.comb += [If(cd, val.eq(Cat(p.address, p.bank, Constant(i, 2)))) for i, (p, cd) in enumerate(zip(dfi_if.phases, conds))]
                latch(f"{tag}_{kind}", reduce(or_, conds), val)

        # Windows: all 4 phases of the PHY's DFI input, one clock before, at and after the most recent
        # CAS (and ACT): {cs_n, ras_n, cas_n, we_n, bank[2:0], address[14:0]} per phase and clock.
        m = sdram.dfii.master
        def word(p):
            return Cat(p.address, p.bank, p.we_n, p.cas_n, p.ras_n, p.cs_n)
        cur  = [word(p) for p in m.phases]
        prev = [Signal(22) for _ in range(4)]
        self.sync += [pr.eq(c) for pr, c in zip(prev, cur)]
        for kind, ras, cas in (("cas", 1, 0), ("act", 0, 1)):
            hit = reduce(or_, [(p.cs_n == 0) & (p.ras_n == ras) & (p.cas_n == cas) & ((p.we_n == 1) if kind == "act" else 1)
                               for p in m.phases])
            pending = Signal()
            regs = [[CSRStatus(22, name=f"w{kind}_{t}_p{i}") for i in range(4)] for t in ("m1", "t0", "p1")]
            for t, row in zip(("m1", "t0", "p1"), regs):
                for i, r in enumerate(row):
                    setattr(self, f"w{kind}_{t}_p{i}", r)
            self.sync += [
                pending.eq(hit),
                If(hit, *[r.status.eq(v) for r, v in zip(regs[0], prev)], *[r.status.eq(v) for r, v in zip(regs[1], cur)]),
                If(pending, *[r.status.eq(v) for r, v in zip(regs[2], cur)]),
            ]


if os.environ.get("YPCB_DRAM_CHANNEL"):
    _orig_soc_init_ch = target.BaseSoC.__init__

    def _soc_init_ch(self, *args, **kwargs):
        kwargs.setdefault("dram_channel", int(os.environ["YPCB_DRAM_CHANNEL"]))
        _orig_soc_init_ch(self, *args, **kwargs)

    target.BaseSoC.__init__ = _soc_init_ch

class _DDR1Window(LiteXModule):
    """Wishbone window onto a DDR3 channel for the CPU and the JTAG loader: 2**win_bits 32-bit words, `page`
    (CSR <name>_page, page_bits wide) selects which part of the 2 GiB channel it shows. Channel 1: 1 GiB at
    0x80000000 (ddr1_page, 2 pages); channel 0 with YPCB_DDR0WIN: 256 MiB at 0xD0000000 (ddr0_page, 8 pages; main
    RAM only maps channel 0's first 512 MiB). Bulk users (BIST, accelerator) take their own native ports instead.
    The board has no DDR3 DM pins, so every native-port write stores a whole 64-byte word (byte enables are
    ignored): a single 32-bit write would zero the other 15 words. The window therefore goes through an
    8 KiB write-back cache like main RAM's L2, which only ever writes whole lines. Before another port reads
    what was written here, evict the cache (read 16 KiB elsewhere in the window)."""
    def __init__(self, port, cache_size=8192, win_bits=28, page_bits=1):
        from litex.soc.interconnect import wishbone
        from litex.soc.interconnect.csr import CSRStorage
        from litedram.frontend.wishbone import LiteDRAMWishbone2Native
        from migen.fhdl.simplify import FullMemoryWE
        self.page = CSRStorage(page_bits)
        self.bus = bus = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        inner = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        self.comb += [bus.connect(inner, omit={"adr"}), inner.adr.eq(Cat(bus.adr[:win_bits], self.page.storage))]
        wide = wishbone.Interface(data_width=port.data_width, address_width=32, addressing="word")
        # reverse=False like main RAM's L2: the Cache default (reverse=True) stores each line's 32-bit words in
        # reverse order in DRAM - invisible through the cache, but other DRAM readers (the matvec engine) saw
        # every 64-byte line word-reversed.
        self.cache = FullMemoryWE()(wishbone.Cache(cachesize=cache_size // 4, master=inner, slave=wide, reverse=False))
        self.wb2native = LiteDRAMWishbone2Native(wishbone=wide, port=port)


if os.environ.get("YPCB_REFRESH_FIX"):
    from litedram import core as _ldcore
    from litedram.core.controller import ControllerSettings as _CtrlSettings
    from ddr3_module import MT41J256M16_ns as _MT41_ns
    _orig_ldcore_init = _ldcore.LiteDRAMCore.__init__

    def _ldcore_init(self, phy, geom_settings, timing_settings, clk_freq, **kw):
        kw.setdefault("controller_settings", _CtrlSettings(refresh_postponing=8))
        _orig_ldcore_init(self, phy, geom_settings, timing_settings, clk_freq, **kw)
    _ldcore.LiteDRAMCore.__init__ = _ldcore_init
    target.MT41J256M16 = _MT41_ns                       # channel 0 (the target's add_sdram)


def _dram_module():
    """the DDR3 module class for channel 1 (channel 0: the target's, patched above)"""
    if os.environ.get("YPCB_REFRESH_FIX"):
        from ddr3_module import MT41J256M16_ns
        return MT41J256M16_ns
    from litedram.modules import MT41J256M16
    return MT41J256M16


if os.environ.get("YPCB_DUAL"):
    _orig_soc_init_dual = target.BaseSoC.__init__

    def _soc_init_dual(self, *args, **kwargs):
        _orig_soc_init_dual(self, *args, **kwargs)
        from litedram.common import PHYPadsReducer as _PadsReducer
        from litedram.core import LiteDRAMCore
        from litedram.modules import MT41J256M16
        from litedram.phy import s7ddrphy
        from litex.soc.integration.soc import SoCRegion
        lanes = [int(x) for x in os.environ.get("YPCB_LANES1", "0,1,2,3,4,5,6,7").split(",")]
        self.ddrphy1 = s7ddrphy.A7DDRPHY(_PadsReducer(self.platform.request("ddram", 1), lanes),
            memtype="DDR3", nphases=4, sys_clk_freq=self.sys_clk_freq)
        module = _dram_module()(self.sys_clk_freq, "1:4")
        self.sdram1 = LiteDRAMCore(phy=self.ddrphy1, geom_settings=module.geom_settings,
            timing_settings=module.timing_settings, clk_freq=self.sys_clk_freq)
        self.ddr1 = _DDR1Window(self.sdram1.crossbar.get_port())
        self.bus.add_slave("ddr1", self.ddr1.bus, SoCRegion(origin=0x80000000, size=0x40000000, cached=False))
        if os.environ.get("YPCB_DDR0WIN"):                  # all of channel 0 for the CPU / JTAG loader
            self.ddr0 = _DDR1Window(self.sdram.crossbar.get_port(), win_bits=26, page_bits=3)
            self.bus.add_slave("ddr0", self.ddr0.bus, SoCRegion(origin=0xD0000000, size=0x10000000, cached=False))
        if os.environ.get("YPCB_BIST"):
            from litedram.frontend.bist import LiteDRAMBISTChecker, LiteDRAMBISTGenerator
            self.sdram1_generator = LiteDRAMBISTGenerator(self.sdram1.crossbar.get_port())
            self.sdram1_checker = LiteDRAMBISTChecker(self.sdram1.crossbar.get_port())

    target.BaseSoC.__init__ = _soc_init_dual

if os.environ.get("YPCB_ACCEL"):
    _orig_soc_init_acc = target.BaseSoC.__init__

    def _soc_init_acc(self, *args, **kwargs):
        _orig_soc_init_acc(self, *args, **kwargs)
        import sys
        from litex.soc.integration.soc import SoCRegion
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "accel", "litex"))
        from mvaccel import MVAccel
        B = int(os.environ["YPCB_ACCEL"])
        jr = os.environ.get("YPCB_JTAGREAD") == "2"       # results read port on the JTAG clock (no bus reads)
        pc = bool(os.environ.get("YPCB_PCIE"))            # ... or on the sys clock for the PCIe bridge
        assert not (jr and pc), "YPCB_PCIE replaces YPCB_JTAGREAD"
        rd = "sys" if pc else "jtagl"
        sp = bool(os.environ.get("YPCB_SPLITDMA"))
        self.mvacc = MVAccel(self.platform, self.sdram.crossbar.get_port(), B=B, jtag_results=jr or pc,
                             results_domain=rd, port1=self.sdram.crossbar.get_port() if sp else None)
        self.bus.add_slave("mvacc", self.mvacc.bus, SoCRegion(origin=0xC0000000, size=0x100000, cached=False))
        if hasattr(self, "sdram1"):                                     # YPCB_DUAL: one engine per channel
            self.mvacc1 = MVAccel(self.platform, self.sdram1.crossbar.get_port(), B=B, jtag_results=jr or pc,
                                  results_domain=rd, port1=self.sdram1.crossbar.get_port() if sp else None)
            self.bus.add_slave("mvacc1", self.mvacc1.bus, SoCRegion(origin=0xC0100000, size=0x100000, cached=False))
            if os.environ.get("YPCB_FFN"):                              # gate rows on channel 0, up rows on 1
                from ffnunit import FFNUnit
                assert B == 1, "the FFN unit takes one result per row"
                self.ffn = FFNUnit(self.platform, self.mvacc, self.mvacc1)

    target.BaseSoC.__init__ = _soc_init_acc

if os.environ.get("YPCB_BUSPIPE"):
    # Register slices (wb_slice.py) in front of the bus slaves that sit far from the CPU: both DDR3 channels'
    # CPU paths (main RAM's L2, the ddr0/ddr1 windows), the engines' windows and the CSR bridge. LiteX adds the CSR
    # bridge in _finalize_bus right before building the interconnect, so the slices go in there.
    from litex.soc.integration.soc import SoC as _SoCB
    _orig_add_csr_bridge = _SoCB.add_csr_bridge

    def _add_csr_bridge_pipe(self, *args, **kwargs):
        _orig_add_csr_bridge(self, *args, **kwargs)
        import sys
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from wb_slice import pipeline_slaves
        done = pipeline_slaves(self, ["main_ram", "ddr0", "ddr1", "mvacc", "mvacc1", "csr"])
        self.logger.info(f"YPCB_BUSPIPE: register slices in front of {', '.join(done)}")

    _SoCB.add_csr_bridge = _add_csr_bridge_pipe

if os.environ.get("YPCB_SPY"):
    _orig_soc_init = target.BaseSoC.__init__

    def _soc_init(self, *args, **kwargs):
        _orig_soc_init(self, *args, **kwargs)
        self.dramspy = _DRAMSpy(self.sdram)

    target.BaseSoC.__init__ = _soc_init

if any(os.environ.get(k) for k in ("YPCB_CSNOP", "YPCB_ZIDLE", "YPCB_HOLD")):
    from migen import Array, Replicate
    from migen.fhdl.structure import _Assign
    from litedram.core import multiplexer as _mux
    _orig_steerer_init = _mux._Steerer.__init__

    def _steerer_init(self, commands, dfi):
        _orig_steerer_init(self, commands, dfi)
        if os.environ.get("YPCB_CSNOP"):
            cs = {id(p.cs_n) for p in dfi.phases}
            self._fragment.sync["sys"] = [st for st in self._fragment.sync["sys"]
                                          if not (isinstance(st, _Assign) and id(st.l) in cs)]

        def valid_and(cmd, attr):
            return cmd.valid & cmd.ready & getattr(cmd, attr) if hasattr(cmd, "valid") else 0

        for phase, sel in zip(dfi.phases, self.sel):
            active = Array(valid_and(c, "cas") | valid_and(c, "ras") | valid_and(c, "we") for c in commands)[sel]
            if os.environ.get("YPCB_CSNOP"):
                self.sync += phase.cs_n.eq(Replicate(~active, len(phase.cs_n)))
            if os.environ.get("YPCB_ZIDLE"):
                held = {id(phase.address), id(phase.bank)}
                self._fragment.sync["sys"] = [st for st in self._fragment.sync["sys"]
                                              if not (isinstance(st, _Assign) and id(st.l) in held)]
                self.sync += If(active,
                    phase.address.eq(Array(c.a for c in commands)[sel]),
                    phase.bank.eq(Array(c.ba for c in commands)[sel])
                ).Else(phase.address.eq(0), phase.bank.eq(0))
            if os.environ.get("YPCB_HOLD"):
                held = {id(phase.address), id(phase.bank)}
                self._fragment.sync["sys"] = [st for st in self._fragment.sync["sys"]
                                              if not (isinstance(st, _Assign) and id(st.l) in held)]
                self.sync += If(active,
                    phase.address.eq(Array(c.a for c in commands)[sel]),
                    phase.bank.eq(Array(c.ba for c in commands)[sel]))

    _mux._Steerer.__init__ = _steerer_init

LOOP_PINS = [("cs_n", 0), ("ras_n", 0), ("cas_n", 0), ("we_n", 0), ("ba", 0), ("ba", 1), ("ba", 2)] + \
            [("a", i) for i in range(10)]


class _PadLoop(LiteXModule):
    def __init__(self, ofb, dfi, ncycles=12, post=8, from_pad=False):
        from litex.soc.interconnect.csr import CSR, CSRStatus, CSRStorage
        self.arm   = CSR()
        self.mode  = CSRStorage(1)        # 0: trigger on CAS, 1: on ACT
        self.done  = CSRStatus()
        words = {}
        for key in LOOP_PINS:
            q = Signal(8)
            self.specials += Instance("ISERDESE2", name=f"loop_iserdes_{key[0]}{key[1]}",
                p_DATA_WIDTH=8, p_DATA_RATE="DDR", p_SERDES_MODE="MASTER",
                p_INTERFACE_TYPE="NETWORKING", p_NUM_CE=1, p_IOBDELAY="NONE",
                p_OFB_USED="FALSE" if from_pad else "TRUE",
                **({"i_D": ofb[key]} if from_pad else {"i_OFB": ofb[key]}),
                i_CE1=1, i_RST=ResetSignal("sys"), i_BITSLIP=0,
                i_CLK=ClockSignal("sys4x"), i_CLKB=~ClockSignal("sys4x"), i_CLKDIV=ClockSignal("sys"),
                **{f"o_Q{8 - k}": q[k] for k in range(8)})   # q[0] = earliest sample
            words[key] = q
        cycle = Cat(*[words[k] for k in LOOP_PINS])
        hist  = [Signal(len(cycle)) for _ in range(ncycles)]
        self.sync += [hist[0].eq(cycle)] + [hist[k].eq(hist[k - 1]) for k in range(1, ncycles)]
        self.snap = CSRStatus(len(cycle) * ncycles)
        cas = reduce(or_, [(p.cs_n == 0) & (p.ras_n == 1) & (p.cas_n == 0) for p in dfi.phases])
        act = reduce(or_, [(p.cs_n == 0) & (p.ras_n == 0) & (p.cas_n == 1) & (p.we_n == 1) for p in dfi.phases])
        trig = Signal()
        self.comb += trig.eq(Mux(self.mode.storage, act, cas))
        armed, count = Signal(), Signal(max=post + 1)
        self.sync += [
            If(self.arm.wr_stb, armed.eq(1), count.eq(0), self.done.status.eq(0)),
            If(armed & (count == 0) & trig, count.eq(1)),
            If(armed & (count != 0),
                count.eq(count + 1),
                If(count == post,
                    armed.eq(0), count.eq(0), self.done.status.eq(1),
                    self.snap.status.eq(Cat(*hist)))),
        ]


if os.environ.get("YPCB_LOOP"):
    from litedram.phy import s7ddrphy as _s7
    _orig_a7_init = _s7.A7DDRPHY.__init__

    def _a7_init(self, pads, **kwargs):
        from migen.fhdl.structure import _Slice, _Assign
        pad_mode = os.environ["YPCB_LOOP"] == "pad"
        names = ("a", "ba", "cs_n", "ras_n", "cas_n", "we_n")
        if pad_mode:
            # The PHY drives internal signals; IOBUFs below drive the real pads.
            inner = {n: Signal(len(getattr(pads, n)), name=f"loop_{n}") for n in names}

            class _Proxy:
                def __getattr__(_, name):
                    return inner[name] if name in inner else getattr(pads, name)
            target_pads = _Proxy()
        else:
            target_pads = pads
        _orig_a7_init(self, target_pads, **kwargs)
        driven = inner if pad_mode else {n: getattr(pads, n) for n in names}
        # Map each command/address OSERDES to its pad (the PHY drives pads.ba through pads_ba).
        alias = {}
        for st in self._fragment.comb:
            if isinstance(st, _Assign) and st.l is driven["ba"]:
                alias[id(st.r)] = "ba"
        for n in names:
            alias.setdefault(id(driven[n]), n)
        taps, tq = {}, {}
        for sp in self._fragment.specials:
            if getattr(sp, "of", None) != "OSERDESE2":
                continue
            oq = [it for it in sp.items if isinstance(it, Instance.Output) and it.name == "OQ"][0].expr
            if not (isinstance(oq, _Slice) and id(oq.value) in alias):
                continue
            key = (alias[id(oq.value)], oq.start)
            if pad_mode:
                t = Signal(name=f"loop_tq_{key[0]}{key[1]}")
                sp.items += [Instance.Input("T1", 0), Instance.Input("TCE", 1), Instance.Output("TQ", t)]
                tq[key] = t
            elif key in LOOP_PINS:
                o = Signal(name=f"loop_ofb_{key[0]}{key[1]}")
                sp.items.append(Instance.Output("OFB", o))
                taps[key] = o
        if pad_mode:
            assert len(tq) == sum(len(getattr(pads, n)) for n in names), len(tq)
            for n in names:
                for i in range(len(getattr(pads, n))):
                    o = Signal(name=f"loop_pad_{n}{i}")
                    self.specials += Instance("IOBUF", i_I=inner[n][i], i_T=tq[(n, i)],
                                              io_IO=getattr(pads, n)[i], o_O=o)
                    taps[(n, i)] = o
        assert all(k in taps for k in LOOP_PINS), sorted(taps)
        self.submodules.padloop = _PadLoop({k: taps[k] for k in LOOP_PINS}, self.dfi, from_pad=pad_mode)

    _s7.A7DDRPHY.__init__ = _a7_init

if os.environ.get("YPCB_TIMING"):
    from litedram.modules import MT41J256M16
    over = dict(kv.split("=") for kv in os.environ["YPCB_TIMING"].split(","))
    for t in MT41J256M16.speedgrade_timings.values():
        for k, val in over.items():
            setattr(t, k, (None, float(val)) if k in ("tRFC", "tFAW") else float(val))

class _DFISkew(LiteXModule):
    def __init__(self, m, p, maxd=3):
        from litex.soc.interconnect.csr import CSRStorage
        self.addr_delay = CSRStorage(2)
        self.cmd_delay  = CSRStorage(2)
        groups = {"address": self.addr_delay, "bank": self.addr_delay}
        for name in ("cs_n", "ras_n", "cas_n", "we_n", "wrdata", "wrdata_en", "wrdata_mask", "rddata_en"):
            groups[name] = self.cmd_delay
        for mp, pp in zip(m.phases, p.phases):
            for name, sel in groups.items():
                src, dst = getattr(mp, name), getattr(pp, name)
                taps = [src]
                for _ in range(maxd):
                    r = Signal(len(src), reset_less=True)
                    self.sync += r.eq(taps[-1])
                    taps.append(r)
                self.comb += Case(sel.storage, {k: dst.eq(t) for k, t in enumerate(taps)})


if os.environ.get("YPCB_SKEW"):
    from migen.fhdl.structure import _Assign
    from litedram.core import LiteDRAMCore
    _orig_core_init = LiteDRAMCore.__init__

    def _core_init(self, phy, *args, **kwargs):
        _orig_core_init(self, phy, *args, **kwargs)
        names = ("address", "bank", "cs_n", "ras_n", "cas_n", "we_n", "wrdata", "wrdata_en", "wrdata_mask", "rddata_en")
        targets = {id(getattr(pp, n)) for pp in phy.dfi.phases for n in names}
        before = len(self._fragment.comb)
        self._fragment.comb = [st for st in self._fragment.comb
                               if not (isinstance(st, _Assign) and id(st.l) in targets)]
        assert before - len(self._fragment.comb) == len(targets), (before, len(self._fragment.comb), len(targets))
        self.submodules.dfiskew = _DFISkew(self.dfii.master, phy.dfi)

    LiteDRAMCore.__init__ = _core_init

if os.environ.get("YPCB_CMDGAP"):
    from migen.fhdl.structure import _Assign, _Operator
    from litedram.core import multiplexer as _muxmod
    _orig_mux_init = _muxmod.Multiplexer.__init__

    def _mux_init(self, settings, *args, **kwargs):
        _orig_mux_init(self, settings, *args, **kwargs)
        ph = {id(settings.phy.rdphase), id(settings.phy.wrphase)}
        new, n = [], 0
        for st in self._fragment.comb:
            if (isinstance(st, _Assign) and isinstance(st.r, _Operator) and st.r.op == "-"
                    and id(st.r.operands[0]) in ph):
                new.append(st.l.eq(st.r.operands[0] - 2)); n += 1
            else:
                new.append(st)
        assert n == 2, n
        self._fragment.comb = new

    _muxmod.Multiplexer.__init__ = _mux_init

if os.environ.get("YPCB_CMD_PHASE") is not None:
    from migen.fhdl.structure import _Slice, _Assign
    from litedram.phy import s7ddrphy as _s7c
    _orig_a7_cmdclk = _s7c.A7DDRPHY.__init__

    def _a7_cmdclk(self, pads, **kwargs):
        _orig_a7_cmdclk(self, pads, **kwargs)
        cmd = {id(getattr(pads, n)) for n in ("a", "cs_n", "ras_n", "cas_n", "we_n")}
        for st in self._fragment.comb:
            if isinstance(st, _Assign) and st.l is pads.ba:
                cmd.add(id(st.r))
        n = 0
        for sp in self._fragment.specials:
            if getattr(sp, "of", None) != "OSERDESE2":
                continue
            oq = [it for it in sp.items if isinstance(it, Instance.Output) and it.name == "OQ"][0].expr
            if isinstance(oq, _Slice) and id(oq.value) in cmd:
                for it in sp.items:
                    if isinstance(it, Instance.Input) and it.name == "CLK":
                        it.expr = ClockSignal("sys4x_cmd"); n += 1
        assert n == len(pads.a) + len(pads.ba) + 4, n

    _s7c.A7DDRPHY.__init__ = _a7_cmdclk

if os.environ.get("YPCB_CK_PHASE") is not None:
    from litedram.phy import s7ddrphy as _s7k
    _orig_a7_ck = _s7k.A7DDRPHY.__init__

    def _a7_ck(self, pads, **kwargs):
        _orig_a7_ck(self, pads, **kwargs)
        n = 0
        for sp in self._fragment.specials:
            if getattr(sp, "of", None) != "OSERDESE2":
                continue
            d = {it.name: it.expr for it in sp.items if isinstance(it, Instance.Input) and it.name.startswith("D")}
            val = lambda e: e if isinstance(e, int) else getattr(e, "value", None)
            if [val(d.get(f"D{k}")) for k in range(1, 9)] == [0, 1, 0, 1, 0, 1, 0, 1]:   # the CK serializer
                for it in sp.items:
                    if isinstance(it, Instance.Input) and it.name == "CLK":
                        it.expr = ClockSignal("sys4x_ck"); n += 1
        assert n == len(pads.clk_p), n

    _s7k.A7DDRPHY.__init__ = _a7_ck

if os.environ.get("YPCB_DQOE_EARLY"):
    from litedram.common import TappedDelayLine as _TDL
    from litedram.phy import s7ddrphy as _s7o
    _orig_a7_oe = _s7o.A7DDRPHY.__init__

    def _a7_oe(self, pads, **kwargs):
        _orig_a7_oe(self, pads, **kwargs)
        # The DQ and DQS tristates both come from 2-tap delay lines (T1 = ~line.output); the DQ one is the
        # line driving one T1 per DQ pin.
        lines = {id(m.output): m for _, m in self._submodules if isinstance(m, _TDL) and len(m.taps) == 2}
        users = {}
        for sp in self._fragment.specials:
            if getattr(sp, "of", None) != "OSERDESE2":
                continue
            for it in sp.items:
                if not (isinstance(it, Instance.Input) and it.name == "T1" and getattr(it.expr, "op", None) == "~"):
                    continue
                if id(it.expr.operands[0]) in lines:
                    users.setdefault(id(it.expr.operands[0]), []).append(it)
        dq = [k for k, its in users.items() if len(its) == len(pads.dq)]
        assert len(dq) == 1, {k: len(v) for k, v in users.items()}
        line = lines[dq[0]]
        for it in users[dq[0]]:
            it.expr = ~(line.taps[0] | line.output)

    _s7o.A7DDRPHY.__init__ = _a7_oe

if os.environ.get("YPCB_LANES"):
    from litedram.common import PHYPadsReducer as _Reducer
    _lanes = [int(x) for x in os.environ["YPCB_LANES"].split(",")]
    target.PHYPadsReducer = lambda pads, modules: _Reducer(pads, _lanes)

class _JtagLoader(LiteXModule):
    def __init__(self, soc):
        from litex.soc.interconnect import stream, wishbone
        from litex.soc.cores.jtag import XilinxJTAG

        def find(m):
            for _, sub in getattr(m, "_submodules", []):
                if isinstance(sub, XilinxJTAG) and sub.chain == 1:
                    return sub
                r = find(sub)
                if r is not None:
                    return r
        uart_jtag = find(soc)
        assert uart_jtag is not None, "needs --uart-name jtag_uart"
        # Clock and TDI come from the console's BSCANE2 (chain 1): on this toolchain the TCK/TDI outputs of a
        # second BSCANE2 (BSCAN2_TCK/TDI pips) never toggle - the NES design, which works, also uses
        # BSCAN1's. SEL/SHIFT/CAPTURE of chain 2 are fine.
        # TCK goes through a BUFG (as in the NES design): on plain fabric routing the clock skew corrupts
        # the shift logic.
        self.cd_jtagl = ClockDomain()
        tck, tdi = uart_jtag.tck, uart_jtag.tdi
        sel, shift, capture, tdo = Signal(), Signal(), Signal(), Signal()
        self.specials += Instance("BSCANE2", p_JTAG_CHAIN=2,
            o_TCK=Signal(), o_TDI=Signal(), o_SEL=sel, o_SHIFT=shift, o_CAPTURE=capture,
            o_UPDATE=Signal(), o_DRCK=Signal(), o_RESET=Signal(), o_RUNTEST=Signal(), o_TMS=Signal(), i_TDO=tdo)
        self.specials += Instance("BUFG", i_I=tck, o_O=self.cd_jtagl.clk)
        fifo = stream.AsyncFIFO([("addr", 30), ("data", 32)], depth=256)
        self.fifo = fifo = ClockDomainsRenamer({"write": "jtagl", "read": "sys"})(fifo)
        if os.environ.get("YPCB_JTAGREAD"):
            # result reader (jtag_shift.py): read scans stream the engines' results out on TDO
            import sys
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            from jtag_shift import JtagShift
            from migen.genlib.cdc import MultiReg
            engines = [e for e in (getattr(soc, "mvacc", None), getattr(soc, "mvacc1", None)) if e is not None]
            assert engines, "YPCB_JTAGREAD needs YPCB_ACCEL"
            est = Signal(12 + 2 * hasattr(soc, "ffn"))
            for i, e in enumerate(engines):
                self.specials += MultiReg(e.st, est[6 * i:6 * i + 6], "jtagl")
            if hasattr(soc, "ffn"):                                     # FFN unit busy, err -> status bits 61, 62
                self.specials += MultiReg(soc.ffn.st, est[12:14], "jtagl")
            self.js = JtagShift(fifo.sink, [e.jtag_port() for e in engines], est,
                                bc_offset=0xC0100000 - 0xC0000000)     # 'both' writes: mvacc -> mvacc1 window
            self.comb += [self.js.sel.eq(sel), self.js.shift.eq(shift), self.js.capture.eq(capture),
                          self.js.tdi.eq(tdi), tdo.eq(self.js.tdo)]
        sr, cnt, have_addr, addr = Signal(32), Signal(5), Signal(), Signal(32)
        # status, shifted out on TDO during the next scan: [31:0] current byte address (next word goes there),
        # [55:32] words received, [56] FIFO overflow (sticky)
        nwords, overflow, status = Signal(24), Signal(), Signal(64)
        word = Cat(sr[1:], tdi)
        if not os.environ.get("YPCB_JTAGREAD"):
          self.comb += tdo.eq(status[0])
          self.sync.jtagl += [
            fifo.sink.valid.eq(0),
            If(fifo.sink.valid & ~fifo.sink.ready, overflow.eq(1)),
            If(fifo.sink.valid, nwords.eq(nwords + 1)),
            If(sel & capture, cnt.eq(0), have_addr.eq(0), status.eq(Cat(addr, nwords, overflow))),
            If(sel & shift,
                status.eq(status[1:]),
                sr.eq(word), cnt.eq(cnt + 1),
                If(cnt == 31,
                    If(~have_addr, addr.eq(word), have_addr.eq(1)
                    ).Else(fifo.sink.valid.eq(1), fifo.sink.addr.eq(addr[2:]), fifo.sink.data.eq(word),
                           addr.eq(addr + 4))))
          ]
        wb = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        self.comb += [
            wb.adr.eq(fifo.source.addr), wb.dat_w.eq(fifo.source.data), wb.sel.eq(0xF), wb.we.eq(1),
            wb.cyc.eq(fifo.source.valid), wb.stb.eq(fifo.source.valid), fifo.source.ready.eq(wb.ack),
        ]
        soc.bus.add_master(name="jtagload", master=wb)
        # debug: sys-side view. Every popped FIFO entry is logged (32 entries): address, data, and how many
        # cycles the bus took (a bus timeout shows as ~1e6). CSRs: dbg_sel selects the entry; dbg_n = entries.
        from litex.soc.interconnect.csr import CSRStatus, CSRStorage
        self.dbg_n    = CSRStatus(32, name="dbg_n")
        self.dbg_sel  = CSRStorage(5, name="dbg_sel")
        self.dbg_addr = CSRStatus(32, name="dbg_addr")
        self.dbg_data = CSRStatus(32, name="dbg_data")
        self.dbg_lat  = CSRStatus(32, name="dbg_lat")
        log_a = Array(Signal(32) for _ in range(32))
        log_d = Array(Signal(32) for _ in range(32))
        log_l = Array(Signal(32) for _ in range(32))
        lat = Signal(32)
        self.sync += [
            If(fifo.source.valid & ~wb.ack, lat.eq(lat + 1)),
            If(wb.ack,
                If(self.dbg_n.status < 32,
                    log_a[self.dbg_n.status[:5]].eq(Cat(Constant(0, 2), fifo.source.addr)),
                    log_d[self.dbg_n.status[:5]].eq(fifo.source.data),
                    log_l[self.dbg_n.status[:5]].eq(lat)),
                self.dbg_n.status.eq(self.dbg_n.status + 1),
                lat.eq(0)),
        ]
        self.comb += [
            self.dbg_addr.status.eq(log_a[self.dbg_sel.storage]),
            self.dbg_data.status.eq(log_d[self.dbg_sel.storage]),
            self.dbg_lat.status.eq(log_l[self.dbg_sel.storage]),
        ]


if os.environ.get("YPCB_JTAGLOAD"):
    _orig_soc_init_jl = target.BaseSoC.__init__

    def _soc_init_jl(self, *args, **kwargs):
        _orig_soc_init_jl(self, *args, **kwargs)
        self.jtagload = _JtagLoader(self)

    target.BaseSoC.__init__ = _soc_init_jl

if os.environ.get("YPCB_PCIE"):
    _orig_soc_init_pcie = target.BaseSoC.__init__

    def _soc_init_pcie(self, *args, **kwargs):
        _orig_soc_init_pcie(self, *args, **kwargs)
        import sys
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from pcie_bridge import PCIeBridge, add_pcie_io
        add_pcie_io(self.platform)
        engines = [e for e in (getattr(self, "mvacc", None), getattr(self, "mvacc1", None)) if e is not None]
        ffn = getattr(self, "ffn", None)
        self.pcie = PCIeBridge(self.platform, self.platform.request("ypcb_pcie_x8"), engines,
                               ffn_st=ffn.st if ffn is not None else None)
        self.bus.add_master(name="pcie", master=self.pcie.bus)

    target.BaseSoC.__init__ = _soc_init_pcie

if __name__ == "__main__":
    target.main()
