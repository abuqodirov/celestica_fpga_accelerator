#!/usr/bin/env python3
"""Check nextpnr's wire-node model (prjxray tileconn.json applied on the xc7k480t tile grid, exactly as
nextpnr-xilinx's bbaexport/tileconn.py does) against a real routed bitstream (the factory FASM).

For every interconnect pip feature TILE.DST.SRC in the FASM, rebuild the node of SRC@TILE from the tileconn
rules and look for its driver: another pip feature that drives a wire of that node, a site output (LOGIC_OUTS,
...), a constant or a wire that leaves the INT tiles. A source whose node has no driver at all means the model
joins wires that the hardware does not (or misses a join it does) -> counted per source-wire name.
usage: node_check.py design.fasm [tile-filter-regex]"""
import os
import collections, json, re, sys

DB = os.path.expanduser("~/tools/prjxray-db/kintex7")
PART = "xc7k480t"
INT = {"INT_L", "INT_R"}
grid = json.load(open(f"{DB}/{PART}/tilegrid.json"))
by_xy, xy, ttype = {}, {}, {}
for name, t in grid.items():
    by_xy[t["grid_x"], t["grid_y"]] = name
    xy[name] = (t["grid_x"], t["grid_y"])
    ttype[name] = t["type"]
rules = collections.defaultdict(list)       # (tile type, wire) -> [(dx, dy, other type, other wire)]
for e in json.load(open(f"{DB}/{PART}/tileconn.json")):
    t0, t1 = e["tile_types"]; dx, dy = e["grid_deltas"]
    for a, b in e["wire_pairs"]:
        rules[t0, a].append((dx, dy, t1, b))
        rules[t1, b].append((-dx, -dy, t0, a))

def node(tile, wire):
    seen, todo, external = {(tile, wire)}, [(tile, wire)], False
    while todo:
        t, w = todo.pop()
        x, y = xy[t]
        for dx, dy, t2, w2 in rules.get((ttype[t], w), ()):
            n = by_xy.get((x + dx, y + dy))
            if n is None or ttype[n] != t2: continue
            if t2 not in INT: external = True; continue
            if (n, w2) not in seen:
                seen.add((n, w2)); todo.append((n, w2))
    return seen, external

feats = [l.strip().split(".") for l in open(sys.argv[1]) if l.startswith("INT_")]
flt = re.compile(sys.argv[2]) if len(sys.argv) > 2 else None
driven = set((p[0], p[1]) for p in feats if len(p) == 3)
SITE_OUT = re.compile(r"^(LOGIC_OUTS|VCC_WIRE|GND_WIRE|GCLK|CLK_|CTRL|GFAN|BYP_BOUNCE\d|FAN_BOUNCE\d)")
ok = bad = skip = 0
badk = collections.Counter(); okk = collections.Counter(); examples = {}
cache = {}
for p in feats:
    if len(p) != 3: continue
    t, d, s = p
    if flt and not flt.search(t): continue
    if SITE_OUT.match(s): skip += 1; continue
    if (t, s) in driven: ok += 1; okk[s] += 1; continue
    nd, ext = cache.get((t, s)) or node(t, s)
    for m in nd: cache[m] = (nd, ext)
    if ext or any(m in driven for m in nd) or any(SITE_OUT.match(w) for _, w in nd):
        ok += 1; okk[re.sub(r"\d+$", "#", s)] += 1
    else:
        bad += 1; k = re.sub(r"\d+$", "#", s); badk[k] += 1
        examples.setdefault(k, f"{t}.{d}.{s}  node={sorted(nd)[:4]}")
print(f"pip sources checked: {ok + bad} ok {ok}, NO DRIVER IN MODEL {bad}, skipped (site/const) {skip}")
for k, n in badk.most_common(40):
    print(f"  {n:6d}  {k:20s} (ok {okk[k]})   e.g. {examples[k]}")
