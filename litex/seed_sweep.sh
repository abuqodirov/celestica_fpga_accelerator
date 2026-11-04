#!/bin/bash
# Re-run place & route of an existing build with other nextpnr seeds (same synthesized netlist):
#   seed_sweep.sh <build dir> <seed>...  ->  <build dir>/gateware/seeds/s<seed>.bit
# Extra nextpnr options from $NEXTPNR_EXTRA (e.g. "--pre-place floorplan_dual.py"). At most 2 jobs at once (nextpnr + fasm2frames are RAM-hungry; 10 in parallel OOM-killed the session).
. ~/celestica/litex/env.sh
P=xc7k480tffg1156-2; DB=$PRJXRAY_DB_DIR/kintex7
G=$(readlink -f "$1")/gateware; shift
mkdir -p "$G/seeds"; cd "$G/seeds" || exit 1
for s in "$@"; do
  while [ "$(jobs -rp | wc -l)" -ge 2 ]; do sleep 5; done
  (
    timeout 2400 nextpnr-xilinx --json ../ypcb_00338_1p1.json --xdc ../ypcb_fixed.xdc --fasm s$s.fasm --chipdb $CHIPDB/$P.bin \
        --timing-allow-fail --seed $s --freq 75 $NEXTPNR_EXTRA --log s$s.pnr.log > /dev/null 2>&1
    rc=$?
    # a failed / timed-out nextpnr leaves no or an empty FASM, and fasm2frames would still make a full-size BLANK
    # bitstream (that happened 10-17: the board tester loaded two of them) -> no bitstream at all then
    if [ $rc -ne 0 ] || [ ! -s s$s.fasm ]; then
        rm -f s$s.bit s$s.fasm
        echo "$(date +%T) $(basename $(dirname $G)) seed $s: FAILED (nextpnr exit $rc: $(grep -m1 -o 'ERROR.*' s$s.pnr.log | cut -c1-70))"
        exit 1
    fi
    python3 ~/celestica/tools/unused_pins.py s$s.fasm s$s.pn0.fasm > /dev/null
    sed "s/\.VREF\.V_675_MV$/.VREF.V_750_MV/" s$s.pn0.fasm > s$s.pn.fasm
    fasm2frames --part $P --db-root $DB s$s.pn.fasm > s$s.frames 2> s$s.f2f.log
    xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file s$s.frames --output_file s$s.bit > /dev/null
    rm -f s$s.frames s$s.fasm s$s.pn0.fasm
    echo "$(date +%T) $(basename $(dirname $G)) seed $s: $([ -s s$s.bit ] && echo built || echo FAILED)"
  ) &
done
wait
