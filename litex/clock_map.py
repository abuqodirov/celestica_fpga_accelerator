#!/usr/bin/env python3
"""Which global clock (GCLK number) reaches the clock pins of every DDR3 DQ/DQS IO tile, from a FASM file.

Chain per IO tile: IOI_<site>_<pin> <- IOI_LEAF_GCLKn (or via IOI_OCLK_m) ; the bank's HCLK_IOI3 tile maps
LEAF_GCLK_{TOP,BOT}n <- IGCLKk <- BUFHCLKk (TOP/BOT = tile above/below the HCLK row, by tilegrid grid_y) ;
the clock row CLK_HROW_* of that clock region maps track Lk <- MUX_OUT_Lk <- GCLKg.
Prints one line per DDR3 lane: the GCLKs feeding OLOGIC CLK / CLKDIV and ILOGIC CLK / CLKDIV of its DQ tiles
and DQS tile, so a lane wired differently from the others stands out.
usage: clock_map.py <fasm> <channel 0|1> <lanes, e.g. 0,1,2,3,4,5,6,8> [failing logical lanes, e.g. 6,7]"""
import os
import csv
import json
import re
import sys
from collections import Counter, defaultdict

DB = os.path.expanduser("~/tools/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7")
sys.path.insert(0, os.path.expanduser("~/tools/litex/litex-boards"))


def main():
    fasm, ch, lanes = sys.argv[1], int(sys.argv[2]), [int(x) for x in sys.argv[3].split(",")]
    failing = {int(x) for x in sys.argv[4].split(",")} if len(sys.argv) > 4 and sys.argv[4] else set()
    grid = json.load(open(f"{DB}/xc7k480t/tilegrid.json"))
    site_tile = {s: t for t, v in grid.items() for s in v.get("sites", {})}
    pp = {r["pin"]: r for r in csv.DictReader(open(f"{DB}/xc7k480tffg1156-2/package_pins.csv"))}
    from litex_boards.platforms.ypcb_00338_1p1 import _io
    e = next(e for e in _io if e[0] == "ddram" and e[1] == ch)
    pins = {s.name: " ".join(s.constraints[0].identifiers).split() for s in e[2:] if hasattr(s, "name")}

    feats = defaultdict(set)                         # tile -> set of "a.b" features
    for line in open(fasm):
        t, _, f = line.strip().partition(".")
        if f and not line.startswith("#"):
            feats[t].add(f.split(" ")[0])

    def region(t):
        return grid[t]["clock_region"]

    hclk = {region(t): t for t in feats if t.startswith("HCLK_IOI")}
    hrow = {}
    for t in feats:
        if t.startswith("CLK_HROW"):
            r = region(t)                            # X1Yr (center) -> rows shared with X0Yr
            hrow[r.split("Y")[1]] = t

    def gclk_of_track(row, k):
        t = hrow.get(row)
        for f in feats.get(t, ()):
            m = re.fullmatch(rf"CLK_HROW_CK_MUX_OUT_L{k}\.CLK_HROW_R_CK_GCLK(\d+)", f)
            if m:
                return int(m.group(1))
        return None

    def leaf_gclk(tile, n):
        h = hclk[region(tile)]
        half = "TOP" if grid[tile]["grid_y"] < grid[h]["grid_y"] else "BOT"
        for f in feats[h]:
            m = re.fullmatch(rf"HCLK_IOI_LEAF_GCLK_{half}{n}\.HCLK_IOI_CK_IGCLK(\d+)", f)
            if m:
                k = int(m.group(1))
                assert f"HCLK_IOI_CK_IGCLK{k}.HCLK_IOI_CK_BUFHCLK{k}" in feats[h], (h, k)
                return f"{half[0]}{n}:L{k}:G{gclk_of_track(region(h).split('Y')[1], k)}"
        return f"{half[0]}{n}:?"

    def pin_clocks(tile, idx):                       # idx 0/1 = site pair within the tile
        out = {}
        fs = feats[tile]
        for f in fs:
            m = re.fullmatch(rf"IOI_(OLOGIC|ILOGIC){idx}_(CLK|CLKB|CLKDIV)\.(IOI_\w+)", f)
            if not m:
                continue
            src = m.group(3)
            mm = re.fullmatch(r"IOI_LEAF_GCLK(\d+)", src)
            if not mm:                               # through IOI_OCLK_m / IOI_ICLK... muxes
                nxt = [g for g in fs if g.startswith(src + ".IOI_LEAF_GCLK")]
                mm = re.search(r"IOI_LEAF_GCLK(\d+)$", nxt[0]) if nxt else None
            out[f"{m.group(1)[0]}{m.group(2)}"] = leaf_gclk(tile, int(mm.group(1))) if mm else src
        return out

    def where(pin):
        n = int(re.search(r"Y(\d+)$", pp[pin]["site"]).group(1))
        t = site_tile[f"OLOGIC_X0Y{n}"]
        ys = sorted(int(re.search(r"Y(\d+)$", s).group(1)) for s in grid[t]["sites"] if s.startswith("OLOGIC"))
        return t, (1 - ys.index(n)) if len(ys) == 2 else 0      # lower site number = Y0 = pip index 1

    rows = []
    for li, phys in enumerate(lanes):
        dq = Counter()
        for b in range(8):
            t, i = where(pins["dq"][8 * phys + b])
            c = pin_clocks(t, i)
            dq[tuple(sorted((k, v.split(":")[-1]) for k, v in c.items()))] += 1
        t, i = where(pins["dqs_p"][phys])
        dqs = tuple(sorted((k, v.split(":")[-1]) for k, v in pin_clocks(t, i).items()))
        rows.append((li, phys, pp[pins["dqs_p"][phys]]["bank"], dq, dqs))
    for li, phys, bank, dq, dqs in rows:
        flag = "FAIL" if li in failing else "ok  "
        print(f"m{li} (lane {phys}, bank {bank}) {flag} DQ: " +
              " | ".join(f"{n}x " + " ".join(f"{k}={v}" for k, v in key) for key, n in dq.items()) +
              "   DQS: " + " ".join(f"{k}={v}" for k, v in dqs))


if __name__ == "__main__":
    main()
