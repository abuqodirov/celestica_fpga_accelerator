# Toolchain patches

The changes we made to the open-source tools to get this card working. What each one fixes, and whether it is
still needed with current upstream versions, is explained in [`../docs/toolchain-bugs.md`](../docs/toolchain-bugs.md).

| File | Applies to | What it does | Still needed? |
|---|---|---|---|
| `yosys-0.52-brams_xc6v_map.diff` | yosys 0.52 (`share/yosys/xilinx/brams_xc6v_map.v`) | RAMB36 72-bit SDP parity typo `== 71` → `== 72` | No with yosys ≥ 0.65 |
| `nextpnr-xilinx.diff` | openXC7/nextpnr-xilinx `bc9b234` (archived) | see below | Partly (see below) |
| `openFPGALoader-xadc-kintex7.diff` | trabucayre/openFPGALoader `efb64ff` | allow `--read-xadc` on Kintex-7 | Yes |
| `prjxray-gcc15.diff` | f4pga/prjxray `c9f02d8` | build with GCC 15 (`<cstdint>`, no `-Werror`) | Until PR #2556 is merged |

`nextpnr-xilinx.diff` contains four independent changes:

| File | Change | Needed with openXC7/nextpnr (himbaechel)? |
|---|---|---|
| `xilinx/fasm.cc` | RAMB36 72-bit SDP write: emit `WRITE_WIDTH_A_18` | No, fixed there |
| `xilinx/pack.cc` | connect BRAM output-register clocks `REGCLKARDRCLK`/`REGCLKB` when `DO*_REG=1` | No, fixed there |
| `xilinx/pack_gt_xc7.cc` | keep `CPLLREFCLKSEL` connected (not a clock input) | Yes, until PR #83 or similar is merged |
| `xilinx/arch.cc` | **debug only**, off by default: `NPNR_HARD_TIMING=1` times PCIe-block ↔ BRAM paths with *assumed* numbers; `NPNR_HARD_TIMING_DUMP=<file>` writes their routed delays | Not for upstream |

Apply with `git apply` in the tool's source tree, then rebuild. The nextpnr-xilinx build directory uses Ninja:
run `ninja -C build`; `make` silently does nothing there.

The VREF problem (0.675 V written for 1.5 V DDR3) is not patched in the tool. Every build script here fixes the
FASM file instead:

    sed 's/\.VREF\.V_675_MV$/.VREF.V_750_MV/' in.fasm > out.fasm
