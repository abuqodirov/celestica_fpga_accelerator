#!/usr/bin/env python3
"""Simulation of pcie_bridge.BridgeSys (the sys-clock side of the PCIe bridge) with migen's simulator:
random commands (window writes with byte enables, mirror writes, base-register writes, reads of the bus, of the
bridge registers, of engine results and of packed bfloat16 results) against a Python model; a Wishbone slave with
random latency, two result memories with random contents, random back-pressure on the response stream.
    python3 sim/test_pcie_bridge_sys.py [n_commands] [seed]"""
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from migen import Memory, Module, Signal, passive, run_simulation  # noqa: E402

from pcie_bridge import BridgeSys  # noqa: E402

N = int(sys.argv[1]) if len(sys.argv) > 1 else 1500
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 1
rng = random.Random(SEED)
ROWS = 8192
WIN = (0xC0000000, 0xC0100000)


def bf16(f):
    return ((f + 0x7FFF + ((f >> 16) & 1)) >> 16) & 0xFFFF


class Top(Module):
    def __init__(self):
        self.res = [[rng.getrandbits(32) for _ in range(ROWS)] for _ in range(2)]
        self.mems = [Memory(32, ROWS, init=r) for r in self.res]
        ports = []
        for m in self.mems:
            p = m.get_port()
            self.specials += m, p
            ports.append((p.adr, p.dat_r))
        self.est = Signal(14, reset=0x2A5)
        self.s_cnt = [Signal(32, reset=100 + i) for i in range(4)] + [Signal(16, reset=7 + i) for i in range(4)]
        self.s_link = Signal(32, reset=0x12345)
        self.s_ev = Signal(128, reset=(0x1111 << 96) | 0x22220003)
        self.submodules.dut = BridgeSys(ports, self.est, self.s_cnt, self.s_link, self.s_ev, WIN)


top = Top()
dut = top.dut

# ---------------------------------------------------------------------------------------- model + command list
bases = [0] * 7
busmem = {}            # byte address (aligned) -> value, model of the Wishbone slave's memory
cmds, expect = [], []  # expect: list of (seq, value) in order
seq = 0
REGIONS = [0x40000000, 0x80000000, 0xD0000000, 0x12340000]


def model_bus_write(ba, be, v):
    old = busmem.get(ba & ~3, 0)
    m = sum(0xFF << (8 * k) for k in range(4) if be >> k & 1)
    busmem[ba & ~3] = (old & ~m) | (v & m)


def reg_value(o):
    vals = {0: 0x50434901, 1: 0x2A5, 2: None, 3: None, 4: None, 5: 0,
            16: 100, 17: 101, 18: 102, 19: 103, 20: 8 | 10 << 16, 21: 7 | 9 << 16, 22: 0x12345,
            24: 0x22220003, 25: 0, 26: 0, 27: 0x1111}
    for i in range(7):
        vals[8 + i] = bases[i]
    return vals.get(o, 0xBAD0BAD0)


n_writes_model = 0
aw_expect = [[], []]   # activation fast-path writes per engine: (addr, vec, data)
aw_got = [[], []]
for t in range(N):
    k = rng.random()
    if k < 0.08 or t < 7:                                  # base register write
        i = t if t < 7 else rng.randrange(7)
        r = rng.random()
        if r < 0.25:
            b = (WIN[rng.randrange(2)] + (rng.randrange(1 << 19) & ~3)) | (rng.random() < 0.5)
            # engine window (activation area: any vector / address), maybe mirrored
        elif r < 0.5:                                           # engine results, plain or packed
            b = WIN[rng.randrange(2)] + rng.choice([0x80000, 0xC0000]) + 4 * rng.randrange(4096)
        else:
            b = rng.choice(REGIONS) + 4 * rng.randrange(256)
        bases[i] = b
        adw = (7 << 16) | (8 + i)
        cmds.append((0 << 55) | (adw << 36) | (0xF << 32) | b)
        n_writes_model += 1
    elif k < 0.55:                                         # window write
        s = rng.randrange(7)
        off = rng.randrange(64)
        be = rng.choice([0xF, 0xF, 0xF, 1, 2, 4, 8, 3, 0xC, 0x6])
        v = rng.getrandbits(32)
        adw = (s << 16) | off
        cmds.append((adw << 36) | (be << 32) | v)
        ba = (bases[s] & ~3) + 4 * off
        eng = [e for e in (0, 1) if (ba >> 20) == (WIN[e] >> 20)]
        if eng and not ba & 0x80000 and be == 0xF:              # activation fast path: engine port(s), not the bus
            aw_expect[eng[0]].append(((ba >> 2) & 0x1FFF, (ba >> 16) & 3, v))
            if eng[0] == 0 and bases[s] & 1:
                aw_expect[1].append(((ba >> 2) & 0x1FFF, (ba >> 16) & 3, v))
        elif not (WIN[0] <= ba < WIN[1] + 0x100000 and ba & 0x80000):   # writes to results windows: not modelled
            model_bus_write(ba, be, v)
            if bases[s] & 1:
                model_bus_write(ba + 0x100000, be, v)
        else:
            cmds.pop()
            continue
        n_writes_model += 1
    else:                                                  # read
        kind = rng.random()
        n = rng.choice([1, 1, 1, 2, 4, 8, 16, 32])
        if kind < 0.2:                                     # registers
            off = rng.choice([0, 1, 5, 8, 9, 14, 16, 20, 22, 24, 27, 30])
            adw = (7 << 16) | off
            vals = []
            for j in range(n):
                v = reg_value(off + j)
                vals.append(v)
            cmds.append((1 << 55) | (adw << 36) | (0xF << 32) | (seq << 28) | n)
            expect.append((seq, vals, "reg", off))
        else:
            s = rng.randrange(7)
            off = rng.randrange(64)
            adw = (s << 16) | off
            ba0 = (bases[s] & ~3) + 4 * off
            vals = []
            for j in range(n):
                ba = ba0 + 4 * j
                e = (ba >> 20) - (WIN[0] >> 20)
                if (ba >> 20) in (WIN[0] >> 20, WIN[1] >> 20) and ba & 0x80000:
                    row = (ba >> 2) & 0x3FFF
                    if ba & 0x40000:                       # packed: rows 2k, 2k+1
                        r0 = (2 * row) % ROWS
                        v = bf16(top.res[e][r0]) | bf16(top.res[e][r0 + 1]) << 16
                    else:
                        v = top.res[e][row % ROWS]
                else:
                    v = busmem.get(ba & ~3, 0)
                vals.append(v)
            cmds.append((1 << 55) | (adw << 36) | (0xF << 32) | (seq << 28) | n)
            expect.append((seq, vals, "bus", hex(ba0)))
        seq = (seq + 1) & 15

