import os
# floorplan_half.py (the floorplan of build_dacc4 seed 4, the first dual + 2-engine build to pass) with the
# rename-tolerant name matching of floorplan_lib2.py and NO propagation: only named cells are constrained.
REGIONS = {
    "ch0": (0, 200, 160, 416),
    "ch1": (0, 0, 160, 215),
}
RAW_PREFIXES = {
    "ch0": ("litedramcore0_", "litedramcrossbar0_", "basesoc_litedramnativeport"),
    "ch1": ("litedramcore1_", "litedramcrossbar1_", "litedramnativeport"),
}
PREFIXES = {
    "ch0": ("sdram_", "a7ddrphy", "ddr0_", "mvacc_", "mv_engine."),
    "ch1": ("sdram1_", "ddrphy1_", "ddr1_", "mvacc1_", "mv_engine_1."),
}
ROUNDS = 0
exec(open(os.path.expanduser("~/celestica/litex/floorplan_lib2.py")).read())
