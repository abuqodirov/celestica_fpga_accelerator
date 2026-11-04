#!/usr/bin/env python3
"""Print the configuration packet sequence of a 7-series bitstream (.bit or raw .bin).

Usage: bitparse.py <file> [max_bytes]
Skips the FDRI frame payload and prints every register write / command.
"""
import struct
import sys

REGS = {0x00: "CRC", 0x01: "FAR", 0x02: "FDRI", 0x03: "FDRO", 0x04: "CMD", 0x05: "CTL0",
        0x06: "MASK", 0x07: "STAT", 0x08: "LOUT", 0x09: "COR0", 0x0A: "MFWR", 0x0B: "CBC",
        0x0C: "IDCODE", 0x0D: "AXSS", 0x0E: "COR1", 0x10: "WBSTAR", 0x11: "TIMER",
        0x16: "BOOTSTS", 0x18: "CTL1", 0x1F: "BSPI"}
CMDS = {0: "NULL", 1: "WCFG", 2: "MFW", 3: "LFRM", 4: "RCFG", 5: "START", 6: "RCAP", 7: "RCRC",
        8: "AGHIGH", 9: "SWITCH", 10: "GRESTORE", 11: "SHUTDOWN", 12: "GCAPTURE", 13: "DESYNC",
        15: "IPROG", 16: "CRCC", 17: "LTIMER"}


def main():
    path = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
    d = open(path, "rb").read()
    if limit:
        d = d[:limit]
    i = d.find(bytes.fromhex("aa995566"))
    print(f"{path}: {len(d)} bytes, sync word at byte {i}")
    i += 4
    w = lambda j: struct.unpack(">I", d[j:j + 4])[0]
    last_reg = None
    nops = 0
    while i + 4 <= len(d):
        h = w(i)
        t = h >> 29
        if h == 0x20000000:
            nops += 1
            i += 4
            continue
        if nops:
            print(f"  {i - 4 * nops:9}  NOP x{nops}")
            nops = 0
        if t == 1:
            op = (h >> 27) & 3
            reg = (h >> 13) & 0x1F
            n = h & 0x7FF
            last_reg = reg
            name = REGS.get(reg, f"reg{reg:#x}")
            vals = [w(i + 4 + 4 * k) for k in range(min(n, 4))]
            extra = ""
            if reg == 0x04 and vals:
                extra = f"  ({CMDS.get(vals[0], vals[0])})"
            kind = {1: "read", 2: "write"}.get(op, f"op{op}")
            print(f"  {i:9}  T1 {kind:5} {name:8} words={n:<4} {' '.join(f'{v:08x}' for v in vals)}{extra}")
            i += 4 + 4 * n
        elif t == 2:
            n = h & 0x7FFFFFF
            print(f"  {i:9}  T2 {REGS.get(last_reg, last_reg)} words={n} ({n * 4} bytes payload)")
            i += 4 + 4 * n
        else:
            if h != 0xFFFFFFFF:
                print(f"  {i:9}  ?? {h:08x}")
            i += 4
    if nops:
        print(f"  NOP x{nops}")


if __name__ == "__main__":
    main()
