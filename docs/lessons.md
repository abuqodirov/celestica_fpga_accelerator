# Practical lessons

Things that cost us time and would cost you time too.

## Use the factory design as your reference

The card's factory design (loaded from flash at power-on) is a working, Vivado-built design for exactly this
board. With prjxray's `bit2fasm` you can decode it (from a JTAG readback, `tools/readback.py`, or from a flash
backup) and learn:
- which pins are used, with which I/O standards (our `pins/board.xdc` was checked against it);
- how the transceivers and the PCIe block are configured, attribute by attribute (`pcie/gen_params.py`);
- which hold-fixing delays Vivado added, and which bits the open database can't decode yet.

Building a probe design and diffing its bits against the factory's, tile by tile (`pcie/compare_tiles.py`), got
PCIe right before we ever loaded it. JTAG readback of the *running* chip also shows block-RAM contents, which
helped find the BRAM output-register bug.

## Patch the finished design instead of rebuilding

A big design takes 75 minutes of place and route. Many experiments only need a few configuration bits changed in
the routed FASM file, and then only `fasm2frames` (3–4 min):
- PLL phases (DDR3 CK/DQS sweeps: `litex/ddr_phases.sh`);
- PLL frequency, to measure real timing margin or run a design at a different clock (`litex/pll_retime.py`,
  `litex/pll_patch.sh`; lock and filter tables from nextpnr-xilinx's `fasm.cc`);
- VREF, unused-pin pulls, refclk sharing, input delays (all post-processing steps in the build scripts).

## nextpnr's timing estimate is very pessimistic on this chip

Designs estimated at 42–48 MHz run correctly at 75–80 MHz (a factor of 1.6–1.8). Use the estimate only to compare
builds of the same design. To find the real limit, re-clock a finished bitstream and test it: our LLM design is
exact at 80 and 81.67 MHz and fails at 83.33 MHz.

## Memory use of the tools (16 GB PC)

| Step | Peak memory |
|---|---|
| chip database generation | ~13 GB |
| nextpnr, LLM design | ~5.5 GB |
| fasm2frames (pure Python), LLM design | ~10 GB |
| Migen simulation with a big memory | unbounded (see below) |

Two `fasm2frames` at once ran the PC out of memory, and the kernel killed the whole desktop session. Run every
heavy step in a memory-capped scope so an overflow kills only that step:

```bash
systemd-run --user --scope -p MemoryMax=10G -p MemorySwapMax=3G fasm2frames ...
```

and serialise the big ones (`flock /tmp/fasm2frames.lock ...`, as the build scripts do).

**Migen's simulator turns every word of a `Memory` into its own signal.** A LiteDRAM PHY model with a realistic
memory size used 14 GB. Keep simulated memories tiny (a few thousand words); `litex/sim/test_dram_split.py` shows
how (8 rows, small address width).

## Floorplanning by net name

`litex/floorplan_half4.py` assigns cells to regions by the prefix of their net names. When one module's signal is
assigned combinationally from another module's register, both nets can end up with the *other* module's name,
and cells get pulled into the wrong region. nextpnr then failed with "Unable to find legal placement" (a carry
chain split between two regions). Fix: register the signal at the module boundary instead of aliasing it.

## Testing

- **Make tests fail on purpose.** For every checker, break the thing it checks (a mutant) and confirm the test
  catches it: a wrong RoPE pairing, a swapped byte enable, a wrong window offset. This found gaps in several of
  our checkers, e.g. a test whose random addresses never exercised the bits it was meant to check.
- **Bit-exact reference.** The engines and the PC reference compute exactly the same arithmetic, so every result
  can be compared bit for bit, at any time (`fpga_chat --check`). That turned "the answer looks a bit off" into
  "row 12 of layer 3 differs".
- **DDR3 keeps its contents across FPGA reloads (mostly).** A test that writes the same data to the same address
  every run can pass with a broken write path. Use fresh, random locations.
- **Re-check hardware results after changing the clock**, including rare events: a 7-minute soak found an FFN
  failure that short tests never showed (it turned out to be host-side timing, below).

## Host side

- **Python's `memcpy` into a PCIe BAR** sent one byte per packet. Use 32-bit, 64-byte (`MOVDIR64B`) or 32-byte
  AVX stores (`mustaqi/c/pcie_io.c`).
- **Linux can pause your program at any point** for hundreds of microseconds. If two register writes must land
  close together (both engines' start bits), write them in one C call, not two Python calls.
- **JTAG reads at 30 MHz** fail with the HS3's default sampling edge; falling-edge sampling works
  (`mustaqi/fpga_link.py`).
- **The nextpnr-xilinx build directory uses Ninja.** `make` there silently does nothing; use `ninja -C build`.

## Shell

- Never edit a bash script while it runs: bash reads the file as it executes, and an edit above the current line
  makes it run garbage later.
- `pgrep -f PATTERN` / `pkill -f PATTERN` also match your own shell when its command line contains the pattern.
  Wait on a PID (`kill -0 $pid`) instead.
