#!/usr/bin/env python3
"""Compare the constant input ties of our PCIE_2_1 with the factory design's (like ../s1/check_ties.py for the GTs).

Ours: from the net on the pin in our pin map (GND/VCC/none = unrouted = 1). Factory: a pin's value in a FASM: 0 if its IMUX is driven from GND_WIRE (via GFAN/FAN_BOUNCE), 1 if the IMUX has no pip at
all (silicon default VCC_WIRE), 'net' if driven by logic. Pin -> INT wire maps: pinmap files from pinmap_route.py.

  pcie_ties.py ours.fasm pinmap.txt [more pinmaps...]
"""
import re, sys

def drivers(fasm):
    drv = {}
    for line in open(fasm):
        m = re.match(r"^(INT_[LR]_X\d+Y\d+)\.(\w+)\.(\w+)$", line.strip())
        if m:
            drv[(m.group(1), m.group(2))] = m.group(3)
    return drv

def value(drv, tile, wire, depth=0):
    src = drv.get((tile, wire))
    m = re.match(r"(FAN|BYP)_BOUNCE(_L)?(\d)$", wire)
    if src is None and m:
        return value(drv, tile, f"{m.group(1)}_ALT{m.group(2) or ''}{m.group(3)}", depth + 1)
    if src is None:
        return "1" if re.match(r"(IMUX|FAN_ALT|BYP_ALT)(_L)?\d", wire) else "u0"
    if src == "GND_WIRE":
        return "0"
    if src == "VCC_WIRE":
        return "1"
    if depth < 3 and re.match(r"(GFAN|FAN_BOUNCE|FAN_ALT|BYP_ALT|BYP_BOUNCE)(_L)?\d", src):
        return value(drv, tile, src, depth + 1)
    return "net:" + src

ours_fasm, maps = sys.argv[1], sys.argv[2:]
pinw, ournet = {}, {}
for line in open(maps[0]):   # our own pin map: the net on each pin (constants are $PACKER_GND_NET / _VCC_NET)
    f = line.split()
    if f[0].startswith("PCIE_X0Y0"):
        ournet[f[1]] = f[2]
for mp in maps:
    for line in open(mp):
        f = line.split()
        if f[0].startswith("PCIE_X0Y0") and f[3] != "-":
            pinw.setdefault(f[1], f[3])
ports = [l.split() for l in open("pcie_ports.txt")]
inputs = [p[3] for p in ports if p[4] == "input"]
fd, od = drivers("../flash_v3.fasm"), drivers(ours_fasm)
bad = unmapped = dyn = 0
for pin in inputs:
    if pin not in pinw:
        unmapped += 1; continue
    tile, wire = pinw[pin].split("/")
    fv = value(fd, tile, wire)
    n = ournet.get(pin)
    ov = "1" if n in (None, "$PACKER_VCC_NET") else "0" if n == "$PACKER_GND_NET" else "net:" + n
    if fv.startswith("net:") or fv == "u0":
        dyn += 1; continue
    if fv != ov:
        bad += 1
        print(f"DIFF {pin}: factory {fv} ours {ov}")
print(f"{len(inputs)} inputs: {bad} constant ties differ from the factory, {dyn} driven by logic in the factory, "
      f"{unmapped} without a pin map")
