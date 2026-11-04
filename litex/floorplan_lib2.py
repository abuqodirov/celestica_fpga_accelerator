# Like floorplan_lib.py, but robust to LiteX's naming shuffles (adding a module renamed basesoc_basesoc_uart_* to
# basesoc_uart_*, basesoc_basesoc_sdram_* to basesoc_sdram_*, ...): a net name is matched first against
# RAW_PREFIXES as is (for numbered instances whose channel is known, e.g. litedramcore0 = channel 0), then with all
# leading "basesoc_" removed against PREFIXES. Then the same propagation to unnamed logic as floorplan_lib.py.
# exec'd with REGIONS, RAW_PREFIXES, PREFIXES defined.
ROUNDS = globals().get("ROUNDS", 8)
MAX_FANOUT = 32


def _region_of(n):
    for r, ps in RAW_PREFIXES.items():
        if n.startswith(ps):
            return r
    while n.startswith("basesoc_"):
        n = n[8:]
    for r, ps in PREFIXES.items():
        if n.startswith(ps):
            return r
    return None


for r, (x0, y0, x1, y1) in REGIONS.items():
    ctx.createRectangularRegion(r, x0, y0, x1, y1)

assign = {}
for nname, net in ctx.nets:
    if net.driver.cell is None:
        continue
    region = _region_of(str(nname))
    if region is not None:
        assign.setdefault(str(net.driver.cell.name), region)
seeded = len(assign)
seed_counts = {r: sum(1 for v in assign.values() if v == r) for r in REGIONS}

nbrs = {}
for nname, net in ctx.nets:
    if net.driver.cell is None:
        continue
    users = [u.cell for u in net.users if u.cell is not None]
    if len(users) > MAX_FANOUT:
        continue
    cells = [str(net.driver.cell.name)] + [str(c.name) for c in users]
    for c in cells:
        nbrs.setdefault(c, set()).update(cells)
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

# carry chains are placed as one vertical unit; propagation can split a chain's CARRY4s between two regions and
# then no legal spot exists (p5, non-overlapping regions: "Unable to find legal placement for ...carry4").
# Leave every CARRY4 free - it follows the LUTs around it.
_carry = {str(n) for n, c in ctx.cells if str(c.type) == "CARRY4"}
for c in _carry:
    assign.pop(c, None)

# optional (floorplan_half4.py): hard blocks, clock buffers, PLLs, pads ... keep their own placement rules
_skip = globals().get("SKIP_TYPES", ())
_skip_regions = globals().get("SKIP_REGIONS", tuple(REGIONS))
if _skip:
    for n, c in ctx.cells:
        if assign.get(str(n)) in _skip_regions and (any(k in str(c.type) for k in _skip) or
                                                     "BEL" in [str(k) for k, _ in c.attrs]):
            assign.pop(str(n), None)

counts = {r: 0 for r in REGIONS}
for cname, region in assign.items():
    ctx.constrainCellToRegion(cname, region)
    counts[region] += 1
import json as _json
_json.dump({"regions": REGIONS, "assign": assign}, open("floorplan_assign.json", "w"))
print(f"floorplan: seeded {seed_counts}, after propagation {counts} ({len(_carry)} CARRY4 left free)")
