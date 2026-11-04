#!/bin/bash
# Unattended seed sweep for a dual-channel engine SoC whose netlist is already synthesized: place & route ONE seed at
# a time (seed_sweep.sh, honours NEXTPNR_EXTRA; a seed only starts with >= 7 GB RAM available - two parallel jobs
# plus other heavy work once triggered the desktop session's memory reaper), then check it on the board:
#   boottest.sh (channel-0 leveling + memtest) -> ch1_init.py (channel-1 leveling) -> engine_selftest.py
#   (both engines bit-exact twice, CPU crc twice). One line per seed in <build>/night.txt; PASS lines end in
#   "engine selftest: PASS". No new seeds are started after the deadline (epoch seconds).
# usage: NEXTPNR_EXTRA="--pre-place ..." night_sweep.sh <build dir> <first seed> <deadline epoch>
cd "$(dirname "$0")"
B=$(readlink -f "$1"); S=$2; END=$3; LOG=$B/night.txt
check() {
    local bit=$B/gateware/seeds/s$1.bit R C1 ST
    [ -s "$bit" ] || { echo "$(date +%T) seed $1: build FAILED ($(grep -m1 -o 'ERROR.*' $B/gateware/seeds/s$1.pnr.log | cut -c1-80))" >> $LOG; return; }
    R=$(YPCB_BUILD=$B ./boottest.sh "$bit" | sed -E 's/^[^ ]* //; s/m([0-7]):b0[0-9]@[0-9]+\+-([0-9]+)/m\1:±\2/g')
    if echo "$R" | grep -q "Memtest OK" && ! echo "$R" | grep -q -- "----"; then
        C1=$(YPCB_BUILD=$B timeout 600 ~/tools/venv/bin/python ch1_init.py 2>&1 | tail -1 | sed -E 's/m([0-7]):b0[0-9]@[0-9]+\+-([0-9]+)/m\1:±\2/g')
        R="$R || ch1: $C1"
        if ! echo "$C1" | grep -q -- "----"; then
            ST=$(YPCB_BUILD=$B timeout 900 ~/tools/venv/bin/python ../accel/host/engine_selftest.py 2>&1 | tail -1)
            R="$R || $ST"
        fi
    fi
    echo "$(date +%T) seed $1: $R" >> $LOG
}
while [ "$(date +%s)" -lt "$END" ]; do
    while [ "$(free -m | awk '/^Mem:/ {print $7}')" -lt 7000 ]; do sleep 30; done
    ./seed_sweep.sh "$B" $S > /dev/null 2>&1
    check $S
    S=$((S + 1))
done
echo "$(date +%T) sweep stopped at the deadline (next seed would be $S)" >> $LOG
