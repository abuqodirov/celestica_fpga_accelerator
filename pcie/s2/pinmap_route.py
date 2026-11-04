# nextpnr-xilinx --post-route script: for every routed input of the PCIE_2_1 and GTXE2_CHANNEL cells, walk the
# route back from the pin; write  bel pin net INT-wire chain...  (the INT tile wire the route enters the pin from).
import os
out = open(os.environ.get("PINMAP_OUT", "pinmap.txt"), "w")
for cname, cell in ctx.cells:
    t = str(cell.type)
    if "PCIE_2_1" not in t and "GTXE2_CHANNEL" not in t: continue
    for pname, port in cell.ports:
        if "IN" not in str(port.type) or port.net is None: continue
        net = port.net
        byname = {str(w): str(pm.pip) for w, pm in net.wires}
        try:
            w = str(ctx.getBelPinWire(cell.bel, pname))
        except Exception as e:
            out.write(f"{cell.bel} {pname} ERR {e}\n"); continue
        chain = [w]
        while w in byname and "->" in byname[w] and len(chain) < 12:
            w = byname[w].split("->")[0]
            chain.append(w)
        ints = [c for c in chain if c.startswith("INT_L") or c.startswith("INT_R")]
        out.write(f"{cell.bel} {pname} {net.name} {ints[0] if ints else '-'} {' '.join(chain[1:4])}\n")
out.close()
