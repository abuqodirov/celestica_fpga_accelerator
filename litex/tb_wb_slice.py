#!/usr/bin/env python3
"""Simulation test of wb_slice.WishboneSlice: a master issues 3000 random reads/writes (random gaps, often
back-to-back with cyc held), the slave answers after a random 0..4 cycles. Checks: every read returns what a
reference memory holds, every write is performed exactly once, no transaction is lost or duplicated."""
import random

from migen import *
from litex.soc.interconnect import wishbone

from wb_slice import WishboneSlice

N, WORDS = 3000, 64
rng = random.Random(1)


class DUT(Module):
    def __init__(self):
        self.m = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        self.s = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        self.submodules.slice = WishboneSlice(self.m, self.s)


dut = DUT()
mem = [0] * WORDS                   # slave's memory
ref = [0] * WORDS                   # reference
log = {"slave_writes": 0, "slave_reads": 0, "errors": 0, "done": 0}


def master():
    m = dut.m
    for i in range(N):
        we = rng.random() < 0.5
        adr = rng.randrange(WORDS)
        dat = rng.getrandbits(32)
        yield m.adr.eq(adr); yield m.we.eq(we); yield m.dat_w.eq(dat); yield m.sel.eq(0xF)
        yield m.cyc.eq(1); yield m.stb.eq(1)
        yield
        while not (yield m.ack):
            yield
        if we:
            ref[adr] = dat
        else:
            got = yield m.dat_r
            if got != ref[adr]:
                log["errors"] += 1
        # classic master: after ack, either a gap (stb low) or the next request right away
        if rng.random() < 0.5:
            yield m.stb.eq(0)
            if rng.random() < 0.5:
                yield m.cyc.eq(0)
            for _ in range(rng.randrange(3)):
                yield
    yield m.cyc.eq(0); yield m.stb.eq(0)
    for _ in range(10):
        yield
    log["done"] = 1


def slave():
    s = dut.s
    while not log["done"]:
        if (yield s.cyc) and (yield s.stb):
            for _ in range(rng.randrange(5)):          # wait states
                yield
                if not ((yield s.cyc) and (yield s.stb)):
                    log["errors"] += 1                 # request withdrawn before ack: protocol error
            adr, we = (yield s.adr), (yield s.we)
            if we:
                mem[adr] = (yield s.dat_w); log["slave_writes"] += 1
            else:
                yield s.dat_r.eq(mem[adr]); log["slave_reads"] += 1
            yield s.ack.eq(1)
            yield
            yield s.ack.eq(0)
            yield                                      # the slice must have dropped stb by now
            if (yield s.stb) and (yield s.ack):
                log["errors"] += 1
        else:
            yield


run_simulation(dut, [master(), slave()])
writes_expected = None
print(log)
ok = log["errors"] == 0 and log["slave_writes"] + log["slave_reads"] == N and mem == ref
print("WishboneSlice:", "PASS" if ok else "FAIL")