# make some reads hit the result windows on purpose
print(f"{len(cmds)} commands, {len(expect)} reads, {sum(len(e[1]) for e in expect)} read DWs")

errors = []
got = []
done = [False]


def driver():
    for c in cmds:
        yield dut.sink.valid.eq(1)
        yield dut.sink.data.eq(c)
        while True:
            yield
            if (yield dut.sink.ready):
                break
        yield dut.sink.valid.eq(0)
        for _ in range(rng.choice([0, 0, 0, 1, 3])):
            yield
    done[0] = True


@passive
def bus_slave():
    wb = dut.bus
    while True:
        yield wb.ack.eq(0)
        yield
        if (yield wb.cyc) and (yield wb.stb):
            for _ in range(rng.choice([0, 1, 2, 5])):
                yield
            adr = (yield wb.adr) << 2
            if (yield wb.we):
                v = (yield wb.dat_w)
                sel = (yield wb.sel)
                old = slave_mem.get(adr, 0)
                m = sum(0xFF << (8 * k) for k in range(4) if sel >> k & 1)
                slave_mem[adr] = (old & ~m) | (v & m)
            else:
                yield wb.dat_r.eq(slave_mem.get(adr, 0))
            yield wb.ack.eq(1)
            yield


slave_mem = {}


@passive
def aw_monitor():
    while True:
        yield
        en = yield dut.aw_en
        for e in (0, 1):
            if en >> e & 1:
                aw_got[e].append(((yield dut.aw_addr), (yield dut.aw_vec), (yield dut.aw_data)))


@passive
def collector():
    while True:
        yield dut.source.ready.eq(rng.random() < 0.7)
        yield
        if (yield dut.source.valid) and (yield dut.source.ready):
            got.append((yield dut.source.data))


def checker():
    while not done[0] or len(got) < sum(len(e[1]) for e in expect):
        yield
        if len(got) > 10 * len(cmds) + 100:
            break
    for _ in range(50):
        yield
    i = 0
    for s, vals, kind, where in expect:
        for j, v in enumerate(vals):
            if i >= len(got):
                errors.append(f"missing read data (read seq {s} {kind} {where} DW {j})")
                break
            g = got[i]
            gs, gv = g >> 32, g & 0xFFFFFFFF
            if kind == "reg" and (where + j) in (2, 3, 4):   # live counters: just take them
                pass
            elif gs != s or gv != v:
                errors.append(f"read seq {s} {kind} {where} DW {j}: got seq {gs} {gv:#010x}, expected {v:#010x}")
            i += 1
    if len(got) != i:
        errors.append(f"{len(got) - i} extra response DWs")
    n_wr = (yield dut.n_wr)
    if n_wr != n_writes_model:
        errors.append(f"writes done {n_wr}, expected {n_writes_model}")
    for e in (0, 1):
        if aw_got[e] != aw_expect[e]:
            n = next((i for i, (a, b) in enumerate(zip(aw_got[e], aw_expect[e])) if a != b),
                     min(len(aw_got[e]), len(aw_expect[e])))
            errors.append(f"engine {e} activation writes: {len(aw_got[e])} got, {len(aw_expect[e])} expected, "
                          f"first difference at {n}")
    # every modelled bus write must be in the slave memory
    for a, v in busmem.items():
        if slave_mem.get(a, 0) != v:
            errors.append(f"bus memory {a:#010x}: {slave_mem.get(a, 0):#010x}, expected {v:#010x}")
            break


run_simulation(top, [driver(), bus_slave(), collector(), aw_monitor(), checker()])
for e in errors[:10]:
    print("ERROR", e)
print(f"{'FAIL' if errors else 'PASS'}: {len(got)} response DWs checked, activation fast-path writes "
      f"{len(aw_got[0])} + {len(aw_got[1])}, {len(errors)} errors")
sys.exit(1 if errors else 0)
