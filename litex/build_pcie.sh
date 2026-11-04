#!/bin/bash
# LLM SoC (= build_dacc12 options, without the JTAG result reader) + PCIe Gen1 x8 (YPCB_PCIE, pcie_bridge.py):
# generate + synthesize, then place & route each seed with the PCIe post-processing of ../pcie/s2/build.sh:
#   pin map of the PCIe / GT inputs (post-route script) -> unused pins PULLNONE -> DDR3 VREF 750 mV ->
#   quad-115 refclk sharing (../pcie/fasm_patch.py) -> PIPE/TRN input delays (../pcie/s2/delay_patch.py) ->
#   fasm2frames with ../pcie/db/kintex7_llm (= the LLM flow's database + the PCIe/GT overlay files)
# usage: build_pcie.sh <outdir> [seed ...]     (default seed 1)
#   SKIP_GEN=1: reuse <outdir>'s synthesized netlist
#   PNR_JOBS=n: place & route jobs at once (default 1). MEMORY: every step runs in its own memory-capped scope, and the
#   ~10 GB fasm2frames steps run one at a time and only AFTER all place & route has finished (2026-11-02 two
#   overlapping fasm2frames OOM-killed the whole session).
#   YPCB_REFRESH_FIX (default 1, ypcb_soc.py item 16): DDR3 refresh with tRFC in ns + postponing 8 (build_pcie2+;
#   build_pcie1 was built before it existed: YPCB_REFRESH_FIX=0 reproduces it, apart from pcie_bridge.py's activation
#   fast path)
# Does NOT load anything onto the board.
set -e
cd "$(dirname "$0")"
. ./env.sh
OUT=$(readlink -f "$1"); shift
SEEDS=${*:-1}
P=xc7k480tffg1156-2
DB=$HOME/celestica/pcie/db/kintex7_llm
PCIE=$HOME/celestica/pcie
[ -f $PCIE/factory_params.vh ] && [ -f $PCIE/core/pcie_x8_params.vh ] || {
    echo "missing PCIe parameter files: run pcie/make_params.sh <your card's factory bitstream> first (docs/pcie.md)"; exit 1; }
export YPCB_DUAL=1 YPCB_JTAGLOAD=1 YPCB_ACCEL=1 YPCB_DDR0WIN=1 YPCB_BUSPIPE=1 YPCB_FFN=1 YPCB_PCIE=1
export YPCB_REFRESH_FIX=${YPCB_REFRESH_FIX-1}
[ -n "$YPCB_SPLITDMA" ] && export YPCB_SPLITDMA        # item 17 (two-port weight feed), off unless set
[ "$YPCB_REFRESH_FIX" = 0 ] && unset YPCB_REFRESH_FIX
PNR_JOBS=${PNR_JOBS:-1}
# SYS_FREQ (default 75e6 = DDR3-600) / CK_PHASE / DQS_PHASE: DDR3-667 = SYS_FREQ=83.333333e6 CK_PHASE=270 DQS_PHASE=150
# (window from litex/ddr_phases.sh on the small build_ddr667, NOTES 2026-11-03 evening; phases in 15 deg steps there)
SYS_FREQ=${SYS_FREQ:-75e6}
FREQ_MHZ=$(python3 -c "print(round($SYS_FREQ / 1e6, 2))")
export YPCB_ZIDLE=1 YPCB_CK_PHASE=${CK_PHASE:-292.5} YPCB_DQS_PHASE=${DQS_PHASE:-150} YPCB_LANES=0,1,2,3,4,5,6,8
G=$OUT/gateware
if [ -z "$SKIP_GEN" ]; then
    systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 python ypcb_soc.py --toolchain openxc7 --sys-clk-freq $SYS_FREQ --uart-name jtag_uart --output-dir "$OUT" \
        --build --no-compile-gateware > "gen_$(basename "$OUT").log" 2>&1
    sed 's/synth_xilinx -flatten -abc9 -arch/synth_xilinx -flatten -abc9 -nosrl -arch/' \
        $G/ypcb_00338_1p1.ys > $G/ypcb_fixed.ys
    { cat $G/ypcb_00338_1p1.xdc; echo
      echo "# Board fix: PLL next to the 200 MHz input (bank 12, clock region 1)."
      echo "set_property BEL PLLE2_ADV_X0Y1/PLLE2_ADV [get_cells PLLE2_ADV]"
      echo "# PCIe clocks (pcie_x8.v): pclk 125 MHz, userclk 250 MHz (one of the two pclk names matches)"
      echo "create_clock -period 8.0 [get_nets pcie_clk]"
      echo "create_clock -period 8.0 [get_nets pciebridge_pcie_pclk]"
      echo "create_clock -period 4.0 [get_nets pcie_core.userclk]"; } > $G/ypcb_fixed.xdc
    echo "$(date +%T) synthesis"
    (cd $G && systemd-run --user --scope -q -p MemoryMax=8G -p MemorySwapMax=2G yosys -q -l ypcb_00338_1p1.rpt ypcb_fixed.ys)
    grep -A60 "Number of cells" $G/ypcb_00338_1p1.rpt | grep -E "GTX|PCIE|RAMB|DSP|BUFG|LUT6 " | tail -8
