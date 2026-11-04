# Run inside nextpnr-xilinx (--run): map every PCIE_2_1 input pin to the INT tile wire that drives it.
ports = [l.split() for l in open("pcie_ports.txt")]
bel = ["PCIE_X0Y0/PCIE_2_1"]
out = open("pcie_pinmap.txt", "w")
out.write(f"# bels {bel}\n")
def trace(w, depth=0):
    name = str(w)
    if name.startswith("INT_") or depth > 5:
        return [name]
    res = []
    try:
        pips = list(ctx.getPipsUphill(w))
    except Exception:
        return ["UPHILL_ERR:" + name]
    for pip in pips:
        src = pip.split("->")[0] if "->" in pip else ctx.getPipSrcWire(pip)
        res += trace(src, depth + 1)
    return res
b = bel[0]
for c, base, idx, pin, d in ports:
    if d != "input": continue
    try:
        w = ctx.getBelPinWire(b, pin)
    except Exception as e:
        out.write(f"{b} {pin} ERR {e}\n"); continue
    srcs = trace(w)
    ints = sorted(set(s for s in srcs if s.startswith("INT_")))
    out.write(f"{b} {pin} {str(w)} {' '.join(ints) if ints else 'NO_INT ' + ' '.join(sorted(set(srcs)))[:200]}\n")
out.close()
