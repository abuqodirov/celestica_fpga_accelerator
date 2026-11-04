#!/usr/bin/env python3
"""Stage 1 soak: each rate x (PRBS-7, PRBS-31, 8b/10b data) for T seconds, all 8 lanes, near-end PMA loopback."""
import sys, time
from s1 import S1, ST, TS
T = float(sys.argv[1]) if len(sys.argv) > 1 else 20
d = S1()
total_bits, bad = 0, 0
for rate in (0, 1):
    d.set(idle=1, prbs=1, data=0, manual=1, rate=0); d.restart(); time.sleep(0.1); d.wait_ready()
    if rate:
        d.set(rate=1); s = d.wait_ready()
        assert s["st"] == 7 and s["cur_rate"] == 1, (ST.get(s["st"]), ST.get(s["err_st"]))
    for name, kw in (("PRBS-7", dict(prbs=1, data=0)), ("PRBS-31", dict(prbs=4, data=0)), ("8b/10b data", dict(prbs=0, data=1))):
        d.set(idle=0, **kw); time.sleep(0.05)
        d.clear(); time.sleep(T)
        s = d.read()
        ok = s["st"] == 7 and s["ts"] == 8 and max(s["errs"]) == 0
        bits = 8 * T * (5e9 if rate else 2.5e9)
        total_bits += bits; bad += not ok
        print(f"{'5.0' if rate else '2.5'} GT/s {name:12s} {T:.0f} s: errors {s['errs']}  {ST.get(s['st'])}/{TS.get(s['ts'])}"
              f"  aligned {s['byteisaligned']:08b}  {'OK' if ok else 'FAIL'}")
        d.set(idle=1)
print(f"{6 - bad}/6 runs clean, {total_bits:.2e} bits checked -> bit error rate below {1 / total_bits:.1e}" if not bad else f"{bad} runs failed")
