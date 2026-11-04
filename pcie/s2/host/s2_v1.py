#!/usr/bin/env python3
"""PCIe stage 2 on the card: watch the PCIe link over JTAG (design: ../s2_top.v).

  s2.py status              read and print everything
  s2.py trace               print the link recorder (every LTSSM change since the block left reset)
  s2.py watch [seconds]     print LTSSM / link state once per second
  s2.py set key=val ...     change control fields: pcie_en=0/1 (hold the PCIe block in reset), mode=0/1
                            (recorder: 0 = link fields only, 1 = also per-lane RX idle/valid/aligned), lpm=0/1
  s2.py restart             rerun the lane reset sequence and retrain (the block is reset too)
  s2.py rearm               restart the recorder
  s2.py clear               clear the counters
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "calc", "host"))
from hs3_jtag import HS3Jtag, IR_USER1   # noqa: E402

IR_USER2 = 0x03
DR_BITS = 1024
IDCODE = 0x23751093
SCLK_MHZ = 64.2           # CFGMCLK, measured 2026-10-31 (stage 1); only used to print absolute MHz
WINDOW = 1 << 24          # sclk cycles per frequency-count window
PCLK_MHZ = 125.0

CTL = {"pcie_en": (2, 1), "mode": (4, 1), "lpm": (6, 1)}   # name: (lsb, width)
ST = {0: "START", 1: "PDREL", 2: "CPLLRST", 3: "LOCK", 4: "GTRST", 5: "SYNC", 6: "SYNCW", 7: "READY", 15: "ERROR"}
TS = {0: "IDLE", 1: "DLYSRST", 2: "MINIT", 3: "MALIGN", 4: "MDLYEN", 5: "SINIT", 6: "SALIGN", 7: "MDLYEN2",
      8: "DONE", 15: "ERR"}
LTSSM = {  # pg054 Table 11, pl_ltssm_state
    0x00: "Detect.Quiet", 0x01: "Detect.Quiet", 0x02: "Detect.Active", 0x03: "Detect.Active",
    0x04: "Polling.Active", 0x05: "Polling.Config", 0x06: "Polling.Comp.PreSendEIOS",
    0x07: "Polling.Comp.PreTimeout", 0x08: "Polling.Comp.SendPattern", 0x09: "Polling.Comp.PostSendEIOS",
    0x0A: "Polling.Comp.PostTimeout", 0x0B: "Cfg.Linkwidth.State0", 0x0C: "Cfg.Linkwidth.State1",
    0x0D: "Cfg.Linkwidth.Accept0", 0x0E: "Cfg.Linkwidth.Accept1", 0x0F: "Cfg.Lanenum.Wait",
    0x10: "Cfg.Lanenum.Accept", 0x11: "Cfg.Complete.x1", 0x12: "Cfg.Complete.x2", 0x13: "Cfg.Complete.x4",
    0x14: "Cfg.Complete.x8", 0x15: "Cfg.Idle", 0x16: "L0", 0x17: "L1.Entry0", 0x18: "L1.Entry1",
    0x19: "L1.Entry2", 0x1A: "L1.Idle", 0x1B: "L1.Exit", 0x1C: "Recovery.RcvrLock", 0x1D: "Recovery.RcvrCfg",
    0x1E: "Recovery.Speed0", 0x1F: "Recovery.Speed1", 0x20: "Recovery.Idle", 0x21: "HotReset",
    0x22: "Disabled.Entry0", 0x23: "Disabled.Entry1", 0x24: "Disabled.Entry2", 0x25: "Disabled.Idle",
    0x2D: "TimeoutToDetect", 0x2E: "Loopback.Entry0", 0x2F: "Loopback.Entry1", 0x30: "Loopback.Active0",
    0x31: "Loopback.Exit0", 0x32: "Loopback.Exit1", 0x33: "LoopbackMaster.Entry0",
}
WIDTH = {0: "x1", 1: "x2", 2: "x4", 3: "x8"}
# link_t field layout (status bits 327:264), LSB first, as packed in s2_top.v
LINK = [("ltssm", 6), ("phy_lnk_up", 1), ("trn_lnk_up", 1), ("user_rst_n", 1), ("pcie_rst_n", 1),
        ("phy_gate", 1), ("sel_width", 2), ("sel_rate", 1), ("hot_rst", 1), ("init_width", 3), ("gen2_cap", 1),
        ("partner_gen2", 1), ("upcfg_cap", 1), ("lane_rev", 2), ("tx_pm", 3), ("rx_pm", 2),
        ("link_training", 1), ("dll_active", 1), ("bm_en", 1), ("mem_en", 1), ("err_cor", 1),
        ("err_nonfatal", 1), ("err_fatal", 1), ("err_ur", 1), ("pm_state", 2), ("link_state", 3),
        ("cur_speed", 2), ("neg_width", 4), ("tbuf_av", 6), ("tcfg_req", 1), ("tx_pd0", 2), ("rcvrdet", 1),
        ("tx_rate", 1)]


def field(v, lsb, width):
    return (v >> lsb) & ((1 << width) - 1)


def ltssm_name(s):
    return f"{s:02x} {LTSSM.get(s, '?')}"


class S2:
    def __init__(self):
        self.j = HS3Jtag(freq=6e6)
        idc = self.j.idcode()
        if idc != IDCODE:
            raise SystemExit(f"unexpected IDCODE {idc:#x}")
        self.j.ir(IR_USER1)

    def raw(self):
        self.j.ir(IR_USER1)
        return self.j.dr(0, DR_BITS)

    def read(self):
        v = self.raw()
        if field(v, 0, 8) != 0xC2:
            raise SystemExit(f"stage-2 design not loaded (magic {field(v, 0, 8):#x})")
        s = {"version": field(v, 8, 8), "ctl": field(v, 128, 32), "st": field(v, 160, 4),
             "err_st": field(v, 164, 4), "core_rst_n": field(v, 172, 1), "pcie_en": field(v, 173, 1),
             "perst_n": field(v, 174, 1), "pll_locked": field(v, 175, 1),
             "cplllock": field(v, 176, 8), "txresetdone": field(v, 184, 8), "rxresetdone": field(v, 192, 8),
             "txphaligndone": field(v, 200, 8), "rxelecidle": field(v, 208, 8), "rxvalid": field(v, 216, 8),
             "chanisaligned": field(v, 224, 8), "phystatus": field(v, 232, 8), "byteisaligned": field(v, 240, 8),
             "txelecidle": field(v, 248, 8), "refclklost": field(v, 256, 8),
             "seen": field(v, 328, 8), "ts": field(v, 336, 4), "ts_err": field(v, 340, 4),
             "trp": field(v, 344, 9), "twp": field(v, 353, 9), "trace_full": field(v, 362, 1),
             "f_ref": field(v, 368, 32), "f_pclk": field(v, 400, 32), "f_uclk": field(v, 432, 32),
             "windows": field(v, 464, 32), "ready_time": field(v, 496, 32),
             "restarts": field(v, 528, 16), "perst_falls": field(v, 544, 16),
             "last_cfg_addr": field(v, 560, 7), "last_cfg_wr": field(v, 567, 1),
             "rcv_found": field(v, 568, 8), "rcv_done": field(v, 576, 8), "lnk_time": field(v, 592, 32),
             "first_tlp": field(v, 768, 128), "last_tlp": field(v, 896, 128)}
        for i, n in enumerate(("n_l0", "n_recovery", "n_detect", "n_hot_rst", "n_cfg_rd", "n_cfg_wr", "n_rx_tlp",
                               "n_msg", "n_pme_to")):
            s[n] = field(v, 624 + 16 * i, 16)
        lk, pos = field(v, 264, 64), 0
        for n, w in LINK:
            s[n] = field(lk, pos, w)
            pos += w
        return s

    def write_ctl(self, ctl, restart=False, rearm=False, rptr=False, clear=False):
        w = (ctl & ~0x42B) | 1 | (2 if restart else 0) | (8 if rearm else 0) | (0x20 if rptr else 0) \
            | (0x400 if clear else 0)
        self.j.ir(IR_USER1)
        self.j.dr(w, DR_BITS)

    def set(self, **kw):
        ctl = self.read()["ctl"]
        for k, val in kw.items():
            lsb, width = CTL[k]
            ctl = (ctl & ~(((1 << width) - 1) << lsb)) | ((int(val) & ((1 << width) - 1)) << lsb)
        self.write_ctl(ctl)

    def trace(self):
        s = self.read()
        n = 512 if s["trace_full"] else s["twp"]
        self.write_ctl(s["ctl"], rptr=True)
        self.j.ir(0x03)
        return [self.j.dr(0, 72) for _ in range(n)]


def ctl_str(ctl):
    return " ".join(f"{k}={field(ctl, *CTL[k])}" for k in CTL)


def link_line(s):
    up = "LINK UP" if s["trn_lnk_up"] else ("phy up" if s["phy_lnk_up"] else "no link")
    return (f"LTSSM {ltssm_name(s['ltssm'])}  {up}  width {WIDTH[s['sel_width']]} "
            f"rate {'5.0' if s['sel_rate'] else '2.5'} GT/s  DL active {s['dll_active']}  "
            f"mem_en {s['mem_en']} bus_master {s['bm_en']}")


def show(s):
    w = WINDOW / SCLK_MHZ
    print(f"sequencer {ST.get(s['st'], s['st'])}" + (f" (timed out in {ST.get(s['err_st'])})" if s["err_st"] else "")
          + f"   tx-align {TS.get(s['ts'], s['ts'])}" + (f" (timed out in {TS.get(s['ts_err'])})" if s["ts_err"] else "")
          + f"   PERST# {s['perst_n']}  pll_locked {s['pll_locked']}  pcie block "
          + ("running" if s["core_rst_n"] else "IN RESET") + f"  (ctl {ctl_str(s['ctl'])})")
    print(f"restarts {s['restarts']}  PERST# falls {s['perst_falls']}  PHY ready after "
          f"{s['ready_time'] / SCLK_MHZ / 1000:.2f} ms  link up after {s['lnk_time'] / PCLK_MHZ / 1000:.2f} ms")
    if s["f_ref"]:
        print(f"clocks: ref {s['f_ref'] / w:.2f} MHz  pclk/ref {s['f_pclk'] / s['f_ref']:.4f}  "
              f"userclk/ref {s['f_uclk'] / s['f_ref']:.4f}  (windows {s['windows']})")
    else:
        print(f"clocks: NO reference clock seen (windows {s['windows']})")
    print(link_line(s))
    print(f"  phy_lnk_up {s['phy_lnk_up']} user_rst_n {s['user_rst_n']} pcie_rst_n {s['pcie_rst_n']} "
          f"init_width {s['init_width']} partner_gen2 {s['partner_gen2']} lane_rev {s['lane_rev']} "
          f"tx_pm {s['tx_pm']} rx_pm {s['rx_pm']} link_training {s['link_training']}")
    print(f"  cfg: link_state {s['link_state']} pm_state D{s['pm_state']} cur_speed {s['cur_speed']} "
          f"neg_width {s['neg_width']}  errors cor {s['err_cor']} nonfatal {s['err_nonfatal']} "
          f"fatal {s['err_fatal']} ur {s['err_ur']}  tbuf_av {s['tbuf_av']}")
    print(f"  PIPE: lane0 power {s['tx_pd0']} rcvrdet {s['rcvrdet']} tx_rate {s['tx_rate']}  "
          f"receiver detected {s['rcv_found']:08b} (of tried {s['rcv_done']:08b})")
    print(f"counters: L0 entries {s['n_l0']}  recovery {s['n_recovery']}  detect {s['n_detect']}  "
          f"hot reset {s['n_hot_rst']}  config reads {s['n_cfg_rd']} writes {s['n_cfg_wr']} "
          f"(last {'wr' if s['last_cfg_wr'] else 'rd'} dword {s['last_cfg_addr']:#x})  "
          f"RX TLPs {s['n_rx_tlp']}  messages {s['n_msg']}  PME_Turn_Off {s['n_pme_to']}")
    if s["n_rx_tlp"]:
        print(f"  first RX TLP {s['first_tlp']:032x}\n  last RX TLP  {s['last_tlp']:032x}")
    print(f"recorder: {s['twp']}{' (FULL)' if s['trace_full'] else ''} entries")
    print("lane:            " + "  ".join(f"{i:>5}" for i in range(8)))
    for k in ("cplllock", "refclklost", "txresetdone", "rxresetdone", "txphaligndone", "txelecidle", "rxelecidle",
              "byteisaligned", "chanisaligned", "rxvalid", "phystatus"):
        print(f"{k:16s} " + "  ".join(f"{(s[k] >> i) & 1:>5}" for i in range(8)))


def show_trace(entries):
    prev = None
    for n, e in enumerate(entries):
        t = field(e, 0, 32) / PCLK_MHZ
        lt = field(e, 32, 6)
        line = (f"{n:3d} {t:12.1f} us  {ltssm_name(lt):26s} phy {field(e, 38, 1)} trn {field(e, 39, 1)} "
                f"{WIDTH[field(e, 40, 2)]} rate {field(e, 42, 1)} hot {field(e, 43, 1)} pd0 {field(e, 44, 2)} "
                f"rcvrdet {field(e, 46, 1)} txrate {field(e, 47, 1)}  "
                f"rxEI {field(e, 48, 8):08b} aligned {field(e, 56, 8):08b} valid {field(e, 64, 8):08b}")
        if prev is not None:
            line += f"  (+{(field(e, 0, 32) - field(prev, 0, 32)) / PCLK_MHZ:.1f} us)"
        print(line)
        prev = e


def main():
    d = S2()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        show(d.read())
    elif cmd == "trace":
        show_trace(d.trace())
    elif cmd == "watch":
        t_end = time.time() + (float(sys.argv[2]) if len(sys.argv) > 2 else 30)
        while time.time() < t_end:
            s = d.read()
            print(time.strftime("%H:%M:%S"), link_line(s), f" L0 {s['n_l0']} rec {s['n_recovery']} "
                  f"det {s['n_detect']} cfg rd/wr {s['n_cfg_rd']}/{s['n_cfg_wr']} tlps {s['n_rx_tlp']}", flush=True)
            time.sleep(1)
    elif cmd == "set":
        d.set(**dict(a.split("=") for a in sys.argv[2:]))
        time.sleep(0.05)
        show(d.read())
    elif cmd == "restart":
        d.write_ctl(d.read()["ctl"], restart=True)
        time.sleep(0.2)
        show(d.read())
    elif cmd == "rearm":
        d.write_ctl(d.read()["ctl"], rearm=True)
    elif cmd == "clear":
        d.write_ctl(d.read()["ctl"], clear=True)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
