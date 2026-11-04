#!/usr/bin/env python3
"""Soak monitor: poll XADC + STAT register over JTAG and log to CSV.

Usage: soak_monitor.py <out.csv> [duration_s] [interval_s]
Each sample: temperature, VCCINT, VCCAUX, VCCBRAM, DONE, CRC error, over-temp,
raw STAT. A failed JTAG read is logged as a row with jtag_ok=0 instead of aborting,
so a board that drops off mid-test shows up in the data.
"""
import os
import csv, json, re, subprocess, sys, time

OFL = [os.path.expanduser("~/.local/bin/openFPGALoader"), "-c", "digilent_hs3"]

def run(args):
    p = subprocess.run(OFL + args, capture_output=True, text=True, timeout=30)
    return p.returncode, p.stdout + p.stderr

def read_xadc():
    rc, out = run(["--read-xadc"])
    m = re.search(r"\{.*\}", out, re.S)
    if rc or not m:
        return None
    # openFPGALoader prints trailing commas; strip them so json can parse it.
    data = json.loads(re.sub(r",\s*([}\]])", r"\1", m.group(0)))
    raw6 = data["raw"].get("6", 0)
    return {
        "temp_c": data["temp"],
        "vccint": data["vccint"],
        "vccaux": data["vccaux"],
        "vccbram": raw6 / 65536 * 3.0,  # same scaling as VCCINT/VCCAUX
    }

def read_stat():
    rc, out = run(["--read-register", "STAT"])
    m = re.search(r"Register raw value: (0x[0-9a-fA-F]+)", out)
    if rc or not m:
        return None
    field = lambda name: re.search(rf"^{name}\s+(\S.*)$", out, re.M).group(1).strip()
    return {
        "stat_raw": m.group(1),
        "done": int(field("Done"), 16),
        "crc_error": 0 if field("CRC Error").startswith("No") else 1,
        "over_temp": int(field("XADC Over temp"), 16),
        "mmcm_lock": int(field("MMCM lock"), 16),
    }

def main():
    out_path = sys.argv[1]
    duration = float(sys.argv[2]) if len(sys.argv) > 2 else 1200
    interval = float(sys.argv[3]) if len(sys.argv) > 3 else 5
    cols = ["t_s", "wall", "jtag_ok", "temp_c", "vccint", "vccaux", "vccbram",
            "done", "crc_error", "over_temp", "mmcm_lock", "stat_raw"]
    t0 = time.time()
    with open(out_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        while time.time() - t0 < duration:
            ts = time.time()
            row = {"t_s": round(ts - t0, 1), "wall": time.strftime("%H:%M:%S")}
            try:
                x, s = read_xadc(), read_stat()
            except subprocess.TimeoutExpired:
                x = s = None
            row["jtag_ok"] = int(bool(x and s))
            row.update(x or {})
            row.update(s or {})
            w.writerow(row)
            f.flush()
            if x and s:
                print(f"{row['wall']} t={row['t_s']:7.1f}s  T={x['temp_c']:5.1f}C  "
                      f"VCCINT={x['vccint']:.3f}  VCCAUX={x['vccaux']:.3f}  "
                      f"VCCBRAM={x['vccbram']:.3f}  DONE={s['done']} CRC_ERR={s['crc_error']} "
                      f"MMCM={s['mmcm_lock']}", flush=True)
            else:
                print(f"{row['wall']} t={row['t_s']:7.1f}s  JTAG READ FAILED", flush=True)
            time.sleep(max(0, interval - (time.time() - ts)))

if __name__ == "__main__":
    main()
