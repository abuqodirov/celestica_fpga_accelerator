# DDR3 on both channels

The card has two independent DDR3 channels (SK hynix H5TC2G83FFR, 2 Gbit x8; 64 data bits + one ECC byte lane each,
2 GiB per channel; I/O configured as SSTL15, like the factory design, see [board.md](board.md)). Both work with LiteX's LiteDRAM controller and its `A7DDRPHY` (the 7-series high-range-bank PHY, no write
leveling), at a 1:4 clock ratio. Getting there took several fixes, because the first builds failed in ways that
looked like everything from timing to wrong pins.

## The working recipe

`litex/ypcb_soc.py` wraps the litex-boards `ypcb_00338_1p1` target; `litex/build.sh <dir>` builds a CPU + DDR3 SoC
with the defaults below. Options are environment variables (`YPCB_*`, documented at the top of `ypcb_soc.py`).

| Setting | Value | Why |
|---|---|---|
| Clocking | **PLL** CRG (`S7PLL`), not MMCM | MMCM outputs with a phase shift were dead in this flow |
| sys clock | 75 MHz → DDR3-600 (default); 80 MHz → DDR3-640 (LLM design) | see "Speed" below |
| Internal VREF | 0.75 V (half of SSTL15's 1.5 V): FASM fix `VREF.V_675_MV` → `VREF.V_750_MV` | nextpnr always writes 0.675 V (the SSTL135 value) |
| `YPCB_ZIDLE=1` | address/bank = 0 on idle command phases | command/address bus is marginal (below) |
| CK phase | own PLL output, **shifted earlier**: CK 292.5° (at 75 MHz) | DRAMs must sample cmd/addr early |
| DQS phase | 150° (at 75 MHz) | centre of the read-leveling window with 8 lanes |
| Lanes, channel 0 | `YPCB_LANES=0,1,2,3,4,5,6,8` (lane 7 replaced by the ECC lane) | lane 7 never levels |
| Lanes, channel 1 | 0–7 | all fine |
| Refresh | `YPCB_REFRESH_FIX=1`: tRFC 350 ns + refresh postponing 8 | LiteDRAM's tRFC is far too long (below) |
| Unused pins | PULLNONE (`tools/unused_pins.py`) | otherwise the FPGA never starts |
| Build check | `litex/boottest.sh` on every build; re-run place & route with another seed on failure (`build_good.sh`) | some builds lose lanes |

Both channels in one SoC: `YPCB_DUAL=1`. Channel 0 is the CPU's main RAM and is initialised by the BIOS.
Channel 1 has its own controller and a 1 GiB CPU window at `0x80000000` (CSR `ddr1_page` selects which GiB);
**it is initialised from the PC** by `litex/ch1_init.py` (replays LiteX's init sequence through the DFI injector
and read-levels all lanes, 56 s).

Result: BIOS memtest OK, and `litex/bist_full.py` over the **full 2 GiB of each channel, 5 passes, 0 errors**.

## What was wrong (in the order we found it)

1. **No BIOS output at all:** the DQS clock came from an MMCM output with a phase shift, and those are dead in this
   flow. Switching the clock generator to a PLL fixed it.
2. **Wrong reference voltage:** nextpnr writes the SSTL135 value (0.675 V) for every SSTL bank, while SSTL15 needs
   0.75 V. We fix the FASM after place and route.
3. **Writes depended on the DQS phase**: beats were stored as p1, p2, p2, p3 at 90°. A phase sweep (by patching the
   PLL bits in the routed FASM, ~1.5 min per variant, no new place and route) found working read leveling at
   150–165°.
4. **Every read and write went to column 0**, while row addresses worked and hand-driven (DFI injector) accesses
   were perfect. A pad-loopback build (each address pin's output serializer looped back into its input
   deserializer) showed the cause: address bits are read correctly by the DRAMs only if they *rise* in the
   command's own clock slot, and highs collapse about one sample after the edge. LiteDRAM drives the column
   address on two phases, so by the CAS slot it is "old", and the DRAMs read 0. That is a board-level signal
   integrity problem on the command/address bus (the data lines use on-die termination and are fine).
   **Fix:** drive address 0 on idle phases (`YPCB_ZIDLE`) and give CK its own PLL output shifted *earlier*
   (CK 292.5°), so the DRAMs sample sooner after the bus changes; DQS follows. Working window: CK 270–337.5°.
5. **Lane 7 of channel 0 never levels** at any DQS phase. The ECC byte lane (lane 8) works, so channel 0 uses
   lanes 0–6 + 8.
6. **About 1 in 10 channel-0 builds (and 3 in 7 channel-1 builds) lose a group of lanes.** Only beats 0–1 of
   writes are wrong, only some bits, always 1→0, and the result is deterministic per bitstream. Nothing in
   nextpnr's timing model separates good from bad builds, and an "earlier output enable" option did not help
   (sweep of 15 seeds each). **Cause unknown.** Practical rule: test every build with `boottest.sh` and re-run
   place and route with another seed if lanes fail.
7. **The card has no data-mask pins.** Every write stores a whole 64-byte word; byte enables are ignored. Single
   32-bit writes through a narrow path zeroed the other 15 words of the line. CPU windows onto DRAM must go through
   a write-back cache; the accelerator writes whole words.
8. **Channel 0's bank-13 lanes have the least margin.** Re-clocking the same bitstream (PLL bits patched,
   `litex/pll_retime.py`) showed logic margin up to 87.5 MHz, but channel 0's lanes 4–6 drop out at 85 MHz.
   Channel 1 has more margin.

