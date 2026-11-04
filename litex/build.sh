#!/bin/bash
# Generate + build a LiteX SoC for the card with all board fixes.
# usage: build.sh <outdir> [extra ypcb_soc.py args]
# env:   board defaults for working DDR3 (see NOTES "DDR3 FIXED"): YPCB_ZIDLE=1, YPCB_CK_PHASE=292.5,
#        YPCB_DQS_PHASE=150, YPCB_LANES=0,1,2,3,4,5,6,8 (64-bit / 2 GiB; lane 7 never levels, the ECC
#        chip stands in) (set YPCB_ZIDLE= / YPCB_CK_PHASE= empty to disable); YPCB_BIST=1 for BIST cores;
#        other debug options are documented at the top of ypcb_soc.py
set -e
cd "$(dirname "$0")"
. ./env.sh
OUT=$1; shift
export YPCB_ZIDLE=${YPCB_ZIDLE-1}
export YPCB_CK_PHASE=${YPCB_CK_PHASE-292.5}
export YPCB_DQS_PHASE=${YPCB_DQS_PHASE:-150}
export YPCB_LANES=${YPCB_LANES:-0,1,2,3,4,5,6,8}
[ -z "$YPCB_ZIDLE" ] && unset YPCB_ZIDLE
[ -z "$YPCB_CK_PHASE" ] && unset YPCB_CK_PHASE
python ypcb_soc.py --toolchain openxc7 --sys-clk-freq 75e6 --uart-name jtag_uart --output-dir "$OUT" \
    --build --no-compile-gateware "$@" > "gen_$(basename "$OUT").log" 2>&1
G=$OUT/gateware
sed 's/synth_xilinx -flatten -abc9 -arch/synth_xilinx -flatten -abc9 -nosrl -arch/' \
    $G/ypcb_00338_1p1.ys > $G/ypcb_fixed.ys
{ cat $G/ypcb_00338_1p1.xdc; echo
  echo "# Board fix: PLL next to the 200 MHz input (bank 12, clock region 1)."
  echo "set_property BEL PLLE2_ADV_X0Y1/PLLE2_ADV [get_cells PLLE2_ADV]"; } > $G/ypcb_fixed.xdc
if [ -n "$YPCB_LOOP" ]; then   # pad-loop ISERDES must sit in the ILOGIC of their own pad (OFB is a local wire)
python3 - "$G/ypcb_fixed.xdc" <<'PY'
import csv, sys
pp = {r["pin"]: r["site"] for r in csv.DictReader(open(
    "$HOME/tools/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7/xc7k480tffg1156-2/package_pins.csv"))}
pins = {"cs_n0": "AK28", "ras_n0": "AJ29", "cas_n0": "AP26", "we_n0": "AN27",
        "ba0": "AM26", "ba1": "AP24", "ba2": "AN28"}
pins.update({f"a{i}": p for i, p in enumerate("AK27 AN23 AL24 AK26 AH24 AH25 AL26 AJ24 AJ25 AM23".split())})
with open(sys.argv[1], "a") as f:
    for n, p in pins.items():
        f.write(f"set_property BEL {pp[p].replace('IOB', 'ILOGIC')}/ISERDESE2 [get_cells loop_iserdes_{n}]\n")
PY
fi
cp build_75/gateware/build_fixed.sh $G/
$G/build_fixed.sh > $G/build_fixed.log 2>&1
grep "Max frequency" $G/pnr.log | tail -3
ls -la $G/ypcb_00338_1p1.bit
