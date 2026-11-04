#!/usr/bin/env python3
"""Per-lane read-delay scan through DFII (8-lane PHY): writes one burst where every byte names its origin
(beat << 4 | lane), then for each selected lane steps its IDELAY tap 0..31 and prints what that lane reads
at each beat. A lane whose delay control works shows the data move across taps; a dead control reads the
same bytes at every tap.   usage: tap_scan.py [--lanes 4,6,7] [--bitslip N]"""
import argparse

from bios import Bios, csr

CS, WE, CAS, RAS, WREN, RDEN = 1, 2, 4, 8, 0x10, 0x20
SW, HW = 0x0E, 0x01
CTRL, PI0 = csr("sdram_dfii_control"), csr("sdram_dfii_pi0_command")
STRIDE = csr("sdram_dfii_pi1_command") - PI0
WR, RD = csr("sdram_dfii_pi0_wrdata") - PI0, csr("sdram_dfii_pi0_rddata") - PI0
NW = (RD - WR) // 4                              # 32-bit words per phase (4 for a 64-bit bus)
DB = NW * 16                                     # DQ bits per beat
PHY = {n: csr("ddrphy_" + n) for n in ("dly_sel", "rdly_dq_rst", "rdly_dq_inc", "rdly_dq_bitslip_rst", "rdly_dq_bitslip")}


def burst_value():
    """8 beats x (DB/8) lanes, byte = beat << 4 | lane."""
    return [[(b << 4) | l for l in range(DB // 8)] for b in range(8)]


def phase_words(beats, p):
    v = 0
    for n in range(2):                           # wrdata[n*DB + 8*l] = beat 2p+n, lane l
        for l, byte in enumerate(beats[2 * p + n]):
            v |= byte << (n * DB + 8 * l)
    return [(v >> (32 * (NW - 1 - k))) & 0xFFFFFFFF for k in range(NW)]   # CSR order: MSB word first


def words_to_beats(words):
    beats = []
    for p in range(4):
        v = 0
        for k in range(NW):
            v = (v << 32) | words[p * (STRIDE // 4) + k]
        for n in range(2):
            beats.append([(v >> (n * DB + 8 * l)) & 0xFF for l in range(DB // 8)])
    return beats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lanes", default="4,6,7")
    ap.add_argument("--bitslip", type=int, default=None)
    ap.add_argument("--row", type=int, default=0x55)
    ap.add_argument("--matrix", type=int, default=None, help="set every lane to this tap, print beat x lane once")
    ap.add_argument("--xor", type=lambda s: int(s, 0), default=0, help="xor every pattern byte with this")
    args = ap.parse_args()
    b = Bios(freq=15e6); b.sync(); b.drain(1.0)

    def issue(phase, cmd, addr=0, bank=0):
        for p in range(4):                       # same address on all phases (marginal cmd/addr bus)
            b.write(PI0 + STRIDE * p + 0x8, addr); b.write(PI0 + STRIDE * p + 0xC, bank)
        b.write(PI0 + STRIDE * phase, cmd); b.write(PI0 + STRIDE * phase + 0x4, 1)

    beats = [[x ^ args.xor for x in beat] for beat in burst_value()]
    b.write(CTRL, SW)
    issue(0, RAS | WE | CS, 0x400)               # precharge all
    issue(0, RAS | CS, args.row)                 # activate
    for p in range(4):
        for k, w in enumerate(phase_words(beats, p)):
            b.write(PI0 + STRIDE * p + WR + 4 * k, w)
    issue(3, CAS | WE | CS | WREN, 0)
    if args.matrix is not None:
        for lane in range(DB // 8):
            b.write(PHY["dly_sel"], 1 << lane); b.write(PHY["rdly_dq_rst"], 1)
            for _ in range(args.matrix):
                b.write(PHY["rdly_dq_inc"], 1)
        b.write(PHY["dly_sel"], 0)
        issue(3, CAS | CS | RDEN, 0)
        got = words_to_beats(b.read(PI0 + RD, (3 * STRIDE + 4 * NW) // 4))
        print(f"tap {args.matrix}, pattern byte = (beat<<4 | lane) ^ 0x{args.xor:02x}; rows = beats, columns = lanes m0..m{DB // 8 - 1}")
        for i, beat in enumerate(got):
            print(f"  beat {i}: " + " ".join(f"{x ^ args.xor:02x}" + ("  " if x == beats[i][l] else "* ") for l, x in enumerate(beat)))
        issue(0, RAS | WE | CS, 0x400); b.write(CTRL, HW); b.close()
        return
    print("expected per beat: lane L reads b0L b1L ... b7L (hex)")
    for lane in [int(x) for x in args.lanes.split(",")]:
        b.write(PHY["dly_sel"], 1 << lane)
        if args.bitslip is not None:
            b.write(PHY["rdly_dq_bitslip_rst"], 1)
            for _ in range(args.bitslip):
                b.write(PHY["rdly_dq_bitslip"], 1)
        b.write(PHY["rdly_dq_rst"], 1)
        print(f"lane m{lane}:")
        for tap in range(32):
            issue(3, CAS | CS | RDEN, 0)
            w = b.read(PI0 + RD, (3 * STRIDE + RD + 4 * NW - RD) // 4)
            got = [beat[lane] for beat in words_to_beats(w)]
            ok = got == [(i << 4) | lane for i in range(8)]
            print(f"  tap {tap:2d}: " + " ".join(f"{x:02x}" for x in got) + ("  OK" if ok else ""))
            b.write(PHY["rdly_dq_inc"], 1)
        b.write(PHY["dly_sel"], 0)
    issue(0, RAS | WE | CS, 0x400)
    b.write(CTRL, HW)
    b.close()


if __name__ == "__main__":
    main()
