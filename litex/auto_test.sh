#!/bin/bash
# Board-test every new seed bitstream of the given builds as it appears (one at a time; the board has one JTAG).
# usage: auto_test.sh <results file> <build>...      prints + appends one full_check.sh line per bitstream
cd "$(dirname "$0")"
OUT=$1; shift
touch "$OUT"
while true; do
    for B in "$@"; do
        for bit in $B/gateware/seeds/s*.bit; do
            [ -f "$bit" ] || continue
            grep -q "^$bit " "$OUT" && continue
            grep -q "^ERROR" "${bit%.bit}.pnr.log" 2>/dev/null && continue        # never load a failed build
            [ "$(stat -c %s "$bit")" -ge 18000000 ] && [ $(( $(date +%s) - $(stat -c %Y "$bit") )) -ge 10 ] || continue
            r=$(./full_check.sh "$B" "$bit" 2>&1 | tail -1)
            echo "$bit $(date +%T) $r" | tee -a "$OUT"
        done
    done
    sleep 30
done
