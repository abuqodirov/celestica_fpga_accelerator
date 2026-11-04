"""PCIe x8 (Gen1) endpoint + bus bridge for the LLM SoC (ypcb_soc.py YPCB_PCIE=1).

Gateware: ../pcie/core/pcie_x8.v (lanes + PCIE_2_1 hard block, = the stage-2/3a test design that linked with the PC)
and ../pcie/core/pcie_trn_bridge.v (TLP parser / completion generator, pclk = 125 MHz). This module adds the clock
domain crossing (two async FIFOs: commands pcie -> sys, read data sys -> pcie) and executes the commands in order in
the sys domain, so a PC read always returns after every earlier PC write has been done on the bus.

The PC sees BAR0 (2 MB) as 8 slots of 256 KB:
  slots 0..6  windows onto the SoC bus: bus byte address = base[slot] + offset (base: bridge register, bit 0 of the
              base = mirror: every write also goes to address + 0x100000, i.e. engine 0's window -> engine 1's)
  slot 7      bridge registers (DW offset within slot 7):
                0 magic 0x50434901     1 status: [5:0] engine 0 st, [11:6] engine 1 st, [13:12] FFN unit (busy, err)
                2 writes done          3 reads done          4 sys clock counter      5 bus errors
                8..14 base[0..6] (RW)  16 TLP writes / 17 TLP reads / 18 completions / 19 write DWs (pcie domain)
                20 {n_stale, n_ur}     21 {n_dsc, n_other}   22 link: [5:0] LTSSM, [9:6] width, [11:10] speed,
                12 bus master, 13 mem enable, 14 link up, [19:16] sequencer state, [23:20] its error state
                24..27 error event counters (2 x 16 bit each, order of pcie_x8.v ev_count)
Fast paths (no bus access): reads of an engine's result window, bus address 0xC0080000 + 4 * row (engine 0) /
0xC0180000 (engine 1), come straight from the result memory (the engines' bus result reads are switched off for
this); 0xC00C0000 + 4 * k / 0xC01C0000 + 4 * k return rows 2k and 2k+1 rounded to bfloat16 (low half = row 2k),
exactly as the JTAG reader's packed reads (jtag_shift.bf16).
Writes with all four byte enables to an engine's ACTIVATION buffer (bus address 0xC0000000 / 0xC0100000 + byte offset
< 0x80000; with the mirror bit on engine 0's window: both engines) skip the bus too: they go straight to the engines'
activation write ports (aw_en / aw_addr / aw_vec / aw_data -> MVAccel.connect_pcie_aw), one DW every 2 sys clocks instead of
one Wishbone write (two with the mirror) of ~7 clocks each. The PC waits for a CSR read or the engines' start (both
behind these writes in the same command stream), so the order with later commands is kept.
"""
import os

from migen import Array, Cat, ClockDomain, ClockDomainsRenamer, Constant, If, Instance, Mux, Signal
from migen.genlib.cdc import MultiReg

from litex.gen import LiteXModule
from litex.soc.interconnect import stream, wishbone
from litex.soc.interconnect.csr import CSRStatus, CSRStorage

HERE = os.path.dirname(os.path.abspath(__file__))
CORE = os.path.join(HERE, "..", "pcie", "core")

PCIE_IO = [
    ("ypcb_pcie_x8", 0,
        # lanes / refclk / PERST# from the factory bitstream (pcie/s2/s2.xdc, NOTES 2026-10-30); bank 14 is unused
        # by the SoC, so PERST# can be LVCMOS18 there. NOT the board file's "pcie_x8": its lane 6 RX_N is E3, the
        # factory bitstream (and stage 2, which linked x8) uses R3 (MGTXRXN1_115).
        ("rst_n", "Y26"),
        ("clk_p", "J8"), ("clk_n", "J7"),
        ("rx_p", "H6 J4 K6 L4 M6 P6 R4 T6"), ("rx_n", "H5 J3 K5 L3 M5 P5 R3 T5"),
        ("tx_p", "F2 H2 K2 M2 N4 P2 T2 U4"), ("tx_n", "F1 H1 K1 M1 N3 P1 T1 U3")),
]


