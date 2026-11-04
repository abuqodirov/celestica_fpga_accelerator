#!/usr/bin/env python3
"""Compare the PCIe/GTX tiles of two decoded bitstreams (bit2fasm --verbose output).

Known features are compared by name; bits the database cannot name (unknown_bit lines) are mapped
to their tile via the tilegrid and compared as raw tile bits.

  compare_tiles.py factory_verbose.fasm probe_verbose.fasm
"""
import collections, json, os, re, sys

TILE_RE = re.compile(r"^(GTX_CHANNEL_\d_X309Y(214|225|243|254|266|277|295|306)|GTX_COMMON_X309Y(231|283)|PCIE_BOT_X279Y219)\.")
TG = os.path.expanduser("~/tools/prjxray-db/kintex7/xc7k480t/tilegrid.json")


def load(path, idx):
    feats = collections.defaultdict(set)
    pat = re.compile(r'unknown_bit = "([0-9a-f]+)_(\d+)_(\d+)"')
    for line in open(path):
        m = TILE_RE.match(line)
        if m:
            feats[m.group(1)].add(line.strip()[len(m.group(1)) + 1:])
            continue
        if not line.startswith("{"):
            continue
        m = pat.search(line)
        fa, w, bit = int(m.group(1), 16), int(m.group(2)), int(m.group(3))
        base = fa & ~0x7F
        for off, nw, nf, t in idx.get(base, ()):
            if off <= w < off + nw and fa - base < nf:
                if TILE_RE.match(t + "."):
                    feats[t].add(f"?bit {fa - base:02d}_{(w - off) * 32 + bit:04d}")
                break
    return feats


def main(a, b):
    tg = json.load(open(TG))
    idx = collections.defaultdict(list)
    for t, v in tg.items():
        bits = v.get("bits", {}).get("CLB_IO_CLK")
        if bits:
            idx[int(bits["baseaddr"], 16)].append((bits["offset"], bits["words"], bits["frames"], t))
    fa, fb = load(a, idx), load(b, idx)
    for t in sorted(set(fa) | set(fb)):
        only_a, only_b = sorted(fa[t] - fb[t]), sorted(fb[t] - fa[t])
        print(f"== {t}: same {len(fa[t] & fb[t])}, only factory {len(only_a)}, only ours {len(only_b)}")
        for f in only_a:
            print("   factory:", f[:150])
        for f in only_b:
            print("   ours:   ", f[:150])


if __name__ == "__main__":
    main(*sys.argv[1:3])
