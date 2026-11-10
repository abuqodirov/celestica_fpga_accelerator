# Engineering log

The dated lab notebook of the whole project, as it was written while working (2026-10-05 to 2026-11-04), lightly
cleaned for publication. Paths refer to the original working folder (`~/celestica`, now this repository) and
include build folders and data files that are not in the repository. "The user" is the card's owner; build names
(`build_dacc12`, `build_pcie4`, ...) are local build folders. The organised summaries are in the other docs.


## Hardware
- FPGA: **XC7K480T-2FFG1156I** (JTAG IDCODE 0x23751093, silicon rev 2)
- Cable: Digilent JTAG-HS3 (FT232H, 0403:6014), openFPGALoader cable `digilent_hs3`
- Config mode pins: MODE=0b010 → **Master BPI, x16** (parallel NOR flash)

## Health check — 2026-10-05
Status register (`openFPGALoader -c digilent_hs3 --read-register STAT`) = 0x4107afc:
DONE=1, INIT complete, no CRC error, no ID error, MMCM lock=1, DCI match=1, no over-temp.
→ Factory design loaded cleanly from flash at power-up.

XADC (`openFPGALoader -c digilent_hs3 --read-xadc`, patched build):
| Rail     | Measured | Nominal | DS182 recommended |
|----------|----------|---------|-------------------|
| Temp     | 47.5 °C  | —       | -40..100 °C (I grade) |
| VCCINT   | 0.959 V  | 1.00 V  | 0.97..1.03 V |
| VCCAUX   | 1.796 V  | 1.80 V  | 1.71..1.89 V |
| VCCBRAM  | ~0.958 V | 1.00 V  | 0.97..1.03 V |

VCCINT/VCCBRAM read ~10 mV under the recommended minimum — within XADC error (~±1%),
but confirm with a multimeter at the VCCINT regulator output.

## Toolchain (all in ~/tools, binaries in ~/.local/bin)
- yosys 0.52 (apt) — synthesis (`synth_xilinx -family xc7`)
- nextpnr-xilinx (openXC7, ~/tools/nextpnr-xilinx/build/nextpnr-xilinx)
- chipdb: ~/tools/chipdb/xc7k480tffg1156-2.bin
- prjxray: fasm2frames (python, venv ~/tools/venv), xc7frames2bit (~/tools/prjxray/build/tools)
- openFPGALoader upstream (~/.local/bin) — patched src/xilinx.cpp to allow XADC read on Kintex-7.
  Ubuntu's 0.13.1 does NOT know xc7k480t.
- prjxray build fixes for GCC 15: added `#include <cstdint>` to memory_mapped_file.h, removed -Werror.

## Soak test — 2026-10-05 18:59–19:08 (factory design, fan on)
108 samples / 9 min (`soak/soak_factory.csv`, `tools/soak_monitor.py`): DONE=1, CRC 0, MMCM locked, no over-temp in every sample.
Temp 40.6 → plateau ~47.5 °C after ~4 min (unconfigured idle: 29.4 °C). Rails constant to the mV: VCCINT 0.958, VCCAUX 1.796, VCCBRAM 0.958.
Kernel log: no PCIe errors during 30 min of factory design (18:17–18:47); 2 correctable RxErr at 18:47 caused by our reconfig.

## Gotchas
- Killing a BPI flash dump mid-read leaves the flash unbootable; finish any short `--dump-flash` cleanly (ends with READ_ARRAY + reset) to recover without a power cycle.
- Card is in this PC's PCIe slot (10ee:7028) — never hot-unplug; full power-cycle = PC shutdown.

## !! Open-source bitstreams: unused pins MUST be PULLNONE
nextpnr-xilinx emits nothing for unused IOBs; all-zero IOB bits = PULLDOWN. On this board a pulldown on
some unused pin aborts startup (openFPGALoader shows `init 0 done 0`, STAT settles at 0x4001a0c).
Fix: run `tools/unused_pins.py in.fasm out.fasm` between nextpnr and fasm2frames (Vivado-equivalent of
UNUSEDPIN PULLNONE). Found by bisecting: Vivado design re-encoded via bit2fasm→fasm2frames loads; our
empty design's bits were a strict subset of it; the difference was 354 unused-pin PULLNONE settings.
Load at 30 MHz: `openFPGALoader -c digilent_hs3 --freq 30M x.bit` (~6 s for the 18.7 MB uncompressed .bit).

## calc/ — JTAG calculator (2026-10-05): works on hardware
No board pins needed: clock = STARTUPE2.CFGMCLK (measured 63.64 MHz), I/O = BSCANE2 USER1 (112-bit DR).
Flash control pins (V30 CE, T33 OE, T34 WE, M31 ADV, LVCMOS18) held high so the board can still boot.
`make sim` (Verilator C++ tb, 18,370 vectors, calc.vcd for GTKWave) / `make bit` / `make load` / `make run`
(287 vectors: results + cycle counts identical to simulation) / `make restore` (factory design back).
Host JTAG driver: calc/host/hs3_jtag.py (pyftdi, HS3 pin setup 0x88/0x8B low, 0x20/0x30 high).

## calc/ big-integer multiplier (USER2) — works on hardware
rtl/bigmul.v: 1024x1024-bit (up to 308 decimal digits), 32 parallel 32x32 multipliers (132 DSP48E1),
65 cycles = 1.02 us at 63.4 MHz. `make sim-big` (2004 cases vs decimal-string grade-school reference),
`make run-big` (random 200x200-digit + 300-case batch vs Python), `make run-big A=... B=...`.
Single multiply is NOT faster than the PC (Python 0.34 us; JTAG ~1 ms/op) — speedup needs replication + PCIe.
Timing: whole design est. 70.6 MHz (clk) after splitting calc_core GCD finish into two cycles
(the big design's placement pushed that path to 61 MHz, below CFGMCLK's 63.6 MHz).
- `make restore` (JPROGRAM) sometimes leaves STAT at 0x4001a0c (waiting, BOOTSTS=0) right after one of our
  designs ran; just run `openFPGALoader -c digilent_hs3 -r` again — the second reset booted the factory
  design within 4 s (2026-10-05 evening). Flash contents verified unchanged.

## Where we stopped (2026-10-05) / next session
Board left on the FACTORY design (STAT 0x4107afc). Flash never written.
Next steps, in order:
1. Full flash dump (~1 h): backup of the factory image (required before ever writing flash) + decode the
   factory design (tools/fasm_pins.py) to find LED3/LED6, oscillator, DDR3, PCIe pins.
2. Blink LEDs, switch from CFGMCLK to the board oscillator + MMCM.
3. Stress design + soak monitor to settle VCCINT (0.958 V) / cooling under full load.
4. Then: RISC-V soft CPU (LiteX) / DDR3 (LiteDRAM) / PCIe (LitePCIe).
Open questions for the user: multimeter reading of VCCINT; what the coworker meant by "stops working".

## Pinout (2026-10-07): board = YPCB-00338-1P1 pinout, verified
Master constraints: pins/board.xdc (all pins, commented out). Source: github.com/TiferKing/ypcb_00338_1p1_hack
- JTAG readback of the running factory design (tools/readback.py, 15 MHz, 10.7 s; identical to flash):
  297 used pins = DDR3 ch0 (banks 11-13) + ch1 (16-18) 234 pins, 12 VREF, 45 flash, AA28, AH27/28, G25/26, Y26.
  All match YPCB. Factory design keeps unused pins PULLUP; never drives LED pins.
- Passive scan (pins/scan): AA28 49.998 MHz, AH27/28 199.993 MHz, G25/26 199.993 MHz; R28, N24/N25, P25,
  R26/R27, Y26 idle high. LED pins read LOW with pull-up and pull-down (board pulls them low).
- Blink test (pins/blink, 4 mA): N30 = LED4 yellow (fast), M30 = LED5 (medium), P30 = LED3 (slow);
  LED6 always on (not FPGA). JTAG USER1 16-bit DR: [3]=manual, [2:0]=LED values.
- JTAG READS fail at 30 MHz (one-bit slip); use <= 20 MHz for reads. Writes/loads are fine at 30 MHz.

