#!/usr/bin/env python3
"""PCIe stage 1 on the card: control and read the 8-lane loopback test over JTAG (design: ../s1_top.v).

  s1.py status              read and print everything
  s1.py set key=val ...     change control fields, e.g. rate=1 loopback=2 prbs=1 idle=0 manual=1 lpm=1 data=0
  s1.py restart             rerun the lane reset sequence (keeps the control fields)
  s1.py clear               clear the error counters
  s1.py test                the whole stage-1 test, prints a summary
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "calc", "host"))
from hs3_jtag import HS3Jtag, IR_USER1   # noqa: E402

DR_BITS = 512
IDCODE = 0x23751093
SCLK_MHZ = 63.64          # CFGMCLK, measured 2026-10-05 (NOTES); only used to print absolute MHz
WINDOW = 1 << 24          # sclk cycles per frequency-count window

CTL = {  # name: (lsb, width)
    "rate": (2, 1), "loopback": (3, 3), "prbs": (6, 3), "idle": (9, 1), "forceerr": (11, 1),
    "manual": (12, 1), "lpm": (13, 1), "data": (14, 1),
}
ST = {0: "START", 1: "PDREL", 2: "CPLLRST", 3: "LOCK", 4: "GTRST", 5: "SYNC", 6: "SYNCW", 7: "READY",
      8: "RPCLK", 9: "RSEL", 10: "RDONE", 11: "RRST", 15: "ERROR"}
TS = {0: "IDLE", 1: "DLYSRST", 2: "MINIT", 3: "MALIGN", 4: "MDLYEN", 5: "SINIT", 6: "SALIGN", 7: "MDLYEN2",
      8: "DONE", 9: "AUTO", 15: "ERR"}


def field(v, lsb, width):
    return (v >> lsb) & ((1 << width) - 1)


class S1:
    def __init__(self):
        self.j = HS3Jtag(freq=6e6)
        idc = self.j.idcode()
        if idc != IDCODE:
            raise SystemExit(f"unexpected IDCODE {idc:#x}")
        self.j.ir(IR_USER1)

    def raw(self):
        return self.j.dr(0, DR_BITS)

    def read(self):
        v = self.raw()
        if field(v, 0, 8) != 0xC1:
            raise SystemExit(f"stage-1 design not loaded (magic {field(v, 0, 8):#x})")
        s = {
            "version": field(v, 8, 8), "st": field(v, 16, 4), "err_st": field(v, 24, 4),
            "cplllock": field(v, 32, 8), "txresetdone": field(v, 40, 8), "rxresetdone": field(v, 48, 8),
            "txdlysresetdone": field(v, 56, 8), "txphinitdone": field(v, 64, 8), "txphaligndone": field(v, 72, 8),
            "txratedone": field(v, 80, 8), "rxratedone": field(v, 88, 8),
            "rxelecidle": field(v, 96, 8), "byteisaligned": field(v, 104, 8), "phystatus": field(v, 112, 8),
            "rxvalid": field(v, 120, 8),
            "gtreset": field(v, 128, 1), "cpllpd": field(v, 129, 1), "gt_rate": field(v, 130, 1),
            "manual": field(v, 131, 1), "perst_n": field(v, 132, 1), "cur_rate": field(v, 133, 1),
            "pclk_sel": field(v, 134, 1), "pll_locked": field(v, 135, 1),
            "ts": field(v, 136, 4), "ts_err": field(v, 140, 4), "sync_seen": field(v, 144, 8),
            "refclklost": field(v, 152, 8),
            "f_ref": field(v, 160, 32), "f_pclk": field(v, 192, 32), "f_dclk": field(v, 224, 32),
            "windows": field(v, 256, 32),
            "errs": [field(v, 288 + 16 * i, 16) for i in range(8)],
            "ctl": field(v, 416, 32), "ready_time": field(v, 448, 32),
            "restarts": field(v, 480, 16), "rate_changes": field(v, 496, 16),
        }
        return s

    def write_ctl(self, ctl, restart=False, clear=False):
        w = (ctl & ~0x403) | 1 | (2 if restart else 0) | (0x400 if clear else 0)
        self.j.dr(w, DR_BITS)

    def set(self, **kw):
        ctl = self.read()["ctl"]
        for k, val in kw.items():
            lsb, width = CTL[k]
            ctl = (ctl & ~(((1 << width) - 1) << lsb)) | ((int(val) & ((1 << width) - 1)) << lsb)
        self.write_ctl(ctl)

    def restart(self):
        self.write_ctl(self.read()["ctl"], restart=True)

    def clear(self):
        self.write_ctl(self.read()["ctl"], clear=True)

    def wait_ready(self, timeout=2.0):
        t0 = time.time()
        while time.time() - t0 < timeout:
            s = self.read()
            if s["st"] in (7, 15) and s["ts"] in (8, 15):
                return s
            time.sleep(0.02)
        return self.read()


def ctl_str(ctl):
    return " ".join(f"{k}={field(ctl, *CTL[k])}" for k in CTL)


def show(s):
    w = WINDOW / SCLK_MHZ   # window length in us
    ref = s["f_ref"] / w
    print(f"sequencer {ST.get(s['st'], s['st'])}" + (f" (timed out in {ST.get(s['err_st'])})" if s["err_st"] else "")
          + f"   tx-align {TS.get(s['ts'], s['ts'])}" + (f" (timed out in {TS.get(s['ts_err'])})" if s["ts_err"] else "")
          + f"   lanes aligned mask {s['sync_seen']:08b}")
    print(f"ctl: {ctl_str(s['ctl'])}   restarts {s['restarts']}  rate changes {s['rate_changes']}"
          f"   ready after {s['ready_time'] / SCLK_MHZ / 1000:.2f} ms")
    print(f"rate {'5.0' if s['cur_rate'] else '2.5'} GT/s (gt_rate {s['gt_rate']}, pclk_sel {s['pclk_sel']})"
          f"  pll_locked {s['pll_locked']}  gtreset {s['gtreset']}  cpllpd {s['cpllpd']}  PERST# {s['perst_n']}")
    if s["f_ref"]:
        print(f"clocks: ref {ref:.2f} MHz (if CFGMCLK = {SCLK_MHZ})   pclk/ref {s['f_pclk'] / s['f_ref']:.4f}"
              f"   dclk/ref {s['f_dclk'] / s['f_ref']:.4f}   (windows {s['windows']})")
    else:
        print(f"clocks: NO reference clock seen   (windows {s['windows']})")
    print("lane:            " + "  ".join(f"{i:>5}" for i in range(8)))
    for k in ("cplllock", "refclklost", "txresetdone", "rxresetdone", "txdlysresetdone", "txphinitdone",
              "txphaligndone", "txratedone", "rxratedone", "rxelecidle", "byteisaligned", "phystatus", "rxvalid"):
        print(f"{k:16s} " + "  ".join(f"{(s[k] >> i) & 1:>5}" for i in range(8)))
    print(f"{'errors':16s} " + "  ".join(f"{e:>5}" for e in s["errs"]))


def soak(d, seconds):
    d.clear()
    time.sleep(seconds)
    return d.read()["errs"]


def test(d):
    results = []

    def check(name, ok, info=""):
        results.append((name, ok, info))
        print(f"{'PASS' if ok else 'FAIL'}  {name}  {info}")

    d.set(rate=0, loopback=2, prbs=1, idle=1, forceerr=0, manual=1, lpm=1, data=0)   # known start
    d.restart()
    time.sleep(0.1)
    s = d.wait_ready()
    show(s)
    check("reset sequence reaches READY", s["st"] == 7, ST.get(s["st"]))
    check("all 8 CPLLs locked", s["cplllock"] == 0xFF, f"{s['cplllock']:08b}")
    check("TX phase alignment done", s["ts"] == 8, TS.get(s["ts"]))
    if s["f_ref"]:
        check("pclk = 1.25 x refclk at 2.5 GT/s", abs(s["f_pclk"] / s["f_ref"] - 1.25) < 0.001,
              f"{s['f_pclk'] / s['f_ref']:.4f}")
    for idle in (1, 0):
        d.set(idle=idle)
        time.sleep(0.05)
        e = soak(d, 2.0)
        check(f"PRBS-7 loopback 2.5 GT/s, TX idle={idle}: no errors in 2 s", max(e) == 0, e)
    d.set(forceerr=1)
    time.sleep(0.01)
    d.set(forceerr=0)
    e = d.read()["errs"]
    check("checker sees forced errors", min(e) > 0, e)
    d.set(idle=1)            # PCIe mode: the GTX changes rate only while TX is in electrical idle
    d.set(rate=1)
    s = d.wait_ready()
    check("switch to 5 GT/s", s["st"] == 7 and s["cur_rate"] == 1 and s["ts"] == 8,
          f"{ST.get(s['st'])} rate {s['cur_rate']} align {TS.get(s['ts'])}")
    time.sleep(0.6)          # let a full frequency window pass at the new rate
    s = d.read()
    if s["f_ref"]:
        check("pclk = 2.5 x refclk at 5 GT/s", abs(s["f_pclk"] / s["f_ref"] - 2.5) < 0.002,
              f"{s['f_pclk'] / s['f_ref']:.4f}")
    e = soak(d, 2.0)
    s = d.read()
    check("PRBS-7 loopback 5 GT/s: no errors in 2 s", s["st"] == 7 and max(e) == 0, e)
    d.set(prbs=0, data=1, idle=0)   # 8b/10b data needs TX out of electrical idle
    time.sleep(0.05)
    e = soak(d, 1.0)
    s = d.read()
    check("8b/10b data loopback 5 GT/s (K28.5/D21.5)", s["st"] == 7 and max(e) == 0,
          f"{e} aligned {s['byteisaligned']:08b}")
    d.set(idle=1)
    d.set(rate=0)
    s = d.wait_ready()
    d.set(idle=0)
    time.sleep(0.05)
    e = soak(d, 1.0)
    s = d.read()
    check("back to 2.5 GT/s, data loopback", s["st"] == 7 and s["cur_rate"] == 0 and max(e) == 0, e)
    # (auto = per-lane TX alignment, TXPHALIGNEN = 0, failed on lane 5 on 2026-10-31; the factory uses manual)
    d.set(manual=1, idle=1)
    d.restart()
    time.sleep(0.1)
    s = d.wait_ready()
    print()
    show(s)
    print()
    print(f"{sum(ok for _, ok, _ in results)}/{len(results)} checks passed")


def main():
    d = S1()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        show(d.read())
    elif cmd == "set":
        d.set(**dict(a.split("=") for a in sys.argv[2:]))
        time.sleep(0.05)
        show(d.read())
    elif cmd == "restart":
        d.restart()
        time.sleep(0.1)
        show(d.wait_ready())
    elif cmd == "clear":
        d.clear()
    elif cmd == "test":
        test(d)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
