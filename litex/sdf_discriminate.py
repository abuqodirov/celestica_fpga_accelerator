#!/usr/bin/env python3
"""Search nextpnr SDF delays for whatever separates failing DDR3 lanes from working ones.

For every DQ/DQS IO cell (OSERDES, ISERDES, IDELAY) of each lane, every routed input delay (clocks included)
is collected per build, plus derived skews: OSERDES CLK - CLKDIV, and per lane DQS-OSERDES CLK - DQ-OSERDES CLK.
Samples: (build, lane) -> "bad" if the lane failed in that build, "good" otherwise. For each feature the script
reports how well a single threshold separates bad from good samples (margin > 0 = perfect separation).
usage: sdf_discriminate.py <yosys json> <lanes 0,1,..,8 (physical, logical order)> "<bad logical lanes per sdf>" \
          s1.sdf:0,1,3 s2.sdf: s3.sdf: ...      (after the colon: the logical lanes that failed in that build)"""
import json
import re
import sys
from collections import defaultdict

unesc = lambda s: re.sub(r"\\(.)", r"\1", s)


def lane_cells(netfile, lanes):
    net = json.load(open(netfile))
    top = next(m for m in net["modules"].values() if any(re.fullmatch(r"ddram\d_dq", p) for p in m.get("ports", {})))
    ch = next(p for p in top["ports"] if re.fullmatch(r"ddram\d_dq", p))[:-3]
    phys2log = {p: i for i, p in enumerate(lanes)}
    pad = {}
    for i, b in enumerate(top["ports"][ch + "_dq"]["bits"]):
        if i // 8 in phys2log: pad[b] = ("dq", phys2log[i // 8])
    for i, b in enumerate(top["ports"][ch + "_dqs_p"]["bits"]):
        if i in phys2log: pad[b] = ("dqs", phys2log[i])
    cells, out, inp = top["cells"], {}, {}
    res = {}
    for n, c in cells.items():
        io = c["connections"].get("IO", [None])[0]
        if c["type"].startswith("IOBUF") and io in pad:
            res[n] = ("IOBUF_" + pad[io][0],) + (pad[io][1],)
            out[c["connections"]["I"][0]] = pad[io]
            if "T" in c["connections"]: out[c["connections"]["T"][0]] = pad[io]
            if "O" in c["connections"]: inp[c["connections"]["O"][0]] = pad[io]
    dly = {}
    for n, c in cells.items():
        if c["type"] == "IDELAYE2" and c["connections"]["IDATAIN"][0] in inp:
            kind, lane = inp[c["connections"]["IDATAIN"][0]]
            res[n] = ("IDELAY_" + kind, lane); dly[c["connections"]["DATAOUT"][0]] = (kind, lane)
    for n, c in cells.items():
        if c["type"] == "OSERDESE2" and c["connections"]["OQ"][0] in out:
            kind, lane = out[c["connections"]["OQ"][0]]; res[n] = ("OSERDES_" + kind, lane)
        if c["type"] == "ISERDESE2" and c["connections"].get("DDLY", [None])[0] in dly:
            kind, lane = dly[c["connections"]["DDLY"][0]]; res[n] = ("ISERDES_" + kind, lane)
    return res


def features(sdf, cells):
    f = defaultdict(list)                     # (feature, lane) -> values (ns)
    for m in re.finditer(r"\(INTERCONNECT\s+(\S+)\s+(\S+)\s+\(([\d.]+):([\d.]+):([\d.]+)\)", open(sdf).read()):
        cell, _, pin = unesc(m.group(2)).rpartition("/")
        if cell in cells:
            kind, lane = cells[cell]
            f[(f"{kind}.{pin}", lane)].append((cell, float(m.group(5)) / 1000))
    out = {}
    for (name, lane), v in f.items():
        vals = [x for _, x in v]
        out[(name + ".max", lane)] = max(vals); out[(name + ".min", lane)] = min(vals)
    for kind in ("OSERDES_dq", "OSERDES_dqs"):    # per-cell CLK - CLKDIV skew
        per = defaultdict(dict)
        for (name, lane), v in f.items():
            if name in (kind + ".CLK", kind + ".CLKDIV"):
                for cell, x in v: per[(lane, cell)][name.rsplit(".", 1)[1]] = x
        lanes = defaultdict(list)
        for (lane, cell), d in per.items():
            if "CLK" in d and "CLKDIV" in d: lanes[lane].append(d["CLK"] - d["CLKDIV"])
        for lane, v in lanes.items():
            out[(kind + ".CLK-CLKDIV.max", lane)] = max(v); out[(kind + ".CLK-CLKDIV.min", lane)] = min(v)
    for lane in {l for (_, l) in out}:
        a, b = out.get(("OSERDES_dqs.CLK.max", lane)), out.get(("OSERDES_dq.CLK.max", lane))
        if a is not None and b is not None:
            out[("DQSclk-DQclk", lane)] = a - b
    return out


def main():
    netfile, lanes = sys.argv[1], [int(x) for x in sys.argv[2].split(",")]
    cells = lane_cells(netfile, lanes)
    samples = []                              # (build, lane, bad, feats)
    for arg in sys.argv[3:]:
        sdf, _, bad = arg.partition(":")
        bad = {int(x) for x in bad.split(",") if x}
        fe = features(sdf, cells)
        for lane in range(len(lanes)):
            samples.append((sdf, lane, lane in bad, {k[0]: v for k, v in fe.items() if k[1] == lane}))
    names = sorted({k for _, _, _, f in samples for k in f})
    ranked = []
    for name in names:
        bad = [f[name] for _, _, b, f in samples if b and name in f]
        good = [f[name] for _, _, b, f in samples if not b and name in f]
        if not bad or not good:
            continue
        hi = min(bad) - max(good)                 # bad all above good
        lo = min(good) - max(bad)                 # bad all below good
        ranked.append((max(hi, lo), name, "bad higher" if hi > lo else "bad lower", min(bad), max(bad), min(good), max(good)))
    ranked.sort(reverse=True)
    nb = sum(1 for s in samples if s[2])
    print(f"{len(cells)} IO cells, {len(samples)} (build, lane) samples, {nb} bad; best separating features:")
    for m, name, d, b0, b1, g0, g1 in ranked[:15]:
        print(f"  margin {m:+6.3f} ns  {name:32s} {d:10s} bad [{b0:6.3f} .. {b1:6.3f}]  good [{g0:6.3f} .. {g1:6.3f}]")


if __name__ == "__main__":
    main()
