#!/bin/bash
# Small DDR3-only SoC (build.sh defaults: CPU + channel 0, 8 lanes, BIOS read leveling + memtest) at another sys clock,
# to find out whether the board's DDR3 runs faster than DDR3-600 (sys 75 MHz) before touching the LLM design.
#   build_ddrfreq.sh <outdir> <sys_clk_hz> [ck_phase dqs_phase]
# Every step memory-capped; fasm2frames under the shared lock (never two at once). Phase variants without re-P&R:
# ddr_phases.sh. Then: YPCB_BUILD=<outdir> ./boottest.sh <bit>.
set -e
cd "$(dirname "$0")"
. ./env.sh
OUT=$(readlink -f "$1"); F=$2
export YPCB_ZIDLE=1 YPCB_CK_PHASE=${3:-292.5} YPCB_DQS_PHASE=${4:-150} YPCB_LANES=0,1,2,3,4,5,6,8
P=xc7k480tffg1156-2
DB=$PRJXRAY_DB_DIR/kintex7
G=$OUT/gateware
systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=0 python ypcb_soc.py --toolchain openxc7 \
    --sys-clk-freq "$F" --uart-name jtag_uart --output-dir "$OUT" --build --no-compile-gateware \
    > "gen_$(basename "$OUT").log" 2>&1
sed 's/synth_xilinx -flatten -abc9 -arch/synth_xilinx -flatten -abc9 -nosrl -arch/' $G/ypcb_00338_1p1.ys > $G/ypcb_fixed.ys
{ cat $G/ypcb_00338_1p1.xdc; echo
  echo "set_property BEL PLLE2_ADV_X0Y1/PLLE2_ADV [get_cells PLLE2_ADV]"; } > $G/ypcb_fixed.xdc
cd $G
systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=1G yosys -q -l ypcb_00338_1p1.rpt ypcb_fixed.ys
MHZ=$(python3 -c "print(int($F / 1e6))")
systemd-run --user --scope -q -p MemoryMax=4G -p MemorySwapMax=1G timeout 2400 nextpnr-xilinx --json ypcb_00338_1p1.json \
    --xdc ypcb_fixed.xdc --fasm ypcb_00338_1p1.fasm --chipdb $CHIPDB/$P.bin --timing-allow-fail --seed 1 --freq $MHZ \
    --log pnr.log > /dev/null 2>&1
python3 ~/celestica/tools/unused_pins.py ypcb_00338_1p1.fasm ypcb_00338_1p1_pn0.fasm > /dev/null
sed "s/\.VREF\.V_675_MV$/.VREF.V_750_MV/" ypcb_00338_1p1_pn0.fasm > ypcb_00338_1p1_pn.fasm
flock ${TMPDIR:-/tmp}/fasm2frames.lock systemd-run --user --scope -q -p MemoryMax=6G -p MemorySwapMax=2G \
    fasm2frames --part $P --db-root $DB ypcb_00338_1p1_pn.fasm > ypcb_00338_1p1.frames
xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file ypcb_00338_1p1.frames \
    --output_file ypcb_00338_1p1.bit
rm -f ypcb_00338_1p1.frames ypcb_00338_1p1_pn0.fasm
grep "Max frequency" pnr.log | tail -4
ls -la ypcb_00338_1p1.bit
