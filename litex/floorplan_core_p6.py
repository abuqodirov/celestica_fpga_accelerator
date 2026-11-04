import os
# nextpnr-xilinx --pre-place script for YPCB_DUAL (+ACCEL, BIST, DDR0WIN) SoCs: each DDR3 channel's logic in the
# half of the die next to its IO banks (column x = 0; channel 0 rows 263..414, channel 1 rows 3..154), and a CORE
# region mid-die for the CPU, its bus, the CSR bridge + banks, UART/timer and the JTAG loader, so every CPU access to
# either channel is a short trip. Name matching + propagation: floorplan_lib2.py. Die grid 327 x 417.
REGIONS = {                 # p6: full usable width, overlapping like p4 (p5 without overlap could not place carry chains)
    "ch0": (0, 200, 250, 416),
    "ch1": (0, 0, 250, 215),
    "core": (0, 150, 250, 265),
}
RAW_PREFIXES = {            # numbered LiteDRAM instances (checked against build_dacc6's netlist)
    "ch0": ("litedramcore0_", "litedramcrossbar0_", "basesoc_litedramnativeport"),
    "ch1": ("litedramcore1_", "litedramcrossbar1_", "litedramnativeport"),
}
PREFIXES = {                # after removing leading "basesoc_"
    "ch0": ("sdram_", "a7ddrphy", "ddr0_", "mvacc_", "mv_engine.", "wb_sdram", "port_", "tag_port", "data_port",
            "adr_offset", "l2_"),
    "ch1": ("sdram1_", "ddrphy1_", "ddr1_", "mvacc1_", "mv_engine_1."),
    "core": ("VexRiscv", "uart", "timer", "ram_bus", "basesoc_ram", "cpu_", "ibus", "dbus", "bus_errors",
             "scratch", "reset", "word", "aborted", "selected_r_wishbone2csr", "csr_interconnect", "shared_",
             "slave_sel", "interface0", "jtagloader", "csr_bankarray", "ctrl_"),
}
exec(open(os.path.expanduser("~/celestica/litex/floorplan_lib2.py")).read())
