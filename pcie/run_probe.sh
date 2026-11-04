#!/bin/bash
# Build the PCIe toolchain probe and compare its transceiver/PCIe bits with the factory bitstream.
# SOFTWARE ONLY: produces probe.bit on disk, never loads it.
set -e
cd "$(dirname "$0")"
. ~/celestica/litex/env.sh
P=xc7k480tffg1156-2
DB=$PWD/db/kintex7        # private overlay, see db/README.txt
python3 gen_params.py > factory_params.vh
yosys -q -l probe_yosys.log probe.ys
timeout 1200 nextpnr-xilinx --json probe.json --xdc probe.xdc --fasm probe.fasm \
    --chipdb $CHIPDB/$P.bin --timing-allow-fail --seed 1 --log probe_pnr.log > /dev/null
python3 ~/celestica/tools/unused_pins.py probe.fasm probe_pn.fasm
python3 fasm_patch.py probe_pn.fasm probe_patched.fasm
fasm2frames --part $P --db-root $DB probe_patched.fasm > probe.frames 2> fasm2frames.log
xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file probe.frames --output_file probe.bit
python3 ~/tools/prjxray/utils/bit2fasm.py --db-root $DB --part $P --bitread ~/tools/prjxray/build/tools/bitread \
    --verbose probe.bit > probe_verbose.fasm
python3 compare_tiles.py flash_v3.fasm probe_verbose.fasm > compare.txt
grep '^==' compare.txt
