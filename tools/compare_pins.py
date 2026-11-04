#!/usr/bin/env python3
"""Compare the pins a decoded design uses (fasm_pins.py output) with the
YPCB-00338-1P1 reverse-engineered pinout.

Usage: compare_pins.py <fasm_pins output> <ypcb_repo_dir>
"""
import re
import sys
from collections import Counter


def ypcb_names(repo):
    names = {}
    for line in open(f"{repo}/constraints/ypcb003381p1.xdc"):
        m = re.search(r"PACKAGE_PIN\s+(\w+)\s+\[get_ports\s+\{?([^}\]]+?)\}?\]", line)
        if m:
            names[m.group(1)] = m.group(2).strip()
    for ch in ("CH0", "CH1"):
        for line in open(f"{repo}/constraints/MEMORY_{ch}.ucf"):
            m = re.search(r'NET\s+"([^"]+)"\s+LOC\s*=\s*"(\w+)"', line)
            if m:
                names[m.group(2)] = f"{ch.lower()}_{m.group(1)}"
    for line in open(f"{repo}/ypcb003381p1/1.0/part0_pins.xml"):
        m = re.search(r'name="([^"]+)".*loc="(\w+)"', line)
        if m and m.group(2) not in names:
            names[m.group(2)] = m.group(1)
    return names


def direction(feats):
    out = "DRIVE" in feats
    inp = any(k in feats for k in (".IN ", "IN_ONLY", "IN_DIFF")) or feats.endswith(".IN")
    return "in/out" if out and inp else "out" if out else "in" if inp else "?"


def standard(feats):
    if "LVDS" in feats and "IN_DIFF" in feats:
        return "LVDS/diff in"
    if "SSTL" in feats and ("DRIVE" in feats or "IN_DIFF" in feats or "IN_TERM" in feats):
        return "SSTL15"
    for s in ("LVCMOS33", "LVCMOS25", "LVCMOS18", "LVCMOS15"):
        if f"{s}.DRIVE" in feats or f"{s}." in feats:
            return s
    return "LVCMOS"


def main():
    pins_txt, repo = sys.argv[1], sys.argv[2]
    names = ypcb_names(repo)
    used = {}
    for line in open(pins_txt):
        f = line.split()
        used[f[0]] = (f[2], f[3], " ".join(f[5:]))

    groups = Counter()
    rows = []
    for pin, (bank, func, feats) in sorted(used.items(), key=lambda kv: (int(kv[1][0]), kv[0])):
        name = names.get(pin, "-")
        grp = re.sub(r"\[\d+\]|_\d+$|\d+$", "", name.split("_", 1)[1] if name.startswith("ch") else name)
        groups[(name != "-", grp if name != "-" else "unknown")] += 1
        rows.append((pin, bank, direction(feats), standard(feats), name))

    print("Non-DDR3 pins used by the factory design:")
    print(f"  {'pin':5} {'bank':>4}  {'dir':7} {'standard':13} YPCB-00338-1P1 name")
    for pin, bank, d, std, name in rows:
        if not name.startswith("ch") and not name.startswith("linear_flash") and not name.startswith("bpi"):
            print(f"  {pin:5} {bank:>4}  {d:7} {std:13} {name}")
    ddr = [r for r in rows if r[4].startswith("ch")]
    flash = [r for r in rows if r[4].startswith(("linear_flash", "bpi"))]
    print(f"\nDDR3 pins: {len(ddr)} used pins match YPCB DDR3 pins "
          f"(ch0 {sum(r[4].startswith('ch0') for r in ddr)}, ch1 {sum(r[4].startswith('ch1') for r in ddr)}); "
          f"standards: {dict(Counter(r[3] for r in ddr))}")
    print(f"Flash pins: {len(flash)} used pins match YPCB flash pins")
    ypcb_ddr = [p for p, n in names.items() if n.startswith("ch")]
    missing = [p for p in ypcb_ddr if p not in used]
    print(f"YPCB DDR3 pins NOT used by factory design: {len(missing)} of {len(ypcb_ddr)} {missing[:12]}")
    unknown = [r for r in rows if r[4] == "-"]
    print(f"Used pins with no YPCB name: {len(unknown)}")
    interesting = ["P30", "M30", "N30", "AA28", "AH27", "AH28", "G25", "G26", "R28", "N24", "N25",
                   "P25", "R26", "R27", "Y26"]
    print("\nYPCB control pins and whether the factory design uses them:")
    for p in interesting:
        u = used.get(p)
        print(f"  {p:5} {names.get(p, '?'):24} " +
              (f"USED  {direction(u[2]):7} {standard(u[2])}" if u else "not used"))


if __name__ == "__main__":
    main()
