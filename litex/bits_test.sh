#!/bin/bash
# usage: BUILD=build_ck bits_test.sh file1.bit file2.bit ...  (files relative to $BUILD/gateware/phases)
cd "$(dirname "$0")"
for f in "$@"; do
  p=$BUILD/gateware/phases
  ~/.local/bin/openFPGALoader -c digilent_hs3 --freq 30M $p/$f > /dev/null 2>&1
  timeout 120 ~/tools/venv/bin/python console.py --seconds 50 --log $p/${f%.bit}.log > /dev/null 2>&1
  t=$(sed 's/\x1b\[[0-9;]*m//g' $p/${f%.bit}.log | tr -d '\r')
  m=$(echo "$t" | grep -E "bus errors|addr errors|data errors" | tr -s ' ' | tr '\n' ' ')
  lv=$(echo "$t" | grep -c "best: m.*delays: [0-9]")
  s1=$(YPCB_BUILD=$BUILD timeout 300 ~/tools/venv/bin/python seq_test.py 72 64,8,16,72,112 | sed 's/.*-> written cols: //')
  s2=$(YPCB_BUILD=$BUILD timeout 300 ~/tools/venv/bin/python seq_test.py 73 120,104,48,24,88 | sed 's/.*-> written cols: //')
  bm=$(YPCB_BUILD=$BUILD timeout 300 ~/tools/venv/bin/python bist_map.py 0x10000 0x100000 0x10000000 | sed 's/.*: //' | tr '\n' ' ')
  echo "$f: leveled $lv/4 |$m| colA $s1 | colB $s2 | BIST2048: $bm"
done
