#!/usr/bin/env python3
"""Routed delay of the DDR3 DQ output-enable to every DQ pin, from nextpnr SDF files.
The DQ OSERDES run their tristate in BUF mode: T1 -> pad driver is untimed, so this delay decides when each
pin starts driving at the beginning of a write.
usage: oe_report.py <yosys json> s1.sdf [s2.sdf ...]"""
import json, re, sys
LANES = [0, 1, 2, 3, 4, 5, 6, 8]                     # logical lane -> physical lane (build.sh YPCB_LANES default)

net = json.load(open(sys.argv[1]))
top = next(m for m in net["modules"].values() if "ddram0_dq" in m.get("ports", {}))
dqbit = {b: i for i, b in enumerate(top["ports"]["ddram0_dq"]["bits"])}
cells = top["cells"]
oq_to_k = {}                                         # OSERDES OQ net bit -> dq index via the IOBUF on that pad
for c in cells.values():
    if c["type"] == "IOBUF" and c["connections"]["IO"][0] in dqbit:
        oq_to_k[c["connections"]["I"][0]] = dqbit[c["connections"]["IO"][0]]
cell_k = {n: oq_to_k[c["connections"]["OQ"][0]] for n, c in cells.items()
          if c["type"] == "OSERDESE2" and c["connections"]["OQ"][0] in oq_to_k}
print(f"{len(cell_k)} DQ OSERDES mapped to dq[0..{max(cell_k.values())}]")
unesc = lambda s: re.sub(r"\\(.)", r"\1", s)
for f in sys.argv[2:]:
    d = {}
    for m in re.finditer(r"\(INTERCONNECT\s+(\S+)\s+(\S+)\s+\(([\d.]+):([\d.]+):([\d.]+)\)", open(f).read()):
        dst = unesc(m.group(2))
        cell, _, pin = dst.rpartition("/")
        if pin == "T1" and cell in cell_k:
            d[cell_k[cell]] = float(m.group(5))               # ps
    print(f"== {f}: {len(d)} DQ enable delays (ns); rows = logical lanes m0..m7, columns = bits 0..7")
    for lane in range(8):
        row = [d[8 * LANES[lane] + b] / 1000 if 8 * LANES[lane] + b in d else None for b in range(8)]
        print(f"  m{lane}: " + " ".join(f"{x:5.2f}" if x is not None else "   ? " for x in row)
              + f"   max {max(x for x in row if x is not None):5.2f}")
