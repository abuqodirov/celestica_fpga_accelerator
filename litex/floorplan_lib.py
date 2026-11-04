# Shared by the floorplan_*.py nextpnr --pre-place scripts (exec'd with REGIONS / PREFIXES defined).
# 1. seed: a cell joins a region when a net it drives is named with one of that region's prefixes
#    (after synthesis only registers and a few others keep names);
# 2. propagate: the anonymous logic between them (LUTs, carry chains, ...) joins the region of the cells it is
#    wired to, when all its already-assigned neighbours agree, repeated ROUNDS times (spreads through logic cones).
#    Without step 2 the unnamed logic floats: engine 1's arithmetic landed in channel 0's half, 300 tiles away.
#    High-fanout nets (clocks, resets, enables) are ignored for the propagation.
ROUNDS = globals().get("ROUNDS", 8)
MAX_FANOUT = 32

for r, (x0, y0, x1, y1) in REGIONS.items():
    ctx.createRectangularRegion(r, x0, y0, x1, y1)

assign = {}
for nname, net in ctx.nets:
    n = str(nname)
    region = next((r for r, p in PREFIXES.items() if n.startswith(p)), None)
    if region is None or net.driver.cell is None:
        continue
    assign.setdefault(str(net.driver.cell.name), region)
seeded = len(assign)

nbrs = {}
for nname, net in ctx.nets:
    if net.driver.cell is None:
        continue
    users = [u.cell for u in net.users if u.cell is not None]
    if len(users) > MAX_FANOUT:
        continue
    cells = [str(net.driver.cell.name)] + [str(c.name) for c in users]
    for c in cells:
        s = nbrs.setdefault(c, set())
        s.update(cells)
for c, s in nbrs.items():
    s.discard(c)

for rnd in range(ROUNDS):
    new = {}
    for c, s in nbrs.items():
        if c in assign:
            continue
        regs = {assign[n] for n in s if n in assign}
        if len(regs) == 1:
            new[c] = regs.pop()
    if not new:
        break
    assign.update(new)

counts = {r: 0 for r in REGIONS}
for cname, region in assign.items():
    ctx.constrainCellToRegion(cname, region)
    counts[region] += 1
import json as _json
_json.dump({"regions": REGIONS, "assign": assign}, open("floorplan_assign.json", "w"))
print(f"floorplan: {seeded} seeded + {len(assign) - seeded} propagated cells; per region: {counts}")
