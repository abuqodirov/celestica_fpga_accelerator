import os
# nextpnr-xilinx --pre-place script (+ propagation to unnamed logic, see floorplan_lib.py) (half-die variant) for YPCB_DUAL (+ YPCB_ACCEL) SoCs: keep each DDR3 channel's logic next to its
# IO banks. Without it the placer scatters a channel's controller over the die (e.g. channel 0's refresher/tFAW
# logic at tile rows 169..317 while its pins are at 263..414), and builds fail the memtest with data errors.
#
# Die grid 327 x 417 tiles; both channels' pins are in column x = 0:
#   channel 0: banks 11-13, rows 263..414      channel 1: banks 16-18, rows 3..154
# A cell goes to a channel's region when a net it drives is named with one of that channel's prefixes (after
# synthesis most cells are anonymous, but the registers keep their nets' names; the placer pulls the
# anonymous logic around them along).
REGIONS = {                     # half the die's width per channel (routable, never hung; see floorplan_dual.py)
    "ch0": (0, 200, 160, 416),
    "ch1": (0, 0, 160, 215),
}
PREFIXES = {
    "ch0": ("basesoc_basesoc_sdram", "basesoc_a7ddrphy", "mvacc_", "mv_engine."),
    "ch1": ("sdram1_", "ddrphy1_", "ddr1_", "mvacc1_", "mv_engine_1."),
}

exec(open(os.path.expanduser("~/celestica/litex/floorplan_lib.py")).read())
