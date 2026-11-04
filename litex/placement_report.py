# nextpnr-xilinx --pre-route script: report where each block of the SoC was placed and which nets cross the die,
# then stop (no routing). usage: NEXTPNR_EXTRA="--pre-place floorplan_half.py --pre-route placement_report.py"
# Output: <cwd>/placement_report.txt
# Cells are mostly anonymous after synthesis; a cell is attributed to a block by the name of a net it drives.
import json
import os
import traceback
from collections import defaultdict

# nextpnr-xilinx's Python API has no getBelLocation; a bel's name is "<site>/<bel>", and prjxray's tile grid
# (same 327 x 417 grid as nextpnr's x/y) maps every site to its tile's grid position
_TG = json.load(open(os.path.expanduser(
    "~/tools/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7/xc7k480t/tilegrid.json")))
SITE_XY = {site: (t["grid_x"], t["grid_y"]) for t in _TG.values() for site in t.get("sites", {})}

BLOCKS = [                      # (block, net-name prefixes), first match wins
    ("ch0_ctl", ("basesoc_basesoc_sdram", "basesoc_a7ddrphy")),
    ("ch1_ctl", ("sdram1_", "ddrphy1_")),
    ("ch1_win", ("ddr1_",)),
    ("eng0", ("mvacc_", "mv_engine.")),
    ("eng1", ("mvacc1_", "mv_engine_1.")),
    ("l2", ("basesoc_basesoc_l2", "basesoc_basesoc_wb_sdram", "basesoc_basesoc_adr_offset", "basesoc_basesoc_port")),
    ("cpu", ("VexRiscv", "basesoc_vexriscv", "IBusCached", "DBusCached", "dataCache", "IBus", "DBus")),
    ("bus", ("shared_", "slave_sel", "interface", "basesoc_basesoc_basesoc_ram", "basesoc_basesoc_ram")),
    ("csr", ("basesoc_csr", "csr_bankarray", "basesoc_basesoc_csr")),
    ("jtag", ("jtagl", "basesoc_basesoc_uart", "basesoc_uart")),
]


def block_of(name):
    for b, ps in BLOCKS:
        if name.startswith(ps):
            return b
    return None


def loc(cell):
    if cell is None or not cell.bel:
        return None
    return SITE_XY.get(str(cell.bel).split("/")[0])


try:
    owner = {}
    for nname, net in ctx.nets:
        c = net.driver.cell
        if c is None:
            continue
        b = block_of(str(nname))
        if b is not None:
            owner.setdefault(str(c.name), b)

    pos = defaultdict(list)
    for cname, cell in ctx.cells:
        p = loc(cell)
        if p is not None:
            pos[owner.get(str(cname), "other")].append(p)

    out = []
    out.append("block      cells   x min/med/max      y min/med/max")
    for b in [b for b, _ in BLOCKS] + ["other"]:
        ps = pos.get(b)
        if not ps:
            continue
        xs = sorted(p[0] for p in ps); ys = sorted(p[1] for p in ps)
        m = len(ps) // 2
        out.append(f"{b:9s} {len(ps):6d}   {xs[0]:3d}/{xs[m]:3d}/{xs[-1]:3d}        {ys[0]:3d}/{ys[m]:3d}/{ys[-1]:3d}")

    # region compliance (floorplan_lib.py leaves floorplan_assign.json in the working directory)
    if os.path.exists("floorplan_assign.json"):
        fa = json.load(open("floorplan_assign.json"))
        out.append("\nregion compliance (cells placed outside their region, by cell type):")
        for r, (x0, y0, x1, y1) in fa["regions"].items():
            tot, outside = 0, defaultdict(int)
            for cname, cell in ctx.cells:
                if fa["assign"].get(str(cname)) != r:
                    continue
                p = loc(cell)
                if p is None:
                    continue
                tot += 1
                if not (x0 <= p[0] <= x1 and y0 <= p[1] <= y1):
                    outside[str(cell.type)] += 1
            out.append(f"  {r:5s} {tot:6d} cells, outside: {sum(outside.values())} {dict(outside)}")

    # long nets: max driver->user Manhattan distance; global clocks/resets are routed on dedicated wires, skip them
    long_nets = []
    pair = defaultdict(int)
    for nname, net in ctx.nets:
        d = loc(net.driver.cell)
        if d is None:
            continue
        n = str(nname)
        best, far = 0, None
        for u in net.users:
            p = loc(u.cell)
            if p is None:
                continue
            dist = abs(p[0] - d[0]) + abs(p[1] - d[1])
            if dist > best:
                best, far = dist, u.cell
        if best >= 120 and len(net.users) < 2000:
            long_nets.append((best, n, d, loc(far), owner.get(str(net.driver.cell.name), "other"),
                              owner.get(str(far.name), "other"), len(net.users)))
            pair[(owner.get(str(net.driver.cell.name), "other"), owner.get(str(far.name), "other"))] += 1

    long_nets.sort(reverse=True)
    out.append(f"\nnets with driver->user distance >= 120 tiles: {len(long_nets)}")
    out.append("by (driver block -> farthest user block):")
    for (a, b), k in sorted(pair.items(), key=lambda t: -t[1]):
        out.append(f"  {a:9s} -> {b:9s} {k:6d}")
    out.append("\nlongest 60:")
    for best, n, d, f, a, b, nu in long_nets[:60]:
        out.append(f"  {best:4d}  {a}->{b}  {d}->{f}  fanout {nu}  {n[:110]}")

    open("placement_report.txt", "w").write("\n".join(out) + "\n")
    print("\n".join(out[:20]))
except Exception:
    open("placement_report.txt", "w").write(traceback.format_exc())
os._exit(0)
