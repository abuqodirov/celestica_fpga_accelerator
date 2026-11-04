#!/bin/bash
# Build PCIe stage 1 (build/s1.bit) and check it against the factory design. Does NOT load it.
set -e
cd "$(dirname "$0")"
. ~/celestica/litex/env.sh
P=xc7k480tffg1156-2
DB=$PWD/../db/kintex7          # overlay DB, see ../db/README.txt
mkdir -p build
yosys -q -l build/yosys.log -p "read_verilog -I .. s1_top.v; synth_xilinx -flatten -abc9 -nosrl -arch xc7 -top s1_top; stat; write_json build/s1.json"
timeout 1800 nextpnr-xilinx --json build/s1.json --xdc s1.xdc --fasm build/s1.fasm --chipdb $CHIPDB/$P.bin \
    --seed 1 --freq 250 --timing-allow-fail --log build/pnr.log > /dev/null
grep -E 'Max frequency for clock' build/pnr.log | tail -8
python3 ~/celestica/tools/unused_pins.py build/s1.fasm build/s1_pn.fasm
python3 ../fasm_patch.py build/s1_pn.fasm build/s1_patched.fasm
fasm2frames --part $P --db-root $DB build/s1_patched.fasm > build/s1.frames 2> build/fasm2frames.log
xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file build/s1.frames --output_file build/s1.bit
python3 ~/tools/prjxray/utils/bit2fasm.py --db-root $DB --part $P --bitread ~/tools/prjxray/build/tools/bitread \
    --verbose build/s1.bit > build/s1_verbose.fasm
python3 ../compare_tiles.py ../flash_v3.fasm build/s1_verbose.fasm > build/compare.txt
grep '^==' build/compare.txt
python3 check_ties.py build/s1_patched.fasm | tail -40
ls -la build/s1.bit
