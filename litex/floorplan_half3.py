import os
# floorplan_half2.py + a region for the FFN unit (YPCB_FFN, accel/rtl/ffn_unit.v): it takes both engines' result
# streams and writes both engines' activation buffers, so it sits in free fabric right of the engines' regions,
# straddling the boundary between the channel 0 (top) and channel 1 (bottom) halves. Without it (build_dacc12 s1/s2)
# the placer spread the unit over the congested middle and routing did not converge.
REGIONS = {
    "ch0": (0, 200, 160, 416),
    "ch1": (0, 0, 160, 215),
    "ffn": (160, 150, 240, 270),
}
RAW_PREFIXES = {
    "ch0": ("litedramcore0_", "litedramcrossbar0_", "basesoc_litedramnativeport"),
    "ch1": ("litedramcore1_", "litedramcrossbar1_", "litedramnativeport"),
}
PREFIXES = {
    "ch0": ("sdram_", "a7ddrphy", "ddr0_", "mvacc_", "mv_engine."),
    "ch1": ("sdram1_", "ddrphy1_", "ddr1_", "mvacc1_", "mv_engine_1."),
    "ffn": ("ffn_unit.", "ffn_"),
}
ROUNDS = 0
exec(open(os.path.expanduser("~/celestica/litex/floorplan_lib2.py")).read())
