import os
# (p3: + channel 0's CPU window ddr0_ and BIST) nextpnr-xilinx --pre-place script (+ propagation to unnamed logic, see floorplan_lib.py): floorplan_half.py (each DDR3 channel's logic next to its IO banks) plus a
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
            "tag_mem", "data_mem", "ddr0_", "sdram_generator", "sdram_checker", "basesoc_sdram_"),
    "ch1": ("sdram1_", "ddrphy1_", "ddr1_", "mvacc1_", "mv_engine_1."),
    "core": ("VexRiscv", "basesoc_basesoc_uart", "basesoc_basesoc_timer", "basesoc_basesoc_ram",
             "basesoc_basesoc_basesoc", "basesoc_basesoc_ibus", "basesoc_basesoc_dbus", "basesoc_basesoc_interface",
             "basesoc_basesoc_bus", "basesoc_basesoc_data", "basesoc_basesoc_reset", "basesoc_basesoc_aborted",
             "basesoc_basesoc_word", "basesoc_basesoc_scratch", "selected_r_wishbone2csr", "csr_interconnect",
             "shared_", "slave_sel", "interface0", "jtagloader", "csr_bankarray"),
}

exec(open(os.path.expanduser("~/celestica/litex/floorplan_lib.py")).read())
