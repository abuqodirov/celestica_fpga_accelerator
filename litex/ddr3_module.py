"""DDR3 module definition for the YPCB card: LiteDRAM's MT41J256M16 with tRFC in NANOSECONDS.
LiteDRAM gives this part tRFC = 208 clocks of DDR3-1600 (= 260 ns) and converts clocks, not time: at our DDR3-600
(sys 75 MHz, 1:4) that becomes 52 sys clocks = 693 ns per refresh, every 7.8 us - ~9 % of the DRAM time spent idle
(measured with litex/sim/test_dram_split.py: the engines' 84.9 % efficiency is reproduced exactly).
JEDEC tRFC: 2 Gbit 160 ns, 4 Gbit 260 ns, 8 Gbit 350 ns. 350 ns was chosen before we knew the chips, so it is safe even
for 8 Gbit chips: 27 sys clocks at 75 MHz. The card photos (2026-11-04) show SK hynix H5TC2G83FFR = 2 Gbit x8, nine per
channel: tRFC=(None, 160) should free roughly another 2.5 % of DRAM bandwidth (untested, needs a rebuild)."""
from litedram.modules import MT41J256M16, _SpeedgradeTimings


class MT41J256M16_ns(MT41J256M16):
    speedgrade_timings = dict(MT41J256M16.speedgrade_timings)
    speedgrade_timings["default"] = _SpeedgradeTimings(tRP=13.75, tRCD=13.75, tWR=13.75, tRFC=(None, 350),
                                                       tFAW=(None, 40), tRAS=35)
