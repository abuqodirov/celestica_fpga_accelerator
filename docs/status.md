# Project status and next steps (2026-11-10)

Where the project stands, what is not in the repository, the known problems and the next ideas. Start here if you
take the project over. The full history is in [engineering-log.md](engineering-log.md).

## What runs today

| | |
|---|---|
| Design | `build_pcie4`: LiteX SoC with both DDR3 channels (4 GiB), two matrix-vector engines, the FFN unit and our PCIe Gen1 x8 core, at **80 MHz logic / DDR3-640** |
| MustaqiLLM 5.17B | **0.31 s/token**, bit-exact with the PC reference (`--check`: 26.7 M results, 0 different) |
| NeuronLM-103M | **17 ms/token** (~58 tokens/s), bit-exact |
| Soak | 30 min, 554 M results, 0 different, 0 FFN-unit failures |

How `build_pcie4` was made (it is `build_pcie2`'s design built for 83.33 MHz, then run at 80 MHz because the FFN
unit fails timing at 83.33):

```bash
. litex/env.sh
SYS_FREQ=83.333333e6 CK_PHASE=270 DQS_PHASE=150 litex/build_pcie.sh build_pcie4 1 2   # ~75 min, 10 GB per seed
litex/pll_patch.sh build_pcie4 2 5 24        # seed 2 -> 80 MHz without re-routing: build_pcie4/gateware/seeds/s2_d5m24.bit
cp litex/build_pcie4/gateware/seeds/s2_d5m24.bit litex/build_pcie4/gateware/ypcb_00338_1p1.bit   # what fpga_chat loads
litex/pcie_candidate.sh build_pcie4 build_pcie4/gateware/ypcb_00338_1p1.bit                      # DDR3 + link check
```

Every place-and-route seed is different: check each new bitstream on the card (`pcie_candidate.sh`, then
`mustaqi/pcie_selftest.py` and `fpga_chat.sh --check`) before trusting it. Prerequisites: the PCIe settings files
([pcie.md](pcie.md), "Generate the settings") and the database overlay (`pcie/db/make_overlay.sh`).

## Daily routine with the card

```bash
cat /sys/bus/pci/devices/0000:01:00.0/current_link_{speed,width}   # after boot: factory design, expect 5.0 GT/s x8
mustaqi/fpga_chat.sh                     # first run after boot: loads the design, sudo PCIe rescan, weight upload
mustaqi/fpga_chat.sh --no-bit            # later runs: design and weights still on the card
mustaqi/fpga_chat.sh --model neuronlm    # the small model
mustaqi/fpga_factory.sh                  # ALWAYS before shutting the PC down: card back to its factory design
```

Rules we kept: never remove the card while the PC is on; never write the flash without a backup (`pins/flashdump`,
read-only); only drive pins that are verified in `pins/board.xdc`; every big job (place and route, `fasm2frames`,
simulations, the model scripts) in a memory-capped `systemd-run --user --scope -p MemoryMax=...`, and never two
`fasm2frames` at once (each needs ~10 GB) — see [lessons.md](lessons.md).

## Not in this repository (you make it)

| What | How |
|---|---|
| PCIe and transceiver settings (read from the card's factory design) | `pcie/make_params.sh` ([pcie.md](pcie.md)) |
| Factory comparison file for the PCIe stage scripts (optional) | [pcie.md](pcie.md), "Optional: compare with the factory design" |
| Model weights | download + `mustaqi/export_q4h.py`, `neuronlm/export_q4h_neuron.py` ([llm-accelerator.md](llm-accelerator.md)) |
| Bitstreams | build them (above); none are published |
| Engine test data, simulation vectors (made from the weights) | `accel/host/acc_test.py`; `mustaqi/accel_vectors.py`, `mustaqi/ffn_vectors.py` |
| Toolchain | [getting-started.md](getting-started.md); exact versions in `tools/toolchain_versions.txt` |

Not yet done: a complete build from a fresh clone of this repository. On 2026-11-10 we checked by reading the
scripts that every file they need is in the repository or made by the steps above, but did not run the build.

## Known problems

1. **PCIe link x4 since 11-04.** At the PC boots on 11-04 and 11-10 the factory design trained only x4 at 5 GT/s
   (x8 before). Cause unknown: card seating, slot or BIOS. Our x8 Gen1 design has not been loaded since. First
   check: reboot, read the link width; if still x4, switch the PC off and reseat the card.
2. **Two-port DRAM reader, channel-0 bug** (`YPCB_SPLITDMA`, `accel/litex/dramsplit.py`, build_pcie3). Streams
   94.5 % of peak (now 88.8 %), but engine 0 computes ~66 of 512 rows wrong in a layer-0 test, the same rows on
   both seeds; the DRAM holds the right weights; not reproduced in simulation (`litex/sim/test_dram_split.py`).
   The bad rows cover the first ~40 words of even 128-word blocks right after an odd block, i.e. port A's
   prefetched words after the merger switches back from port B. Parked; do not use build_pcie3.
3. **FFN unit timing at 83.33 MHz.** ~45 % wrong outputs at 83.33 MHz, exact at 81.67 and 80 MHz. The other seed
   failed more widely at 83.33, so other paths are close too. nextpnr's timing estimate did not point at the FFN
   unit: measure on the card.
4. **Refresh interval 4 % long.** `build_pcie4`'s refresh clocks were computed for 83.33 MHz; at 80 MHz the average
   interval is 8.1 µs instead of 7.8 µs. Harmless at room temperature in practice; a build at `SYS_FREQ=80e6`
   removes it.
5. **DDR3 lane failures depend on the placement:** about 1 in 10 channel-0 and 3 in 7 channel-1 builds lose a
   group of lanes. Cause unknown; check every build ([ddr3.md](ddr3.md)).
6. **Limits:** DDR3-800 does not work with this PHY (no write leveling on these banks); PCIe Gen2 is not done;
   nextpnr's timing estimates for the PCIe clocks fail (95/97 MHz vs 125/250 MHz) while the hardware runs clean.
7. **NeuronLM at 4 bits** loses quality (perplexity 12.43 vs 12.01 in float32) and its speed is limited by the fixed
   cost of ~67 engine runs per token.

## Next ideas (estimates, none tested)

| Idea | Gain | Work |
|---|---|---|
| Refresh time 160 ns instead of 350 ns (the chips are 2 Gbit: SK hynix H5TC2G83FFR) | ~+2.5 % | one value in `litex/ddr3_module.py`, rebuild; memory test + `--check` catch a too-short value |
| Fix the two-port reader's channel-0 bug (problem 2) | ~+6 % | debugging, open-ended |
| Pipeline the FFN unit's quantizer (subtract, clamp, 24-bit shift and round compare are one cycle now) to reach 83.33 MHz | ~+4 % | RTL + rebuild; other paths may fail at that clock |
| NeuronLM: fewer, larger engine runs per token | large for NeuronLM | host software + engine registers |
| Try [openXC7/nextpnr](https://github.com/openXC7/nextpnr) (himbaechel) instead of the archived nextpnr-xilinx | maintenance | the GT fix is still needed ([toolchain-bugs.md](toolchain-bugs.md)) |