## Flash backup (2026-10-07) — DONE
backup/flash_full_64MB.bin (64 MiB, sha256 aff61ce2…1546), .xz (4.1 MB), README.txt with content map.
Read by pins/flashdump (own read-only design, WE# tied high, 512-word blocks, 0.88 MiB/s → 73 s).
Verified: = day-one 64 KiB; 1000 random blocks re-read identical; single complete factory bitstream to 17.87 MiB;
rest erased except a board ID record at 0x3FC0000 (contents omitted).
Config data pins are bit-swapped: flash bus word = bit-reverse of the bitstream's 16-bit word.

## !! Toolchain bug: SRL primitives broken → always `synth_xilinx -nosrl`
flashdump's 32-bit USER2 register lost bits 24-30: yosys packed the 6 pass-through bits into an SRL16E;
with -nosrl it works. Earlier designs had no SRLs (parallel-loaded registers). Added -nosrl everywhere.

## minirv on the FPGA (2026-10-07) — PASS
minirv/fpga/: user's CPU (minirv/top.v, untouched; prep_core.py strips DPI-C, adds dbg_a0/dbg_ebreak)
+ SoC (64 KiB BRAM at 0x3000_0000, console 0x1000_0000 + LSR 0x1000_0005, LEDs 0x1000_1000) + JTAG debug port.
50 MHz board clock (timing est. ~85 MHz). Programs: sw/programs.py (own assembler + reference model; minirv has
no branches -> loops via jump tables + jalr). `make sim` = Verilator vs model PASS; `make hw` = FPGA vs Verilator
PASS for hello (92 instr, 362 cycles) and selftest (2079 instr, 6717 cycles, 72 result words); `make leds` runs a
binary LED counter. Block RAM verified working on this board through this flow.
Tools added (no sudo): RISC-V GCC 15.2 ~/tools/riscv/xpack-riscv-none-elf-gcc-15.2.0-1/bin,
OpenOCD 0.12 ~/tools/openocd/xpack-openocd-0.12.0-7/bin (has interface/ftdi/digilent_jtag_hs3.cfg).
GitHub API is rate-limited from this network: use /releases/latest redirects, not api.github.com.

## LiteX bring-up (2026-10-07, user away)
Setup: litex_setup.py --config=standard into ~/tools/venv (+ pip meson); wrappers in ~/tools/bin
(nextpnr-xilinx, xc7frames2bit, fasm2frames); env in litex/env.sh. litex/ypcb_soc.py wraps the
litex-boards ypcb_00338_1p1 target: forces toolchain=openxc7 (upstream target ignores --toolchain ->
Vivado) and swaps the MMCM CRG for an S7PLL CRG. Flow: generate with `--build --no-compile-gateware`, then
gateware/build_fixed.sh (-nosrl, correct chipdb/part names xc7k480tffg1156-2, unused_pins.py, PLL/MMCM BEL pin).
Findings (all measured on hardware):
- Block-RAM INIT contents through the bitstream: correct (tests/diag: 4096/4096 words).
- LUT-RAM (RAM32M/RAM64X1S/RAM128X1S): correct (tests/lutram: 414k passes, 0 errors).
- !! MMCME2 phase shift BROKEN: any non-zero CLKOUTn_PHASE output is dead (tests/phase); phase 0 outputs exact.
  PLLE2 phase shifts run fine (tests/pllphase, 0/45/90/135 deg all toggle). Use PLLs for shifted clocks.
- nextpnr placed the MMCM in the top half while its BUFGs went bottom -> route failure; fix: BEL constraint
  (MMCME2_ADV_X0Y1 / PLLE2_ADV_X0Y1, next to clk200 on bank 12).
- LiteX SoC without DDR3 (build_noddr, 100 MHz despite 82.5 MHz estimate): BIOS boots, memtest OK on 64 KiB
  integrated RAM. Console: litex/console.py (own pyftdi JTAG-UART client, 2-way, --cmd). OpenOCD jtagstream
  bridge gave no data; not needed.

### DDR3 debugging (2026-10-07 afternoon) — channel 0, LiteDRAM A7DDRPHY, 4 of 9 byte lanes
1. First DDR build: BIOS silent. Cause chain: MMCM phase bug killed sys4x_dqs. -> PLL CRG (ypcb_soc.py).
2. nextpnr hard-codes HCLK_IOI3 VREF.V_675_MV (DDR3L) for SSTL banks; this board is 1.5 V DDR3 -> patch FASM
   to VREF.V_750_MV (build_fixed.sh does it now). (Factory/Vivado uses the external VREF pins instead.)
3. MPR read test (sdram_mr_write 3 4, then mem_read): DRAM answers -> CK/cmd/addr/reset OK.
   Manual IDELAY/bitslip sweep under MPR (CSRs: dly_sel 0xf0000804, rdly_rst 0x..814, rdly_inc 0x..818,
   rdly_bitslip_rst 0x..81c, rdly_bitslip 0x..820, wdly_bitslip_rst 0x..824, wdly_bitslip 0x..828):
   all 32 DQ bits have clean 10-13 tap eyes at bitslip 3, overlapping per lane around taps 15-22.
4. Writes depended on DQS phase (sys4x_dqs): 90 deg -> beats stored as p1,p2,p2,p3. FASM-patched PLL
   CLKOUT2 phase sweep (build_pll/gateware/phases/make.sh, ~1.5 min per variant, no re-PnR): at 333 MHz
   read leveling passes lane0/1 at 135, lanes0-2 at 150, ALL FOUR at 165 deg (bitslip 3, delays 18-20 +-4).
5. At 165 deg: bursts are bit-exact, but the controller in hardware mode aliases addresses (col bits 3/8,
   BA1) -> memtest KO. Pins match UCF; sys domain timing est. 72.7 MHz vs 83.33 actual -> rebuilding at
   75 MHz (DDR3-600, VCO 1800, DQS 150 deg ~= same delay; phase steps 7.5 deg at divide 6).
6. 75 MHz rebuild (build_75): timing PASSES (sys est. 90.2 MHz). Read leveling passes ALL 4 lanes for DQS
   142.5-172.5 deg (L0/L2 bitslip 3 delay ~25, L1/L3 bitslip 2 delay ~5). Memtest still KO.
7. Address-bit map (build_75, DQS 157.5, write tag at base+(1<<bit), read back): all addresses inside the first
   4 KiB alias to ONE location (LiteDRAM col bits A3..A9 ignored), while ROW bits A3..A12 work -> the pins are
   fine; READ/WRITE commands are paired with the wrong phase's address (command/address phase misalignment).
   (bits 12-17 of that test were overwritten by my eviction write at 0x40001000-0x40021000 -> redo with eviction
   elsewhere, e.g. 0x50000000.)
NEXT: sweep rdphase/wrphase (CSRs 0xf000082c / 0xf0000830, BIOS sdram_force_rdphase/_wrphase) and inspect
LiteDRAM's DFI command phase (cmd_phase / cmd_latency) vs the A7DDRPHY address OSERDES; compare with a Vivado
reference if needed. Board left on the FACTORY design (STAT 0x4107afc, 37.6 C).

### DDR3 column bug — session 2026-10-08 (NOT fixed yet)
Tools: litex/bios.py (scripted BIOS), dfii_test.py, bist_vs_dfii.py, probe_banks.py, probe_rows.py, slot_map.py,
hw_read_test.py, spy_read.py, window_read.py, padloop_read.py; litex/build.sh <dir> (env YPCB_BIST/SPY/CSNOP/LOOP,
options documented in ypcb_soc.py); sim/ctrl_trace.py, sim/netlist/ (RTL vs gate-level controller sim).
Facts (all measured):
- DFII (hand-driven) access is perfect: every row bit, every column, every phase (command uses its own phase's address).
- Hardware-mode (controller) READ/WRITE always hit COLUMN 0 (bank probably 0 too); ACT rows correct on all bits.
  Same with READ on phase 2 or 3, with or without L2, with CPU or BIST.
- Controller is correct in hardware: dramspy CSRs show the right col/bank/phase at the PHY's DFI input, and the
  3-clock window matches simulation (no 1-clock shift explains the results).
- Ruled out: yosys (gate-level sim == RTL), RAM256X1S/shallow RAM32M (tests/lutram256, tests/lutram8 pass),
  CS held low (YPCB_CSNOP fixes memtest bus errors 64->0 but not columns), OSERDES configs (all 25 pins identical),
  MR0-3 values, CKE/ODT, DFII register leakage (ghost_test).
- Separate small issue: some DFII writes corrupt one byte lane at specific columns (32, 40, 96, 128, ...).
NEXT: build_loop (OSERDES OFB -> ISERDES per pin, BEL-pinned, built OK) — run padloop_read.py to see the
serializer output around a CAS. If col bits are missing there -> toolchain/timing bug in the IOI path;
if present -> board/DRAM-side timing. Nothing physical needed: DFII proves chips and wiring work.

### DDR3 column bug — ROOT CAUSE FOUND (2026-10-08 afternoon)
- Address bits are only read correctly by the DRAMs if they RISE in the command's own slot (pad loopback
  shows highs collapsing ~1 sample after the edge; different chips decode different columns from one
  write). LiteDRAM drives the CAS column on phase 2 AND 3 (choose_cmd/choose_req), so it is "old" by the
  CAS slot -> read as 0 => column 0. ACT works because the row only appears in the ACT slot.
  DFII works because its addresses never change. Board-level signal integrity on the cmd/addr bus
  (VTT/termination?) — DQ uses ODT and is fine.
- Workaround (ypcb_soc.py): YPCB_CSNOP=1 (deselect idle) + YPCB_ZIDLE=1 (address 0 on idle phases)
  + YPCB_CMDGAP=1 (ACT/PRE on phase 1, CAS on 3). build_gap: memtest addr errors 8184 -> ~680/8192,
  data errors ~100% -> ~7%; single-write column tests exact.
- Next: YPCB_CMD_PHASE (PLL CLKOUT4 clocks cmd/addr OSERDES, sweep via build_cmdph/gateware/phases/make.sh
  — run at most 2 fasm2frames in parallel: 10 at once ran the PC out of RAM and killed the session).
- Ruled out along the way: tRCD, tRFC, CS behaviour, RAM256X1S, shallow RAM32M, OSERDES config, MR values,
  CKE/ODT, IOB settings (identical to factory), tristate config, whole-clock skew (YPCB_SKEW).

### DDR3 FIXED — 2026-10-08 18:00 — "Memtest OK"
CK clocked from its own PLL output (YPCB_CK_PHASE, CLKOUT4) shifted EARLIER by 22.5..90 deg, DQS clock
(CLKOUT2) following (DQS = 157.5 - shift): BIOS Memtest OK, BIST 2048 bursts 0 errors, column tests exact.
Tested on build_ck (CSNOP+ZIDLE+CMDGAP+CK_PHASE) variants ck337.5_dqs135, ck315_dqs112.5, ck292.5_dqs90,
ck270_dqs67.5 (build_ck/gateware/phases, make.sh PAIRS="ck:dqs"). Read leveling now uniform (all lanes b02).
Cause: DRAMs sampled cmd/addr too late after the bus changed; earlier CK = earlier sampling.
Minimal fix = YPCB_ZIDLE=1 (address/bank 0 on idle DFI phases) + CK on its own PLL output shifted
earlier (YPCB_CK_PHASE=292.5) with DQS following (YPCB_DQS_PHASE=90). CSNOP/CMDGAP not needed.
Now the DEFAULT in litex/build.sh. build_ddr3 (default build + BIST): Memtest OK, BIST full 1 GiB x 5
passes 0 errors; build_ck 30 passes 0 errors. Working window: CK 337.5..270 deg (DQS = CK - 202.5).
Test tools: bist_full.py [passes] (whole 1 GiB, ~7 s/pass), bist_map.py, seq_test.py.
Gotchas: BIOS sdram_hw_test ignores nonzero origins (tests nothing); BIST needs power-of-two lengths;
DFII helpers must load the same address into all 4 phases (dfii_test.Dfii.issue does now).
Still 4 of 9 byte lanes (1 GiB of channel 0). NEXT: all 8 lanes (2 GiB), then channel 1.

### DDR3 channel 0 at full width: 2 GiB — 2026-10-08 19:00
8 lanes: per-lane DQS windows (CK 292.5): L0/1 60-165, L2/3 75-165, L4/5 120-165, L6 135-165, L7 NEVER
levels (pin mapping suspect, bank 12). Using the ECC chip (lane 8) instead: YPCB_LANES=0,1,2,3,4,5,6,8 with
DQS 150 -> all 8 level (b02), Memtest OK, BIST full 2 GiB x5 passes 0 errors (build_8e). Now the default
in build.sh (main_ram region in the CPU map is still 512 MiB; BIST covers all 2 GiB).
TODO: lane 7 pin check vs factory; channel 1 (second controller); timing estimate ~64-75 MHz.

## NES project (started 2026-10-08 evening) — state at stop
- Core: fpganes (GPLv2, third_party/fpganes; patched copy nes/hw/fpganes: compat primitives renamed,
  MicroCode 'b_ fixed). Games built with cc65 (~/tools/cc65src/bin): nes/roms/thwaite.nes, croom.nes
  (NROM), nova.nes (MMC1 platformer, GPLv3 code / CC BY-NC-SA art).
- Verilator sim works (nes/sim, tb_top.v + tb.cpp; rom2hex.py now writes banked prg0-7/chr0-3.hex —
  sim/obj needs a rebuild after the banking change). Thwaite + Nova run in sim (screenshots in sim/run_*).
- FPGA: nes/hw/nes_top.v + nes_mem.v, nes/fpga/build.sh -> fpga/build/nes.bit BUILT (42 MHz est vs 21.5
  needed, 122 BRAM). Memories banked <=32K deep (nextpnr mis-places cascaded BRAMs); `delete t:$print`.
  NOT yet tested on hardware.
- Host: nes/host/nesjtag.py (USER1 ctrl/buttons, USER2 ROM upload, USER3 frame read), nes_shot.py.
  NEXT: pip install pillow (+ pygame) into ~/tools/venv, run nes_shot.py ../roms/thwaite.nes, then the
  interactive pygame window, then audio (USER4), then ROM library in DDR3 via LiteX.
- Board left on the FACTORY design (openFPGALoader -r) — safe to power off.
- 2026-10-09: NES RUNS ON HARDWARE. Thwaite + Nova playable at ~36 fps via JTAG (nes/host/nes_play.py:
  pygame window, keyboard controller, SOUND). Fixes: JTAG scans >= 4 KiB deadlocked the FT232H (combined
  in/out MPSSE command) -> nesjtag.dr_write uses write-only 0x19, dr_read read-only 0x28 (full speed).
  Audio: APU summed over 487 clocks /512 -> 44.1 kHz ring (4096) -> USER4 (wp + last 2048 samples);
  host keeps only new samples, removes DC, SDL callback with 60 ms prefill: 0 underruns.
  pygame: use pygame-ce (pygame has no py3.14 wheel); pygame.mixer.quit() + init_subsystem(INIT_AUDIO).
  DDR3 NOT used by the NES yet (all in block RAM, 122/955 BRAM) - next: ROM library in DDR3 via LiteX.

## Tiny LLM on the FPGA — WORKS 2026-10-09 13:35
fpgachat (llm/): llama2.c-style char model (dim 128, 4 layers, 0.87M params, Q8_0) trained by
llm/train_chat.py; bare-metal firmware llm/fw (VexRiscv rv32im, soft-float) in DDR3; host llm/chat.py loads
the SoC, streams weights (0x41000000) + firmware (0x40000000) through the JTAG loader (USER2, YPCB_JTAGLOAD),
checks BIOS crc (it flushes L2, so it covers the DDR3 round trip), boots, relays chat over the JTAG UART.
"hi" -> "hello there! how can i help?" at ~420-550 ms/token. Upload 937 KB in 0.5 s.
Run: cd llm && ~/tools/venv/bin/python chat.py   (interactive; --say "hi" for scripted)

### Loader bug = two toolchain bugs in RAMB36 72-bit SDP mode (both fixed)
The loader's AsyncFIFO (256 x 64) maps to one RAMB36E1 SDP x72. Per-entry sys-side log showed bits 0..35
replaced by DI[1:0] replicated per byte, and FIFO bit 44 stuck at addr bit 8.
1. yosys 0.52 /usr/share/yosys/xilinx/brams_xc6v_map.v:278 `.DIPBDIP(PORT_W_WIDTH == 71 ? ...)` — typo for 72:
   upper parity inputs get the lower parity bits. Fixed in a private copy ~/tools/yosys-fix (binary + share/,
   yosys finds share/ next to its binary); litex/env.sh puts it first on PATH. (NES build.sh doesn't source
   env.sh -> still stock yosys.)
2. nextpnr-xilinx fasm.cc write_bram_width: RAMB36 WRITE_WIDTH_B=72 never emitted WRITE_WIDTH_A_18 (only the
   RAMB18 x36 case was handled) -> A-side write path narrow. Patched + rebuilt (old binary kept as
   build/nextpnr-xilinx.pre-ramb36fix).
Only RAMB36 SDP x72 is affected (RAMB18 x36 was already right) — matters for wide accelerator BRAMs.

### DDR3 8 lanes are build-dependent
build_llm (8 lanes, same settings as build_8e): read leveling finds NO window on m6/m7 (lane 6 + ECC lane 8)
at DQS 135/142.5/150/157.5/165 (m4 also drops at >=157.5); data on those lanes shifted one beat. IO-tile
config identical to build_8e (only HCLK track choice differs), IDELAYCTRLs identical. Not solved.
LLM uses build_llm4 (YPCB_LANES=0,1,2,3, 1 GiB): all lanes level, Memtest OK, CRCs OK.
Tools: build_*/gateware/phases/make.sh (PLL phase variants without PnR), phases/boottest.sh (boot log summary).

### DDR3 8-lane failures — investigation 2026-10-09 14:17-15:10 (UNRESOLVED mechanism)
- build_8e (yesterday) still passes today -> hardware fine, failure is build-dependent.
- Unfixed LLM SoC (build_llm) seeds 1-5 (litex/seed_sweep.sh): seed 1 FAILS (m6/m7 no read window), 2-5 pass.
- Signature (litex/tap_scan.py --matrix 8 [--xor 0xa5], DFII, static write data): only a few DQ bits wrong and
  only in beats 0-1 of each write (seed 1: m6 bit1, m7 bit0/bit7, once m4 bit4); errors follow the stored beat
  when the read tap moves -> write side; static data -> suspected late DQ output enable (OSERDES TQ "BUF").
- Fix candidate YPCB_DQOE_EARLY=1 (ypcb_soc.py: DQ T1 = ~(tap0|tap1), enable one sys cycle earlier):
  build_llm8 seeds 1-5 all pass; LLM 923 KB CRC OK on 8 lanes. NOT default in build.sh yet.
- BUT nextpnr SDF delays (oe_report.py on seeds/s*.sdf; seed 1 re-run FASM byte-identical) show the failing
  pins' enable routes are NOT longer in seed 1 (1.0-1.7 ns) than in passing seeds (0.8-3.1 ns). Mechanism
  unproven; 5/5 fixed passes could be luck (~1/3) given 4/5 unfixed pass.
- NEXT options given to user: (1) keep fix + DDR3 check after every build (boottest + matrix), reseed on fail;
  (2) ~10 more seeds fixed/unfixed for statistics; (3) inspect seed-1 routing of failing pins. Then 2 GiB BIST.

## 2026-10-10
### DDR3 channel 0, 8 lanes + YPCB_DQOE_EARLY: 2 GiB BIST x5 passes, 0 errors (build_8f)
All 8 lanes level (same delays as build_8e), BIOS memtest OK, bist_full.py 5 0x80000000: 5 x 2047.97 MiB,
0 burst errors. Statistics sweep (seeds 6-15, unfixed vs fixed) -> litex/sweep_results.txt
(litex/boottest.sh: [YPCB_BUILD=dir] boottest.sh x.bit ... = leveling + memtest summary per bitstream).

### Goal: MustaqiLLM (NeuronUz/MustaqiLLM, Apache-2.0) on the FPGA
5.167B params, 36 layers, dim 3584, 28 q heads / 4 KV heads (head 128, GQA 7:1), QK-norm (RMSNorm per head,
before RoPE), RoPE adjacent pairs theta 5e5, SwiGLU 9728 (fused gate_up: gate = first half), pre-norm RMSNorm
eps 1e-5, no biases, untied lm_head, vocab 48000 BPE, ChatML (<|im_start|>=4, <|im_end|>=5), ctx 4096.
Weights bf16 (embeddings/lm_head/norms f32), 11 GB file in mustaqi/hf (downloaded data, don't execute its .py).
Card: chat with t=0.7 top_p=0.9 repetition_penalty 1.05-1.10, no system prompt; greedy repeats.
Budget: bf16 10.3 GB / int8 ~5.5 GB do NOT fit the card's 4 GiB; int4 ~2.9 GB (+0.3 GB KV fp16 @4096)
fits only with BOTH DDR3 channels. Bandwidth-bound: ~2.8 GB read per token -> ~2 tok/s ceiling at the
current 600 MT/s on 2 channels. Plan: A PC reference + 4-bit quality (mustaqi/ref.py), B channel 1,
C matvec accelerator (prove on fpgachat), D norms/softmax/SiLU/RoPE in HW, E mid-size model, F 5B.
**12:05 CORRECTION: YPCB_DQOE_EARLY does NOT fix the 8-lane failure.** Sweep: fixed build_llm8 seed 9 fails with the
same signature (m6/m7 no read window, Memtest KO). Tally so far: unfixed 1/9 fail (seed 1), fixed 1/9 fail (seed 9).
Consistent with the SDF data (enable route delay doesn't correlate). Root cause unknown; practical rule: run
boottest.sh on every 8-lane build and re-run place & route with another seed if m6/m7 fail.
**Final sweep (litex/sweep_results.txt, seeds 1-15 each):** unfixed 1/15 fail, YPCB_DQOE_EARLY 2/15 fail -> the
option does not help (documented as such in ypcb_soc.py). ~10% of 8-lane builds lose m6/m7, cause unknown.
RULE: every 8-lane build gets `YPCB_BUILD=<dir> litex/boottest.sh <bit>`; on m6/m7 failure re-run place & route
with another seed (litex/seed_sweep.sh <dir> <seed>).

### MustaqiLLM step A done (2026-10-10)
- mustaqi/ref.py: torch reference from the model code (memory-mapped, one matrix at a time). bf16 ppl 8.757 on
  eval_uz.txt (238 tok). Quantization (mustaqi/quant_results.txt): q8 = lossless (KL 1e-4); q4 sym g32 +19% ppl;
  **q4 asym g32 (scale+offset per 32) ppl 8.98 (+2.5%), top-1 90.3%** <- chosen; clip search no gain; g128 +12%.
- Format Q4A (export_q4a.py -> out/mustaqi_q4a.bin, 3.23 GiB incl. 0.32 GiB fp16 embeddings): per 32 weights
  fp16 scale, fp16 offset, 16 B nibbles = 20 B (5 bits/w). Hardware dot per group: s*sx*sum(q*xq) + lo*sx*sum(xq)
  with int8 activations per 32 (the sum(xq) term is shared by all rows).
- mustaqi/c/mustaqi.c: golden C reference (int8 activations, Q4A weights, AVX2 + plain C). ppl 8.985 (plain C
  8.997). Model-card test (greedy "O'zbekistonning poytaxti qaysi shahar?") -> "Oʻzbekistonning poytaxti -
  Toshkent." exactly. Chat: mustaqi/run_c.py "..." -> fluent, factual Uzbek. PC speed 11.5 tok/s (6 threads,
  ~33 GB/s = RAM-bandwidth bound). Model file sha256 verified (HF commit b2e14ee).
- NEXT: B = DDR3 channel 1 (needed for the 3 GB of weights), C = matvec accelerator.

### DDR3 channel 1 brought up (2026-10-10 afternoon)
- Pins: all 117 ch1 pins (banks 16-18) match the factory readback (pins/factory_pins.txt) incl. direction; DQ in
  their DQS byte groups. YPCB_DRAM_CHANNEL=1 (ypcb_soc.py). Same PLL/clocks/CK 292.5/DQS 150 as ch0.
- build_c1 (8 lanes 0-7, BIST): seeds 2,3,5,6 = all 8 lanes level (b02, wide +-8..9 taps), Memtest OK;
  seeds 1,4,7 = bank-16 lanes m0,m1,m3 dead (always together) -> 3/7 builds fail (ch0: ~1/10). sweep_c1.txt
- Same signature as ch0 (tap_scan --matrix): only beats 0-1 of writes wrong, only some bits, always 1 -> 0.
- Deterministic per bitstream: 5x sdram_init (includes PHY/SERDES reset) -> identical results (litex/reinit_test.py).
- Ruled out: DQS phase (60..240 on seed 1: bank 16 never levels), IDELAYCTRL/VREF (present per bank), OSERDES TQ
  mode (all BUF), clock assignment (litex/clock_map.py: every lane G2/G0/G3 identical), and EVERY nextpnr-modelled
  routed delay into the IO cells incl. clocks/enables/resets (litex/sdf_discriminate.py over ch0 seeds 1-5 and
  ch1 seeds 1-7: best separating margin 0). Cause is not visible in nextpnr's timing model.

### BOTH DDR3 channels in one SoC: 4 GiB, 0 errors (2026-10-10 ~14:10)
- YPCB_DUAL=1 (ypcb_soc.py): ch0 = main RAM (BIOS init) + ch1 = ddrphy1/sdram1 core, 1 GiB CPU window at
  0x80000000 (CSR ddr1_page picks the GiB), BIST on both. Built with litex/build_good.sh (seed retry: seed 1
  lost ch0 m4/m6/m7, seed 2 good). Channel 1 initialised from the host: litex/ch1_init.py (replays the generated
  init_sequence via sdram1 DFII + read leveling of all lanes at once; 56 s; same delays the BIOS finds on ch1).
- bist_full.py 5 0x80000000 on BOTH (BIST_CORE=sdram / sdram1): 5 x 2048 MiB each, 0 burst errors.
- Board quirk: NO DDR3 DM pins -> every native-port write stores the whole 64-byte word (byte enables ignored).
  Single 32-bit writes through a narrow path zeroed the other 15 words of the line (seen through the first,
  uncached ch1 window). Fix: window goes through an 8 KiB write-back cache (like main RAM's L2). RULE for the
  accelerator / any DRAM writer: write whole 64-byte words (or read-modify-write).
- fasm2frames "invalid word address 101" warnings (108/build) are all LIOB33_SING tiles of UNUSED pins
  (PULLNONE dropped) - harmless.

### Timing-margin test (2026-10-10 16:00): same bitstream at 75/80/85/87.5 MHz (litex/pll_retime.py, margin_test.sh)
pll_retime.py re-encodes only the PLL (bits made by nextpnr from a 1-PLL design at the same BEL, ZINV_* kept from
the original; the 75 MHz re-encode reproduces the original bits exactly) -> identical placement/routing.
Results (litex/margin_results.txt):
- Fabric logic has real margin: build_dual s5 (nextpnr Fmax estimate 53.9 MHz!) passes 2 GiB BIST on BOTH channels
  at 80 MHz and channel 1 at 87.5 MHz. nextpnr-xilinx's Fmax estimate is very pessimistic (>=1.6x) - not useful.
- Channel 0's bank-13 lanes (m4..m7) are the I/O weak spot: in EVERY ch0 build m5/m6 (then m4) drop out at 85 MHz,
  windows shrink 75->80 MHz from +-6 to +-4/5 (fly-by / DQS window, board level, not build-dependent).
- Channel 1 has far more I/O margin: good builds pass at 87.5 MHz with +-7 windows on every lane.
- Build-dependent dead lane groups do NOT change with frequency (ch1 s1 bank 16 dead at all clocks; ch0 s1 m6/m7
  dead at all clocks) -> not a slow logic path; still unexplained. build_good.sh remains the way.
- Keep 75 MHz (ch0 margin at 80 MHz is only +-4..5 taps).

### Hardware arithmetic + bits-per-weight study (2026-10-10 evening)
- Golden model (mustaqi/c/mustaqi.c, default = FPGA arithmetic, -legacy = old): MXINT8 activations (int8, one
  power-of-two scale per 32, round-half-even), fp16 s/lo split exactly into int mantissa*2^exp, per group
  (m_s*D)<<(E_s+e) + (m_lo*S)<<(E_lo+e) into int64 with 30 fractional bits, one int64->fp32 rounding per output.
  ppl 8.966 (legacy float 8.985) -> no quality cost; card test (capital) passes.
- Bits/weight (ref.py eval, asym = fp16 scale+offset, RTN): 4b g32 (5.0 b/w) KL 0.020 | 4b g64 (4.5) KL 0.024 |
  4b g128 (4.25) KL 0.028, top1 90.3% | 3b g32 (4.0) KL 0.088, top1 80% | 3b g64 (3.5) KL 0.12 | 2b g32 (3.0) ppl 47.
  -> 4-bit with weight groups of 128 = 1.18x fewer bytes than g32 at small cost; 3-bit needs GPTQ-class methods.
- Speed levers discussed with user: bytes/token (bits), DDR3 clock (+10-25%), tokens per weight pass (prefill,
  speculative decoding needs a draft model). Engine to be built batch-capable (several x vectors per weight pass).

### Accelerator: state at end of 2026-10-10
- Spec: accel/golden/golden.h (header-only C, bit-exact): Q4H weights (groups of 128, fp16 scale+offset, 4-bit codes;
  row = ceil(NG/16) scale words + NG code words of 64 B), MXINT8 activations (per 32: e in [-64,63], a in +-127,
  S = sum a), int64 accumulator 2^-30 units, one RNE rounding to float32. Includes q4h_quantize_row.
- RTL: accel/rtl/mv_engine.v (B vectors per weight pass, one 64 B word/clock, 8-stage pipeline P1..P8, activation
  buffer write port, results r_valid/r_row/r_data). Written + stage alignment checked by hand; verilator lint shows
  only width warnings (to clean). NOT yet simulated.
- NEXT: lint cleanup, Verilator testbench linking golden.h (random + real MustaqiLLM rows, valid gaps, B=1 and 4),
  then LiteX wrapper with LiteDRAM DMA reader per channel. Board left on the factory design.

### MATVEC ENGINE WORKS ON THE FPGA (2026-10-10 17:15)
- Simulation (accel/sim, Verilator + golden.h): 80 random runs (K 128..10240, 3-15 rows, 0-50% stream gaps,
  B=1 and B=4) + real MustaqiLLM rows (layer-0 qkv, down_proj K=9728 with outliers): all bit-exact. A mutant
  (nibble decode bug) is caught, so the comparison is real.
- LiteX: accel/litex/mvaccel.py (LiteDRAMDMAReader -> mv_engine, CSRs mvacc_*, window 0xC0000000), option
  YPCB_ACCEL=B in ypcb_soc.py. build_acc (ch0 8 lanes + JTAG loader + engine B=1): seed 1 good.
- accel/host/acc_test.py prep/run: layer-0 qkv_proj, 4608 rows x 3584 (8.85 MB Q4H, uploaded over JTAG in 6.6 s,
  CRC OK) -> ALL 4608 RESULTS BIT-EXACT vs golden, 162787 cycles = 2.17 ms = 4.08 GB/s (84.9% of 64 B/clock).
  accel/golden/q4h_tool.c prepares DRAM image + activation image + expected results with golden.h.
- Projection: 2 channels x 4.08 GB/s, 2.65 GB Q4H per token -> ~3.1 tok/s for the matmuls.
- Dual + 2 engines (build_dacc, YPCB_DUAL+JTAGLOAD+ACCEL): seeds 1,2 rejected - ch0 levels all 8 lanes but memtest
  has partial data errors (3.6%). nextpnr critical path (39 MHz est.) runs through CH0's DRAM controller (zqcs timer
  -> refresher -> tfawcon) with 5.2 ns cross-die wires: placer scatters controller logic over the die. Robust fix =
  floorplan: nextpnr supports regions from a --pre-place python script (ctx.createRectangularRegion(name,x0,y0,x1,y1),
  ctx.constrainCellToRegion(cell, name); used internally in xilinx/pack.cc). Keep each channel's controller+PHY logic
  next to its banks (ch0 banks 11-13, ch1 banks 16-18), each engine next to its channel. Need nextpnr x/y of the banks.
- KV-cache storage formats (mustaqi.c -kv, eval_long.txt 2215 tokens, mostly model-written Uzbek): float32 ppl 3.269,
  MXINT8 per 32 3.272 (+0.1%), 4-bit asym per 128-value head with fp16 scale/offset (Q4H-like) 3.290 (+0.6%).
  -> either format is fine; 4-bit lets attention reuse the matvec engine.
- Engine DSP finding: the 4b x 8b products written with '*' became one DSP48 each (276 DSPs in the dual design),
  scattering both engines over the DSP columns. Rewritten as shift-and-add (qmul in mv_engine.v): 20 DSPs total
  (8 per engine for the 12x18 scale products + 4 CPU). Re-verified: 80 random + real-data runs bit-exact.
- Floorplan (litex/floorplan_dual.py via NEXTPNR_EXTRA="--pre-place ..." in build_fixed.sh / seed_sweep.sh):
  95-column strips next to the pins -> router2 failed (47 overused wires, congestion at the PHY bitslip logic).
  Now half-die regions: ch0 x0-160 y200-416, ch1 x0-160 y0-215 (~10k cells each constrained).
- build_good.sh SKIP_BUILD=1 reuses the synthesized netlist (all seeds via seed_sweep.sh).
- 2026-10-10 evening: 4-VECTOR ENGINE ON THE FPGA (build_acc4, YPCB_ACCEL=4, no floorplan): layer-0 qkv, 4608 rows x
  4 real tokens = 18432 results BIT-EXACT, 4.08 GB/s (acc_test.py run --vecs 4; data/qkv4.*). BUT the CPU side was
  flaky in that build: BIOS crc of the (correct) weights differs run to run. nextpnr Fmax est 36.5 MHz (B=1 build:
  48.9 MHz, solid). Real silicon ~1.6x the estimate -> <~47 MHz estimate = trouble. Critical path = ch0 DRAM controller
  (zqcs timer/refresher) with 6.3 + 5.3 ns wires across 150+ columns: the scattered-controller problem also hits
  single-channel builds once they grow -> use the floorplan (NEXTPNR_EXTRA="--pre-place .../floorplan_dual.py";
  ch1 prefixes match nothing on single-channel builds) for every engine build.
- Dual build_dacc2 (floorplan, seed 1): ch0 engine BIT-EXACT alone AND while ch1 streams 512 MiB; ch1 engine wrong.
  Cause: _DDR1Window's wishbone.Cache defaulted to reverse=True -> every 64 B line stored word-reversed in DRAM
  (invisible through the cache; seen by DFII peek and by the engine: one-hot probes returned other weights of the
  row). Fixed (reverse=False like main RAM's L2). Tools: accel/host/dual_test.py, ch1_debug.py, ch1_lanes.py, ch1_peek.py.
- build_dacc3 (floorplan + window fix, seed 1): ch1 engine BIT-EXACT (alone + loaded) -> cache fix confirmed; but ch0
  engine 286..1305 random mismatches (varies per run) + CPU crc of ch1 upload flaky: TIMING (est. 41 MHz, critical
  path = ch0 controller zqcs/refresher -> bankmachine, 21.5 of 24 ns routing, spread inside the big region).
- accel/host/engine_selftest.py: per engine 512 qkv rows, CPU crc x2 + engine run x2 bit-exact; build_good.sh
  CHECK=<script> adds it to the seed acceptance. build_acc4f (floorplanned B=4 single channel): PASS.
- Engine v2 (accel/rtl/mv_engine.v, v1 backup in session scratch): +input register, registered buffer address,
  accumulate split (sum of 4 | +acc), float conversion split (leading one | normalize | round). Same arithmetic:
  80 random + real-data sims bit-exact (B=1, B=4).
- floorplan_dual.py v3: per-block regions: ctl (controller+PHY) x0-100 beside the banks, eng (engine, wrapper,
  ch1 window) x0-170 slightly taller. build_dacc4 = dual + engine v2 + this floorplan + CHECK.
- 2026-10-10 19:06-22:56 LOST: build_dacc4 seed 1 rejected (all lanes level, memtest KO; est. 40.3 MHz), seed 2's
  nextpnr hung in the SA refinement placer (iteration #1 for 3.5 h, with the per-block floorplan regions). No timeout
  existed -> now `timeout 2400` on nextpnr in build_fixed.sh (master copy) and seed_sweep.sh.
- 23:00-23:15 overnight sweep (night_sweep.sh, build_dacc4 netlist, floorplan_half.py) KILLED by the desktop session's memory
  reaper before any seed was tested: 2 parallel nextpnr + fasm2frames PLUS the C-model ppl runs (3.2 GB mmap each)
  exhausted RAM (swap in use). RULE: at most 2 heavy jobs in total, and the C model / ref.py count as heavy jobs.
- -hwmath (C model): exp via 64-entry table + linear interpolation, 8-way interleaved fp32 sums (RMSNorm, softmax):
  ppl 3.272 vs 3.269 exact (eval_long, KV f32) -> cheap vector-unit math is fine.
- 23:25 asked the user (Remote Control) whether to restart the reaped sweep; answered "[No preference]" at 08:59,
  after the 10-hour window -> not restarted. night_sweep.sh now: one seed at a time + 7 GB free-RAM guard.
  -hwmath + -kv q4: ppl 3.290 (same as q4 alone). REPORT.md written (overnight report). FPGA on factory design.

## 2026-10-17: memory first (user: "we need the whole 4gb"; LLM work paused)
- build_dual s5 (dual channel, no engines) re-tested after a week off: identical leveling to 10-10, memtest OK,
  2 GiB BIST 0 errors on each channel (margin_test.sh build_dual 5 75).
- litex/bist_both.py: BIST on BOTH channels simultaneously (write together, check together), whole 2 GiB each,
  alternating random / counter data: 6 passes (24 GiB written+checked) 0 errors, 22 s per pass.
- litex/bist_addr.py: high address-bit aliasing test (bits 20..30, stuck-0 and stuck-1; block BIST is blind to
  it because every block restarts the same data) + positive control (2 GiB wraps to 0, must fail: detected,
  16384/16384 bursts). Both channels: ALL OK -> 4 GiB is real and unique.
- placement_report.py (--pre-route hook, places then stops): where each SoC block lands + nets crossing the die.
- build_dacc5 = build_dacc4 netlist (dual + 2 engines B=1, engine v2) placed with floorplan_core_p2.py: CPU/bus/CSR/
  UART/JTAG loader in a "core" region mid-die (40,150)-(200,265) + unnamed logic propagated to regions
  (floorplan_lib.py). Placement-only trials (place_try.sh, ~4 min): est. 39.1 (floorplan_half) -> 34.5 (core, no
  propagation) -> 40.7 (core + propagation) -> 44.0 MHz (+ CSR banks in core). Region compliance ~1-2% outside.
- build_dacc4 seeds 3/4 (floorplan_half.py, routed by the 10-10 overnight sweep before it was killed; frames never
  generated) -> bitstreams made today, full_check.sh (new: ch0 lanes+memtest, ch1 init, engine selftest, bist_both,
  bist_addr): s3 (est 46.0 MHz) memtest KO (12/524288 data errors, all lanes level); **s4 (est 47.8 MHz):
  ch0+ch1 all lanes, memtest OK, engine selftest PASS (both engines bit-exact x2, CPU crc x2)** = first dual +
  2-engine build to pass. dacc4 has no BIST cores, so no 2 GiB hardware test on it.
- FOUND: CPU map of the dual SoCs = MAIN_RAM 512 MiB (ch0's first quarter only) + DDR1 window 1 GiB x 2 pages.
  The JTAG loader is a wishbone master on that map -> 1.5 GiB of channel 0 unreachable for CPU/loader (engines'
  DMA reaches all). New YPCB_DDR0WIN=1: 256 MiB window at 0xD0000000, CSR ddr0_page 0..7 (_DDR1Window
  generalised: win_bits, page_bits).
- build_dacc6 = YPCB_DUAL JTAGLOAD ACCEL=1 BIST DDR0WIN + floorplan_core_p3.py (started 15:08).
- dacc4 s4 CPU memtest (BIOS mem_test, unique LFSR data): ch0 512 MiB OK (144 s), ch1 page 0 + page 1 (1 GiB
  each) OK (~295 s each). Installed as build_dacc4's good bitstream (good_seed.txt = 4; seed 1 kept as _s1).
- build_dacc6 netlist renames (adding BIST): basesoc_basesoc_sdram_* -> basesoc_sdram_*, basesoc_basesoc_uart ->
  basesoc_uart, numbered litedramcore0/1, litedramcrossbar0/1 (0 = ch0), basesoc_litedramnativeport* = ch0,
  litedramnativeport* = ch1. floorplan_lib2.py strips leading basesoc_ + raw prefixes for numbered ones;
  floorplan_core_p4.py. Trial on dacc6: est 44.0 MHz. First dacc6 nextpnr (p3, mismatched names) killed.
- litex/dram.py: write/crc/evict at any offset of either channel through the paged windows; loader_test.py
  (17 x 256 KiB per channel incl. last block, aliasing-sensitive, + main-RAM cross-check); full_check.sh runs
  it when the SoC has ddr0. auto_test.sh <results> <builds...>: board-tests each new seed bitstream.
- 15:43-16:25 floorplan attempts with the core region: p2 (dacc5 s1) placed at est 44 MHz but did NOT route in
  40 min (overuse 3132 at iter 7; dacc4 s4 routed in ~13 min); p5 (full width, regions not overlapping) cannot
  place: "Unable to find legal placement for ...carry4" even with CARRY4 cells left unconstrained.
- BUG fixed: seed_sweep.sh made full-size BLANK bitstreams from failed/timed-out nextpnr runs (empty FASM); the
  board tester loaded two (harmless: FPGA unconfigured until the next load). Now no .bit unless nextpnr exit 0 and
  FASM non-empty; auto_test.sh also skips seeds whose pnr log has ERROR. dacc4 s4 re-verified afterwards (same).
- 16:27 two tracks on build_dacc6 (4 GiB window + BIST): A = floorplan_half2.py (= the floorplan of dacc4 s4,
  rename-tolerant, no propagation), seeds 1-6 one at a time; B = floorplan_core_p6.py (wide 250 cols, overlapping
  like p4), seeds 101-103. auto_test.sh board-tests each bitstream (auto_results.txt).
- 17:27 results: dacc6 (4 GiB window + BIST) is much harder to route than dacc4. half2 s1 routed (est 49.7) but
  memtest KO 6/524288; half2 s2 did NOT route in 40 min (stuck ~330 overused); p6 s101 did not route (227 overused
  at the 40 min limit); p6 s102 and half2 s3 running. Few-word memtest errors (dacc4 s3: 12, dacc6 s1: 6) match the
  critical path seen in dacc4 s1: CPU read of the L2 line (adr_offset_r word select -> shared_dat_r -> CPU) across
  the die in one cycle. Time-boxed: stopped floorplan work, options to the user (bus pipelining, drop BIST from the
  full design, engines further right).
- dacc6 half2 s3: ch0 memtest OK but ch1 m5 did not level (build-dependent lane loss) -> FAIL. All dacc6 sweeps
  stopped (user chose the design fix).
- litex/wb_slice.py: WishboneSlice (registered request + registered response, +2 cycles; new request only after the
  ack cycle) + pipeline_slaves(). tb_wb_slice.py: 3000 random transactions, random wait states, back-to-back: PASS;
  mutation (no ~ack_r guard) caught (1395 errors).
- YPCB_BUSPIPE=1 (ypcb_soc.py option 12): slices in front of main_ram, ddr0, ddr1, mvacc, mvacc1, csr, inserted via
  a wrapped SoC.add_csr_bridge (LiteX adds the CSR bridge in _finalize_bus just before bus.finalize()).
- build_dacc7 = YPCB_DUAL JTAGLOAD ACCEL=1 DDR0WIN BUSPIPE, NO BIST (less routing pressure), floorplan_half2.py.
- build_dacc7 (BUSPIPE, no BIST, half2): routes in ~14 min (s1 est 43.5 MHz; critical path now ch0 controller
  zqcs timer -> refresher, anonymous logic down to y=178). s1: both channels all lanes, memtest OK, CPU crc OK,
  ch1 engine OK, ch0 engine exactly 1 row (291) wrong, identical every run. s2: ch1 m5 does not level.
- ROOT CAUSE of the ch0 engine row: my slice bug, NOT timing. pipeline_slaves made the bus-side interface with
  wishbone.Interface(address_width=len(orig.adr)=30) - in this LiteX address_width counts BYTE bits -> 28-bit adr:
  main RAM lost address bits 28-29 (CPU 0x48000000 -> 0x08000000 -> minus the 0x40000000 base wraps to DRAM
  0x48000000). Proven: CPU mem_write 0x48000000 shows up via the ddr0 window at DRAM 0x48000000; the CPU memtest
  passes (same mapping both ways). Windows/engine windows/CSR use only low bits -> unaffected (loader test: all
  34 blocks OK, only its via-main-RAM cross-check BAD). Fix: wishbone.Interface.like(orig) + width assert;
  dacc8 netlist: slice input 30 bits (dacc7: 28).
- The engine saw 511/512 correct rows because DRAM KEEPS ITS CONTENTS across FPGA reloads: the selftest always
  wrote the same rows to the same address, so old data from earlier builds was still there (row 291 had decayed).
  engine_selftest.py now uploads to a random 64-B-aligned offset (0..32 MiB) each run. dacc4 s4 with it: PASS x2
  (fresh address 0x48100000 too) -> dacc4 s4 is genuinely good.
- build_dacc8 = dacc7 + slice fix (started 18:31).
- **build_dacc8 s1 (est 46.1 MHz): ALL PASS** (18:55) - ch0/ch1 all 8 lanes, memtest OK, engine selftest PASS at
  random addresses (ch0 +10181K, ch1 +21163K), loader test PASS (17 blocks per channel over the whole 2 GiB +
  main-RAM cross-check). = both channels + both engines + all 4 GiB reachable by CPU/loader, everything passing.
  Installed as build_dacc8's bitstream (good_seed.txt = 1). Running memtest_4g.py (CPU mem_test of all 4 GiB
  through the windows, 10 pages) on it; seeds 2-5 building to measure the pass rate.
- dacc8 s1 memtest_4g.py: CPU mem_test of ALL 4 GiB through the windows: ch0 8 x 256 MiB OK (75 s each), ch1
  2 x 1 GiB OK (298 s each) -> PASS (19:18).
- build_dacc8 seeds: s1 ALL PASS (+ full 4 GiB CPU memtest), s2 ALL PASS, s3/s4 did not route (router2 gave up,
  25/29 overused wires; detected automatically, no bitstream), s5 ALL PASS. => every seed that routes passes
  the board tests (3/3), vs 1/4 before the slices. BLOCKER (dual channel + 2 engines timing) FIXED by
  YPCB_BUSPIPE; remaining per-seed risks: routing (~2/5 fail, just retry) and the old build-dependent lane loss
  (not seen in dacc8; full_check catches it). Use build_dacc8 (gateware/ypcb_00338_1p1.bit = seed 1) from now on;
  host access to all 4 GiB: litex/dram.py.

## 2026-10-17 evening: MustaqiLLM chat on the FPGA (user: "make an app ... interactive chat ... test it yourself")
- Plan: weights (Q4H 4-bit, 2.49 GiB) in the card's DDR3, half of every matrix per channel; both matvec engines do
  every weight matrix multiply; the PC does norms/attention/SiLU/sampling (no vector unit on the FPGA yet).
  Bottleneck = PC<->card transport: the BIOS console reads at a few KB/s -> new JTAG read path for engine results.
- mustaqi/export_q4h.py: Q4H channel images out/q4h_ch{0,1}.bin (1.244 GiB each) + out/q4h_index.json in 42 s;
  layer-0 qkv byte-identical to accel/golden/q4h_tool's file.
- mustaqi/c/q4h_lib.c (.so): golden.h MXINT8 quantizer + bit-exact reference matvec (OpenMP, ~1.8 GMAC/s):
  matches accel/host/data/qkv.exp bit for bit.
- mustaqi/fpga_llm.py: forward pass with backends FpgaBackend / CpuBackend. CPU backend greedy check: "Salom!
  Qalaysiz?" -> "Vaalaykum assalom! Oʻzingiz qal..." (correct Uzbek), ~2 s/token on the PC.
- Gateware YPCB_JTAGREAD (ypcb_soc.py option 13, litex/jtag_shift.py): chain-2 scans with header bit 0 set stream an
  engine's float32 results from word 2 on; every scan's first 64 TDO bits = status incl. each engine's Gray-coded
  finished-run counter (mvaccel.py fin). tb_jtag_shift.py (40 random write/read scans, both engines): PASS (the
  first run "failed" by one bit everywhere = the testbench sampled TDO one clock early; fixed in the testbench).
- build_dacc9 try 1: a 3rd port on the result memory made yosys put both engines' results into LUT RAM
  (RAM64M 342 -> 5974, RAMB36 20 -> 4). Fix: separate result copy for the JTAG port (RAMB36 36, +118 LUT6).
- build_dacc9 (= dacc8 + JTAGREAD): s1 est 40.0 MHz, did NOT route (7 overused wires after 147 iterations);
  s2 (est 41.2) and s3 routing.
- BIOS crc through the windows is only 4.4 MB/s (10 min for all weights) -> fpga_chat.py verifies the weights by
  running every matrix on the engines with a test vector (all activations non-zero) against the PC reference and
  re-uploads only damaged 16 MiB chunks.
- Loader writes work at 30 MHz TCK: 3.17 MB/s (15 MHz: 1.7 MB/s), CRC OK both channels. Uploading all weights now
  through build_dacc8 (same windows/CSRs; DRAM mostly survives the reload to dacc9, the engine check repairs the rest).
- build_dacc9 abandoned: s1 unroutable (7 overused), s2 hit the 40 min limit, s3 ~440 overused after 21 iterations
  (dacc8 seeds: ~100-200 overused at iteration 5, routed in 14-90 iterations) - the 16 extra RAMB36 / their wiring
  made the die much harder to route.
- build_dacc10 = dacc8 + YPCB_JTAGREAD=2: the EXISTING result memory's read port is clocked by JTAG (jtagl), so no
  extra RAM (netlist = dacc8 +15 FF +8 LUT6); bus reads of results then return 0, so accel/host/dual_test.py
  check() reads results over JTAG when <build>/jtagread exists (engine_selftest/full_check work unchanged).
- FT232H deadlock in my first read scan: kilobytes of TDI zeros in one USB write followed by a long read -> the
  chip's output buffer fills before the host reads, it stops taking commands, USB timeout (Errno 110). Fix: header
  with 0x39, the rest with read-only clocks 0x28 (fpga_link.read_scan_cmd): tiny command, reply streams.
- dacc10 s1 (est 40.9): lanes + memtest + both engines over JTAG bit-exact, but loader test FAIL: ch0 window
  (0xD0000000) WRITES corrupt word 0 of every 64-B line in bits 12..20 (reads fine, main RAM path fine, ch1 fine)
  = seed-specific timing on the ddr0 window write path. Kept as ypcb_00338_1p1_s1.bit, not used.
- **dacc10 s2 (est 46.0, routed in 4 iterations): full_check ALL PASS** (8+8 lanes, memtest, engines bit-exact over
  JTAG, loader test 4 GiB). Installed (good_seed.txt = 2).
- mustaqi/link_test.py on dacc10 s2: PASS - status word decodes right on hardware (write address, word count, both
  run counters), both engines bit-exact over JTAG; activations + 2 engine runs + 4608 results = 18 ms (1.0 MB/s of
  results incl. overheads). Reads at 30 MHz TCK do not work (as noted before: TDO <= ~20 MHz) -> reads 15 MHz,
  writes 30 MHz, switched inline in the MPSSE stream (0x86 divisor) without extra USB round trips.
- **2026-10-18 00:32: MustaqiLLM RUNS ON THE FPGA** (mustaqi/fpga_chat.py, build_dacc10 s2). First run --check
  --greedy "Salom! Qalaysiz?": "Vaalaykum assalom! Oʻzingiz qal" = identical to the CPU backend; 29,761,152 engine
  results compared with the PC reference (c/q4h_lib.so), 0 differ.
- DRAM does NOT keep the weights across FPGA reloads: after dacc8 -> dacc10 s1 -> s2 (+ full_checks) the engine-based
  check found all 160 chunks damaged (each 16 MiB chunk had at least one bad row) -> full re-upload, 13.5 min, then
  "all good". => after loading a bitstream always expect the full upload; keep the FPGA loaded and use --no-bit.
  (The earlier "DRAM keeps contents across reloads" is true for most bits, not all.)
- Speed: first run 7.0 s/token with --check, 5070 of 15224 reads were full-length result reads of a still-running
  engine. Link.wait() (2-word status scans, both engines' run counters) before the reads -> 0 retries,
  **3.7 s/token** without --check (same greedy text). Per token ~4.7 MB results in at 15 MHz (~2.5 s), ~0.8 MB
  activations out at 30 MHz, engines ~0.3 s. Next speed-ups if wanted: bf16 result packing in the reader (halves
  reads), or the stage D vector unit (results stay on the card).
- dacc10 s3: est 39.1, ~30 overused after 70 iterations, stopped (not needed). dacc10 seeds: s1 routed (window write
  timing bad), s2 ALL PASS, s3 not routed.
- Quality check (00:45): sampled 2-turn chat said the capital of Uzbekistan is "Jakarta". Not a bug: my pipeline's
  perplexity on eval_uz (238 tokens, CPU backend = bit-exact with the FPGA) 8.894 vs c/mustaqi.c Q4A 8.966 (bf16
  8.757). Causes: (1) the repetition penalty also hit the question's words (as in c/mustaqi.c): the top first word
  'Oʻzbekistonning' 0.110 fell below 'Bu' 0.100 -> now only the answer's own tokens are penalised; (2) sampling:
  c/mustaqi.c at temp 0.7 answers "Toshkent" in 1 of 6 seeds ("Qarshi" 3, evasive 2) -> app default = greedy
  (--temp > 0 samples). Greedy on the FPGA: "Oʻzbekistonning poytaxti - Toshkent." + follow-up "...Chorsu bozori,
  Xasti imom maqbarasi, Xasti imom jome' masjidi va boshqalar." (same as the C model's greedy first answer).
- How to use: mustaqi/fpga_chat.sh (docs mustaqi/FPGA_CHAT.md); before shutdown mustaqi/fpga_factory.sh.

## 2026-10-29: where a token's time goes + 30 MHz result reads (user: "analyze what calculations ... faster results")
- mustaqi/profile_token.py work (counted per token): weight matvecs 4994 M MACs = gate_up 50.3%, down 25.1%, qkv
  11.9%, out 9.3%, lm_head 3.4%; 2.67 GB of weights streamed = 1.87 MACs per DRAM byte (every weight used once per
  token -> memory-bound: the engines' 128 MACs/clock already match 64 B/clock of DRAM; faster/more multipliers
  alone gain nothing). Attention: 0.1% of the weight MACs at T=16, 2.6% at 512, 10.6% at 2048. Element-wise ~2.5 M ops.
  Link per token: 4.69 MB of results in (gate_up alone 2.80 MB), 1.67 MB of activations out (both engines' copies).
- profile_token.py pc: the PC's share is 14 ms/token at T=16 (quantize 5 ms), 127 ms at T=2048 (attention 108 ms).
- 30 MHz result reads WORK with falling-edge TDO sampling (MPSSE read commands | 0x04: 0x3D/0x2C/0x2E/0x6F,
  fpga_link.read_scan_cmd(neg=True), Link(read_freq, read_neg)): the cable+FPGA delay is > half a 30 MHz clock
  (rising-edge reads fail) but < a whole one. link_test.py: 15 MHz fall OK, 30 MHz fall 50 x 4608 results 0 wrong,
  30 MHz rise fails. Chat --check at 30 MHz fall: 88,735,104 results, 0 differ. No gateware change.
- Measured same session, same answers (2 questions, greedy): 15 MHz rise 3.64 s/token (result reads 2.71, writes +
  engines + polls 0.87, PC 0.06) -> 30 MHz fall **2.38 s/token** (reads 1.46, 0.87, 0.06). fpga_chat.py default now
  --read-mhz 30 --read-edge fall; it prints this per-token breakdown after every answer.
- 16-bit results (profile_token.py ppl, eval_uz 237 predictions, CPU backend = FPGA arithmetic): fp32 8.952 (the
  older "8.894" was a different measurement), bf16 8.949, fp16 8.938, bf16 on qkv/gate_up/lm_head only 8.946 -> no
  measurable cost. Largest |result|: down 9658 (fp16 max 65504: bf16 is the safe choice).
- Next levers (per answer token, from 2.38 s): bf16 packing in jtag_shift.py (~ -0.65 s), one activation write to
  both engines (~ -0.27 s), FFN fusion on the card = SiLU(gate)*up (table exp, -hwmath: no ppl cost) + MXINT8 straight
  into down's activation buffer (removes 2.80 MB in + 0.79 MB out) -> ~0.85 s/token; stage D ~0.37 s. Below the
  0.33 s weight-streaming floor only by reusing weights: batching (prefill, B=4 engine exists) and speculative
  decoding - worthwhile only once the link no longer carries per-token results (batching multiplies them).
- FPGA back on the factory design at the end (DRAM weights lost -> next chat start uploads 13.5 min).
- Step A (user: "take the necessary steps"): build_dacc11 = dacc10 + jtag_shift.py packed reads (header bit 15: two
  results per word as bfloat16, RNE in hardware: (f + 0x7FFF + f[16]) >> 16, = torch bf16 on 3 M values) + 'both'
  writes (write header bit 1: every word also to + bc_offset = engine 1's window). tb_jtag_shift.py 80 scans PASS.
  Synth = dacc10 +15 CARRY4 +18 FF. s1 (est 42.5) full_check ALL PASS (good_seed 1); s2 stopped (57 overused at
  iter 47, not needed). link_test: packed reads bit-exact vs golden rounded to bf16, 30 MHz fall packed 5 ms/cycle
  (unpacked 8, 15 MHz 13). fpga_link.Link detects the features at start (a 'both' write of 1 word counts 2 in the
  status word counter) -> Link.packed; fpga_chat --results auto|bf16|fp32 (weight check stays float32).
  Chat (same 2 questions, same answers): **1.37 s/token** (reads 0.74, writes+engines+polls 0.61, PC 0.03);
  --check: 88,735,104 results vs CpuBackend(packed=True), 0 differ. Default build now build_dacc11.
- Step B (FFN unit, in progress): accel/rtl/fp32.v (fp_mul 3 clk, fp_add 5 clk; IEEE RNE, no subnormals/inf/nan
  needed): tb_fp32 ~88 M random mul/add each vs the PC's float32, 0 wrong; a ties-away mutant is caught.
  fpga_llm.silu_mul_hw = bit-exact spec (float32 ops + exact bit ops: exp2 by 64-entry table + linear interpolation,
  t in fixed point with 16 fraction bits, reciprocal by 64-entry table + interpolation; |t| >= 64 cut-offs):
  ~3e-5 relative error vs exact SiLU. accel/rtl/ffn_unit.v: FIFOs for the two engines' result streams, silu_mul
  (36-stage pipeline, 5 fp_mul + 3 fp_add), golden MXINT8 quantizer, image kept on chip and copied into both
  engines' activation buffers after the gate_up run (gate_up still reads the old activations while it runs);
  ffn_tables.vh from mustaqi/ffn_vectors.py tables. accel/sim/Makefile.ffn: tb_silu (every float32 h vs the spec,
  33,664 rows incl. ~2000 fixed-point ties) + tb_ffn (activation image, engine-like streams with random gaps/skew,
  period 8 and 30): PASS; mutants (quantizer ties, fixed-point ties, exponent edge) each caught. First tb_ffn run
  found busy falling 1 clock before the last copy write -> busy now covers it.
  Quality (profile_token.py ppl --results bf16 --mats qkv,out,down,lm_head --ffn hw = the planned fused setup):
  8.941 vs 8.952 float32 baseline -> no cost. CpuBackend.ffn_q (fused reference) = unfused hw math, identical logits.
  Gateware: mvaccel.py ext_aw_* port (registered beside the engine), accel/litex/ffnunit.py (CSRs ffn_nrows/arm/
  status), ypcb_soc.py option 14 YPCB_FFN, FFN busy/err in the JTAG status word bits 61/62. PC: Link.ffn_arm,
  wait(ffn=True), FpgaBackend.ffn_q (gate_up as ONE 9728-row run per engine: results only feed the unit),
  Model(ffn_fused), fpga_chat --ffn auto|card|pc, mustaqi/ffn_test.py (layer-0 weights into the test area, fused
  FFN vs CpuBackend.ffn_q). build_dacc12 = dacc11 + YPCB_FFN: synth +10 DSP, +4.3k FF, +8 RAMB18; routing.
- PCIe question (user, then their PM): ~100-1000x the JTAG bandwidth (~0.4 s/token, upload in seconds). Toolchain
  check (CORRECTED - a first `grep` of the chipdb binary for "PCIE_2_1" found nothing, but bel types are constids,
  not strings): bbaexport.py auto-switches to nextpnr-xilinx-meta/kintex7 for xc7k (has site_type_PCIE_2_1 + GTXE2_*);
  480T tilegrid has PCIE_X0Y0 (PCIE_2_1) in PCIE_BOT_X279Y219 and 8 GTX quads; prjxray-db kintex7 segbits_pcie_bot
  1711 lines (= artix7), segbits_gtx_channel_* 1675; nextpnr has pack_gt_xc7.cc (GTX) + fasm write_gtx_channel/
  write_gtx_pll/write_pcie_2_1. GAPS: kintex7 GTX routing never fuzzed (prjxray has 065/066 gtp-*-pips only):
  GTX_INT_INTERFACE 48 IMUX_DELAY pips + GTX_COMMON/CHANNEL SOUTHREFCLK/GTGREFCLK pips (3 + 2) have no bits (block
  them; x4 in the refclk's quad avoids the refclk sharing); LitePCIe s7pciephy generates Xilinx pcie_7x via Vivado
  create_ip (need the wrapper Verilog: free Vivado on a small Kintex-7 part?); GTX/PCIe path not proven on hardware.
  Board lanes/refclk/PERST unknown -> decode the factory bitstream (PCIe endpoint 10ee:7028 = Gen2 x8 default ID).
  (A short briefing for the project manager covered phases, routes and the Vivado licence question.)
  Nothing PCIe-related touched.
- build_dacc12 (= dacc11 + YPCB_FFN, floorplan_half2): s1 and s2 both hit the 40 min nextpnr limit (97 / 74 overused
  after 98 / 58 iterations): the unconstrained FFN unit (~4.9k cells) landed in the congested middle. litex/
  floorplan_half3.py = half2 + region "ffn" (x160-240, y150-270, right of the engines, straddling the ch0/ch1
  boundary; prefixes ffn_unit. / ffn_): seed 11 routed in ~11 min (est 42.0 MHz), full_check ALL PASS ->
  installed (good_seed 11, seeds/README.txt). Seed 12 stopped (not needed). LESSON: give every new block that talks
  to both channels its own floorplan region.
- mustaqi/ffn_test.py on dacc12 s11: layer-0 gate_up + down (56 MB) into the test area in 17 s, 20 vectors: down
  results BIT-EXACT vs CpuBackend.ffn_q, err 0. Per layer FFN 10.8 ms with the unit vs 38.2 ms with gate_up over
  the cable.
- Chat on dacc12 s11 (FFN unit): **0.83 s/token** (reads 0.31, writes+engines+polls 0.49, PC 0.03); --check 82.8 M
  results vs CpuBackend fused reference, 0 differ. BUT the capital question now answers "Bu javob mantiqiy
  fikrlashning ..." (off-topic). Not a bug: first answer token probabilities (CPU, same arithmetic as the card):
  float32 + numpy SiLU 'Oʻzbekistonning' 0.110 / 'Bu' 0.100; dacc11 arithmetic 0.115 / 0.095; float32 + hw SiLU
  0.103 / 0.100; dacc12 0.082 / 0.099; dacc12 with exact SiLU 0.0965 / 0.0965 -> a coin flip that any arithmetic
  change tips (model card: batch padding flips greedy output in 8 of 32 prompts). 12-question quiz (fresh
  conversation each, greedy, 40 tokens): card (dacc12) vs PC float32 original: same answers on 11 (incl. the same
  wrong ones: Samarqand -> off-topic, 2x2 -> "Yettita", Earth orbit -> off-topic), only the capital question
  differs. Default build now build_dacc12; MUSTAQI_BUILD=build_dacc11 / --ffn pc give the old arithmetic.
- State at 17:30: FPGA left on build_dacc12 with the weights uploaded (chat starts with --no-bit in seconds);
  run mustaqi/fpga_factory.sh before shutting the PC down.
- User's own chat on dacc12 was poor (2026-10-29 evening): "o'zbekiston poytaxti qayer?" -> "Oʻzbkiston poytaxti - bu
  mamlakat poytaxti.", the follow-up "va shahar nomi?" got the same sentence again, "20ta so'zdan iborat insho yozib
  ber" echoed it + the prompt. Replays (scratchpad multiturn/): FPGA == CPU with the card's arithmetic, word for word
  (no hardware problem); CPU float32 4-bit pipeline: same kind of loop ("... - bu qaysi shahar?" x3); typing ʻ instead
  of ' changes nothing; INDEPENDENT reference ref.py with the ORIGINAL bf16 weights (no 4-bit): "Oʻzbkiston poytaxti
  - Toshkent." (same misspelling), "va shahar nomi? - bu shahar nomi.", "Inshoda 20 ta soʻzdan iborat insho yozish
  kerak." -> the base model itself is weak at short colloquial questions / follow-ups; 4-bit (KL 0.028, top-1 90.3%
  vs bf16, quant_results.txt) makes it somewhat worse. Sampling (model card chat settings 0.7/0.9/1.05, 3 seeds on the
  FPGA) was worse still. Full, formal questions ("Oʻzbekistonning poytaxti qaysi shahar?") work better.

### 2026-10-30 PCIe: user's PDFs (pg054, DS182, edge-connector screenshot) + factory design decode
- pg054 Table 85: XC7K480T-FFG1156 has exactly ONE PCIe hard block, PCIE_X0Y0 (= our chipdb site PCIE_BOT_X279Y219).
- pg054 Table 90 *recommends* lanes 0-7 on GTXE2_CHANNEL_X0Y19..X0Y12 (quads 115/114), but says other GTs are allowed.
  This board does NOT use the recommended ones. pins/factory.fasm (factory readback decode, 2026-10-07) shows the
  factory design uses exactly the 8 channels of quads 115+116 (tiles GTX_CHANNEL_*_X309Y214..306 = X0Y16..X0Y23),
  matching pins/board.xdc (lane0 = F2/H6 ... lane7 = U4/T6). Refclk: only IBUFDS_GTE2 in use is quad 116 Y0 =
  MGTREFCLK0_116 (J8/J7), as board.xdc says. Quad 115 channels show "GTREFCLK1_USED" with no IBUFDS in use there,
  probably the neighbour-quad refclk mux; to be confirmed.
- factory.fasm also holds the complete Xilinx-IP settings: ~143 GTXE2_CHANNEL attributes per lane (PCS_PCIE_EN,
  TX_DRIVE_MODE PIPE, CPLL, RXCDR_CFG, ...), both QPLL commons, and 103 PCIE_2_1 attributes (Gen2 x8,
  USER_CLK_FREQ=4 + USER_CLK2_DIV2 = 128-bit @ 250 MHz, BAR0 = 2 MB 64-bit, class 0x058000). So the attribute
  values Vivado would generate are known without Vivado.
- Still missing: (1) GTX_INT_INTERFACE routing bits are absent from factory.fasm (not in prjxray-db, so not decoded);
  (2) the soft PIPE wrapper logic (reset/rate-change/clocking) that pg054 describes but does not give as source.
- DS182 confirms -2 speed grade supports the hard block at x8 Gen2; screenshot = standard CEM edge-connector pinout
  (card RX on B-side PETp/n), only useful for continuity probing with the card OUT of the PC.

### 2026-10-30 evening: PCIe toolchain probe (software only - nothing loaded, flash untouched)
Dir pcie/. probe_top.v = 8 GTXE2_CHANNEL + IBUFDS_GTE2 + PCIE_2_1 (+2 RAMB36, PLL) wired like Xilinx's PIPE wrapper,
placeholder reset/clock logic. NOT FOR LOADING. Flow: yosys probe.ys -> nextpnr (15 s, routes cleanly) ->
fasm2frames -> probe.bit -> bit2fasm --verbose -> compare_tiles.py vs the factory bitstream.
- gen_params.py inverts nextpnr's FASM writers (fasm.cc write_gtx_channel / write_pcie_2_1) to turn the factory
  features into Verilog parameters -> factory_params.vh (GTX 200 params, PCIE_2_1 267). Every factory feature
  maps to a writer parameter. yosys' cells_xtra lacks LOOPBACK_DRIVE_HIZ / ENABLE_JTAG_DBG (both FALSE = default).
- Result: PCIE_BOT 103/103 features identical; each GTX channel 142-143 identical. Factory reference = the ORIGINAL
  bitstream from the flash backup (pcie/factory_flash.bin = first 0x11DDA00 bytes) - same GT/PCIe bits as the
  readback, so the readback values were not runtime (DRP) changes.
- Gap 1 SOLVED: GT input "delay" pips. Unknown factory bits in frames 26/27 of the GT column belong to
  GTX_INT_INTERFACE tiles (they share column 123 frames with INT_R and GTX_CHANNEL tiles). Artix-7
  segbits_gtp_int_interface.db renamed GTP->GTX (identical wire lists, 342 wires) decodes 288 factory bits, and
  288/288 sit on IMUX inputs driven by INT_R_X123Y(y-1) (chance level ~60%) -> map confirmed.
  Overlay DB: pcie/db/kintex7 (symlinks + segbits_gtx_int_interface.db). The factory uses the delay on 288 of
  1719 driven GT inputs (hold fixing); our probe used only the direct "always" path (no bits needed).
- Lane order: lane0..7 = GTX_CHANNEL_3_X309Y306 (X0Y23) ... GTX_CHANNEL_0_X309Y214 (X0Y16), Xilinx's descending
  order shifted by one quad. DISABLE_LANE_REVERSAL is set in the factory PCIe block.
- Remaining differences (all clocking, all known exactly from the factory bits):
  quad 115 channels: factory GTREFCLK1_USED + unknown bit 31_10 (ours GTREFCLK0_USED) = refclk from quad 116;
  quad 115 common: IN_USE, GTREFCLK1_USED, GTXE2_COMMON_GTGREFCLK.GTXE2_CLK0_2, QPLL attrs, ENABLE_DRP;
  quad 116 common: IN_USE, GTREFCLK0_USED, CLKSWING_CFG, QPLL attrs, ENABLE_DRP, unknown bit 30_1486;
  both commons: 4 unknown bits 27_1540..1564 (frame 27 of INT_R_X123Y274 - probably delays on common inputs).
  nextpnr's write_gtx_pll hard-codes QPLL_COARSE_FREQ_OVRD/QPLL_LPF/... differently from the factory.
  INV_DRPCLK in ours only = DRPCLK tied low (factory clocks DRP).
- Still to do (software): add GTXE2_COMMON x2 + FASM patch for the refclk-sharing bits -> zero differences;
  then the soft PIPE logic (reset/rate change/DRP/clocks) and the user side (LitePCIe on TRN). The GTX and PCIE_2_1
  have no open simulation models, so their behaviour can only be proven on the card (needs the user's OK).
- 20:30 RESULT: pcie/run_probe.sh (yosys -> nextpnr -> fasm_patch.py -> fasm2frames with the overlay DB -> decode ->
  compare) gives ALL 8 GTX_CHANNEL tiles and PCIE_BOT bit-identical to the factory flash bitstream, and both
  GTX_COMMON tiles identical except 4 factory-only bits each (frame 27 bits 4/12/20/28 of word 48 = the INT_R_X123Y274
  row next to the common; probably input delays on QPLL control pins, which we tie to constants). Probe adds both
  GTXE2_COMMONs ((* keep, BEL="GTXE2_COMMON_X0Y4/5/GTXE2_COMMON" *), QPLL powered down) and a real DRPCLK.
  fasm_patch.py: quad-115 channels GTREFCLK0_USED -> GTREFCLK1_USED + XF_REFCLK_31_10; quad-115 common
  GTREFCLK1_USED + GTXE2_COMMON_GTGREFCLK.GTXE2_CLK0_2 (no CLKSWING); quad-116 common XF_REFCLK_30_1486; both
  QPLL_LPF 4'b1101. The readback copy differs from flash only in QPLL_COARSE_FREQ_OVRD (runtime calibration).
  => the configuration side of x8 PCIe is solved without Vivado. Not proven on hardware.

## 2026-10-31 PCIe hardware-test plan (nothing run yet) + PC-side facts
- Slot = root port 00:01.0 (8086:460d, Alder Lake x16), bus 01. Oct 17 boot: card enumerated 10ee:7028, BAR0 0x80800000 2 MB,
  bridge window 0x80800000-0x809fffff. Current boot (Oct 29 13:29): "removing 2.5GT/s downstream link speed restriction" ->
  "retraining failed" -> no 01:00.0, no bridge window. sysfs LnkSta still says 2.5 GT/s x8 (stale/last link).
- JTAG reloads with the PC on only ever gave correctable RxErr AER entries (Oct 29 15:44, 17:41; earlier 18:47). No hangs.
- Plan: S1 transceivers + internal loopback, PCIe block held in reset (PC sees nothing new); S2 link at Gen1 only
  (LINK_CAP_MAX_LINK_SPEED=1), LTSSM trace in BRAM read over JTAG, enumerate via rescan or warm reboot; S3 BAR0 responder,
  then LitePCIe DMA; S4 Gen2 rate change. S2+ only with the user physically at the PC (a freeze needs the power button).
- Rescan may fail to allocate the 2 MB window (no bridge window this boot); fallback = warm reboot with design loaded
  (unknown whether the board keeps FPGA config across a warm reboot).

## 2026-10-31 PCIe stage 1 ON THE CARD: 8 lanes, internal loopback — PASS (pcie/s1/)
User approved hardware tests and was at the PC. s1.bit loaded to RAM only (LLM design replaced; flash untouched).
- Two toolchain traps found before loading:
  1. nextpnr pack_gt_xc7.cc disconnected GTXE2_CHANNEL.CPLLREFCLKSEL ("contains REFCLK" rule) -> unrouted pins read
     3'b111 (GTGREFCLK) -> CPLL would never lock. Patched (exclude "REFCLKSEL"), binary backup
     build/nextpnr-xilinx.pre-refclksel. Rebuild with `ninja` (build dir is Ninja, `make` silently does nothing).
  2. Any GT input left unconnected is unrouted and reads 1 (INT IMUX/FAN_ALT/BYP_ALT default = VCC_WIRE).
     s1_top.v connects every GTXE2 input explicitly.
- Factory input ties recovered for all 8 lanes x ~330 pins: s1/gt_pinmap_npnr.py (run inside nextpnr --run: GT pin ->
  INT_R wire) + s1/factory_ties.py (factory FASM: GFAN<-GND = 0, no pip on IMUX = 1, else net) -> s1/factory_ties.txt.
  Notable: CPLLREFCLKSEL 001 on all lanes; TXPHALIGNEN=1 (multi-lane MANUAL TX buffer bypass), TXDLYBYPASS 0,
  RXDLYBYPASS 1; TSTIN all 1; TXDIFFCTRL 1100, TXBUFDIFFCTRL 100; RXDFELFOVRDEN 1; RXCHBONDLEVEL L0=001 rest 000;
  dynamic: CPLLPD, CPLLRESET, TX/RXPMARESET, RXLPMEN, TX/RX8B10BEN, TX/RXSYSCLKSEL[0], DRP, CLKRSVD[0] (OOB clock;
  we use dclk/2 = 62.5 MHz). s1/check_ties.py compares our routed ties with the factory's.
- Results (s1/host/s1.py test 12/12, s1_rate.py, s1_soak.py):
  all 8 CPLLs lock (quad-115 refclk sharing bits work); reset sequence READY in 1.6 ms; manual multi-lane TX alignment
  DONE on 8 lanes; refclk 100 MHz (CFGMCLK is ~64.2 MHz, not 63.64); pclk/ref exactly 1.25 / 2.5.
  Soak, near-end PMA loopback, 20 s each, 2.5 and 5 GT/s x PRBS-7/PRBS-31/8b10b K28.5+D21.5: 0 errors, 3.6e12 bits,
  BER < 2.8e-13; comma alignment on all lanes. Rate switch 2.5<->5 GT/s 10/10 clean WHEN TX IS IN ELECTRICAL IDLE;
  with TX active TXRATEDONE never comes (PCIe-mode GTX; the PCIe block idles TX before a speed change anyway).
  8b/10b data needs TX out of idle (PRBS works either way). Auto (per-lane) TX alignment failed on lane 5 — unused.
  PC kernel log: nothing (only the FTDI cable USB messages). Root port sysfs still shows 2.5 GT/s x8 (stale).
- Timing: pclk 290 MHz (needs 250), dclk 141 (125), sclk 164 (~64). TX-align FSM runs on dclk (async GT ports).

## 2026-10-31 PCIe stage 2 ON THE CARD: x8 Gen1 link UP, but the PC gets no config answers (pcie/s2/)
build.sh -> build/s2.bit (~4 min), loaded 13:46 RAM only. host/s2.py status|trace (needs `. litex/env.sh`).
- Design: full PCIE_2_1 with all 266 factory params except Gen1 (LINK_CAP_MAX_LINK_SPEED 1, TARGET 1, USER_CLK_FREQ 3,
  ALLOW_X8_GEN2 FALSE); every input tied explicitly (gen_pcie_inst.py). pcie_ties.py vs factory: only CFGDSN, CFGREVID
  (02 = ours) and one GND-holdout bit differ. Bug caught that way: "ends in N = active low" wrongly tied
  CFGFORCEEXTENDEDSYNCON, DRPEN, PLDIRECTEDLINKAUTON, TRNTECRCGEN to 1; TRNRFCPRET must be 1 (factory).
- Hold delays like the factory: delay_patch.py adds IMUX_DELAY on all PIPE-RX inputs of the block (PCIE_INT_INTERFACE
  tile = same row as its INT tile; 191/191 factory delays covered) and on the GT TX inputs (GTX_INT_INTERFACE Y = INT+1).
- MIM RAMs must be LOCed to the factory sites RAMB36_X10Y40/41 (TX) and X10Y43/44 (RX) (placer put them far away).
  36-bit, read port A with DOA_REG=1 (TL_*_RAM_RDATA_LATENCY 2), write port B, NO_CHANGE.
- Result: PHY ready 1.66 ms, receiver detected on 8/8 lanes, Polling -> Config -> L0 at 1375.1 us, TRN link up at
  1375.6 us, x8 2.5 GT/s, 0 recovery, 0 errors. Root port: LnkSta x8 2.5GT/s DLActive+, no AER UE bits.
- BUT: rescan finds nothing. First cause: the empty root port was runtime-suspended (power_state D3hot) and does not
  forward config in D3hot -> `echo on > /sys/bus/pci/devices/0000:00:01.0/power/control` (D0 now). Second rescan:
  still nothing, and the card's CFGTRANSACTION counter stays 0, TRNTBUFAV 29, no recovery, root port AER clean.
- Anomaly: TRNLNKUP reads 1 at the status sync FF and at the lnk_seen LUT (rose 0.5 us after L0), but the recorder
  (tr_prev[7] FF + its comparator LUTs, all fed from one route branch via INT_R_X111Y261.WL1BEG2.SS6END3) never
  saw it change -> one routed branch of a hard-block output apparently delivers a constant. The pip types on that
  branch are all used by the factory, so not a missing-pip-type problem. Unresolved. route_dump.py (nextpnr
  --post-route, ROUTE_OUT=...) dumps the full route of every PCIE_2_1 output net.

## 2026-11-02 PCIe stage 2 v2 (diagnostic build): the RX buffer RAM is written but reads back ZERO
- PC rebooted 11-02 with the factory design: enumerated at boot (10ee:7028, 5 GT/s x8, BAR0 0x80800000 2 MB, bridge
  window allocated). So 01:00.0 stays in sysfs; after a JTAG reload `lspci -s 01:00.0 -x` (no sudo) sends config
  reads. Root port 00:01.0 stays D0 while 01:00.0 exists (its power/control = on).
- s2 v2 (s2_top.v v2; v1 kept as s2_top_v1.v / s2_v1.bit / host/s2_v1.py; bit = s2_v2.bit): 4 snoop RAMs log the
  block's RX/TX buffer RAM writes and reads (USER2, ctl rsel), 15 error/event counters, received DLLPs, CFGMGMT
  config-space read over JTAG. host/s2.py diag | cfg [dw..] | snoop rxw|rxr|txw|txr. Timing: userclk 232 MHz
  (only a diagnostic saturating counter misses 250).
- Results right after load (12:24): link L0 x8 Gen1, TRN up (trn_up_cycles counts -> the recorder anomaly was its
  comparator branch, not TRNLNKUP), DLLPs received continuously, 0 LL/TL errors.
  CFGMGMT read of our config space is correct: DW0 702810ee, DW2 05800002 (rev 02), BAR0 00000004, DW11 000710ee.
  The root port's Set_Slot_Power_Limit message (hdr 74000001 00080050, data 75 W) is WRITTEN into the RX buffer RAM
  correctly (snoop rxw, 3 entries) and the block reads those 3 addresses back - but the read data is ALL ZERO
  (snoop rxr). JTAG configuration readback (tools/readback.py, 11 s; bit2fasm) shows the RX RAM CONTENT is non-zero
  -> writes land, the READ side fails. That is why config requests are never answered (TLPs read back as zeros).
- Ruled out: RAM config bits (= factory except unused port widths, WRITE_MODE_A), pin netlist (bram_dump.py),
  REGCE (IMUX.VCC_WIRE is a "default" ppip = same as factory's unrouted pin), RST* (CTRL<-BYP_BOUNCE4<-BYP_ALT4 VCC,
  inverted, same as factory), clock buffer HCLK_L_X271Y234 (NB HCLK tiles are named by GRID column: the HCLK of
  INT_L_X108 is HCLK_L_X271, not X108), node model: check/node_check.py rebuilds every factory pip source from
  tileconn on the 480T grid -> 0 mismatches in 2.0M; the read-enable pip IMUX_L10/18.BYP_BOUNCE_N3_6 is used by the
  factory (17/43x) and the readback shows it set.
- Leading hypothesis: TIMING. PCIE_2_1 has no timing model in nextpnr, so block<->RAM paths at 250 MHz are untimed;
  our read-enable route detours (SW6 hex + WL1 + BYP bounce). Write side happens to be shorter. Not yet measured
  (getPipSrcWire from Python asserts; mim_delay.py needs another way).

## 2026-11-02 13:07 PCIe stage 2 PASSES: the PC reads our config space (nextpnr BRAM output-register bug fixed)
- ROOT CAUSE of "RX buffer reads back zero": nextpnr-xilinx never connected the block-RAM OUTPUT-REGISTER clock
  site pins REGCLKARDRCLK{L,U} / REGCLKB{L,U} (they are not RAMB36E1 cell ports). With DOA_REG=1 the register
  never clocks -> DO stays at its init value (0). Vivado/factory ties them to the port's data clock: in the BRAM's
  5th INT row (BRAM_CLK0_4/CLK1_4 = INT_L row base+4: rows 204/209/219/224 for the four MIM RAMs), exactly the rows
  where the factory had CLK_L0/L1 <- GCLK and we had nothing. Writes (no output register) worked, our DOA_REG=0
  snoop/trace RAMs worked, LiteX/LLM builds (DO_REG=0) never hit it.
  FIX: xilinx/pack.cc XC7Packer::pack_bram, after generic_xform: for DOA_REG/DOB_REG=1 add ports
  REGCLKARDRCLK{L,U}/REGCLKB{L,U} (RAMB18: no suffix) on the CLKARDCLK/CLKBWRCLK net. Backups:
  build/nextpnr-xilinx.pre-regclk (before this fix), .pre-hardtiming (before today's patches).
  NB affects ANY design with registered BRAM outputs built with the old binary.
- Also added (xilinx/arch.cc, env-gated, default off): NPNR_HARD_TIMING=1 times PCIE_2_1 MIM pins (USERCLK; assumed
  c2q 1.0 / setup 0.5 ns) and RAMB18/36 pins (DS182-like); NPNR_HARD_TIMING_DUMP=<file> writes the routed delay of
  every PCIE<->BRAM arc and of their clock pins. Measured on the failing build: all MIM arcs 0.5-1.1 ns, clock
  0.95 ns (block) vs 0.97 ns (RAMs) -> timing was NOT the problem (hypothesis rejected by measurement).
- Result (s2_v2b.bit, loaded 13:07, RAM only): snoop rxr returns the Set_Slot_Power_Limit TLP intact;
  `lspci -s 01:00.0 -x` (no sudo, kernel kept the device from the factory boot) returns
  ee 10 28 70 / rev 02 / class 058000 / BAR0 64-bit / subsys 10ee:0007 = OUR config space. Card: config reads 32,
  TX buffer writes 64 (completions), all LL/TL/PL error counters 0, no recovery. BAR0 in the hardware is unassigned
  (kernel still has the factory's 0x80800000 cached, memory decode off) -> a proper remove+rescan before stage 3.
- Debug tools from today: check/node_check.py (tileconn node model vs a routed FASM: 0 mismatches in 2.0M factory
  pips), tools/readback.py + bit2fasm reads BRAM contents of the running chip (11 s), s2/bram_dump.py,
  s2/bram_pinmap.py, s2/net_dump.py (nextpnr --post-route). Python getPipDelay etc. assert (pip names are not
  parseable by getPipByName) -> use the C++ dump.
- Still open (minor): the v1 recorder missed the TRN-link-up edge although TRNLNKUP was 1 (its comparator inputs
  used *_N3_3 wires); not understood, not needed.

## 2026-11-02 ~14:00 PCIe stage 3a round 1 (s2_v3.bit, BAR0 writes)
- After remove+rescan, `sudo python3 pcie/s2/host/bar_test.py` (writes only): scratch reg reads 0x11223344 on the card (JTAG),
  67,109,009 write TLPs arrived, 0 link errors (no bad TLP/DLLP, no replays, no malformed). TRN RX format confirmed from the
  snoop: header DW0 at rd[127:96], DW1, DW2 = address, DW3 = first data DW byte-swapped (44332211 -> 0x11223344), sof+eof
  in one beat for 1-DW writes, rrem=11 for a 4-DW beat, bar_hit bit 0.
- Bulk 64 MB at 13.9 MB/s, but Python `m[a:b] = chunk` (memcpy, rep movsb on the UC mapping) sent ONE BYTE per TLP
  (BE 1/2/4/8, 64 Mi TLPs) plus 2 x 32-byte AVX stores (8-DW TLPs) re-writing 64 bytes per 1 MB call: card bytes =
  4 x 64 MiB + 68 + 4096, sum differs from the script's by 0xC6FA2E40 = 64 x (sum of the 64 re-written bytes) (divisible by
  64 as predicted). bar0.v counts 4 bytes per DW regardless of byte enables (fine for its purpose).
- bar_test.py now writes with 32-bit stores (ctypes array slice) and, with --read, checks the bulk delta itself;
  old version kept as host/bar_test_v1.py. Card: `s2.py set bar_rd=1` done (read replies on) for round 2.

## 2026-11-02 ~14:40 PCIe stage 3a round 2 PASS, then LLM + PCIe integration (build_pcie1)
- Round 2 (s2_v3.bit, `s2.py set bar_rd=1`, user ran bar_test.py --read): magic C0DE5303, scratch reg, 16 scratch-RAM
  words and the unmapped-address value all read back correctly; bulk 64 MB with 32-bit stores 44.9 MB/s, card's
  byte count + checksum EXACT; 20,000 single reads 0.96 us each; 20,027 read TLPs -> 20,027 completions; all link
  error counters still 0. => TX completions (CplD, 1 DW) are right on hardware.
- Integration plan (told the user): LLM SoC + PCIe in one bitstream, PC software over PCIe, JTAG kept for loading +
  DDR3 channel-1 bring-up + fallback. Pieces written 14:40-15:05:
  * pcie/core/pcie_x8.v: s2's lanes + PCIE_2_1 + buffer RAMs + reset sequencer + TX alignment, debug removed;
    TRN in/out ports, 8 error-event counters; pcie_x8_inst.vh from gen_pcie_inst_core.py (TRNRDSTRDY now driven =
    back-pressure; REVID 03, DSN ...03). Standalone yosys: 8 GTX, 2 COMMON, 1 PCIE_2_1, 4 RAMB36, PLL, 4 BUFG.
  * pcie/core/pcie_trn_bridge.v (pclk): RX DW serialiser (handles TLPs starting at DW2 = 128-bit straddling, rrem[1]=0)
    -> TLP parser -> ONE in-order command stream (writes per DW with byte enables, reads up to 32 DW, longer = UR
    completion) -> completions from an assembly buffer (one beat/clock, only when all data is there).
    sim/tb_bridge.v (random TLPs, straddling, back-pressure everywhere, reference memory): PASS 6 seeds incl. no-gap
    and heavy-stall runs; 8 of 9 mutants caught (the 9th, single-beat valid mask, is provably benign: the parser drops
    non-SOF DWs between TLPs).
  * litex/pcie_bridge.py: PCIeBridge (pcie_x8 + bridge + 2 AsyncFIFOs, CSRs pcie_link/tlps/reads/cpls/errs/ev/restart)
    + BridgeSys (sys clock, in order): BAR0 = 7 movable 256 KB windows (base bit 0 = mirror write to +0x100000 =
    engine 1) + slot 7 registers (magic 0x50434901, engine/FFN status = JTAG status bits, counters, link word);
    engine results read straight from the result memories (0xC0080000 / 0xC0180000 + 4*row; packed bf16 pairs at
    +0xC0000, same rounding as jtag_shift). sim/test_pcie_bridge_sys.py (migen sim, random latency bus slave):
    PASS 3 seeds; mutants (mirror offset, packed order, engine select, packed row, base index, mirror BE) caught.
  * mvaccel.py: results_domain option (sys for PCIe); ypcb_soc.py option 15 YPCB_PCIE (replaces JTAGREAD).
  * floorplan_half4.py = half3 + region "pcie" (244,100)-(325,240) next to PCIE_X0Y0 (grid 279,197), buffer RAMs
    (x 269) and GT quads (x 309); floorplan_lib2.py: optional SKIP_TYPES/SKIP_REGIONS (hard blocks, BUFG, PLL, pads,
    LOCed cells stay unconstrained). Grid y = nextpnr y (checked: bank-16 DQ pin at grid y 107 = region ch1).
  * pcie/db/kintex7_llm: overlay = the LLM flow's prjxray-db (nextpnr's bundled copy) + the 6 PCIe/GT overlay files
    (the PCIe overlay pcie/db/kintex7 is based on ~/tools/prjxray-db, which only ADDS HCLK_IOI/CMT/HCLK_L bits; the
    LLM FASM uses none of them, but this keeps DDR3 bits identical to before).
  * litex/build_pcie.sh <out> [seeds]: dacc12 options + YPCB_PCIE, -nosrl, PCIe clock constraints (8 / 4 ns), P&R with
    floorplan_half4 + pinmap_route.py, then unused_pins, VREF 750, fasm_patch (quad-115 refclk), delay_patch
    (PCIE_DB env now; 309+240 input delays), fasm2frames on kintex7_llm.
  * PC side: mustaqi/c/pcie_io.c (AVX2 32-byte reads, MOVDIR64B 64-byte writes + sfence; the i5-12400 has both),
    mustaqi/pcie_link.py PcieLink (= fpga_link.Link interface + upload/evict through the DDR windows),
    fpga_chat.py --link pcie (runs `sudo pcie/pcie_rescan.sh` after loading), pcie/pcie_rescan.sh (remove+rescan,
    root port power on, enable, resource0 chown to the user).
- 15:03 build_pcie1 started (seeds 1 + 2).

## 2026-11-03 LLM over PCIe WORKS: 0.41 s/token (JTAG 0.83), weights upload 1.5 min (JTAG 13.5)
- 2026-11-02 15:52 the session was OOM-killed: both build_pcie1 seeds finished routing within a minute (15:48/15:49) and
  build_pcie.sh ran their two fasm2frames at once; ONE needs ~10 GB peak RSS on this design (measured with
  /usr/bin/time: 10.2 / 10.0 GB; pure-Python textX fasm parser), the PC has 14 GB + 4 GB swap -> kernel OOM killer,
  then systemd stopped the whole terminal scope (the terminal included). Fix: build_pcie.sh runs fasm2frames under a
  flock (one at a time) and every heavy step in `systemd-run --user --scope -p MemoryMax=...` (an overflow kills only
  that step). Both routed FASMs survived; only the conversion was redone (3 min each, sequential).
- Earlier build failures on 11-02: (1) litex-boards' ypcb platform "pcie_x8" has lane 6 RX_N = E3 (factory: R3) ->
  own resource "ypcb_pcie_x8" in pcie_bridge.py; (2) "Unable to find legal placement ... carry4": a carry chain
  (res_adr + 1) whose S input net was named after the engine's result memory (mvacc_*), so the floorplan split one
  carry cluster between regions pcie and ch0 -> one address register per engine (pcie_res_adr0/1, +1 cycle latency,
  BridgeSys sim re-run PASS).
- build_pcie1 timing estimates (nextpnr, pessimistic on this chip: sys est 42 MHz runs at 75): pcie_clk 94.6 / 98.9 MHz
  (need 125), userclk 96.9 / 127 MHz (need 250). Critical paths: pcie_trn parser (hmask -> pick -> pe -> need_pq ->
  d_take -> CE, 9 LUTs + long nets to cells placed outside the pcie region, x 220) and the debug ev counters
  (userclk, 5 ns net). Works on hardware (below), but if errors ever show up: propagate the pcie region to unnamed
  cells and pipeline d_take.
- check_ties / pcie_ties on s2.pn.fasm: 0 GT tie differences; PCIe ties differ only in CFGDSN/CFGREVID (intended).
- seed 2 on the card (pcie_candidate.sh): ch0 all 8 lanes + Memtest OK, ch1 all 8 lanes; PCIe link word: LTSSM 0x16,
  x8, 2.5 GT/s, TRN up, sequencer READY, 0 link errors. `sudo pcie/pcie_rescan.sh`: 10ee:7028 rev 03, BAR0 0x80800000.
- mustaqi/pcie_selftest.py: registers, CSR round trip OK; 16 MiB per DDR3 channel written 30.2 MB/s, read back
  17.3 MB/s, 0 words differ; 0 bus errors / UR / stale.
- fpga_chat.py --link pcie --no-bit --check: weights checked on the engines in 1 s (JTAG ~5 s), all 160 chunks uploaded
  over PCIe in 1.5 min (29.7 MB/s), re-check all good; answer identical to the JTAG builds; 20,141,184 results vs the
  PC reference, 0 differ. Without --check (2 questions, 36 + 40 tokens): 0.41 / 0.42 s/token = activations +
  engines + polls 0.35, result reads 0.05 (JTAG 0.31), PC 0.01; prompt 0.43 s/token. The engines (~0.33 s floor)
  are now the bottleneck, not the link.
- Installed: build_pcie1/gateware/ypcb_00338_1p1.bit = seed 2 (seeds/README.txt). The card holds it WITH the weights
  uploaded: `mustaqi/fpga_chat.sh --link pcie --no-bit` starts in seconds. After any FPGA reload:
  `mustaqi/fpga_chat.sh --link pcie` (loads, ch1 init, sudo rescan, upload if needed). Before PC shutdown:
  mustaqi/fpga_factory.sh.

## 2026-11-03 afternoon: PCIe default, speed work ("increase tokens per second to the edge")
- fpga_chat.py: `--link pcie` is now the DEFAULT (`--link jtag` = old cable path, build_dacc12). FPGA_CHAT.md updated.
- Results read WHILE the engines run (pcie_link.PcieLink.run, used by fpga_llm.FpgaBackend._run): each engine's
  `rows` CSR (mvacc_rows / mvacc1_rows, results written so far) is polled and finished rows are read in 32-byte blocks;
  only the last block is left after a run. No gateware change. --check: 12,022,272 results, 0 differ.
  **0.41 -> 0.36 s/token** (engines incl. activation drain 0.351, PC 0.01). Breakdown now printed per answer.
- Measured over PCIe (scratchpad lat.py): bridge register read 1.38 us, CSR read 1.47 us, result reads 18.3 MB/s,
  set_activation K=3584 183 us (22 MB/s: each DW = 2 Wishbone writes of ~7 clocks, mirror) -> ~20 ms/token.
- DRAM efficiency per matrix (engine cycles CSR): EXACTLY 84.9 % of 64 B/clock on every matrix, both channels.
  Reproduced exactly in simulation: litex/sim/test_dram_split.py (LiteDRAM controller + SDRAMPHYModel, MT41J256M16
  @75 MHz 1:4). Two causes (trace):
  1. Refresh: LiteDRAM's MT41J256M16 has tRFC = 208 clocks of DDR3-1600 (= 260 ns) and converts CLOCKS, so at our
     DDR3-600 each refresh blocks 52 sys clocks (693 ns) every 586 -> ~9 %. Fix: litex/ddr3_module.MT41J256M16_ns,
     tRFC 350 ns (safe for 4 and 8 Gbit; board has 15 address pins = 4 Gbit x16) = 27 clocks, + LiteDRAM
     refresh_postponing=8 (JEDEC max). Sim: 84.9 -> 89.1 (tRFC) -> 90.3 % (+postponing). ypcb_soc.py item 16
     YPCB_REFRESH_FIX=1 (both channels; generated Verilog: sequencer trigger tRP+tRFC 54 -> 29, postponer count 7).
  2. Bank change: LiteDRAM's crossbar locks a port to one bank until that bank's command queue is empty, so a
     sequential reader stalls ~7 clocks per 8 KiB row (128 words). accel/litex/dramsplit.BankSplitReader (two ports,
     even/odd banks, merger) - sim: FIFO 64: worse (88.4-89.4 %: the readers share the DRAM 50/50 and the active one
     runs dry); FIFO 128: **94.0 %**; FIFO 256: 92.9 % (all with the refresh fix; that alone: 90.3 %). NOT in build_pcie2
     (more logic in the controller, the timing-critical area; not yet tested inside MVAccel) - next build candidate.
  SIM MEMORY: Migen's simulator turns every Memory word into a Signal: an SDRAMPHYModel with nrows=2048 (8 M words)
  took 14 GB and OOM-killed the session (12:30). The test now uses nrows=8 (8192 words, ~200 MB); every sim runs in
  `systemd-run --user --scope -p MemoryMax=2G -p MemorySwapMax=0`.
- Activation fast path (pcie_bridge.BridgeSys + MVAccel.pcie_aw_*): full-DW writes to an engine's activation area go
  straight to the engines' activation ports (registered at the bridge and again beside each engine), mirror -> both
  engines; one DW per 2 sys clocks instead of 2 x ~7. sim/test_pcie_bridge_sys.py extended (activation writes checked
  per engine, bases anywhere in the activation area): seeds 1-3 PASS; mutants caught: mirror dropped, vector bits,
  address bits, byte-enable check; not caught: results-window check (no test writes go there; the PC never does).
- build_pcie.sh: phase 1 place & route (PNR_JOBS, default 1, each scope 8G+2G), phase 2 FASM post + fasm2frames one at
  a time AFTER all P&R; gen 4G and yosys 8G scopes; YPCB_REFRESH_FIX default 1.
- build_pcie2 (= build_pcie1 + refresh fix + activation fast path) started 17:52, seeds 1 2.
  Expected: engines 0.327 -> ~0.307 s, activations ~0.02 -> ~0.002 s => ~0.32 s/token.
- Remaining levers after that: BankSplitReader (+~3 %), DDR3 clock (600 -> 800 MT/s = +33 %, but the board's cmd/addr
  timing was fragile at 600 and A7DDRPHY has no write leveling; per-lane DQS windows were as narrow as 30 deg), batching
  (prompt reading 4x with a B=4 engine; speculative decoding).
- **build_pcie2 RESULTS (19:08-19:30, seed 2 installed, now the default build):** synthesis 4 min, P&R 29 / 26 min, peak
  5.4 GB, fasm2frames one at a time. First try failed in placement ("Unable to find legal placement" for a LUT of the
  w_ba adder): MVAccel's pcie_aw_* INPUT signals were assigned from the bridge's registers, so those register nets
  also carried mvacc names and the floorplan put them in the engine regions, away from the adder they pack with.
  Fix: MVAccel.connect_pcie_aw() registers the bridge's own signals (no alias). Sys est: s1 37.5 MHz, s2 47.7 MHz.
  s2 on the card: ch0 8 lanes + Memtest OK, ch1 8 lanes, PCIe x8 0 errors, pcie_selftest ALL OK,
  **engine stream 84.9 -> 88.8 %** (sim predicted 90.3), chat --check 31,595,520 results 0 differ (validates the
  activation fast path too), **0.33 s/token** (engines 0.320, activations 0.001, PC 0.01); prompt 16 tokens 5 s.
- History per answer token: 3.7 s (10-18, JTAG) -> 2.38 -> 1.37 -> 0.83 (JTAG, FFN on card) -> 0.41 (PCIe) -> 0.36
  (results read during the run) -> 0.33 (refresh fix + activation fast path).
- YPCB_SPLITDMA (item 17, two-port weight feed) ready: accel/litex/test_mvaccel_split.py PASS for single and split
  (all rows of 4 back-to-back runs, done/fin/rows logic); long runs 89.8 -> 93.9 %, 89.2 -> 92.5 %.
- LESSON: never edit a running bash script (build_pcie.sh was edited while the build ran; reverted within a minute,
  bash had not read past the loop yet).

## 2026-11-03 evening: build_pcie3 (two-port feed) and faster DDR3 (user: "yes make memory faster after build 3")
- build_pcie3 = build_pcie2 + YPCB_SPLITDMA (BankSplitReader, FIFO 128). Sys est s1 41.7 / s2 44.6 MHz. On the card
  (both seeds): DDR3 both channels + PCIe OK, pcie_selftest ALL OK, **engine stream 94.5 %** (build_pcie2 88.8 %),
  BUT channel 0's engine computes wrong rows: chat weight check fails for all 160 chunks after 3 uploads, overflow
  flag. Diagnostic (layer-0 qkv, 512 rows, engine vs PC): engine 1 (channel 1) 0/512 wrong; engine 0 66-67/512
  wrong, the SAME rows on seed 1 and seed 2 (deterministic). The DRAM holds the right weights (read back over PCIe,
  0 of 30720 words differ). Bad rows = rows covering the first ~40 words of EVEN 128-word blocks right after an odd
  block, i.e. port A's prefetched words after the merger switches back from port B. Not reproduced in simulation,
  also not with 2 idle extra crossbar ports first (EXTRA=2, like ch0's main-RAM and ddr0-window ports). Open; ideas:
  ch0-only PHY latency / read_latency difference vs the model, a pattern-repeatable timing path between the ch0
  crossbar and the reader FIFOs, CPU/L2 traffic. PARKED (time box). build_pcie3 must NOT be used.
- DDR3 speed, small DDR-only SoC (litex/build_ddrfreq.sh <dir> <sys Hz> <ck> <dqs>: capped, 5 min) + phase variants
  without re-P&R (litex/ddr_phases.sh <dir> <divider> "ck:dqs ..."; PLL phase bits patched in the FASM; checked that
  it reproduces the toolchain's own encoding):
  * DDR3-800 (sys 100 MHz, VCO 1600, 11.25 deg steps): 13 CK/DQS pairs (CK 247.5-337.5, DQS 112.5-180): at best 4 of 8
    lanes read-level (+-1-3 taps), lanes m1/m4/m5/m6 never, Memtest KO everywhere -> DDR3-800 does NOT work with this
    PHY (A7DDRPHY, no write leveling on these banks).
  * DDR3-667 (sys 83.33 MHz, VCO 1000, 15 deg steps), channel 0: Memtest OK + all 8 lanes level (+-4-5 taps) for
    CK 255-270 x DQS 150-165, CK 270 x DQS 135, CK 285 x DQS 150-165, CK 300 x DQS 165; fails CK 285/300 x DQS 135,
    CK 300 x DQS 150 (lane 6), CK 315, DQS 180. Centre chosen: CK 270, DQS 150.
  * Small DUAL build at 667 (no floorplan, sys est 33.5 MHz): no BIOS output at all -> says nothing about channel 1.
- build_pcie.sh now takes SYS_FREQ / CK_PHASE / DQS_PHASE (defaults 75e6 / 292.5 / 150).
  build_pcie4 = build_pcie2 at SYS_FREQ=83.333333e6 CK_PHASE=270 DQS_PHASE=150, started 20:49 (seeds 1 2).
- Shell lessons again: `until ! pgrep -f "<pattern>"` loops match their OWN command line and never end; killing them
  with `pkill`-like loops killed my shell (exit 144). Use pid files / kill -0 <pid>.
- Memory: scratchpad oomguard.sh raises oom_score_adj to 1000 for nextpnr / yosys / fasm2frames / test sims every 10 s
  (they die first on an OOM, not the session) and logs job RSS + MemAvailable.

## 2026-11-03 night: build_pcie4 -> 80 MHz / DDR3-640 INSTALLED, 0.31 s/token (build_pcie2 0.33)
- build_pcie4 (build_pcie2 at sys 83.33 MHz, DDR3-667, CK 270 / DQS 150): P&R 31 / 28 min, sys est s1 46.9 / s2 47.4.
  * s2 at 83.33 on the card: ch0 + ch1 all 8 lanes level (ch1 +-7-8 taps), Memtest OK, PCIe x8 0 errors, selftest ALL
    OK, weights upload 33.6 MB/s. Every plain engine multiply exact (6 matrices, both engines, float32 + packed) BUT
    chat --check 1,154,222 / 9,614,592 differ: the FFN unit (silu*mul + MXINT8 quantizer, ffn_unit.v) gives ~45 %
    wrong down_proj outputs (both halves equally -> the activation image itself; mostly repeatable; rel err ~6e-3 =
    about one MXINT8 step; ffn err flag 0) -> timing failure at 83.33 MHz. Worst nextpnr path is the jtagloader, not
    the FFN, so the estimate does not point at it.
  * s1 at 83.33: packed results + FFN garbage, half the weight chunks never verify. Whole design is at its edge there.
- NEW litex/pll_patch.sh <build> <seed> <D> <M>: rewrite the main CRG PLL (clkin 200 MHz; the one with CLKOUT4)
  input divider / feedback multiplier in the finished FASM + LKTABLE / TABLE from nextpnr-xilinx's fasm.cc
  (Vivado-harvested, checked: reproduces the M=5 bits) -> no re-P&R, 3.5 min. CLKOUT dividers and phases (degrees)
  unchanged. Options with PFD >= 19 MHz and idelay ref VCO/5 in 190-210: D=4 M=19 79.17, D=5 M=24 80.00, D=6 M=29
  80.56, D=8 M=39 81.25, D=10 M=49 81.67 MHz (nothing between 81.67 and 83.33).
  * s2 at 80.00 (s2_d5m24.bit): PLL locks, both channels 8 lanes, Memtest OK, packed + FFN exact (3 layers x 2 input
    scales), **chat --check 26,684,160 results 0 differ**, **0.31 s/token, engines 0.300 s** (75 MHz: 0.320).
  * s2 at 81.67 (s2_d10m49.bit): also exact -> FFN failure point is between 81.67 and 83.33 MHz; 80 MHz keeps >= 2 %
    clock-period headroom. 81.67 not installed (would be < 2 % headroom for +2 % speed).
- INSTALLED: build_pcie4/gateware/ypcb_00338_1p1.bit = s2_d5m24.bit; fpga_chat.py / pcie_link.py default
  MUSTAQI_BUILD=build_pcie4 (backups *.pre-pcie4), FPGA_CHAT.md updated. Back: MUSTAQI_BUILD=build_pcie2.
  Card holds it WITH the weights (fpga_chat.sh --no-bit starts in seconds).
- Caveat: tREFI is in clocks for 83.33 MHz -> 8.1 us average refresh interval at 80 MHz (JEDEC 7.8 us, +4 %).
  Harmless at room temperature in practice (retention >> 64 ms) and the weights are verified at every chat start; a
  clean rebuild at SYS_FREQ=80e6 would remove it (new placement though).
- Ideas left: pipeline the FFN quantizer (one-cycle subtract + clamp + 24-bit shift + round compare) to make 83.33
  pass; the two-port feed (94.5 % stream) once the channel-0 bug is found.
- SOAK at 80 MHz (scratchpad soak2.py: random layer's FFN unit + random qkv/out matrix vs the PC, back to back):
  7.5 min then 20 min: 47,388 rounds, 364 M results, **0 differ**, but the FFN unit HUNG 2x in ~65,000 FFN runs
  (busy stays 1, err=1 = gate/up FIFO overflow). Cause FOUND (skew.py): the FFN unit pairs engine 0's gate rows with
  engine 1's up rows through 512-row FIFOs; engine 1 started 0-220 us after engine 0: always fine, >= 250 us: overflow
  every time (ERR, or HANG at >= 500 us). start(0) and start(1) were two Python calls, and a Linux interrupt between
  them occasionally delayed engine 1 that long. Host-side, not the 80 MHz clock (same at 75 MHz).
  Fixes (mustaqi, backups *.pre-pair / fpga_llm.py.pre-ffnretry): pcie_link.start_pair() writes both run parameter
  sets, then both start registers in ONE C call (c/pcie_io.c bar_write32_pair, ~100 ns apart); FpgaBackend.ffn_q
  uses it and re-runs a failed FFN (timeout 1 s on PCIe, re-sends the activations, up to 3 tries; mock-tested);
  fpga_chat prints "FFN unit re-runs N" in the link line when it happened.
  * Soak with start_pair (soak3.py, 30 min): 72,107 rounds, 554 M results, 0 differ, 0 hangs, 0 FFN re-runs (the old
    rate predicted 2-3). Final default-command check 23:40: weights all good, --check 26.7 M results 0 differ,
    0.31 s/token. Card holds build_pcie4 (80 MHz) WITH the weights.

## 2026-11-04 NeuronLM-103M on the card (user: "download it and implement it on the fpga")
- NeuronUz/NeuronLM-103M-SFT-v1 downloaded to neuronlm/hf (network only outside the Bash sandbox; HF CDN flaky:
  curl --http1.1 -C - --retry; model.safetensors + tokenizer.json SHA-256 match the repo's SHA256.json). Qwen3,
  103,488,128 F32 params: 16 layers, d 640, FFN 1728, 10 q / 5 kv heads x 64, vocab 48000 (tokenizer IDENTICAL to
  MustaqiLLM's, same sha256), tied embeddings, rope theta 1e4 (HF rotate_half pairs, NOT MustaqiLLM's interleaved).
- No gateware change. down_proj K = 1728 is not a multiple of 128: stored as K = 1792 (pad columns repeat the
  group's real columns 1664..1727 so the quantization is unchanged); the activation pad must be exact zeros
  (Q4H weight = q*s + lo -> the lo*S term needs S = 0): the FFN unit writes only 1728 activations, so
  FpgaBackend.ffn_q writes a zero K=1792 image once per backend (nothing else writes those buffer words).
- fpga_llm.use_model("mustaqi" | "neuronlm") switches module globals (DIM, LAYERS, HEADS, ..., FFN_K, ROPE_HALF,
  HF_DIR, OUT, W_OFF, CTX); MustaqiLLM path unchanged (chat --check after: 9.6 M results 0 differ). fpga_chat.py
  --model neuronlm (backups *.pre-neuron). NeuronLM weights at 1.5 GiB per channel (MustaqiLLM ends 1.34 GiB):
  both resident.
- neuronlm/ref_neuron.py: PyTorch float32 Qwen3 reference; fpga_llm.Model with float weights matches it to 3e-6
  relative over 12 positions (mutation: interleaved RoPE -> FAIL 1.1).
- On the card (build_pcie4, 80 MHz): weights 2 x 29.2 MiB uploaded in ~2 s; --check 3.2 M + 7.6 M results 0 differ;
  **17 ms/token (~58 tokens/s)**: engines + polls 14 ms (DRAM streaming alone ~6.6 ms: ~67 runs/token, ~110 us
  fixed cost each), PC 3 ms.
- Quality (neuronlm/quality.py, eval_uz.txt 237 tokens): ppl float32 12.01, card min/max Q4H 12.72 (top-1 same
  86.9 %), card with export --search (per-group clipped range, least squared error, same format) 12.43 (84.8 %) ->
  installed (out/; old out_minmax/). Capital question: float32 "Toshkent", 4-bit wrong with either quantizer;
  "3 + 2" = "2" repeated in float32 too (model). MustaqiLLM stays the default.
- Ideas: activation-aware quantization (calibration), lm_head (30.7 M tied params) in higher precision on the PC,
  fewer/larger runs per token (fixed per-run cost dominates at this size).

## 2026-11-04 Card photos: the memory chips are 2 Gbit x8
Chip markings in the front/back photos: SK hynix H5TC2G83FFR-PBA (2 Gbit, x8; by SK hynix's numbering a DDR3L part,
1.35 V, normally also fine at 1.5 V), one per byte lane = 9 per channel, 18 in total, 8 x 2 Gbit = 2 GiB per channel.
Our builds use LiteDRAM's MT41J256M16 class (same row/column geometry; what the litex-boards target used then);
current litex-boards uses MT41K256M8. The factory design and litex-boards configure the banks as SSTL15; the rail
was never measured with a meter. JEDEC tRFC for 2 Gbit is 160 ns; ddr3_module.MT41J256M16_ns uses 350 ns (chosen
before the chips were identified), so a rebuild with 160 ns should free roughly another 2.5 % of bandwidth (untested).

## 2026-11-10 Handover check: is everything needed in the repository?
- Card: factory design, link 5 GT/s **x4** again at the 11-10 boot (also 11-04; x8 at the 11-02 boot). Our design
  not loaded since 11-04, so the x8 Gen1 core is untested on this link state. Nothing running.
- Checked against this PC: sources unchanged since the first repository commit; the tool patches are identical to
  the installed trees' `git diff` (openFPGALoader, prjxray, nextpnr-xilinx; nextpnr's bundled prjxray-db has one extra
  line, XF_REFCLK_31_10 in segbits_gtx_channel_2.db = the file in pcie/db/kintex7); LiteX checkouts unmodified.
- Added: files the copy skipped by file type (litex/openocd_hs3_xc7.cfg for jtag_console.py, pcie/probe.ys now with
  relative paths, accel/sim/Makefile.ffn, tests/{phase,pllphase,diag}/rom.hex); tools/toolchain_versions.txt,
  tools/litex_commits.txt, tools/requirements-venv.txt; getting-started: check out the pinned commits, RISC-V GCC +
  OpenOCD (xPack) step; PCIe stage scripts (s1, s2, run_probe): the factory comparison is optional (flash_v3.fasm),
  a clear message when the settings files are missing, run_probe.sh no longer regenerates factory_params.vh
  (make_params.sh does); docs/status.md (state, open problems, next ideas); ddr3_module.py docstring: 2 Gbit chips.
- Not done: a full build from a fresh clone (checked by reading the scripts only).
