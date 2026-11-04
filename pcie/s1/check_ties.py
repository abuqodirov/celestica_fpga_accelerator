#!/usr/bin/env python3
"""Compare the GT input ties of our routed design with the factory design's.

  check_ties.py ours.fasm [../flash_v3.fasm]
Prints every pin the factory ties to a constant where ours differs, and a count of the pins the factory drives
from logic (ours may tie those: that is expected).
"""
import subprocess, sys

def ties(fasm):
    out = subprocess.run([sys.executable, "factory_ties.py", fasm], capture_output=True, text=True, check=True).stdout
    return {tuple(l.split(" ", 2)[:2]): l.rstrip("\n").split(" ", 2)[2] for l in out.splitlines()}

ours = ties(sys.argv[1])
fact = ties(sys.argv[2] if len(sys.argv) > 2 else "../flash_v3.fasm")
bad = 0
for key in sorted(fact):
    f, o = fact[key], ours.get(key, "missing")
    if "net:" in f or "nomap" in f or f == "u0":
        continue
    if f != o:
        bad += 1
        print("DIFF", *key, "factory", f, "ours", o)
print(f"{bad} constant ties differ from the factory design")
