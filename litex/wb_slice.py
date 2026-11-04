"""Wishbone register slice (classic cycles): one register stage on the request and one on the response, so no
combinational path runs through it. Used by YPCB_BUSPIPE to cut the CPU's one-cycle round trips across the die
(e.g. CPU -> interconnect -> channel 0's L2 cache -> read-data mux -> CPU, 24.8 ns in build_dacc4 s1 against a
13.3 ns clock) into two one-way hops. Cost: 2 extra cycles per access through it.

    m: the side the interconnect drives (this module is a slave there)
    s: the side toward the real slave (this module is its master)

The request is captured once per transaction; s.stb drops right after s.ack, and m.ack is a one-cycle registered
pulse. In the cycle m.ack is high the master still shows the old request, so a new one is only accepted the
cycle after (otherwise a write would be done twice)."""
from migen import *

from litex.gen import LiteXModule


class WishboneSlice(LiteXModule):
    def __init__(self, m, s):
        busy, ack_r, err_r = Signal(), Signal(), Signal()
        dat_r = Signal(len(m.dat_r))
        self.comb += [m.ack.eq(ack_r), m.err.eq(err_r), m.dat_r.eq(dat_r)]
        if hasattr(s, "cti"):
            self.comb += [s.cti.eq(0), s.bte.eq(0)]
        self.sync += [
            ack_r.eq(0), err_r.eq(0),
            If(~busy,
                If(m.cyc & m.stb & ~ack_r,
                    s.adr.eq(m.adr), s.dat_w.eq(m.dat_w), s.sel.eq(m.sel), s.we.eq(m.we),
                    s.cyc.eq(1), s.stb.eq(1), busy.eq(1))
            ).Elif(s.ack | s.err,
                s.cyc.eq(0), s.stb.eq(0), busy.eq(0),
                dat_r.eq(s.dat_r), ack_r.eq(s.ack), err_r.eq(s.err))
        ]


def pipeline_slaves(soc, names):
    """Put a WishboneSlice in front of each named bus slave (call before soc.bus.finalize())."""
    from litex.soc.interconnect import wishbone
    done = []
    for n in names:
        orig = soc.bus.slaves.get(n)
        if orig is None:
            continue
        # Interface.like copies the width exactly. (address_width counts BYTE address bits: passing len(orig.adr)
        # = 30 word bits gave a 28-bit adr, dropping main RAM's top address bits -> CPU 0x48000000 landed at DRAM
        # 0x48000000 instead of 0x08000000 in build_dacc7; the windows only use low bits and kept working.)
        new = wishbone.Interface.like(orig)
        assert len(new.adr) == len(orig.adr) and new.addressing == orig.addressing, n
        soc.add_module(name=f"{n}_slice", module=WishboneSlice(new, orig))
        soc.bus.slaves[n] = new
        done.append(n)
    return done
