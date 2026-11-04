"""Bank-split DRAM streamer: reads nwords consecutive 64-byte words over TWO LiteDRAM native ports and returns them
in address order.

Why: LiteDRAM's crossbar locks a port to one bank while that bank still holds the port's commands (so read data
comes back in order). A single sequential reader therefore stalls at every bank change (every 8 KiB DRAM row with
ROW_BANK_COL mapping): the new bank's precharge + activate cannot start until the old bank's queue is empty.
Measured on the card: 84.9 % of 64 B/clock on every matrix (~23 lost clocks per 128 words).
Here port 0 reads the words of even 128-word blocks (= even banks), port 1 those of odd blocks, each into its own
FIFO; while one block is consumed the other port already opens the next bank. The merger takes 128 words from one
FIFO, then 128 from the other, etc.

    go      start (one clock); base / nwords sampled
    source  valid / data (512 bits), in address order; the consumer must always be ready (the matvec engine is)
    gen_done  both address generators have issued all their requests
"""
from migen import If, Module, Signal

from litex.soc.interconnect import stream


class BankSplitReader(Module):
    def __init__(self, port0, port1, blk_bits=7, fifo_depth=64):
        from litedram.frontend.dma import LiteDRAMDMAReader
        self.go = Signal()
        self.base = Signal(32)
        self.nwords = Signal(32)
        self.source = source = stream.Endpoint([("data", port0.data_width)])
        self.gen_done = Signal()

        dmas = [LiteDRAMDMAReader(p, fifo_depth=fifo_depth, fifo_buffered=True) for p in (port0, port1)]
        self.submodules += dmas
        end = Signal(32)
        self.sync += If(self.go, end.eq(self.base + self.nwords))
        blk = 1 << blk_bits
        done = []
        for i, dma in enumerate(dmas):
            addr, act = Signal(32), Signal()
            nxt = Signal(32)
            first = Signal(32)
            # first word of this port's parity at or after base
            self.comb += If(self.base[blk_bits] == i,
                            first.eq(self.base)
                        ).Else(
                            first.eq(((self.base >> blk_bits) + 1) << blk_bits))
            # after issuing addr: next word, skipping the other port's block at a block boundary
            self.comb += If((addr[:blk_bits] + 1) == blk,       # last word of a block (wraps to 0)
                            nxt.eq(addr + 1 + blk)
                        ).Else(
                            nxt.eq(addr + 1))
            lt = Signal()
            self.comb += [
                lt.eq(addr < end),
                dma.sink.valid.eq(act & lt),
                dma.sink.address.eq(addr),
            ]
            # act from the clock after go (when `end` is registered)
            go_d = Signal()
            self.sync += [
                go_d.eq(self.go),
                If(self.go,
                    addr.eq(first), act.eq(0)
                ).Elif(go_d,
                    act.eq(1)
                ).Elif(dma.sink.valid & dma.sink.ready,
                    addr.eq(nxt)),
            ]
            dn = Signal()
            self.comb += dn.eq(~act | ~lt)
            done.append(dn)
        self.comb += self.gen_done.eq(done[0] & done[1])

        # merger: words in address order; c = address of the next word to hand out
        c = Signal(32)
        sel = Signal()
        self.sync += If(self.go, c.eq(self.base)).Elif(source.valid & source.ready, c.eq(c + 1))
        self.comb += [
            sel.eq(c[blk_bits]),
            If(sel,
                source.valid.eq(dmas[1].source.valid), source.data.eq(dmas[1].source.data),
                dmas[1].source.ready.eq(source.ready),
            ).Else(
                source.valid.eq(dmas[0].source.valid), source.data.eq(dmas[0].source.data),
                dmas[0].source.ready.eq(source.ready),
            ),
        ]
