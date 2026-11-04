#!/usr/bin/env python3
"""Simulation test of jtag_shift.JtagShift: scans exactly as the host does them (Capture-DR, then N shift clocks with
TDI = the bits, TDO sampled per bit). Checks: write scans push (address, word) pairs, 'both' writes each word twice
(second copy at + bc_offset); read scans return the engine's result rows from word 2 on, float32 or packed as two
bfloat16 per word (round to nearest even), for both engines, any start row, back to back with writes; the status
word."""
import random

from migen import Memory, Module, Signal, run_simulation
from litex.soc.interconnect import stream

from jtag_shift import JtagShift

rng = random.Random(3)
ROWS = 8192
img = [[rng.getrandbits(32) for _ in range(ROWS)] for _ in range(2)]


class DUT(Module):
    def __init__(self):
        self.sink = stream.Endpoint([("addr", 30), ("data", 32)])
        self.est = Signal(12)
        ports = []
        for e in range(2):
            mem = Memory(32, ROWS, init=img[e])
            p = mem.get_port(clock_domain="jtagl")
            self.specials += mem, p
            ports.append((p.adr, p.dat_r))
        self.submodules.js = JtagShift(self.sink, ports, self.est)


dut = DUT()
js = dut.js
got_writes, errors, done = [], [], []


def scan(bits):
    """One DR scan: Capture-DR clock, then one shift clock per bit; returns the TDO bits."""
    yield js.sel.eq(1); yield js.capture.eq(1); yield js.shift.eq(0)
    yield
    yield js.capture.eq(0); yield js.shift.eq(1)
    out = []
    # migen applies a generator's writes at the next clock edge, so the design sees each write one edge later
    # than it is made: the Capture-DR edge is the first edge in this loop, shift k the (k+1)-th. TDO read right
    # after an edge = what the TAP shows the host before the next one: bit k = after Capture + k shifts.
    for b in bits:
        yield js.tdi.eq(b)
        yield
        out.append((yield js.tdo))
    yield js.shift.eq(0)
    for _ in range(3):                      # Exit1 / Update / Idle
        yield
    return out


def bf16(f):
    return ((f + 0x7FFF + ((f >> 16) & 1)) >> 16) & 0xFFFF


def words_to_bits(ws):
    return [(w >> i) & 1 for w in ws for i in range(32)]


def bits_to_words(bs):
    return [sum(bs[32 * k + i] << i for i in range(32)) for k in range(len(bs) // 32)]


def host():
    yield dut.sink.ready.eq(1)
    yield dut.est.eq(0b101101_110011)
    exp_writes = []
    for t in range(80):
        if rng.random() < 0.5:
            addr = rng.randrange(0, 1 << 30) * 4
            both = rng.randrange(2)
            data = [rng.getrandbits(32) for _ in range(rng.randrange(1, 6))]
            yield from scan(words_to_bits([addr | both << 1] + data))
            for i, d in enumerate(data):
                exp_writes.append((addr // 4 + i, d))
                if both:
                    exp_writes.append(((addr // 4 + i + (0x100000 >> 2)) & (2**30 - 1), d))
            last_addr = addr + 4 * len(data)
        else:
            eng, row, n, packed = rng.randrange(2), rng.randrange(ROWS), rng.randrange(1, 40), rng.randrange(2)
            nw = (n + 1) // 2 if packed else n
            out = bits_to_words((yield from scan(words_to_bits([1 | eng << 1 | row << 2 | packed << 15] +
                                                                 [0] * (nw + 1)))))
            if packed:
                r = [img[eng][(row + i) % ROWS] for i in range(2 * nw)]
                want = [bf16(r[2 * k]) | bf16(r[2 * k + 1]) << 16 for k in range(nw)]
            else:
                want = [img[eng][(row + i) % ROWS] for i in range(n)]
            if out[2:] != want:
                errors.append(f"read eng {eng} row {row} n {n} packed {packed}: got {out[2:5]}.. want {want[:3]}..")
            st = out[0] | out[1] << 32
            if t and (st >> 49) & 0xFFF != 0b101101_110011:
                errors.append(f"status est {(st >> 49) & 0xFFF:b}")
    yield
    yield
    if got_writes != exp_writes:
        errors.append(f"writes: got {len(got_writes)} want {len(exp_writes)}; first diff "
                      f"{next((i for i, (a, b) in enumerate(zip(got_writes, exp_writes)) if a != b), None)}")
    # status after the writes: address of the next write, words received
    out = bits_to_words((yield from scan(words_to_bits([0, 0]))))
    st = out[0] | out[1] << 32
    if st & 0xFFFFFFFF != last_addr or (st >> 32) & 0xFFFF != len(exp_writes) & 0xFFFF:
        errors.append(f"status: addr {st & 0xFFFFFFFF:x} (want {last_addr:x}), words {(st >> 32) & 0xFFFF} "
                      f"(want {len(exp_writes)})")
    done.append(1)


def monitor():
    while not done:
        if (yield dut.sink.valid):
            got_writes.append(((yield dut.sink.addr), (yield dut.sink.data)))
        yield


run_simulation(dut, {"jtagl": [host(), monitor()]}, clocks={"jtagl": 10})
print(f"{len(got_writes)} writes seen")
for e in errors[:10]:
    print("  ", e)
print("JtagShift:", "PASS" if not errors else f"FAIL ({len(errors)} errors)")
