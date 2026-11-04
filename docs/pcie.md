# PCIe x8 without Vivado

The XC7K480T-FFG1156 has one PCIe hard block (`PCIE_2_1`, site `PCIE_X0Y0`) and 8 GTX transceiver quads. Xilinx
normally generates the PCIe "IP" with Vivado: attribute values for the hard block and transceivers, plus soft
logic around them. We had no Vivado, so we built a Gen1 x8 endpoint from the primitives, using the card's factory
design as the reference for the configuration. It links with the PC with no errors and carries the LLM traffic.

Status: **Gen1 (2.5 GT/s) x8, error-free**; our config space and BAR0 (2 MB); PC → card writes 45 MB/s from a plain
loop of 32-bit stores, 33.6 MB/s for weight uploads into DDR3; single 32-bit reads ≈ 1 µs. Gen2 is not done: the
transceivers run at 5 GT/s in loopback, but the speed change during link training isn't implemented.

## How the board is wired

| | |
|---|---|
| Transceivers | quads **115 + 116** (`GTXE2_CHANNEL_X0Y16`–`X0Y23`), not the quads Xilinx's guide recommends |
| Lane order | lane 0 = `X0Y23` … lane 7 = `X0Y16` (descending); lane pins as in `pins/board.xdc` (lane 0 = TX F2, RX H6) |
| Reference clock | 100 MHz on **MGTREFCLK0_116** (J8/J7) only; quad 115 takes it from quad 116 |
| PERST# | Y26 (LVCMOS18, pull-up) |
| PC slot | standard x8 edge; card RX is on the B-side PETp/n fingers |

We learned all of this by decoding the factory bitstream (`bit2fasm` → FASM → which tiles and features are used).
The factory design is a Gen2 x8 endpoint with a 128-bit 250 MHz user interface, BAR0 = 2 MB 64-bit,
class `0x058000`, ID `10ee:7028`.

## The configuration side

- **Attribute values:** `pcie/gen_params.py` inverts nextpnr's FASM writers (`write_gtx_channel`,
  `write_pcie_2_1`), turning the factory bitstream's features back into Verilog parameters: ~200 per transceiver,
  ~267 for the hard block. We changed only the link speed to Gen1. These values come from the factory design, so
  **they are not in this repository; you generate them from your own card** (see "Generate the settings" below). A probe design built with them (`pcie/run_probe.sh`) gives all 8 transceiver tiles and the PCIe tile
  **bit-identical** to the factory bitstream.
- **Reference-clock sharing** (quad 115 from quad 116): a few bits nextpnr can't express; `pcie/fasm_patch.py`
  adds them to the FASM. Two of them have no name in prjxray-db; we named them `XF_REFCLK_*` in our database overlay
  (`pcie/db/kintex7/`).
- **Input delays (hold fixing):** Vivado delays almost every transceiver → PCIe-block input and some inputs in the
  other direction, using `IMUX_DELAY` pips in the `GTX_INT_INTERFACE` / `PCIE_INT_INTERFACE` tiles. prjxray-db has
  no Kintex-7 GTX interface file; the Artix-7 GTP one, renamed, decodes all 288 such factory bits
  ([toolchain-bugs.md](toolchain-bugs.md) #10). `pcie/s2/delay_patch.py` adds the same delays (309 + 240) to our FASM.
- **Every transceiver input tied explicitly.** An unconnected GT input is left unrouted and reads 1 (Vivado would
  tie it to the default). `pcie/s1/factory_ties.py` recovered the factory's ties for all ~330 inputs per lane
  (e.g. `CPLLREFCLKSEL = 001`, manual multi-lane TX phase alignment, LPM receiver).
- **The hard block's buffer RAMs** must sit where the factory design has them (`RAMB36_X10Y40/41` TX,
  `X10Y43/44` RX), read through the output register.

## Toolchain bugs this hit

- **`CPLLREFCLKSEL` disconnected by nextpnr:** the CPLL would never have locked. Patched.
- **Block-RAM output-register clock never connected:** the link came up, but the hard block read all zeros from
  its RX buffer RAM, so the PC never got answers to configuration reads. Patched (fixed upstream since).
