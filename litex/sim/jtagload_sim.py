#!/usr/bin/env python3
"""Simulate the JTAG loader's FIFO + Wishbone path (same code as ypcb_soc._JtagLoader, minus BSCANE2/BUFG)."""
from migen import *
from litex.soc.interconnect import stream, wishbone


class Core(Module):
    def __init__(self):
        self.clock_domains.cd_jtagl = ClockDomain()
        self.sel, self.shift, self.capture, self.tdi = Signal(), Signal(), Signal(), Signal()
        fifo = stream.AsyncFIFO([("addr", 30), ("data", 32)], depth=256)
        self.submodules.fifo = fifo = ClockDomainsRenamer({"write": "jtagl", "read": "sys"})(fifo)
        sr, cnt, have_addr, addr = Signal(32), Signal(5), Signal(), Signal(32)
        word = Cat(sr[1:], self.tdi)
        self.sync.jtagl += [
            fifo.sink.valid.eq(0),
            If(self.sel & self.capture, cnt.eq(0), have_addr.eq(0)),
            If(self.sel & self.shift,
                sr.eq(word), cnt.eq(cnt + 1),
                If(cnt == 31,
                    If(~have_addr, addr.eq(word), have_addr.eq(1)
                    ).Else(fifo.sink.valid.eq(1), fifo.sink.addr.eq(addr[2:]), fifo.sink.data.eq(word),
                           addr.eq(addr + 4))))
        ]
        self.wb = wb = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        self.comb += [
            wb.adr.eq(fifo.source.addr), wb.dat_w.eq(fifo.source.data), wb.sel.eq(0xF), wb.we.eq(1),
            wb.cyc.eq(fifo.source.valid), wb.stb.eq(fifo.source.valid), fifo.source.ready.eq(wb.ack),
        ]


dut = Core()
writes = []


def jtag():                      # jtagl domain: one DR scan = address word + 4 data words, then TCK stops
    words = [0x10001000, 0x03020100, 0x07060504, 0x0b0a0908, 0x0f0e0d0c]
    bits = [(w >> i) & 1 for w in words for i in range(32)]
    yield dut.sel.eq(1); yield dut.capture.eq(1); yield
    yield dut.capture.eq(0); yield dut.shift.eq(1)
    for b in bits:
        yield dut.tdi.eq(b); yield
    yield dut.shift.eq(0)
    for _ in range(3):           # Exit1, Update, Idle
        yield
    yield dut.sel.eq(0)


def bus():                       # sys domain: ack one cycle after cyc&stb
    valid_cycles = 0
    for _ in range(3000):
        if (yield dut.wb.cyc) and (yield dut.wb.stb):
            valid_cycles += 1
            if not (yield dut.wb.ack):
                writes.append(((yield dut.wb.adr) << 2, (yield dut.wb.dat_w)))
                yield dut.wb.ack.eq(1)
            else:
                yield dut.wb.ack.eq(0)
        else:
            yield dut.wb.ack.eq(0)
        yield
    print("valid cycles:", valid_cycles)


run_simulation(dut, {"sys": [bus()], "jtagl": [jtag()]}, clocks={"sys": 10, "jtagl": 67})
for a, d in writes:
    print(f"write 0x{a:08x} <= 0x{d:08x}")
