# nextpnr-xilinx --post-route script: for every input of the named BRAM cells, walk the route back from the
# pin and write  cell pin net chain...  (wires from the pin back towards the source) to $BRAM_PINMAP
import os
out = open(os.environ.get("BRAM_PINMAP", "bram_pinmap.txt"), "w")
want = os.environ.get("BRAM_CELLS", "rx_ram0,tx_ram0").split(",")
for cname, cell in ctx.cells:
    if str(cname) not in want: continue
    for pname, port in cell.ports:
        if "IN" not in str(port.type) or port.net is None: continue
        net = port.net
        byname = {str(w): str(pm.pip) for w, pm in net.wires}
        try:
            w = str(ctx.getBelPinWire(cell.bel, pname))
        except Exception as e:
            out.write(f"{cname} {pname} ERR {e}\n"); continue
        chain = [w]
        while w in byname and "->" in byname[w] and len(chain) < 10:
            w = byname[w].split("->")[0]
            chain.append(w)
        out.write(f"{cname} {pname} {net.name} {' '.join(chain)}\n")
out.close()