fi
mkdir -p $G/seeds
cd $G/seeds
# ---- phase 1: place & route (PNR_JOBS at once, each capped at 8 GB + 2 GB swap: keep PNR_JOBS=1 unless its peak
#      was measured small - two capped jobs must still fit the PC's 14 GB together)
for s in $SEEDS; do
  while [ "$(jobs -rp | wc -l)" -ge "$PNR_JOBS" ]; do sleep 10; done
  (
    set +e
    t0=$(date +%s)
    PINMAP_OUT=s$s.pinmap systemd-run --user --scope -q -p MemoryMax=8G -p MemorySwapMax=2G timeout 3600 nextpnr-xilinx --json ../ypcb_00338_1p1.json --xdc ../ypcb_fixed.xdc \
        --fasm s$s.fasm --chipdb $CHIPDB/$P.bin --timing-allow-fail --seed $s --freq $FREQ_MHZ \
        --pre-place $HOME/celestica/litex/floorplan_half4.py --post-route $PCIE/s2/pinmap_route.py \
        --log s$s.pnr.log > /dev/null 2>&1
    rc=$?
    if [ $rc -ne 0 ] || [ ! -s s$s.fasm ]; then
        rm -f s$s.bit s$s.fasm
        echo "$(date +%T) seed $s: place & route FAILED (nextpnr exit $rc: $(grep -m1 -o 'ERROR.*' s$s.pnr.log | cut -c1-90))"
    else
        echo "$(date +%T) seed $s: routed in $(( ($(date +%s) - t0) / 60 )) min;" \
             "$(grep 'Max frequency for clock' s$s.pnr.log | tail -4 | sed 's/Info: Max frequency for clock//' | tr -s ' ' | tr '\n' ';')"
    fi
  ) &
done
wait
# ---- phase 2: FASM post-processing + bitstream, one seed at a time (fasm2frames ~10 GB)
set +e
for s in $SEEDS; do
    [ -s s$s.fasm ] || continue
    python3 $HOME/celestica/tools/unused_pins.py s$s.fasm s$s.pn0.fasm > /dev/null
    sed "s/\.VREF\.V_675_MV$/.VREF.V_750_MV/" s$s.pn0.fasm > s$s.pn1.fasm
    python3 $PCIE/fasm_patch.py s$s.pn1.fasm s$s.rc.fasm
    PCIE_DB=$DB python3 $PCIE/s2/delay_patch.py s$s.rc.fasm s$s.pinmap s$s.pn.fasm
    flock ${TMPDIR:-/tmp}/fasm2frames.lock systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=3G \
        fasm2frames --part $P --db-root $DB s$s.pn.fasm > s$s.frames 2> s$s.f2f.log
    xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file s$s.frames --output_file s$s.bit > /dev/null
    rm -f s$s.frames s$s.fasm s$s.pn0.fasm s$s.pn1.fasm s$s.rc.fasm
    echo "$(date +%T) seed $s: $([ -s s$s.bit ] && echo "bitstream s$s.bit" || echo "bitstream FAILED")"
done
