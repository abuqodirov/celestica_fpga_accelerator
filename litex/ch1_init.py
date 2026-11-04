#!/usr/bin/env python3
"""Initialise DDR3 channel 1 of a YPCB_DUAL SoC from the host (the BIOS only initialises channel 0).

1. PHY reset, then the JEDEC init sequence replayed from the build's generated sdram_phy.h (init_sequence())
   through sdram1's DFII, loading the address into all 4 DFI phases (this board's cmd/addr bus is marginal).
2. Read leveling: two bursts of known data written by DFII, then every lane's read bitslip x IDELAY tap is
   scanned (all lanes at once) and each lane is set to the centre of its widest passing window.
3. Hardware control. Prints one line per lane like the BIOS ("m0: b02 delays 16+-09").
usage: [YPCB_BUILD=dir] ch1_init.py [--core sdram1] [--phy ddrphy1] [--row R]"""
import argparse
import os
import random
import re
import time

from bios import BUILD, Bios, csr

CS, WE, CAS, RAS, WREN, RDEN = 1, 2, 4, 8, 0x10, 0x20


def init_sequence():
    """[(kind, value...)] from generated/sdram_phy.h init_sequence(): ('ctrl', v) ('cmd', addr, bank, cmd) ('delay', n)"""
    h = open(os.path.join(BUILD, "software", "include", "generated", "sdram_phy.h")).read()
    consts = {k: int(v, 0) for k, v in re.findall(r"#define (DFII_\w+) (0x[0-9a-fA-F]+|\d+)", h)}
    body = re.search(r"static inline void init_sequence\(void\)\s*\{(.*?)\n\}", h, re.S).group(1)
    ev = lambda e: sum(consts[t.strip()] for t in e.split("|"))
    seq, addr, bank = [], 0, 0
    for m in re.finditer(r"(\w+)\(([^)]*)\);", body):
        fn, arg = m.groups()
        if fn.endswith("pi0_address_write"):
            addr = int(arg, 0)
        elif fn.endswith("pi0_baddress_write"):
            bank = int(arg, 0)
        elif fn.endswith("dfii_control_write"):
            seq.append(("ctrl", ev(arg)))
        elif fn == "command_p0":
            seq.append(("cmd", addr, bank, ev(arg)))
        elif fn == "cdelay":
            seq.append(("delay", int(arg)))
        else:
            raise ValueError(f"unhandled init step {fn}({arg})")
    return seq, consts


