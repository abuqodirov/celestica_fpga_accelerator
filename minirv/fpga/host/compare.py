#!/usr/bin/env python3
"""Compare results: `compare.py sim` = Verilator vs Python model; `compare.py hw` = FPGA vs Verilator."""
import json
import os
import sys

PROGS = os.path.join(os.path.dirname(__file__), "..", "build", "progs")


def main():
    mode = sys.argv[1]
    ok_all = True
    for name in ("hello", "selftest"):
        ref = json.load(open(os.path.join(PROGS, f"{name}.ref.json")))
        sim = json.load(open(os.path.join(PROGS, f"{name}.sim.json")))
        if mode == "sim":
            got, base, label = sim, ref, "Verilator vs model"
            checks = {k: got[k] == base[k] for k in ("console", "a0", "instret", "leds")}
            checks["cycles"] = got["cycles"] == base["cycles_model"]
        else:
            got, base, label = json.load(open(os.path.join(PROGS, f"{name}.hw.json"))), sim, "FPGA vs Verilator"
            checks = {k: got[k] == base[k] for k in ("console", "a0", "pc", "instret", "cycles", "leds")}
        checks["halted"] = got["halted"]
        checks["regions"] = all(got["regions"].get(k) == v for k, v in base["regions"].items())
        ok = all(checks.values())
        ok_all &= ok
        bad = [k for k, v in checks.items() if not v]
        print(f"{name:9} {label}: {'PASS' if ok else 'FAIL ' + ', '.join(bad)}"
              f"  ({got['instret']} instructions, {got['cycles']} cycles, a0=0x{got['a0']:08x})")
    sys.exit(0 if ok_all else 1)


if __name__ == "__main__":
    main()
