#!/bin/bash
# usage: [YPCB_BUILD=<build dir>] boottest.sh a.bit [b.bit ...] -> per bitstream: DDR3 read leveling per lane + BIOS memtest

for bit in "$@"; do
  ~/.local/bin/openFPGALoader -c digilent_hs3 --freq 30M "$bit" > /dev/null 2>&1 || { echo "$bit: load failed"; continue; }
  YPCB_BUILD=${YPCB_BUILD:-~/celestica/litex/build_llm4} timeout 200 ~/tools/venv/bin/python - "$bit" <<'PY'
import sys, re
sys.path.insert(0, "$HOME/celestica/litex")
from bios import Bios
b = Bios(freq=15e6)
log = b.drain(quiet=8, limit=150).decode(errors="replace").replace("\r", "")
open(sys.argv[1].replace(".bit", ".boot.log"), "w").write(log)
best = re.findall(r"best: (m\d), (b\d\d) delays: (\S+)", log)
mt = re.findall(r"(bus errors|addr errors|data errors):\s+(\d+/\d+)", log)
print(f"{sys.argv[1]:28s}", " ".join(f"{m}:{bs}@{d}" if d != "-" else f"{m}:----" for m, bs, d in best),
      "|", ", ".join(f"{k.split()[0]} {v}" for k, v in mt), "|", "Memtest OK" if "Memtest OK" in log else "Memtest KO")
b.close()
PY
done
