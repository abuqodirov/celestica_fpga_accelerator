"""TCK-domain (jtagl) shift logic of the JTAG loader with the result reader (YPCB_JTAGREAD, ypcb_soc.py _JtagLoader).

Every DR scan on chain 2 starts with a 32-bit header word (LSB first):
    bit 0 = 0: write   header = byte address | both << 1; every further 32-bit word goes to the bus at address,
                       address + 4, ...; both = 1: each word ALSO goes to address + bc_offset (the other engine's
                       window: one activation upload feeds both engines)
    bit 0 = 1: read    header = 1 | engine << 1 | row << 2 (row 13 bits) | packed << 15: words 2, 3, ... of the scan
                       shift out the engine's float32 results row, row + 1, ... (word 1 is the BRAM read latency;
                       incoming words are ignored); packed = 1: two results per word, each rounded to bfloat16
                       (round to nearest even), row r in bits [15:0], row r + 1 in [31:16]
TDO in the first 64 bits of every scan = status captured at Capture-DR:
    [31:0] write address, [47:32] words received (mod 65536), [48] write FIFO overflow (sticky),
    [49 + 6i +: 6] engine i: fin (4 bits, Gray-coded count of finished runs), ovf, busy
The result memories' read ports run on TCK, which only toggles during scans: no FIFO, nothing to underflow."""
from migen import Cat, If, Mux, Signal

from litex.gen import LiteXModule


def bf16(f):
    """float32 bits -> bfloat16 bits, round to nearest even (finite values; the engines flag inf/nan as overflow)"""
    return (f + 0x7FFF + f[16])[16:32]


class JtagShift(LiteXModule):
    def __init__(self, sink, ports, est, bc_offset=0x100000):
        """sink: write FIFO sink (valid, ready, addr[30], data[32]); ports: [(adr, dat_r)] result read ports in
        jtagl; est: engine status bits (already in jtagl); bc_offset: byte distance of the second copy of a
        'both' write (engine 1's window - engine 0's)"""
        self.sel, self.shift, self.capture, self.tdi, self.tdo = Signal(), Signal(), Signal(), Signal(), Signal()
        sr, cnt, have_addr, addr = Signal(32), Signal(5), Signal(), Signal(32)
        nwords, overflow, status = Signal(16), Signal(), Signal(64)
        rd_mode, rd_on, rd_eng, rd_row, rd_sr = Signal(), Signal(), Signal(), Signal(13), Signal(32)
        rd_pack, rd_lo, both, both_pend = Signal(), Signal(16), Signal(), Signal()
        word = Cat(sr[1:], self.tdi)
        for adr, _ in ports:
            self.comb += adr.eq(rd_row)
        rdat = ports[0][1] if len(ports) == 1 else Mux(rd_eng, ports[1][1], ports[0][1])
        self.comb += self.tdo.eq(Mux(rd_on, rd_sr[0], status[0]))
        self.sync.jtagl += [
            sink.valid.eq(0),
            If(sink.valid & ~sink.ready, overflow.eq(1)),
            If(sink.valid, nwords.eq(nwords + 1)),
            # second copy of a 'both' write, one TCK after the first (sink.data still holds the word)
            If(both_pend, both_pend.eq(0), sink.valid.eq(1), sink.addr.eq(sink.addr + (bc_offset >> 2))),
            If(self.sel & self.capture, cnt.eq(0), have_addr.eq(0), rd_mode.eq(0), rd_on.eq(0),
               status.eq(Cat(addr, nwords, overflow, est))),
            If(self.sel & self.shift,
                status.eq(status[1:]),
                rd_sr.eq(rd_sr[1:]),
                sr.eq(word), cnt.eq(cnt + 1),
                # packed reads: the even row's bfloat16 is taken half way through the word, the odd row's at its end
                If((cnt == 15) & rd_mode & rd_pack, rd_lo.eq(bf16(rdat)), rd_row.eq(rd_row + 1)),
                If(cnt == 31,
                    If(~have_addr,
                        have_addr.eq(1),
                        If(word[0], rd_mode.eq(1), rd_eng.eq(word[1]), rd_row.eq(word[2:15]), rd_pack.eq(word[15])
                        ).Else(addr.eq(word & 0xFFFFFFFC), both.eq(word[1]))
                    ).Elif(rd_mode,
                        rd_sr.eq(Mux(rd_pack, Cat(rd_lo, bf16(rdat)), rdat)), rd_row.eq(rd_row + 1), rd_on.eq(1)
                    ).Else(
                        sink.valid.eq(1), sink.addr.eq(addr[2:]), sink.data.eq(word), addr.eq(addr + 4),
                        both_pend.eq(both))))
        ]
