#!/usr/bin/env python3
"""BIST write (row 5, bank 0, col 64, N bursts), then print the 3-clock x 4-phase DFI windows the
spy captured around the last CAS and the last ACT."""
import sys
from bios import Bios, csr
from bist_vs_dfii import gen_write


def dec(w):
    a, ba = w & 0x7FFF, (w >> 15) & 7
    we, cas, ras, cs = (w >> 18) & 1, (w >> 19) & 1, (w >> 20) & 1, (w >> 21) & 1
    name = "--- " if cs else {(1, 1, 1): "NOP ", (0, 1, 1): "ACT ", (1, 0, 1): "RD  ", (1, 0, 0): "WR  ",
                              (0, 1, 0): "PRE ", (0, 0, 1): "REF ", (0, 0, 0): "MRS ", (1, 1, 0): "ZQ  "}[(ras, cas, we)]
    return f"{name}a={a:5d} ba={ba}"


def main():
    b = Bios()
    b.sync()
    nb = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    row, col = 5, 64
    print("generator done:", gen_write(b, (row << 15) | ((col // 8) << 5), nb))
    for kind in ("act", "cas"):
        print(f"window around last {kind.upper()}:        phase0           |      phase1           |      phase2           |      phase3")
        for t in ("m1", "t0", "p1"):
            ws = [b.read(csr(f"dramspy_w{kind}_{t}_p{i}"))[0] for i in range(4)]
            print(f"  {t}: " + " | ".join(dec(w) for w in ws))
    b.close()


if __name__ == "__main__":
    main()
