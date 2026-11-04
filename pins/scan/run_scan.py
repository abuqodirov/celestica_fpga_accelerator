#!/usr/bin/env python3
"""Read the pin-scan design over JTAG: clock frequencies and pin levels."""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "calc", "host"))
from hs3_jtag import HS3Jtag, IR_USER1  # noqa: E402

DR_BITS = 168
CLOCKS = ["CFGMCLK (internal)", "AA28 (YPCB 50 MHz)", "AH27/AH28 (YPCB 200 MHz #1)", "G25/G26 (YPCB 200 MHz #2)"]
LEVELS = ["P30 LED_R?", "M30 LED_G?", "N30 LED_Y?", "R28 SW_RESET?", "N24 LM73 SCL?", "N25 LM73 SDA?",
          "P25 LM73 ALERT?", "R26 SMBus SCL?", "R27 SMBus SDA?", "Y26 PCIe PERST#?"]


def gray_to_bin(g):
    b = 0
    while g:
        b ^= g
        g >>= 1
    return b


def sample(j):
    v = j.dr(0, DR_BITS)
    if (v >> 160) & 0xFF != 0xC3:
        sys.exit(f"pin-scan design not found (magic 0x{(v >> 160) & 0xFF:02x}); load scan_*.bit first")
    counts = [gray_to_bin((v >> (32 * i)) & 0xFFFFFFFF) for i in range(4)]
    levels = (v >> 128) & 0x3FF
    return time.perf_counter(), counts, levels


def main():
    j = HS3Jtag(freq=6e6)
    try:
        j.ir(IR_USER1)
        t0, c0, _ = sample(j)
        seen = []
        while time.perf_counter() - t0 < 2.0:
            seen.append(sample(j)[2])
            time.sleep(0.01)
        t1, c1, _ = sample(j)
    finally:
        j.close()

    print("Clock frequencies (2 s window, host-timed):")
    for name, a, b in zip(CLOCKS, c0, c1):
        f = ((b - a) % (1 << 32)) / (t1 - t0)
        status = "toggling" if f > 1e3 else "NOT TOGGLING"
        print(f"  {name:30} {f / 1e6:10.4f} MHz   {status}")

    print(f"\nPin levels ({len(seen)} samples over 2 s):")
    for i, name in enumerate(LEVELS):
        vals = {(s >> i) & 1 for s in seen}
        state = "toggling" if len(vals) > 1 else ("HIGH" if vals == {1} else "LOW")
        print(f"  {name:20} {state}")


if __name__ == "__main__":
    main()
