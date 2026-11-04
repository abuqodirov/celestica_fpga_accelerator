# nextpnr-xilinx --post-route script: dump the full route of every net driven by a PCIE_2_1 output
# (driver pin, every wire with the pip that drives it, every sink) to $ROUTE_OUT.
import os
out = open(os.environ.get("ROUTE_OUT", "routes.txt"), "w")
for nname, net in ctx.nets:
    d = net.driver
    if d.cell is None or "PCIE_2_1" not in str(d.cell.type): continue
    out.write(f"NET {nname} DRV {d.cell.bel} {d.port} {ctx.getBelPinWire(d.cell.bel, d.port)}\n")
    for u in net.users:
        try:
            w = ctx.getBelPinWire(u.cell.bel, u.port)
        except Exception:
            w = "?"
        out.write(f"  USER {u.cell.name} {u.cell.type} {u.cell.bel} {u.port} {w}\n")
    for w, pm in net.wires:
        out.write(f"  W {w} {pm.pip}\n")
out.close()
