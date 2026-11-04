#!/usr/bin/env python3
"""Stage 1: switch 2.5 <-> 5 GT/s repeatedly, soak each rate, report where a switch stops."""
import sys, time
from s1 import S1, ST, TS, WINDOW
d = S1()
n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
idle = int(sys.argv[2]) if len(sys.argv) > 2 else 1
d.set(idle=idle, prbs=1, data=0, manual=1, rate=0); d.restart(); time.sleep(0.1)
ok = 0
for i in range(n):
    rate = (i + 1) % 2
    d.set(rate=rate)
    s = d.wait_ready()
    good = s["st"] == 7 and s["cur_rate"] == rate and s["ts"] == 8
    if not good:
        print(f"switch {i} to rate {rate}: {ST.get(s['st'])} err_st {ST.get(s['err_st'])} align {TS.get(s['ts'])}"
              f" ts_err {TS.get(s['ts_err'])} seen {s['sync_seen']:08b} txrd {s['txratedone']:08b} rxrd {s['rxratedone']:08b}"
              f" txresetdone {s['txresetdone']:08b} rxresetdone {s['rxresetdone']:08b}")
        d.restart(); time.sleep(0.1); d.set(rate=0); d.wait_ready()
        continue
    d.clear(); time.sleep(0.6)
    s = d.read()
    ratio = s["f_pclk"] / s["f_ref"]
    print(f"switch {i} to {'5.0' if rate else '2.5'} GT/s ok, pclk/ref {ratio:.4f}, errors {s['errs']}")
    ok += max(s["errs"]) == 0 and s["st"] == 7
print(f"{ok}/{n} switches clean")