## Speed

| Data rate | sys clock | Result |
|---|---|---|
| DDR3-600 | 75 MHz | default; both channels |
| **DDR3-640** | 80 MHz | the LLM design (`build_pcie4`, PLL patched to 80 MHz); both channels, bit-exact |
| DDR3-667 | 83.33 MHz | memory trains on both channels (CK 270°, DQS 150°), but the big LLM design fails timing at this clock |
| DDR3-800 | 100 MHz | **fails**: at best 4 of 8 lanes level over 13 CK/DQS phase pairs |

To try another frequency without a new place and route, `litex/pll_patch.sh <build> <seed> <D> <M>` rewrites the
main PLL's input divider and multiplier in the finished FASM (200 MHz input; VCO = 200·M/D; sys = VCO/12). The
phases stay the same in degrees. Note that the controller's refresh interval is fixed in clock cycles at build
time, so a slower clock stretches it (4 % at 80 MHz for a design built for 83.33 MHz).

`litex/build_ddrfreq.sh` builds a small DDR3-only SoC at any frequency, and `litex/ddr_phases.sh` sweeps CK/DQS
phase pairs on it by FASM patching.

## Efficiency (how fast the accelerator can stream weights)

At 1:4, LiteDRAM delivers at most one 64-byte word per sys clock per channel. Measured with the accelerator
streaming long runs:

| | Stream efficiency |
|---|---|
| LiteDRAM as is | 84.9 % |
| + tRFC in ns (350 ns) + refresh postponing 8 | 88.8 % |
| + two crossbar ports reading even/odd banks (`accel/litex/dramsplit.py`) | 94.5 %, **but channel 0 computes some rows wrong (unsolved)** |

The two losses, found with a cycle-accurate simulation of the controller (`litex/sim/test_dram_split.py`; keep
simulated memories tiny, see lessons.md):
- **Refresh:** LiteDRAM's `MT41J256M16` gives tRFC as 208 clock cycles (correct only at DDR3-1600); at DDR3-600
  that is 693 ns instead of 260 ns. `litex/ddr3_module.py` gives it in ns: 350 ns, chosen conservatively before we
  had read the chip markings. **Untested idea:** the chips are 2 Gbit, for which JEDEC's tRFC is 160 ns. A rebuild
  with 160 ns should free roughly another 2.5 % of memory bandwidth.
- **Bank changes:** a crossbar port can't move to a new bank while the old bank still has queued commands, which
  costs about 7 cycles per 8 KiB DRAM row. Two ports alternating banks hide it; the version we built works in
  simulation and on channel 1, but gives wrong rows on channel 0 at the start of even blocks. Parked.

With both channels at DDR3-640 and 88.8 %, the card streams about **9 GB/s** of weights.

## Tools

| | |
|---|---|
| `litex/boottest.sh` | load a bitstream, summarise BIOS leveling + memtest (`YPCB_BUILD=<dir>`) |
| `litex/ch1_init.py` | bring up channel 1 from the PC |
| `litex/bist_full.py` | full-memory BIST over JTAG (`BIST_CORE=sdram1` for channel 1) |
| `litex/tap_scan.py --matrix` | per-bit write/read error matrix through the DFI injector |
| `litex/console.py`, `litex/bios.py` | BIOS console / scripted BIOS over the JTAG UART |
| `litex/dram.py` | read/write either channel from the PC (paged windows) |
| `litex/seed_sweep.sh`, `build_good.sh` | place & route seed retry |
| `litex/pll_retime.py`, `pll_patch.sh` | re-clock a finished design without place and route |

**Testing pitfall:** DDR3 keeps its contents across FPGA reloads (mostly). A test that writes the same data to the
same address every run can pass with a broken write path. Always write to a fresh or random location.
