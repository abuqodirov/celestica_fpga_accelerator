# nextpnr-xilinx --post-route script: wires+pips of the named nets, only wires whose name contains $NET_FILTER
import os
out = open(os.environ.get("NET_OUT", "nets.txt"), "w")
want = os.environ.get("NETS", "").split(",")
flt = os.environ.get("NET_FILTER", "").split(",")
for nname, net in ctx.nets:
    if str(nname) not in want: continue
    out.write(f"NET {nname}\n")
    for w, pm in net.wires:
        if any(f in str(w) for f in flt):
            out.write(f"  {w} <= {pm.pip}\n")
out.close()
