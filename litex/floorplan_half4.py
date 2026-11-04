import os
# floorplan_half3.py + a region for the PCIe logic (YPCB_PCIE, pcie_bridge.py): the TRN bridge, the lane reset /
# TX alignment logic and the clock-crossing FIFOs sit next to the PCIe hard block (PCIE_X0Y0 at grid 279,197), its
# buffer RAMs (BRAM column x 269, rows 187-207) and the GT quads 115/116 (x 309, rows ~107-211), right of the FFN
# region. Hard blocks, clock buffers, PLLs and pads stay unconstrained (SKIP_TYPES), as do LOCed cells (BEL attr).
REGIONS = {
    "ch0": (0, 200, 160, 416),
    "ch1": (0, 0, 160, 215),
    "ffn": (160, 150, 240, 270),
    "pcie": (244, 100, 325, 240),
}
RAW_PREFIXES = {
    "ch0": ("litedramcore0_", "litedramcrossbar0_", "basesoc_litedramnativeport"),
    "ch1": ("litedramcore1_", "litedramcrossbar1_", "litedramnativeport"),
    "pcie": ("pcie_core.", "pcie_trn."),
}
PREFIXES = {
    "ch0": ("sdram_", "a7ddrphy", "ddr0_", "mvacc_", "mv_engine."),
    "ch1": ("sdram1_", "ddrphy1_", "ddr1_", "mvacc1_", "mv_engine_1."),
    "ffn": ("ffn_unit.", "ffn_"),
    "pcie": ("pciebridge", "pcie_"),
}
SKIP_TYPES = ("BUFG", "BUFH", "PLL", "MMCM", "GTX", "PCIE_2_1", "IBUFDS", "PAD", "IOB", "STARTUP", "BSCAN",
              "IDELAY", "OSERDES", "ISERDES", "OLOGIC", "ILOGIC", "PSEUDO")
SKIP_REGIONS = ("pcie",)   # the other regions as in floorplan_half3.py
ROUNDS = 0
exec(open(os.path.expanduser("~/celestica/litex/floorplan_lib2.py")).read())
