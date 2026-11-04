# nextpnr-xilinx --post-route script: routed delay of every net that drives an OSERDES T1 pin (the DDR3
# DQ/DQS output enables, BUF tristate mode = untimed), per sink, with the sink's site. Prints lines
#   OE <net> <sink cell> <site> <delay> wires=<wires in the whole net> driver=<cell>@<bel>
for nname, net in ctx.nets:
    users = [u for u in net.users if u.port == "T1" and "OSERDES" in u.cell.type]
    if not users:
        continue
    drv = net.driver.cell
    for u in users:
        site = str(u.cell.bel)
        try:
            d = ctx.getNetinfoRouteDelay(net, u)
            d = getattr(d, "maxDelay", lambda: d)() if not isinstance(d, (int, float)) else d
        except Exception as e:
            d = f"err:{e}"
        print(f"OE {nname} {u.cell.name} {site} {d} wires={len(net.wires)} driver={drv.name}@{drv.bel}", flush=True)