def add_pcie_io(platform):
    from litex.build.generic_platform import IOStandard, Pins, Subsignal
    subs = []
    for name, pins in PCIE_IO[0][2:]:
        s = [Pins(pins)]
        if name == "rst_n":
            s.append(IOStandard("LVCMOS18"))
        subs.append(Subsignal(name, *s))
    platform.add_extension([(PCIE_IO[0][0], PCIE_IO[0][1], *subs)])


def bf16(f):
    """float32 bits -> bfloat16 bits, round to nearest even (as jtag_shift.bf16)"""
    return (f + 0x7FFF + f[16])[16:32]


class PCIeBridge(LiteXModule):
    def __init__(self, platform, pads, engines, ffn_st=None, win=(0xC0000000, 0xC0100000)):
        """engines: MVAccel instances built with jtag_results=True, results_domain="sys" (their result memory read
        port is ours: e.jtag_port() = (adr, dat_r), sys clock, one cycle latency)"""
        for f in ("pcie_x8.v", "pcie_trn_bridge.v"):
            platform.add_source(os.path.join(CORE, f))
        platform.add_verilog_include_path(CORE)
        platform.add_verilog_include_path(os.path.join(CORE, ".."))

        # ---------------------------------------------------------------- PCIe core + TRN bridge (pclk)
        self.cd_pcie = ClockDomain("pcie", reset_less=True)
        pclk, user_rst_n, lnk_up = Signal(name="pcie_pclk"), Signal(), Signal()
        rd, rsof, reof, rsrc_rdy, rsrc_dsc, rrem, bar_hit, rdst_rdy = (Signal(128), Signal(), Signal(), Signal(),
            Signal(), Signal(2), Signal(8), Signal())
        td, tsof, teof, tsrc_rdy, trem, tdst_rdy, tbuf_av = (Signal(128), Signal(), Signal(), Signal(), Signal(2),
            Signal(), Signal(6))
        ltssm, seq_st, seq_err, al_st, al_err = Signal(6), Signal(4), Signal(4), Signal(4), Signal(4)
        width, speed, bm_en, mem_en, ev = Signal(4), Signal(2), Signal(), Signal(), Signal(128)
        self.restart = CSRStorage(1, description="toggle: rerun the PCIe lane reset sequence")
        self.specials += Instance("pcie_x8", name="pcie_core",
            i_refclk_p=pads.clk_p, i_refclk_n=pads.clk_n, i_rxp=pads.rx_p, i_rxn=pads.rx_n,
            o_txp=pads.tx_p, o_txn=pads.tx_n, i_perst_n=pads.rst_n, i_restart_t=self.restart.storage,
            o_pclk=pclk, o_user_rst_n=user_rst_n, o_lnk_up=lnk_up,
            o_trn_rd=rd, o_trn_rsof=rsof, o_trn_reof=reof, o_trn_rsrc_rdy=rsrc_rdy, o_trn_rsrc_dsc=rsrc_dsc,
            o_trn_rrem=rrem, o_trn_rbar_hit=bar_hit, i_trn_rdst_rdy=rdst_rdy,
            i_trn_td=td, i_trn_tsof=tsof, i_trn_teof=teof, i_trn_tsrc_rdy=tsrc_rdy, i_trn_trem=trem,
            o_trn_tdst_rdy=tdst_rdy, o_trn_tbuf_av=tbuf_av,
            o_ltssm=ltssm, o_seq_st=seq_st, o_seq_err=seq_err, o_tx_al_st=al_st, o_tx_al_err=al_err,
            o_neg_width=width, o_cur_speed=speed, o_bm_en=bm_en, o_mem_en=mem_en, o_ev_count=ev)
        self.comb += self.cd_pcie.clk.eq(pclk)

        cmd_fifo = stream.AsyncFIFO([("data", 56)], depth=64)
        rsp_fifo = stream.AsyncFIFO([("data", 36)], depth=64)
        self.cmd_fifo = cmd_fifo = ClockDomainsRenamer({"write": "pcie", "read": "sys"})(cmd_fifo)
        self.rsp_fifo = rsp_fifo = ClockDomainsRenamer({"write": "sys", "read": "pcie"})(rsp_fifo)
        cnt = [Signal(32) for _ in range(4)] + [Signal(16) for _ in range(4)]
        self.specials += Instance("pcie_trn_bridge", name="pcie_trn",
            i_clk=pclk, i_rst_n=user_rst_n,
            i_rd=rd, i_rsof=rsof, i_reof=reof, i_rsrc_rdy=rsrc_rdy, i_rsrc_dsc=rsrc_dsc, i_rrem=rrem,
            o_rdst_rdy=rdst_rdy,
            o_td=td, o_tsof=tsof, o_teof=teof, o_tsrc_rdy=tsrc_rdy, o_trem=trem, i_tdst_rdy=tdst_rdy,
            i_tbuf_av=tbuf_av,
            o_cmd_valid=cmd_fifo.sink.valid, i_cmd_ready=cmd_fifo.sink.ready, o_cmd_data=cmd_fifo.sink.data,
            i_rsp_valid=rsp_fifo.source.valid, o_rsp_ready=rsp_fifo.source.ready, i_rsp_data=rsp_fifo.source.data,
            o_n_wr=cnt[0], o_n_rd=cnt[1], o_n_cpl=cnt[2], o_n_dw=cnt[3],
            o_n_other=cnt[4], o_n_ur=cnt[5], o_n_dsc=cnt[6], o_n_stale=cnt[7])

        # pcie-domain status into sys (informational: a multi-bit counter may be sampled mid-change)
        link = Signal(32)
        self.comb += link.eq(Cat(ltssm, width, speed, bm_en, mem_en, lnk_up, Constant(0, 1), seq_st, seq_err,
                                 al_st, al_err))
        s_cnt = [Signal(len(c)) for c in cnt]
        s_link, s_ev = Signal(32), Signal(128)
        for a, b in zip(cnt, s_cnt):
            self.specials += MultiReg(a, b)
        self.specials += MultiReg(link, s_link), MultiReg(ev, s_ev)
        self.link = CSRStatus(32, description="[5:0] LTSSM [9:6] width [11:10] speed 12 BM 13 MEM 14 link up "
                                              "[19:16] sequencer [23:20] its error [27:24] TX align [31:28] its error")
        self.tlps = CSRStatus(32, description="TLP writes received")
        self.reads = CSRStatus(32, description="TLP reads received")
        self.cpls = CSRStatus(32, description="completions sent")
        self.errs = CSRStatus(32, description="[15:0] UR completions [31:16] stale read data")
        self.ev = CSRStatus(128, description="error events: badtlp baddllp replayro replayto ll2_receiver "
                                             "pl2_receiver malformed recovery (16 bit each)")
        self.comb += [self.link.status.eq(s_link), self.tlps.status.eq(s_cnt[0]), self.reads.status.eq(s_cnt[1]),
                      self.cpls.status.eq(s_cnt[2]), self.errs.status.eq(Cat(s_cnt[5], s_cnt[7])),
                      self.ev.status.eq(s_ev)]

        # ---------------------------------------------------------------- sys: commands in order
        est = Signal(14)
        if engines:
            self.comb += est[:6].eq(engines[0].st)
        if len(engines) > 1:
            self.comb += est[6:12].eq(engines[1].st)
        if ffn_st is not None:
            self.comb += est[12:14].eq(ffn_st)
        self.core = core = BridgeSys([e.jtag_port() for e in engines], est, s_cnt, s_link, s_ev, win)
        self.bus = core.bus
        self.comb += [cmd_fifo.source.connect(core.sink), core.source.connect(rsp_fifo.sink)]
        for i, e in enumerate(engines):                  # activation fast path (MVAccel.connect_pcie_aw)
            if hasattr(e, "connect_pcie_aw"):
                e.connect_pcie_aw(core.aw_en[i], core.aw_addr, core.aw_vec, core.aw_data)


