# Bugs we hit in the open-source tools

Everything on this card was built without Vivado. Along the way we hit a number of problems in the open-source tools.
This page lists each one: what it looked like, what caused it, how we worked around it, and whether it is still
present upstream. The upstream status was checked against each project's current source and issue tracker on
**2026-11-04**.

Our patches are in [`../patches/`](../patches/).

## Summary

| # | Tool | Problem | Effect on this card | Upstream status (2026-11-04) |
|---|---|---|---|---|
| 1 | yosys 0.52 | RAMB36 72-bit SDP parity typo (`== 71`) | JTAG loader FIFO corrupted | **Fixed** (PR #5833, yosys ≥ 0.65) |
| 2 | nextpnr-xilinx | RAMB36 72-bit SDP write width not emitted | Same FIFO, low 36 bits corrupted | **Fixed** in openXC7/nextpnr |
| 3 | nextpnr-xilinx | BRAM output-register clock never connected | PCIe block read zeros from its buffer RAM | **Fixed** in openXC7/nextpnr |
| 4 | nextpnr-xilinx | GT `CPLLREFCLKSEL` disconnected | Transceiver PLLs would never lock | **Still present**; open PR #83 |
| 5 | nextpnr-xilinx | Internal VREF always 0.675 V | Wrong reference for SSTL15 (1.5 V) | **Still present**; related issue #20 |
| 6 | LiteDRAM | tRFC given in DDR3-1600 clocks | Refresh 2.7× too long, ~4 % of memory bandwidth lost | **Still present** |
| 7 | litex-boards | `ypcb_00338_1p1`: wrong PCIe lane-6 pin, no PERST# pull-up, `--toolchain` ignored | PCIe build failed to place | **Fixed** upstream |
| 8 | openFPGALoader | `--read-xadc` refuses Kintex-7 | No temperature/voltage readout | **Not reported** |
| 9 | Project X-Ray | Does not build with GCC 15 | Build failure | Open PR #2556 |
| 10 | prjxray-db | Kintex-7 has no `segbits_gtx_int_interface.db` | GT input delays (hold fixing) impossible | **Not covered** |

Problems we could not pin down to one tool (see [the second list](#problems-we-could-not-pin-down)): shift-register
LUTs giving wrong data, MMCM phase-shifted outputs dead, build-dependent DDR3 lane failures, untimed hard-block
paths, and two missing conveniences (unused-pin pull setting, default ties for GT inputs).

---

## 1. yosys 0.52: RAMB36 72-bit SDP parity inputs swapped

- **Symptom:** our JTAG weight loader (an `AsyncFIFO` 256 × 64 that yosys maps to one RAMB36E1 in 72-bit simple
  dual-port mode) corrupted data: parity-bit positions carried the wrong bits.
- **Cause:** `share/yosys/xilinx/brams_xc6v_map.v`, line 278:
  `.DIPBDIP(PORT_W_WIDTH == 71 ? DIP[7:4] : DIP[3:0])`. The `71` is a typo for `72`, so in 72-bit mode the
  upper parity inputs get the lower parity bits.
- **Fix:** change `71` to `72` ([`patches/yosys-0.52-brams_xc6v_map.diff`](../patches/yosys-0.52-brams_xc6v_map.diff)).
  We used a private copy of yosys's `share/` folder (`litex/env.sh` puts it first on `PATH`).
- **Upstream:** fixed by YosysHQ/yosys PR #5833 (merged April 2026), first released in **yosys 0.65**. Use 0.65 or
  newer; Ubuntu's packaged 0.52 still has the typo.

## 2. nextpnr-xilinx: RAMB36 72-bit SDP write never gets `WRITE_WIDTH_A_18`

- **Symptom:** the same FIFO, after fixing #1: the low 36 bits of every 72-bit write were stored as a repeated
  `DI[1:0]`.
- **Cause:** in a 72-bit SDP write, port A carries half the word, so the A side must be configured 36 bits wide
  (`WRITE_WIDTH_A_18` in prjxray's naming). `fasm.cc` only did this for RAMB18 in 36-bit mode, not for RAMB36 in
  72-bit mode.
- **Fix:** [`patches/nextpnr-xilinx.diff`](../patches/nextpnr-xilinx.diff) (`fasm.cc`).
- **Upstream:** nextpnr-xilinx is archived; its successor openXC7/nextpnr (himbaechel `xilinx` uarch) emits
  `WRITE_WIDTH_A_18` for both cases. Nothing to report.

## 3. nextpnr-xilinx: block-RAM output register is never clocked

- **Symptom:** PCIe link up and stable, but the PC never got answers to configuration reads. Snooping showed the
  PCIe hard block writing the received packets into its buffer RAM correctly, and every read of that RAM returning
  zero.
- **Cause:** when a block RAM uses its output register (`DOA_REG=1` / `DOB_REG=1`), the register has its own clock
  site pins, `REGCLKARDRCLK` / `REGCLKB` (`L`/`U` on a RAMB36). They are not ports of the RAMB36E1 cell, so nextpnr
  never connected them. The register never loads, so reads return the register's initial value (0). Vivado ties
  them to the port's data clock. LiteX designs (no output register) never hit this; the PCIe block's buffer RAMs
  need it (`TL_*_RAM_RDATA_LATENCY = 2`).
- **Fix:** connect those pins to the data clock in `pack.cc` ([`patches/nextpnr-xilinx.diff`](../patches/nextpnr-xilinx.diff)).
  This affects any design with registered BRAM outputs built with the old binary.
- **Upstream:** fixed in openXC7/nextpnr (himbaechel `pack.cc` connects the register clocks). Nothing to report.

## 4. nextpnr: GT packer disconnects `CPLLREFCLKSEL` → CPLL never locks

- **Symptom (caught before loading):** the routed design had no route for `GTXE2_CHANNEL.CPLLREFCLKSEL[2:0]`,
  which we tie to `3'b001` (GTREFCLK0).
- **Cause:** the GT packer removes constant ties from "hardwired clock inputs", recognised by name: anything
  containing `REFCLK` or starting with `QPLL`. `CPLLREFCLKSEL` contains `REFCLK` but is an ordinary fabric input
  (a mux select). Once disconnected, the pins are unrouted, and an unrouted GT input reads **1**, so the select
  becomes `3'b111` = GTGREFCLK and the CPLL never locks. The same rule probably also catches `QPLLREFCLKSEL` on
  `GTXE2_COMMON` (we didn't test that).
- **Fix:** exclude names containing `REFCLKSEL` from that rule (`pack_gt_xc7.cc` in our patch). With it, all 8
  CPLLs lock and the x8 link trains.
- **Upstream:** the same rule is still in openXC7/nextpnr (`himbaechel/uarch/xilinx/pack_io.cc`, `is_refclk_or_qpll_port`).
  Open **PR #83** ("retain GTX reference selector nets and emit fabric input enable", October 2026) addresses it.

## 5. nextpnr: internal VREF is always 0.675 V

- **Symptom:** the DDR3 banks on this card are configured as SSTL15 (as in the factory design), which needs a
  0.75 V reference. nextpnr writes `VREF.V_675_MV` (the SSTL135 value) for every bank that has SSTL inputs.
- **Cause:** `fasm.cc` sets one `vref` flag per bank and always emits `VREF.V_675_MV`; the I/O standard
  (SSTL15 vs SSTL135) is not used to choose the value.
- **Fix:** we patch the FASM after place and route: `sed 's/\.VREF\.V_675_MV$/.VREF.V_750_MV/'` (every build
  script here does it). The factory (Vivado) design uses the external VREF pins instead.
- **Upstream:** unchanged in openXC7/nextpnr (`fasm.cc`, `write_bit("VREF.V_675_MV", ...)`). Related open issue
  **#20** (an XC7K480T DDR3/SSTL15 flow: `INTERNAL_VREF` constraint silently ignored).

## 6. LiteDRAM: MT41J256M16 refresh time far too long below DDR3-1600

- **Symptom:** the accelerator's DRAM stream reached only 84.9 % of the theoretical rate. A cycle-accurate
  simulation (`litex/sim/test_dram_split.py`) traced part of the loss to refresh.
- **Cause:** `litedram/modules.py` gives the MT41J256M16's tRFC in clock cycles per speed grade
  (`tRFC=(208, None)` for "1600", which is also the default). 208 cycles are 260 ns at DDR3-1600, but LiteDRAM
  applies them as cycles at whatever clock the controller actually runs. At DDR3-600 that is 693 ns: each refresh
  blocks the channel 2.7 times longer than needed.
- **Fix:** `litex/ddr3_module.py` defines `MT41J256M16_ns` with tRFC in nanoseconds (350 ns, conservative), used by
  `ypcb_soc.py` (`YPCB_REFRESH_FIX`, default on). Together with refresh postponing (8) the stream went from 84.9 %
  to 88.8 % (with a second, unrelated change the LLM went from 0.36 to 0.33 s per token).
- **Upstream:** unchanged in enjoy-digital/litedram master, and other classes share the pattern: `MT41K256M8`
  (the class matching this card's 2 Gbit x8 chips) gives `tRFC=(128, None)`, which is 160 ns only at DDR3-1600. It
  only costs performance (a longer refresh is still safe).

## 7. litex-boards `ypcb_00338_1p1`: PCIe pin and target problems

- **Symptoms/causes (in the copy we used, commit `8215d8d`):**
  - `pcie_x8` resource: lane 6 RX_N was `E3`; the factory design and the package use `R3`. Our PCIe build failed
    to place until we used our own resource (`ypcb_pcie_x8` in `litex/pcie_bridge.py`).
  - PERST# (`Y26`) had no pull-up.
  - The target ignored `--toolchain` and always used Vivado (`litex/ypcb_soc.py` forces `openxc7`).
- **Upstream:** all fixed in litex-boards master (`R3`, `PULLUP=TRUE` on `rst_n`, standard LiteX argument parser).
  Nothing to report.

## 8. openFPGALoader: XADC readout refused on Kintex-7

- **Symptom:** `openFPGALoader -c digilent_hs3 --read-xadc` prints "read_xadc only supported for Artix 7".
- **Cause:** `src/xilinx.cpp` only allows `ARTIX_FAMILY` and `KINTEXUS_FAMILY`. The 7-series XADC is the same on
  Kintex-7.
- **Fix:** add `KINTEX_FAMILY` to the check ([`patches/openFPGALoader-xadc-kintex7.diff`](../patches/openFPGALoader-xadc-kintex7.diff)).
  On the XC7K480T it returns plausible, stable values (47.5 °C, VCCINT 0.958 V, VCCAUX 1.796 V over a 9-minute
  soak).
- **Upstream:** still Artix/Kintex-UltraScale only; no matching issue or PR.

## 9. Project X-Ray: build fails with GCC 15

- **Cause:** `lib/include/prjxray/memory_mapped_file.h` uses `uint8_t` without `#include <cstdint>`, and the
  build uses `-Werror`, which turns a new GCC 15 warning into an error.
- **Fix:** [`patches/prjxray-gcc15.diff`](../patches/prjxray-gcc15.diff).
- **Upstream:** open PR **#2556** adds the include. Nothing new to report.

## 10. prjxray-db: no GTX_INT_INTERFACE bits for Kintex-7

- **Symptom:** the factory design's bitstream contained 288 bits in the GT column that the database could not
  decode, and our design had no way to set them.
- **Cause:** prjxray fuzzed the GT interface routing only for Artix-7 GTP (`segbits_gtp_int_interface.db`). For
  Kintex-7 the file does not exist, so the `IMUX_DELAY` pips on transceiver inputs (Vivado uses them for hold
  fixing) cannot be used.
- **Fix:** the Artix-7 file, renamed from GTP to GTX, has identical wire lists (342 wires). It decodes all 288
  unknown factory bits, and 288/288 land on inputs driven from the expected neighbouring INT tile (chance level
  would be about 60 %). With it, `pcie/s2/delay_patch.py` adds the same input delays as the factory design
  (309 + 240 delays), and the x8 link is error-free. The file is in
  [`pcie/db/kintex7/segbits_gtx_int_interface.db`](../pcie/db/kintex7/segbits_gtx_int_interface.db).
  Our database overlay also adds two refclk-sharing bits the factory design sets (quad 115 takes its reference
  clock from quad 116); their names (`XF_REFCLK_*`) are placeholders, not understood features.
- **Upstream:** neither openXC7/prjxray-db nor f4pga/prjxray-db has the file; no issue covers it (openXC7/prjxray-db
  PR #4 added Kintex-7 PCIe segbits but not this).

---

## Problems we could not pin down

These were real on our setup, but we never isolated which tool causes them. Before reporting, each needs a minimal
reproduction with the **current** tools (several components have been reworked since).

- **Shift-register LUTs (SRL16E/SRLC32E) give wrong data.** Yosys packed six pass-through bits of a 32-bit JTAG
  register into an SRL; bits 24–30 came back wrong on hardware. With `synth_xilinx -nosrl` it works. Every build
  here uses `-nosrl`.
- **MMCME2 outputs with a non-zero phase are dead.** Any `CLKOUTn_PHASE` ≠ 0 gave no clock (`tests/phase`), while
  PLLE2 phase shifts work (`tests/pllphase`). We use PLLs everywhere. openXC7/nextpnr has since reworked the MMCM
  configuration tables, so this may be fixed.
- **Build-dependent DDR3 lane failures.** About 1 in 10 channel-0 builds and 3 in 7 channel-1 builds lose a group
  of byte lanes (only beats 0–1 of writes, only some bits). The routed delays nextpnr reports do not separate good
  from bad builds. It could be the toolchain (I/O tile routing or configuration) or the board. Workaround: test
  every build (`litex/boottest.sh`) and re-run place and route with another seed (`litex/build_good.sh`).
- **Hard-block paths are untimed.** nextpnr marks `PCIE_2_1` and block-RAM pins `TMG_IGNORE`, so the 250 MHz paths
  between the PCIe block and its buffer RAMs are neither reported nor optimised. Our patch adds env-gated timing
  (`NPNR_HARD_TIMING=1`) with **assumed** clock-to-out/setup numbers, only to measure the routes; not upstreamable
  as is.
- **The timing estimate is very pessimistic on this chip.** Designs estimated at 47 MHz run correctly at 75–80 MHz
  (a factor of 1.6–1.8). Useful only for comparing builds with each other.
- **The PLL/MMCM was placed far from its clock buffers** and routing failed; a BEL constraint next to the clock
  input fixes it (`set_property BEL PLLE2_ADV_X0Y1/PLLE2_ADV ...`).

Missing conveniences, possible feature requests:

- **Unused-pin pull setting.** nextpnr writes nothing for unused pins, which means pull-down. On this board a
  pull-down on some unused pin stops the FPGA from starting (DONE never rises). Vivado's equivalent is
  `BITSTREAM.CONFIG.UNUSEDPIN`. Our `tools/unused_pins.py` adds PULLNONE to every unused pin.
- **Default ties for GT inputs.** An unconnected GTXE2 input is left unrouted and reads 1; Vivado ties it to the
  primitive's default. Every GT input must be tied explicitly in the design (`pcie/s1/s1_top.v`,
  `pcie/core/pcie_x8.v`).