- **litex-boards' `pcie_x8` resource had lane 6 RX_N on E3 instead of R3** (fixed upstream since). We use our own
  resource `ypcb_pcie_x8` in `litex/pcie_bridge.py`.

Details: [toolchain-bugs.md](toolchain-bugs.md).

## The stages

| Stage | Folder | What it proved |
|---|---|---|
| Probe | `pcie/probe_top.v`, `run_probe.sh` | configuration bits identical to the factory (software only, never loaded) |
| 1 | `pcie/s1/` | all 8 transceivers: CPLLs lock, reset sequence 1.6 ms, manual multi-lane TX alignment; near-end loopback, 3.6e12 bits at 2.5 and 5 GT/s, **0 errors** |
| 2 | `pcie/s2/` | x8 Gen1 link with the PC in 1.4 ms; then (after the BRAM fix) the PC reads **our** config space |
| 3 | `pcie/s2/bar0.v`, `host/bar_test.py` | BAR0 writes and reads: 67 million write packets, exact checksums, 0 link errors |
| Integration | `pcie/core/`, `litex/pcie_bridge.py` | PCIe in the LiteX LLM SoC (`build_pcie*`) |

The integrated core: `pcie/core/pcie_x8.v` (transceivers + hard block + buffer RAMs + reset sequencer + TX
alignment) and `pcie/core/pcie_trn_bridge.v` (packet parser → one in-order command stream, completions; checked
with random-traffic simulation, `pcie/core/sim/`). `litex/pcie_bridge.py` maps BAR0 to seven movable 256 KB windows
onto the SoC bus plus a register slot. The PC side is `mustaqi/pcie_link.py` with `mustaqi/c/pcie_io.c`
(64-byte `MOVDIR64B` writes and 32-byte AVX2 reads, one PCIe packet each).

## The Linux side

There's no driver: the PC maps BAR0 (`/sys/bus/pci/devices/0000:01:00.0/resource0`) into user space.

- **After every FPGA reload** the PC must re-find the card: `sudo pcie/pcie_rescan.sh` (remove + rescan, root port
  powered on, memory decode enabled, `resource0` handed to your user). The chat program runs it for you.
- Boot the PC once with the card on its factory design, so the BIOS assigns the 2 MB window. A rescan with our
  design loaded may otherwise find no window to assign.
- A root port with nothing behind it can be runtime-suspended (D3hot) and then forwards no config requests; the
  rescan script sets it to `on`.
- Reloading the FPGA while the PC runs only ever caused a few *correctable* PCIe errors. Never remove the card
  while the PC is on.
- Python's `memcpy` onto the mapped BAR sent one byte per packet; write with 32-bit or wider stores
  (`pcie_io.c`).

## Build

### Generate the settings (once)

The PCIe block and transceiver settings are read from your own card's factory design. With the card running it
(the state after power-on; both steps only read):

```bash
python3 tools/readback.py factory.bin <any full .bit built with this flow, as a template> factory.bit   # ~11 s
pcie/make_params.sh factory.bit                                                                         # ~2 min
```

This writes `pcie/factory_params.vh`, `pcie/s2/s2_params.vh` and `pcie/core/pcie_x8_params.vh`. All the PCIe designs
include them, and `git` ignores them. Keep them, and `factory.bit`, to yourself: they come from the makers' design.
We checked the script against our own files: the output is byte-identical.

### Place and route

First create the database overlay once: `pcie/db/make_overlay.sh` (symlinks to nextpnr's prjxray-db plus our
6 changed files → `pcie/db/kintex7_llm`).

`litex/build_pcie.sh <outdir> [seeds]`: LiteX LLM SoC + PCIe with the floorplan (`litex/floorplan_half4.py`), then
unused pins → VREF → refclk patch → delay patch → `fasm2frames` with the database overlay `pcie/db/kintex7_llm`
(nextpnr's prjxray-db plus the 6 files in `pcie/db/kintex7`). About 75 minutes and 10 GB of memory per seed.
`litex/pcie_candidate.sh <build> <bit>` then loads a candidate and checks DDR3 on both channels and the link state
over JTAG, before any PCIe access.