class Channel:
    def __init__(self, b, core, phy):
        self.b = b
        self.ctrl = csr(f"{core}_dfii_control")
        self.pi0 = csr(f"{core}_dfii_pi0_command")
        self.stride = csr(f"{core}_dfii_pi1_command") - self.pi0
        self.wr = csr(f"{core}_dfii_pi0_wrdata") - self.pi0
        self.rd = csr(f"{core}_dfii_pi0_rddata") - self.pi0
        self.nw = (self.rd - self.wr) // 4               # 32-bit words per phase
        self.db = self.nw * 16                           # DQ bits per beat
        self.lanes = self.db // 8
        self.phy = {n: csr(f"{phy}_{n}") for n in ("rst", "dly_sel", "rdly_dq_rst", "rdly_dq_inc",
                                                    "rdly_dq_bitslip_rst", "rdly_dq_bitslip", "rdphase", "wrphase")}
        self.addr = [None] * 4

    def issue(self, phase, cmd, addr=0, bank=0):
        for p in range(4):
            if self.addr[p] != (addr, bank):
                self.b.write(self.pi0 + self.stride * p + 0x8, addr)
                self.b.write(self.pi0 + self.stride * p + 0xC, bank)
                self.addr[p] = (addr, bank)
        self.b.write(self.pi0 + self.stride * phase, cmd)
        self.b.write(self.pi0 + self.stride * phase + 0x4, 1)

    def set_burst(self, beats):                      # beats[8][lanes] bytes
        for p in range(4):
            v = 0
            for n in range(2):
                for l, byte in enumerate(beats[2 * p + n]):
                    v |= byte << (n * self.db + 8 * l)
            for k in range(self.nw):
                self.b.write(self.pi0 + self.stride * p + self.wr + 4 * k, (v >> (32 * (self.nw - 1 - k))) & 0xFFFFFFFF)

    def get_burst(self):
        w = self.b.read(self.pi0 + self.rd, (3 * self.stride + 4 * self.nw) // 4)
        beats = []
        for p in range(4):
            v = 0
            for k in range(self.nw):
                v = (v << 32) | w[p * (self.stride // 4) + k]
            for n in range(2):
                beats.append([(v >> (n * self.db + 8 * l)) & 0xFF for l in range(self.lanes)])
        return beats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--core", default="sdram1")
    ap.add_argument("--phy", default="ddrphy1")
    ap.add_argument("--row", type=int, default=0x77)
    args = ap.parse_args()
    seq, consts = init_sequence()
    rdphase = int(re.search(r"#define SDRAM_PHY_RDPHASE (\d+)", open(os.path.join(
        BUILD, "software", "include", "generated", "sdram_phy.h")).read()).group(1))
    b = Bios(freq=15e6); b.sync(); b.drain(1.0)
    c = Channel(b, args.core, args.phy)
    t0 = time.time()
    sw = consts["DFII_CONTROL_CKE"] | consts["DFII_CONTROL_ODT"] | consts["DFII_CONTROL_RESET_N"]
    b.write(c.ctrl, 0)                                # software control, everything low
    b.write(c.phy["rdphase"], rdphase); b.write(c.phy["wrphase"], rdphase)
    b.write(c.phy["rst"], 1); time.sleep(0.01); b.write(c.phy["rst"], 0); time.sleep(0.01)
    for step in seq:
        if step[0] == "ctrl":
            b.write(c.ctrl, step[1])
        elif step[0] == "cmd":
            c.issue(0, step[3], step[1], step[2])
        else:
            time.sleep(max(0.001, step[1] * 1e-7))
    b.write(c.ctrl, sw)
    # known data: two bursts (random, and its complement) at columns 0 and 8 of one row
    rnd = random.Random(1)
    pats = [[[rnd.randrange(256) for _ in range(c.lanes)] for _ in range(8)]]
    pats.append([[x ^ 0xFF for x in beat] for beat in pats[0]])
    c.issue(0, RAS | WE | CS, 0x400)                  # precharge all
    c.issue(0, RAS | CS, args.row)                    # activate
    for i, p in enumerate(pats):
        c.set_burst(p)
        c.issue(rdphase, CAS | WE | CS | WREN, 8 * i)
    allsel = (1 << c.lanes) - 1
    ok = [[[False] * 32 for _ in range(8)] for _ in range(c.lanes)]
    for bs in range(8):
        b.write(c.phy["dly_sel"], allsel)
        b.write(c.phy["rdly_dq_bitslip_rst"], 1)
        for _ in range(bs):
            b.write(c.phy["rdly_dq_bitslip"], 1)
        b.write(c.phy["rdly_dq_rst"], 1)
        for d in range(32):
            good = [True] * c.lanes
            for i, p in enumerate(pats):
                c.issue(rdphase, CAS | CS | RDEN, 8 * i)
                got = c.get_burst()
                for l in range(c.lanes):
                    good[l] &= all(got[k][l] == p[k][l] for k in range(8))
            for l in range(c.lanes):
                ok[l][bs][d] = good[l]
            b.write(c.phy["rdly_dq_inc"], 1)
    result = []
    for l in range(c.lanes):
        best = (0, 0, 0)                              # (window length, bitslip, centre)
        for bs in range(8):
            run = start = 0
            for d in range(33):
                if d < 32 and ok[l][bs][d]:
                    run += 1
                else:
                    if run > best[0]:
                        best = (run, bs, start + (run - 1) // 2)
                    run, start = 0, d + 1
        result.append(best)
        b.write(c.phy["dly_sel"], 1 << l)
        b.write(c.phy["rdly_dq_bitslip_rst"], 1)
        for _ in range(best[1]):
            b.write(c.phy["rdly_dq_bitslip"], 1)
        b.write(c.phy["rdly_dq_rst"], 1)
        for _ in range(best[2]):
            b.write(c.phy["rdly_dq_inc"], 1)
    b.write(c.phy["dly_sel"], 0)
    c.issue(0, RAS | WE | CS, 0x400)
    b.write(c.ctrl, consts["DFII_CONTROL_SEL"])       # hardware control
    print(" ".join(f"m{l}:b{bs:02d}@{ctr:02d}+-{(n - 1) // 2:02d}" if n else f"m{l}:----"
                   for l, (n, bs, ctr) in enumerate(result)) + f"   ({time.time() - t0:.0f} s)")
    b.close()


if __name__ == "__main__":
    main()
