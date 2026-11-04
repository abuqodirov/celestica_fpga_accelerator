#!/usr/bin/env python3
"""Turn on the interconnect input delay on the PIPE paths between the PCIe block and the transceivers.

The factory design (Vivado hold fixing) delays almost every GT -> PCIe-block PIPE input on all 8 lanes and a
scattering of PCIe-block -> GT inputs (factory_pcie_delays.txt, NOTES 2026-10-31). nextpnr has no hold fixing and
always takes the direct path, so this adds the delay bit on every non-constant input of those groups:
  PCIe block:  PIPERXn{DATA,CHARISK,STATUS,VALID,CHANISALIGNED,PHYSTATUS,ELECIDLE}
  GT channel:  TXDATA[15:0] TXCHARISK[1:0] TXCHARDISPMODE0 TXELECIDLE TXPD RXPD TXDETECTRX TXDEEMPH TXMARGIN RXPOLARITY
The delay mux sits in the interface tile next to the INT tile: PCIE_INT_INTERFACE_{L,R} at the same row as the
INT tile; GTX_INT_INTERFACE one row up in prjxray naming (the borrowed Artix segbits decode the factory's delays
there, 288/288 consistent with the factory's INT routing).

  delay_patch.py in.fasm pinmap.txt out.fasm  (pinmap.txt from pinmap_route.py, same nextpnr run)
"""
import re, sys

PCIE_PINS = re.compile(r"(PIPERX\d(DATA\d+|CHARISK\d|STATUS\d|VALID|CHANISALIGNED|PHYSTATUS|ELECIDLE)|"
                       r"TRNTD\d+|TRNTEOF)$")   # TRNTD/TRNTEOF: the factory delays these too (v3)
GT_PINS = re.compile(r"(TXDATA([0-9]|1[0-5])|TXCHARISK[01]|TXCHARDISPMODE0|TXELECIDLE|TXPD[01]|RXPD[01]|"
                     r"TXDETECTRX|TXDEEMPH|TXMARGIN[0-2]|RXPOLARITY)$")
CONST = ("$PACKER_GND_NET", "$PACKER_VCC_NET")
import os
DB = os.environ.get("PCIE_DB", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "db",
                                                  "kintex7")) + "/"


def segbit_features(name):
    return {l.split()[0].split(".", 1)[1] for l in open(DB + name)}


def main(src, pinmap, dst):
    feats = {"PCIE_INT_INTERFACE_L": segbit_features("segbits_pcie_int_interface_l.db"),
             "PCIE_INT_INTERFACE_R": segbit_features("segbits_pcie_int_interface_r.db"),
             "GTX_INT_INTERFACE": segbit_features("segbits_gtx_int_interface.db")}
    add, problems = [], []
    counts = {"pcie": 0, "gt": 0}
    for line in open(pinmap):
        bel, pin, net, intw = line.split()[:4]
        if net in CONST or intw == "-":
            continue
        is_pcie = bel.startswith("PCIE_X0Y0") and PCIE_PINS.match(pin)
        is_gt = bel.startswith("GTXE2_CHANNEL") and GT_PINS.match(pin)
        if not (is_pcie or is_gt):
            continue
        m = re.match(r"INT_([LR])_X(\d+)Y(\d+)/IMUX(_L)?(\d+)$", intw)
        if not m:
            problems.append(f"{bel} {pin}: enters from {intw}, not an IMUX"); continue
        side, x, y, _, k = m.groups()
        if is_pcie:
            tt = f"PCIE_INT_INTERFACE_{side}"
            l = "_L" if side == "L" else ""
            f = f"PCIE_INT_INTERFACE_IMUX{l}_OUT{k}.PCIE_INT_INTERFACE_IMUX{l}_DELAY{k}"
            tile = f"{tt}_X{x}Y{y}"
        else:
            tt = "GTX_INT_INTERFACE"
            f = f"GTXE2_INT_INTERFACE_IMUX_OUT{k}.GTXE2_INT_INTERFACE_IMUX_DELAY{k}"
            tile = f"{tt}_X{x}Y{int(y) + 1}"
        if f not in feats[tt]:
            problems.append(f"{bel} {pin}: no delay bit for {tt}.{f}"); continue
        add.append(f"{tile}.{f}")
        counts["pcie" if is_pcie else "gt"] += 1
    lines = [l.rstrip("\n") for l in open(src)]
    have = set(lines)
    new = [a for a in add if a not in have]
    open(dst, "w").write("\n".join(lines + new) + "\n")
    print(f"delay_patch: {counts['pcie']} PCIe-block inputs, {counts['gt']} GT inputs delayed "
          f"({len(add) - len(new)} already were)")
    for p in problems:
        print("delay_patch: PROBLEM", p)
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main(*sys.argv[1:4])
