#!/usr/bin/env python3
"""Add the factory design's x8 reference-clock sharing to a nextpnr FASM file.

The board feeds the 100 MHz PCIe clock into quad 116 only (MGTREFCLK0_116); lanes 4-7 sit in quad 115 and
get it through the dedicated inter-quad path. nextpnr cannot express that, so this copies exactly the bits
the factory bitstream uses (see NOTES 2026-10-30 and db/README.txt). Also sets QPLL_LPF to the factory value
(nextpnr hard-codes another one).

  fasm_patch.py in.fasm out.fasm
"""
import re, sys

Q115_CHANNELS = ["GTX_CHANNEL_0_X309Y214", "GTX_CHANNEL_1_X309Y225", "GTX_CHANNEL_2_X309Y243",
                 "GTX_CHANNEL_3_X309Y254"]
Q115_COMMON, Q116_COMMON = "GTX_COMMON_X309Y231", "GTX_COMMON_X309Y283"


def main(src, dst):
    lines = [l.rstrip("\n") for l in open(src)]
    out, seen = [], set()
    for l in lines:
        tile = l.split(".", 1)[0]
        if tile in Q115_CHANNELS and l.endswith(".GTXE2_CHANNEL.GTREFCLK0_USED"):
            continue  # replaced below
        if tile in (Q115_COMMON, Q116_COMMON) and ".GTXE2_COMMON.QPLL_LPF" in l:
            continue
        if tile == Q115_COMMON and re.search(r"\.GTXE2_COMMON\.(GTREFCLK[01]_USED$|IBUFDS_GTE2\.CLKSWING_CFG)", l):
            continue  # quad 115 has no local refclk buffer in use
        seen.add(tile)
        out.append(l)
    missing = [t for t in Q115_CHANNELS + [Q115_COMMON, Q116_COMMON] if t not in seen]
    if missing:
        sys.exit(f"fasm_patch: tiles not in use in {src}: {missing}")
    for t in Q115_CHANNELS:
        out += [f"{t}.GTXE2_CHANNEL.GTREFCLK1_USED", f"{t}.GTXE2_CHANNEL.XF_REFCLK_31_10"]
    out += [f"{Q115_COMMON}.GTXE2_COMMON.GTREFCLK1_USED", f"{Q115_COMMON}.GTXE2_COMMON_GTGREFCLK.GTXE2_CLK0_2",
            f"{Q116_COMMON}.GTXE2_COMMON.XF_REFCLK_30_1486"]
    for t in (Q115_COMMON, Q116_COMMON):
        out.append(f"{t}.GTXE2_COMMON.QPLL_LPF[3:0] = 4'b1101")
    open(dst, "w").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main(*sys.argv[1:3])
