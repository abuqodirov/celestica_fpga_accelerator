# nextpnr-xilinx --post-route script: every port of the named BRAM cells -> net, and the routed source wire
import os
out = open(os.environ.get("BRAM_OUT", "bram_ports.txt"), "w")
want = os.environ.get("BRAM_CELLS", "rx_ram0,rx_ram1,tx_ram0,tx_ram1,snp_rxw.ram,trace_ram").split(",")
for cname, cell in ctx.cells:
    if str(cname) not in want: continue
    out.write(f"CELL {cname} {cell.type} {cell.bel}\n")
    for k, v in cell.params:
        out.write(f"  PARAM {k}={v}\n")
    for pname, port in cell.ports:
        n = port.net.name if port.net is not None else "-"
        out.write(f"  PORT {pname} {port.type} {n}\n")
out.close()
