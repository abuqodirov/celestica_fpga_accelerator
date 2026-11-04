#!/usr/bin/env python3
"""List the package pins a decoded bitstream actually uses.

Usage: fasm_pins.py <decoded.fasm> [package_pins.csv]
Groups IOB FASM features per site, drops sites that only carry the
default unused-pin features, and prints pin / bank / function / features.
"""
import csv, os, re, sys
from collections import defaultdict

DEFAULT_CSV = os.path.expanduser(
    "~/tools/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7/"
    "xc7k480tffg1156-2/package_pins.csv")

# Features every unused IOB carries in this flow; a site with only these is unused.
UNUSED_FEATURES = {
    "IN_TERM.NONE",
    "LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVTTL.SLEW.FAST",
    "LVCMOS12_LVCMOS15_LVCMOS18_SSTL135_SSTL15.STEPDOWN",
    "PULLTYPE.PULLDOWN", "PULLTYPE.PULLUP", "PULLTYPE.KEEPER", "PULLTYPE.NONE",
}

def main():
    fasm_path = sys.argv[1]
    csv_path = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_CSV

    # (tile, IOB_Y0|IOB_Y1) -> pin row. In prjxray IOB_Y0 is the HIGHER-numbered site
    # (verified: nextpnr placed an output on AK18=IOB_X0Y24, FASM said LIOB33_X0Y23.IOB_Y0).
    by_tile = defaultdict(list)
    for row in csv.DictReader(open(csv_path)):
        if row["tile"].startswith(("LIOB", "RIOB")):
            by_tile[row["tile"]].append(row)
    site_map = {}
    for tile, rows in by_tile.items():
        rows.sort(key=lambda r: -int(re.search(r"Y(\d+)$", r["site"]).group(1)))
        for idx, row in enumerate(rows):
            site_map[(tile, f"IOB_Y{idx}")] = row

    feats = defaultdict(set)
    for line in open(fasm_path):
        m = re.match(r"^([LR]IOB\d+_X\d+Y\d+)\.(IOB_Y[01])\.(\S+)", line.strip())
        if m:
            feats[(m.group(1), m.group(2))].add(m.group(3))

    used = []
    for key, fs in feats.items():
        interesting = sorted(f for f in fs if f not in UNUSED_FEATURES)
        if interesting:
            row = site_map.get(key)
            used.append((row, key, interesting, fs))

    used.sort(key=lambda u: (int(u[0]["bank"]) if u[0] else 999, u[0]["pin"] if u[0] else ""))
    for row, key, interesting, fs in used:
        pin = row["pin"] if row else "?"
        bank = row["bank"] if row else "?"
        func = row["pin_function"] if row else f"{key[0]}.{key[1]}"
        pull = next((f.split(".")[1] for f in fs if f.startswith("PULLTYPE")), "-")
        print(f"{pin:5} bank {bank:>3}  {func:28} pull={pull:8} {' '.join(interesting)}")
    print(f"\n{len(used)} used IOB sites", file=sys.stderr)

if __name__ == "__main__":
    main()
