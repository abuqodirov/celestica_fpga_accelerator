#!/bin/bash
# For each cmd-phase bitstream: load, capture BIOS memtest, run two single-write column tests.
cd "$(dirname "$0")"
for ph in $PHASES; do
  ~/.local/bin/openFPGALoader -c digilent_hs3 --freq 30M build_cmdph/gateware/phases/cmd$ph.bit > /dev/null 2>&1
  timeout 120 ~/tools/venv/bin/python console.py --seconds 50 --log build_cmdph/gateware/phases/boot$ph.log > /dev/null 2>&1
  m=$(sed 's/\x1b\[[0-9;]*m//g' build_cmdph/gateware/phases/boot$ph.log | tr -d '\r' | grep -E "bus errors|addr errors|data errors|Memtest (OK|KO)" | tr -s ' ' | tr '\n' ' ')
  lv=$(sed 's/\x1b\[[0-9;]*m//g' build_cmdph/gateware/phases/boot$ph.log | tr -d '\r' | grep -c "best: m.*delays: [0-9]")
  s1=$(YPCB_BUILD=build_cmdph timeout 300 ~/tools/venv/bin/python seq_test.py 72 64,8,16,72,112 | sed 's/.*-> //')
  s2=$(YPCB_BUILD=build_cmdph timeout 300 ~/tools/venv/bin/python seq_test.py 73 120,104,48,24,88 | sed 's/.*-> //')
  echo "phase $ph: leveled lanes $lv/4 | $m"
  echo "          A(64,8,16,72,112): $s1"
  echo "          B(120,104,48,24,88): $s2"
done
