#!/bin/bash
# build.sh + DDR3 check on the board: ~1 build in 10 (channel 0) to 1 in 2 (channel 1) comes out with a group
# of DQ lanes broken (NOTES "DDR3 8-lane failures"; deterministic per bitstream, cause unknown). This builds,
# boot-tests (boottest.sh: every lane must level, BIOS memtest OK) and on failure re-runs place & route with the
# next seed until one passes. The passing bitstream becomes gateware/ypcb_00338_1p1.bit (a failing seed-1 build
# is kept as ypcb_00338_1p1_s1.bit) and its seed is written to gateware/good_seed.txt. For YPCB_DUAL builds every
# channel-1 lane must also level (ch1_init.py). CHECK=<python script> runs a further check on candidates (e.g.
# accel/host/engine_selftest.py); its last line must not contain FAIL.
# usage: build_good.sh <outdir> [build.sh args]      env: as build.sh, MAX_SEEDS (default 8), SKIP_BUILD=1 (reuse
#        the synthesized netlist already in <outdir>: every seed, 1 included, is placed & routed by seed_sweep.sh)
# Needs the board (it loads every candidate bitstream).
set -e
cd "$(dirname "$0")"
OUT=$1
[ -n "$SKIP_BUILD" ] || ./build.sh "$@"
G=$OUT/gateware
for seed in $(seq 1 "${MAX_SEEDS:-8}"); do
    if [ "$seed" = 1 ] && [ -z "$SKIP_BUILD" ]; then
        BIT=$G/ypcb_00338_1p1.bit
    else
        ./seed_sweep.sh "$OUT" "$seed" | grep -v PULLNONE
        BIT=$G/seeds/s$seed.bit
    fi
    R=$(YPCB_BUILD=$(readlink -f "$OUT") ./boottest.sh "$BIT")
    if grep -q "csr_base,sdram1," "$OUT/csr.csv" && echo "$R" | grep -q "Memtest OK"; then   # dual: channel 1 too
        R="$R || ch1: $(YPCB_BUILD=$OUT timeout 600 ~/tools/venv/bin/python ch1_init.py 2>&1 | tail -1)"
    fi
    if [ -n "$CHECK" ] && echo "$R" | grep -q "Memtest OK" && ! echo "$R" | grep -q -- "----"; then   # extra check
        R="$R || $(YPCB_BUILD=$(readlink -f "$OUT") timeout 900 ~/tools/venv/bin/python $CHECK 2>&1 | tail -1)"
    fi
    echo "seed $seed: ${R#* }"
    if echo "$R" | grep -q "Memtest OK" && ! echo "$R" | grep -q -- "----" && ! echo "$R" | grep -q "FAIL"; then
        if [ "$BIT" != "$G/ypcb_00338_1p1.bit" ]; then   # install the good seed's bitstream and FASM
            [ -f "$G/ypcb_00338_1p1.bit" ] && mv "$G/ypcb_00338_1p1.bit" "$G/ypcb_00338_1p1_s1.bit"
            [ -f "$G/ypcb_00338_1p1_pn.fasm" ] && mv "$G/ypcb_00338_1p1_pn.fasm" "$G/ypcb_00338_1p1_s1_pn.fasm"
            cp "$BIT" "$G/ypcb_00338_1p1.bit"
            cp "$G/seeds/s$seed.pn.fasm" "$G/ypcb_00338_1p1_pn.fasm"
        fi
        echo "$seed" > "$G/good_seed.txt"
        echo "good bitstream: $G/ypcb_00338_1p1.bit (seed $seed)"
        exit 0
    fi
done
echo "no passing seed in 1..${MAX_SEEDS:-8}"
exit 1
