#!/bin/bash
# Build PCIe stage 2 (build/s2.bit) and check it against the factory design. Does NOT load it.
set -e
cd "$(dirname "$0")"
. ~/celestica/litex/env.sh
P=xc7k480tffg1156-2
DB=$PWD/../db/kintex7          # overlay DB, see ../db/README.txt
mkdir -p build
python3 gen_params_s2.py
python3 gen_pcie_inst.py
yosys -q -l build/yosys.log -p "read_verilog -I . -I .. s2_top.v; synth_xilinx -flatten -abc9 -nosrl -arch xc7 -top s2_top; stat; write_json build/s2.json"
PINMAP_OUT=$PWD/build/pinmap.txt timeout 1800 nextpnr-xilinx --json build/s2.json --xdc s2.xdc --fasm build/s2.fasm \
    --chipdb $CHIPDB/$P.bin --seed 1 --freq 250 --timing-allow-fail --post-route pinmap_route.py \
    --log build/pnr.log > /dev/null
grep -E 'Max frequency for clock' build/pnr.log | tail -8
python3 ~/celestica/tools/unused_pins.py build/s2.fasm build/s2_pn.fasm
python3 ../fasm_patch.py build/s2_pn.fasm build/s2_rc.fasm
python3 delay_patch.py build/s2_rc.fasm build/pinmap.txt build/s2_patched.fasm
fasm2frames --part $P --db-root $DB build/s2_patched.fasm > build/s2.frames 2> build/fasm2frames.log
xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file build/s2.frames --output_file build/s2.bit
python3 ~/tools/prjxray/utils/bit2fasm.py --db-root $DB --part $P --bitread ~/tools/prjxray/build/tools/bitread \
    --verbose build/s2.bit > build/s2_verbose.fasm
python3 ../compare_tiles.py ../flash_v3.fasm build/s2_verbose.fasm > build/compare.txt
grep '^==' build/compare.txt
(cd ../s1 && python3 check_ties.py ../s2/build/s2_patched.fasm | tail -30)
python3 pcie_ties.py build/s2_patched.fasm build/pinmap.txt probe_pinmap.txt
ls -la build/s2.bit
