# nextpnr-xilinx --pre-place script: floorplan_half.py (each DDR3 channel's logic next to its IO banks) plus a
# CORE region in the middle of the die for the CPU, its bus, the CSR bridge, UART/timer and the JTAG loader.
# Without it the placer put the CPU at the bottom (next to channel 1), so every CPU access to channel 0's L2 cache,
# engine window and CSRs crossed the whole die and back in one clock (24.8 ns of a 13.3 ns cycle).
# See floorplan_half.py for how cells are assigned (by the names of the nets they drive).
REGIONS = {
    "ch0": (0, 200, 160, 416),
    "ch1": (0, 0, 160, 215),
    "core": (40, 150, 200, 265),
}
PREFIXES = {
    "ch0": ("basesoc_basesoc_sdram", "basesoc_a7ddrphy", "mvacc_", "mv_engine.", "litedramcrossbar",
            "basesoc_basesoc_port", "basesoc_basesoc_wb", "basesoc_basesoc_tag", "basesoc_basesoc_adr_offset",
            "tag_mem", "data_mem"),
    "ch1": ("sdram1_", "ddrphy1_", "ddr1_", "mvacc1_", "mv_engine_1."),
    "core": ("VexRiscv", "basesoc_basesoc_uart", "basesoc_basesoc_timer", "basesoc_basesoc_ram",
             "basesoc_basesoc_basesoc", "basesoc_basesoc_ibus", "basesoc_basesoc_dbus", "basesoc_basesoc_interface",
             "basesoc_basesoc_bus", "basesoc_basesoc_data", "basesoc_basesoc_reset", "basesoc_basesoc_aborted",
             "basesoc_basesoc_word", "basesoc_basesoc_scratch", "selected_r_wishbone2csr", "csr_interconnect",
             "shared_", "slave_sel", "interface0", "jtagloader"),
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
print("floorplan_core: constrained cells per region:", counts)
