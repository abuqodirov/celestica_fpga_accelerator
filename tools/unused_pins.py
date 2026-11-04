#!/usr/bin/env python3
"""Give every unused I/O pin Vivado's PULLNONE defaults in a nextpnr FASM file.

Usage: unused_pins.py <in.fasm> <out.fasm> [package_pins.csv]

nextpnr-xilinx emits nothing for unused IOBs, and all-zero IOB bits mean
PULLDOWN on this part. On the Celestica XC7K480T board a pulldown on some unused
pin aborts startup (DONE never rises), so unused pins are set the way Vivado
does with BITSTREAM.CONFIG.UNUSEDPIN PULLNONE: IN_TERM.NONE, SLEW.FAST,
PULLTYPE.NONE, plus STEPDOWN in banks the design runs at <= 1.8 V.
"""
import csv
import os
import re
import sys
from collections import defaultdict

DEFAULT_CSV = os.path.expanduser(
    "~/tools/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7/"
    "xc7k480tffg1156-2/package_pins.csv")

UNUSED = ["IN_TERM.NONE",
          "LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVTTL.SLEW.FAST",
          "PULLTYPE.NONE"]
STEPDOWN = "LVCMOS12_LVCMOS15_LVCMOS18_SSTL135_SSTL15.STEPDOWN"
# Features that mean the design really uses the site (not just a bank-level side effect).
USED_MARKERS = ("DRIVE", ".IN", "IN_ONLY", "IN_DIFF", "PULLTYPE", "IN_TERM", "SLEW")


def main():
    src, dst = sys.argv[1], sys.argv[2]
    csv_path = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_CSV

    # Every IOB site in the package: (tile, IOB_Yn) -> bank. IOB_Y0 is the
    # higher-numbered site of the tile (see fasm_pins.py).
    by_tile = defaultdict(list)
    for row in csv.DictReader(open(csv_path)):
        if re.match(r"[LR]IOB", row["tile"]):
            by_tile[row["tile"]].append(row)
    site_bank = {}
    for tile, rows in by_tile.items():
        rows.sort(key=lambda r: -int(re.search(r"Y(\d+)$", r["site"]).group(1)))
        for idx, row in enumerate(rows):
            site_bank[(tile, f"IOB_Y{idx}")] = row["bank"]

    lines = open(src).read().splitlines()
    feats = defaultdict(set)
    for line in lines:
        m = re.match(r"^([LR]IOB\d+(?:_SING)?_X\d+Y\d+)\.(IOB_Y[01])\.(\S+)", line.strip())
        if m:
            feats[(m.group(1), m.group(2))].add(m.group(3))

    used = {k for k, fs in feats.items() if any(mk in f for f in fs for mk in USED_MARKERS)}
    low_v_banks = {site_bank[k] for k, fs in feats.items() if k in site_bank and STEPDOWN in fs}

    added = 0
    out = lines + ["", "# unused_pins.py: PULLNONE defaults for unused IOBs"]
    for key in sorted(site_bank):
        if key in used:
            continue
        tile, site = key
        want = list(UNUSED)
        if site_bank[key] in low_v_banks:
            want.append(STEPDOWN)
        for f in want:
            if f not in feats.get(key, ()):
                out.append(f"{tile}.{site}.{f}")
        added += 1
    open(dst, "w").write("\n".join(out) + "\n")
    print(f"{added} unused IOB sites set to PULLNONE "
          f"({len(used)} used; low-voltage banks: {sorted(low_v_banks)})", file=sys.stderr)


if __name__ == "__main__":
    main()
