#!/bin/bash
# Timing-margin test: the same bitstream at several sys clocks (pll_retime.py), DDR3 check at each.
# usage: margin_test.sh <build> <seed> <freqs...>      (75 = the original bitstream)
# Per run: boottest (channel 0 / main: leveling + memtest); for YPCB_DUAL builds also ch1_init.py and one
# 2 GiB BIST pass on each channel.
cd "$(dirname "$0")"
B=$1; S=$2; shift 2
for f in "$@"; do
    if [ "$f" = 75 ]; then
        BIT=$([ "$S" = 1 ] && echo "$B/gateware/ypcb_00338_1p1.bit" || echo "$B/gateware/seeds/s$S.bit")
        [ "$B" = build_dual ] && [ "$S" = 1 ] && BIT=$B/gateware/ypcb_00338_1p1_s1.bit
    else
        BIT=$B/gateware/retime/s${S}_sys$f.bit
    fi
    [ -f "$BIT" ] || { echo "$B s$S ${f}MHz: missing $BIT"; continue; }
    R=$(YPCB_BUILD=$(readlink -f "$B") ./boottest.sh "$BIT" | sed 's/^[^ ]* //')
    line="$B s$S ${f}MHz: ${R}"
    if grep -q "csr_base,sdram1," "$B/csr.csv"; then
        C1=$(YPCB_BUILD=$B timeout 600 ~/tools/venv/bin/python ch1_init.py 2>&1 | tail -1 | sed 's/ *(.*s)$//')
        E0=$(BIST_CORE=sdram YPCB_BUILD=$B timeout 300 ~/tools/venv/bin/python bist_full.py 1 0x80000000 2>&1 | grep -o "[0-9]* burst errors" | tail -1)
        E1=$(BIST_CORE=sdram1 YPCB_BUILD=$B timeout 300 ~/tools/venv/bin/python bist_full.py 1 0x80000000 2>&1 | grep -o "[0-9]* burst errors" | tail -1)
        line="$line || ch1: $C1 || BIST 2GiB ch0: ${E0:-?} ch1: ${E1:-?}"
    fi
    echo "$line" | sed 's/| bus [^|]*|/|/'
done
