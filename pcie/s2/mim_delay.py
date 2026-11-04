# nextpnr-xilinx --post-route script: routed delay (sum of pip + wire delays, ns) of every arc between the
# PCIE_2_1 cell and the MIM RAMs, walking each route back from the sink pin
import os, collections
out = open(os.environ.get("DELAY_OUT", "mim_delay.txt"), "w")
rams = {"rx_ram0", "rx_ram1", "tx_ram0", "tx_ram1"}
grp = collections.defaultdict(list)
err = []
def dq(x):
    for f in ("maxDelay", "max_delay"):
        if hasattr(x, f):
            v = getattr(x, f); return v() if callable(v) else v
    return float(x)
for nname, net in ctx.nets:
    d = net.driver
    if d.cell is None: continue
    dn, dt = str(d.cell.name), str(d.cell.type)
    users = [u for u in net.users if ("PCIE_2_1" in dt and str(u.cell.name) in rams) or
             (dn in rams and "PCIE_2_1" in str(u.cell.type))]
    if not users: continue
    wires = {str(w): pm.pip for w, pm in net.wires}
    for u in users:
        try:
            w = ctx.getBelPinWire(u.cell.bel, u.port)
            tot, hops, ws = 0.0, 0, str(w)
            while ws in wires and wires[ws] is not None and hops < 60:
                p = wires[ws]
                tot += dq(ctx.getPipDelay(p)) + dq(ctx.getWireDelay(ctx.getPipDstWire(p)))
                ws = str(ctx.getPipSrcWire(p)); hops += 1
        except Exception as e:
            if len(err) < 3: err.append(repr(e))
            tot, hops = -1, -1
        un = str(u.cell.name)
        key = (dn if dn in rams else "PCIE") + "->" + (un if un in rams else "PCIE") + ":" + \
              "".join(c for c in str(u.port) if not c.isdigit())[:14]
        grp[key].append((tot, hops, str(nname)))
        out.write(f"{tot:.3f} {hops} {nname} {dn}.{d.port} -> {un}.{u.port}\n")
for e in err: out.write("#ERR " + e + "\n")
for k in sorted(grp):
    v = sorted(grp[k])
    out.write(f"#{k:32s} n {len(v):3d}  max {v[-1][0]:.3f} ns ({v[-1][2]}, {v[-1][1]} hops)  min {v[0][0]:.3f}\n")
out.close()
