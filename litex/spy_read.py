#!/usr/bin/env python3
"""Do one BIST write (row 5, bank 0, col 64, 4 bursts) and print every dramspy latch."""
import sys
from bios import Bios, csr
from bist_vs_dfii import gen_write

NAMES = ["bm0_req", "bm0_cas", "bm0_act", "chreq_cas", "ctl_cas", "ctl_act", "phy_cas", "phy_act"]


def show(b, title):
    print(title)
    for n in NAMES:
        v, cnt = b.read(csr("dramspy_" + n), 1)[0], b.read(csr("dramspy_" + n + "_n"), 1)[0]
        if n == "bm0_req":
            a = v & 0x3FFFFF
            dec = f"row {a >> 7} col {(a & 0x7f) * 8} we {v >> 22 & 1}"
        elif n in ("bm0_cas", "bm0_act"):
            dec = f"a={v & 0x7fff}"
        elif n == "chreq_cas":
            dec = f"a={v & 0x7fff} ba={v >> 15 & 7}"
        else:
            dec = f"a={v & 0x7fff} ba={v >> 15 & 7} phase={v >> 18 & 3}"
        print(f"  {n:10s} count={cnt:8d}  last: {dec}")


b = Bios()
b.sync()
show(b, "before:")
row, col, nb = 5, 64, int(sys.argv[1]) if len(sys.argv) > 1 else 4
addr = (row << 15) | ((col // 8) << 5)
print("generator done:", gen_write(b, addr, nb))
show(b, "after:")
b.close()