class BridgeSys(LiteXModule):
    """The bus side of the bridge (sys clock): executes the command stream in order (sink: 56-bit commands from
    pcie_trn_bridge.v), returns read data (source: {seq, data}), registers of slot 7, result fast path.
    ports: [(adr, dat_r)] result memory read ports (one cycle latency); est: engine/FFN status bits;
    s_cnt / s_link / s_ev: pcie-domain counters already synchronised (shown in slot 7)."""
    def __init__(self, ports, est, s_cnt, s_link, s_ev, win=(0xC0000000, 0xC0100000)):
        self.sink = cmd = stream.Endpoint([("data", 56)])
        self.source = rsp = stream.Endpoint([("data", 36)])
        self.bus = wb = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        is_rd, adw, be, wdat = cmd.data[55], cmd.data[36:55], cmd.data[32:36], cmd.data[:32]
        slot, off = adw[16:19], adw[:16]
        self.bases = bases = Array(Signal(32, name=f"pcie_base{i}") for i in range(8))
        self.n_wr, self.n_rdc, self.n_err = n_wr, n_rdc, n_err = Signal(32), Signal(32), Signal(32)
        cycles = Signal(32)
        self.sync += cycles.eq(cycles + 1)

        def reg_val(dwo):
            v = Signal(32)
            cases = {0: 0x50434901, 1: est, 2: n_wr, 3: n_rdc, 4: cycles, 5: n_err,
                     16: s_cnt[0], 17: s_cnt[1], 18: s_cnt[2], 19: s_cnt[3],
                     20: Cat(s_cnt[5], s_cnt[7]), 21: Cat(s_cnt[4], s_cnt[6]), 22: s_link,
                     24: s_ev[0:32], 25: s_ev[32:64], 26: s_ev[64:96], 27: s_ev[96:128]}
            for i in range(7):
                cases[8 + i] = bases[i]
            expr = Constant(0xBAD0BAD0, 32)
            for k, val in cases.items():
                expr = Mux(dwo == k, val, expr)
            self.comb += v.eq(expr)
            return v

        # read state
        r_a, r_n, r_seq = Signal(19), Signal(11), Signal(4)       # current DW address in the BAR, DWs left
        r_slot, r_off = r_a[16:19], r_a[:16]
        r_ba = Signal(32)                                          # bus byte address of the current DW
        self.comb += r_ba.eq(bases[r_slot] + Cat(Constant(0, 2), r_off))
        w_ba = Signal(32)
        self.comb += w_ba.eq(bases[slot] + Cat(Constant(0, 2), off))
        w_ba_reg = Signal(32)
        mirror = Signal()
        rdata = Signal(32)
        # result fast path: engine e, packed, row
        res_e, res_pk, res_row, is_res = Signal(), Signal(), Signal(14), Signal()
        res_adr, res_dat, lo = Signal(14), Signal(32), Signal(16)
        if ports:
            hit = r_ba[20:32] == (win[0] >> 20)
            if len(ports) > 1:
                hit = hit | (r_ba[20:32] == (win[1] >> 20))
            self.comb += [is_res.eq((r_slot != 7) & r_ba[19] & hit),
                          res_e.eq(r_ba[20:32] != (win[0] >> 20)), res_pk.eq(r_ba[18]), res_row.eq(r_ba[2:16])]
            # one register per engine next to its result memory (the floorplan puts nets named after an engine in
            # that engine's region; the shared counter res_adr stays in the PCIe region): +1 cycle read latency
            for i, (adr, _) in enumerate(ports):
                ra = Signal(14, name=f"pcie_res_adr{i}")
                self.sync += ra.eq(res_adr)
                self.comb += adr.eq(ra)
            self.comb += res_dat.eq(ports[0][1] if len(ports) == 1 else Mux(res_e, ports[1][1], ports[0][1]))

        # activation fast path: registered here (PCIe region), registered again next to each engine (MVAccel)
        self.aw_en = aw_en = Signal(2, name="pcie_aw_en")
        self.aw_addr, self.aw_vec = aw_addr, aw_vec = Signal(13, name="pcie_aw_addr"), Signal(2, name="pcie_aw_vec")
        self.aw_data = aw_data = Signal(32, name="pcie_aw_data")
        a_e0, a_e1, a_hit = Signal(), Signal(), Signal()
        self.comb += [
            a_e0.eq(w_ba[20:32] == (win[0] >> 20)),
            a_e1.eq(w_ba[20:32] == (win[1] >> 20)),
            a_hit.eq(((a_e0 | a_e1) & ~w_ba[19] & (be == 0xF)) if ports else 0),
        ]

        state = Signal(4)
        (S_IDLE, S_W, S_WM, S_W2, S_R, S_RWB, S_RES_A, S_RES_B, S_RES_D, S_RES_A2, S_RES_B2, S_RES_D2,
         S_RPUSH) = range(13)
        self.comb += wb.sel.eq(Mux((state == S_W) | (state == S_W2), be, 0xF))
        self.sync += [
            cmd.ready.eq(0),
            aw_en.eq(0),
            If(rsp.ready, rsp.valid.eq(0)),
            If(state == S_IDLE,
                If(cmd.valid & ~cmd.ready,
                    If(is_rd,
                        r_a.eq(adw), r_n.eq(wdat[:11]), r_seq.eq(wdat[28:32]), cmd.ready.eq(1), state.eq(S_R)
                    ).Elif(slot == 7,
                        If((off >= 8) & (off < 15), bases[off[:3]].eq(wdat)),   # base registers (8..14 -> 0..6)
                        cmd.ready.eq(1), n_wr.eq(n_wr + 1)
                    ).Elif(a_hit,                                # activation fast path (engine 0 + mirror: both)
                        aw_en.eq(Cat(a_e0, a_e1 | (a_e0 & bases[slot][0]))),
                        aw_addr.eq(w_ba[2:15]), aw_vec.eq(w_ba[16:18]), aw_data.eq(wdat),
                        cmd.ready.eq(1), n_wr.eq(n_wr + 1)
                    ).Else(
                        wb.cyc.eq(1), wb.stb.eq(1), wb.we.eq(1), wb.adr.eq(w_ba[2:]), wb.dat_w.eq(wdat),
                        w_ba_reg.eq(w_ba), mirror.eq(bases[slot][0]), state.eq(S_W)
                    )
                )
            ).Elif(state == S_W,
                If(wb.ack | wb.err,
                    If(wb.err, n_err.eq(n_err + 1)),
                    wb.cyc.eq(0), wb.stb.eq(0),
                    If(mirror, state.eq(S_WM)
                    ).Else(cmd.ready.eq(1), n_wr.eq(n_wr + 1), state.eq(S_IDLE))
                )
            ).Elif(state == S_WM,                                       # mirror: same data, + 0x100000
                wb.cyc.eq(1), wb.stb.eq(1), wb.adr.eq((w_ba_reg + 0x100000)[2:]), state.eq(S_W2)
            ).Elif(state == S_W2,
                If(wb.ack | wb.err,
                    If(wb.err, n_err.eq(n_err + 1)),
                    wb.cyc.eq(0), wb.stb.eq(0), cmd.ready.eq(1), n_wr.eq(n_wr + 1), state.eq(S_IDLE))
            ).Elif(state == S_R,                                        # next DW of a read
                If(r_n == 0,
                    n_rdc.eq(n_rdc + 1), state.eq(S_IDLE)
                ).Elif(~rsp.valid | rsp.ready,
                    If(r_slot == 7,
                        rdata.eq(reg_val(r_off)), state.eq(S_RPUSH)
                    ).Elif(is_res,
                        res_adr.eq(Mux(res_pk, Cat(Constant(0, 1), res_row[:13]), res_row)), state.eq(S_RES_A)
                    ).Else(
                        wb.cyc.eq(1), wb.stb.eq(1), wb.we.eq(0), wb.adr.eq(r_ba[2:]), state.eq(S_RWB)
                    )
                )
            ).Elif(state == S_RWB,
                If(wb.ack | wb.err,
                    If(wb.err, n_err.eq(n_err + 1)),
                    wb.cyc.eq(0), wb.stb.eq(0), rdata.eq(Mux(wb.err, 0xFFFFFFFF, wb.dat_r)), state.eq(S_RPUSH))
            ).Elif(state == S_RES_A,                    # result memory: address register, memory, data
                state.eq(S_RES_B)
            ).Elif(state == S_RES_B,
                state.eq(S_RES_D)
            ).Elif(state == S_RES_D,
                If(res_pk,
                    lo.eq(bf16(res_dat)), res_adr.eq(res_adr + 1), state.eq(S_RES_A2)
                ).Else(rdata.eq(res_dat), state.eq(S_RPUSH))
            ).Elif(state == S_RES_A2,
                state.eq(S_RES_B2)
            ).Elif(state == S_RES_B2,
                state.eq(S_RES_D2)
            ).Elif(state == S_RES_D2,
                rdata.eq(Cat(lo, bf16(res_dat))), state.eq(S_RPUSH)
            ).Elif(state == S_RPUSH,
                rsp.valid.eq(1), rsp.data.eq(Cat(rdata, r_seq)), r_a.eq(r_a + 1), r_n.eq(r_n - 1), state.eq(S_R)
            ),
        ]
