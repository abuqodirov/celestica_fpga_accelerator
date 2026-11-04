#!/bin/bash
# DDR3 CK / DQS phase variants of an already routed small DDR build (build_ddrfreq.sh) without re-P&R: patch the PLL
# phase bits (CLKOUT4 = CK, CLKOUT2 = DQS) in the routed FASM, make the bitstream, run boottest.sh on the card.
#   ddr_phases.sh <build dir> <divider of the 4x clock: 6 @75 MHz, 4 @100 MHz, 3 @83.33 MHz> "ck:dqs ck:dqs ..."
# Phase step = 360 / (8 * divider) degrees. One variant at a time (fasm2frames under the shared lock, memory-capped).
# Results appended to <build dir>/phases/results.txt.
cd "$(dirname "$0")"
. ./env.sh
B=$(readlink -f "$1"); DIV=$2; PAIRS=$3
P=xc7k480tffg1156-2; DB=$PRJXRAY_DB_DIR/kintex7
mkdir -p $B/phases
for pr in $PAIRS; do
  ck=${pr%%:*}; dq=${pr##*:}; n=ck${ck}_dqs${dq}
  python3 - "$B/gateware/ypcb_00338_1p1_pn.fasm" "$B/phases/$n.fasm" "$DIV" "$ck" "$dq" <<'PY'
import re, sys
src, dst, div, ck, dq = sys.argv[1], sys.argv[2], int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
lines = open(src).read().splitlines()
pfx = next(l.split(".PLLE2_ADV.")[0] for l in lines if ".PLLE2_ADV." in l)
def bits(ph):
    e = round(ph / 360 * 8 * div)
    assert abs(e * 360 / (8 * div) - ph) < 1e-6, f"phase {ph} not a multiple of {360 / (8 * div)}"
    return e % 8, e // 8
out = [l for l in lines if not re.search(r"PLLE2_ADV\.CLKOUT[24]_CLKOUT1_PHASE_MUX|PLLE2_ADV\.CLKOUT[24]_CLKOUT2_DELAY_TIME", l)]
for k, ph in ((4, ck), (2, dq)):
    m, d = bits(ph)
    out.append(f"{pfx}.PLLE2_ADV.CLKOUT{k}_CLKOUT1_PHASE_MUX[2:0] = 3'b{m:03b}")
    out.append(f"{pfx}.PLLE2_ADV.CLKOUT{k}_CLKOUT2_DELAY_TIME[5:0] = 6'b{d:06b}")
open(dst, "w").write("\n".join(out) + "\n")
PY
  [ -s $B/phases/$n.fasm ] || { echo "$n: patch failed"; continue; }
  flock ${TMPDIR:-/tmp}/fasm2frames.lock systemd-run --user --scope -q -p MemoryMax=6G -p MemorySwapMax=2G \
      fasm2frames --part $P --db-root $DB $B/phases/$n.fasm > $B/phases/$n.frames 2>/dev/null
  xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file $B/phases/$n.frames \
      --output_file $B/phases/$n.bit > /dev/null 2>&1
  rm -f $B/phases/$n.frames $B/phases/$n.fasm
  r=$(YPCB_BUILD=$B timeout 300 ./boottest.sh $B/phases/$n.bit 2>&1 | tail -1)
  echo "$r" | sed "s|$B/phases/||" | tee -a $B/phases/results.txt
done
