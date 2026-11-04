#!/bin/bash
# Build the pin-scan bitstream. Usage: build.sh PULLUP|PULLDOWN   -> scan_<pull>.bit
set -euo pipefail
cd "$(dirname "$0")"
PULL=${1:?PULLUP or PULLDOWN}
T=~/tools; P=xc7k480tffg1156-2; DB=$T/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7
mkdir -p build
sed "s/@LEDPULL@/$PULL/" scan.xdc.in > build/scan_$PULL.xdc
[ build/scan.json -nt top.v ] || yosys -q -l build/yosys.log \
    -p "synth_xilinx -flatten -abc9 -nosrl -arch xc7 -top top; write_json build/scan.json" top.v
$T/nextpnr-xilinx/build/nextpnr-xilinx --chipdb $T/chipdb/$P.bin --xdc build/scan_$PULL.xdc \
    --json build/scan.json --fasm build/scan_$PULL.fasm --freq 200 --log build/pnr_$PULL.log >/dev/null
python3 ../../tools/unused_pins.py build/scan_$PULL.fasm build/scan_${PULL}_pn.fasm
$T/venv/bin/python $T/prjxray/utils/fasm2frames.py --part $P --db-root $DB \
    build/scan_${PULL}_pn.fasm > build/scan_$PULL.frames 2>/dev/null
$T/prjxray/build/tools/xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P \
    --frm_file build/scan_$PULL.frames --output_file scan_$PULL.bit
grep -E "Max frequency" build/pnr_$PULL.log | tail -5
