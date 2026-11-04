#!/bin/bash
# Placement-only trial of a floorplan (~4 min): place, report block positions + long nets, stop before routing.
# usage: place_try.sh <build> <floorplan.py> <outdir> [seed]  -> <outdir>/placement_report.txt, place.log
B=$(readlink -f "$1"); FP=$(readlink -f "$2"); O=$3; SEED=${4:-1}
mkdir -p "$O"; cd "$O" || exit 1
. ~/celestica/litex/env.sh
G=$B/gateware
timeout 900 nextpnr-xilinx --json $G/ypcb_00338_1p1.json --xdc $G/ypcb_fixed.xdc \
    --chipdb $CHIPDB/xc7k480tffg1156-2.bin --timing-allow-fail --seed $SEED --freq 75 \
    --pre-place "$FP" --pre-route ~/celestica/litex/placement_report.py --log place.log > stdout.txt 2>&1
grep -h "constrained cells\|^floorplan" stdout.txt place.log | head -1
grep "Max frequency.*clkout_buf0" place.log | tail -1
sed -n "1,/^nets with/p" placement_report.txt
sed -n '/^by (driver/,/^$/p' placement_report.txt | head -12
