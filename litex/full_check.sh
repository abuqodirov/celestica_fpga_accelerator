#!/bin/bash
# Full acceptance test of one dual-channel bitstream (stops at the first failing stage):
#   ch0 read leveling (all 8 lanes) + BIOS memtest -> ch1 init + leveling (all 8 lanes) -> engine selftest (if the
#   SoC has engines: CPU crc x2 + each engine bit-exact x2) -> BIST on both channels at once (2 passes x 2 x 2 GiB)
#   -> high address-bit test on each channel -> (YPCB_DDR0WIN) JTAG loader + CPU windows over all 4 GiB.
# usage: full_check.sh <build> <bitstream>       -> one summary line
cd "$(dirname "$0")"
B=$(readlink -f "$1"); BIT=$2; PY=~/tools/venv/bin/python
R=$(YPCB_BUILD=$B ./boottest.sh "$BIT" | sed -E 's/^[^ ]* //; s/m([0-7]):b0[0-9]@[0-9]+\+-([0-9]+)/m\1:±\2/g')
out() { echo "$(basename "$BIT"): $R"; exit 0; }
{ echo "$R" | grep -q "Memtest OK" && ! echo "$R" | grep -q -- "----"; } || { R="$R => FAIL (ch0)"; out; }
C1=$(YPCB_BUILD=$B timeout 600 $PY ch1_init.py 2>&1 | tail -1 | sed -E 's/m([0-7]):b0[0-9]@[0-9]+\+-([0-9]+)/m\1:±\2/g; s/ *\(.*s\)$//')
R="$R || ch1: $C1"
echo "$C1" | grep -q -- "----" && { R="$R => FAIL (ch1 lanes)"; out; }
if grep -q "csr_base,mvacc," "$B/csr.csv"; then
    ST=$(YPCB_BUILD=$B timeout 900 $PY ../accel/host/engine_selftest.py 2>&1 | tail -1)
    R="$R || $ST"
    echo "$ST" | grep -q PASS || { R="$R => FAIL (engines/CPU)"; out; }
fi
if grep -q "csr_register,sdram_generator_reset," "$B/csr.csv"; then   # BIST cores (YPCB_BIST) present
    BB=$(YPCB_BUILD=$B timeout 900 $PY bist_both.py 2 2>&1 | tail -1)
    R="$R || $BB"
    echo "$BB" | grep -q "ch0 0 ch1 0 burst" || { R="$R => FAIL (BIST)"; out; }
    for c in sdram sdram1; do
        A=$(BIST_CORE=$c YPCB_BUILD=$B timeout 300 $PY bist_addr.py 2>&1 | tail -1)
        R="$R || $A"
        echo "$A" | grep -q "ALL OK" || { R="$R => FAIL (address)"; out; }
    done
else
    R="$R || (no BIST cores in this SoC)"
fi
if grep -q "csr_base,ddr0," "$B/csr.csv"; then       # YPCB_DDR0WIN: the loader/CPU path to all 4 GiB
    L=$(YPCB_BUILD=$B timeout 900 $PY loader_test.py 2>&1 | tail -1)
    R="$R || $L"
    echo "$L" | grep -q PASS || { R="$R => FAIL (loader)"; out; }
fi
R="$R => ALL PASS"; out
