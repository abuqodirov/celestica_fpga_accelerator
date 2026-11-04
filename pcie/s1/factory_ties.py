#!/usr/bin/env python3
"""Read the factory design's value on every GTXE2_CHANNEL / GTXE2_COMMON input pin.

gt_pinmap.txt (from gt_pinmap_npnr.py run inside nextpnr-xilinx) says which interconnect wire feeds each GT pin.
In the factory FASM, a pin is:  0 if its wire is driven from GND_WIRE (via GFAN/FAN_BOUNCE),  1 if an IMUX has no
pip at all (the silicon default is VCC_WIRE),  'net' if driven by real logic (source wire printed).

  factory_ties.py ../flash_v3.fasm > factory_ties.txt
"""
import collections, re, sys

def main(fasm):
    drv = {}   # (tile, dst wire) -> src wire
    for line in open(fasm):
        m = re.match(r"^(INT_R_X\d+Y\d+)\.(\w+)\.(\w+)$", line.strip())
        if m:
            drv[(m.group(1), m.group(2))] = m.group(3)

    def value(tile, wire, depth=0):
        src = drv.get((tile, wire))
        m = re.match(r"(FAN|BYP)_BOUNCE(\d)$", wire)
        if src is None and m:   # FAN_BOUNCEk <- FAN_ALTk and BYP_BOUNCEk <- BYP_ALTk are fixed ("always") connections
            return value(tile, f"{m.group(1)}_ALT{m.group(2)}", depth + 1)
        if src is None:   # silicon defaults: IMUX/FAN_ALT/BYP_ALT -> VCC_WIRE; CTRL/CLK unrouted (taken as 0)
            return "1" if re.match(r"(IMUX|FAN_ALT|BYP_ALT)\d", wire) else "u0"
        if src == "GND_WIRE":
            return "0"
        if src == "VCC_WIRE":
            return "1"
        if depth < 3 and re.match(r"(GFAN|FAN_BOUNCE|FAN_ALT|BYP_ALT|BYP_BOUNCE)\d", src):
            return value(tile, src, depth + 1)
        return "net:" + src

    portbit = {}   # pin name -> (port, bit), from the cell library (gt_ports.txt)
    for line in open("gt_ports.txt"):
        cell, port, idx, pin = line.split()
        portbit[(cell, pin)] = (port, max(int(idx), 0))
    vals = collections.defaultdict(dict)   # (site, port) -> {bit: value}
    for line in open("gt_pinmap.txt"):
        f = line.split()
        site, pin, ints = f[0], f[1], [x for x in f[3:] if x.startswith("INT_R_")]
        port, bit = portbit[(site.rsplit("_", 1)[0], pin)]
        if len(ints) != 1:
            vals[(site, port)][bit] = "nomap"
            continue
        tile, wire = ints[0].split("/")
        vals[(site, port)][bit] = value(tile, wire)

    for (site, port), bits in sorted(vals.items()):
        n = max(bits) + 1
        vs = [bits.get(i, "?") for i in range(n)]
        if all(v in "01" for v in vs):
            s = f"{n}'b" + "".join(reversed(vs))
        else:
            s = " ".join(f"[{i}]={v}" for i, v in enumerate(vs)) if n > 1 else vs[0]
        print(f"{site} {port} {s}")

if __name__ == "__main__":
    main(sys.argv[1])
