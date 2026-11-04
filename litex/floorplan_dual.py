# nextpnr-xilinx --pre-place script for YPCB_DUAL (+ YPCB_ACCEL) SoCs: keep each DDR3 channel's logic next to its
# IO banks. Without it the placer scatters a channel's controller over the die (e.g. channel 0's refresher/tFAW
# logic at tile rows 169..317 while its pins are at 263..414), and builds fail the memtest with data errors.
#
# Die grid 327 x 417 tiles; both channels' pins are in column x = 0:
#   channel 0: banks 11-13, rows 263..414      channel 1: banks 16-18, rows 3..154
# A cell goes to a channel's region when a net it drives is named with one of that channel's prefixes (after
# synthesis most cells are anonymous, but the registers keep their nets' names; the placer pulls the
# anonymous logic around them along).
REGIONS = {
    # controller + PHY: a 100-column band beside the channel's banks (one 95-column region holding EVERYTHING of a
    # channel was unroutable; one half-die region per channel left the controller spread over ~200 rows)
    "ch0_ctl": (0, 250, 100, 416),
    "ch1_ctl": (0, 0, 100, 170),
    # matvec engine + its DMA/CSR wrapper (and the ch1 CPU window): next to them, a little wider and taller
    "ch0_eng": (0, 205, 170, 416),
    "ch1_eng": (0, 0, 170, 215),
}
PREFIXES = {
    "ch0_ctl": ("basesoc_basesoc_sdram", "basesoc_a7ddrphy"),
    "ch1_ctl": ("sdram1_", "ddrphy1_"),
    "ch0_eng": ("mvacc_", "mv_engine."),
    "ch1_eng": ("ddr1_", "mvacc1_", "mv_engine_1."),
}

for r, (x0, y0, x1, y1) in REGIONS.items():
    ctx.createRectangularRegion(r, x0, y0, x1, y1)

assign = {}
for nname, net in ctx.nets:
    n = str(nname)
    region = next((r for r, p in PREFIXES.items() if n.startswith(p)), None)
    if region is None or net.driver.cell is None:
        continue
    assign.setdefault(str(net.driver.cell.name), region)

counts = {r: 0 for r in REGIONS}
for cname, region in assign.items():
    ctx.constrainCellToRegion(cname, region)
    counts[region] += 1
print("floorplan_dual: constrained cells per region:", counts)
