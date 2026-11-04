ports = [l.split() for l in open("ports.txt")]
lanes = ["GTXE2_CHANNEL_X0Y%d" % y for y in range(23, 15, -1)]

commons = ["GTXE2_COMMON_X0Y5", "GTXE2_COMMON_X0Y4"]
out = open("pinmap.txt","w")
def trace(w, depth=0):
    name = str(w)
    if name.startswith("INT_R_") or depth > 4:
        return [name]
    res = []
    try:
        pips = list(ctx.getPipsUphill(w))
    except Exception:
        return ["UPHILL_ERR:" + name]
    for pip in pips:
        src = pip.split("->")[0] if "->" in pip else ctx.getPipSrcWire(pip)
        res += trace(src, depth+1)
    return res
for tiles, cell in ((lanes, "GTXE2_CHANNEL"), (commons, "GTXE2_COMMON")):
    for t in tiles:
        bel = t + "/" + cell
        for c, base, idx, pin in ports:
            if c != cell: continue
            try:
                w = ctx.getBelPinWire(bel, pin)
            except Exception as e:
                out.write(f"{t} {pin} ERR {e}\n"); continue
            srcs = trace(w)
            ints = sorted(set(s for s in srcs if s.startswith("INT_R_")))
            out.write(f"{t} {pin} {str(w)} {' '.join(ints) if ints else 'NO_INT ' + ' '.join(sorted(set(srcs)))[:200]}\n")
out.close()
