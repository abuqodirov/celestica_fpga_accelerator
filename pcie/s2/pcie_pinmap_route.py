import os
# nextpnr-xilinx --post-route script: for every routed PCIE_2_1 input, walk the route back from the pin and
# record the interface-tile wire (PCIE_INT_INTERFACE_*/..IMUX_OUTk) and the INT tile wire it enters from.
out = open(os.path.expanduser("~/celestica/pcie/s2/pcie_pinmap.txt"), "w")
for cname, cell in ctx.cells:
    if "PCIE_2_1" not in str(cell.type): continue
    out.write(f"# cell {cname} {cell.type} {cell.bel}\n")
    bel = str(cell.bel)
    for pname, port in cell.ports:
        if "IN" not in str(port.type) or port.net is None: continue
        net = port.net
        if net.name in ("$PACKER_GND_NET", "$PACKER_VCC_NET"): pass
        byname = {str(w): str(pm.pip) for w, pm in net.wires}
        try:
            w = str(ctx.getBelPinWire(cell.bel, pname))
        except Exception as e:
            out.write(f"{pname} ERR {e}\n"); continue
        chain = [w]
        while w in byname and byname[w] and "->" in byname[w] and len(chain) < 40:
            w = byname[w].split("->")[0]
            chain.append(w)
        while w in byname and len(chain) < 40:
            p = byname[w]
            if p in ("", "None") or "->" not in p:
                try:
                    w2 = str(ctx.getPipSrcWire(ctx.getPipByName(p)))
                except Exception:
                    break
            else:
                w2 = p.split("->")[0]
            if w2 == w: break
            w = w2; chain.append(w)
        iface = [c for c in chain if "INT_INTERFACE" in c]
        ints = [c for c in chain if c.startswith("INT_L") or c.startswith("INT_R")]
        out.write(f"{pname} {net.name} {' '.join(iface[:2]) or '-'} {ints[0] if ints else '-'} CHAIN {' '.join(chain[:4])}\n")
out.close()
