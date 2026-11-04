#!/usr/bin/env python3
"""Dump the BPI flash through the flashdump design (load flashdump.bit first).

Usage: run_dump.py <out.bin> [first_block] [n_blocks] [--raw]
A block is 512 words = 1 KiB; the full 64 MB flash is 65536 blocks.
Output is in bitstream/openFPGALoader order: the FPGA config data pins are bit-swapped,
so each 16-bit word is bit-reversed. --raw writes the D[15:0] bus words unchanged.
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "calc", "host"))
from hs3_jtag import HS3Jtag, IR_USER1  # noqa: E402

IR_USER2 = 0x03
WORDS = 512
DR1 = WORDS * 16 + 64
TOTAL_BLOCKS = 64 * 1024 * 1024 // (WORDS * 2)
REV8 = bytes(int(f"{b:08b}"[::-1], 2) for b in range(256))


def read_block(j, block):
    addr = block * WORDS
    j.ir(IR_USER2)
    j.dr(addr | (1 << 31), 32)
    j.ir(IR_USER1)
    for _ in range(50):
        v = j.dr(0, DR1)
        magic = (v >> (WORDS * 16 + 40)) & 0xFF      # fields total 8240 bits; top 16 are zero
        if magic != 0xF1:
            raise RuntimeError(f"flashdump design not found (magic 0x{magic:02x})")
        done = (v >> (WORDS * 16 + 32)) & 1
        got = (v >> (WORDS * 16)) & 0x1FFFFFF
        if done and got == addr:
            return v & ((1 << (WORDS * 16)) - 1)
    raise RuntimeError(f"block {block}: no valid data after 50 reads")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    raw = "--raw" in sys.argv
    out = args[0]
    first = int(args[1]) if len(args) > 1 else 0
    count = int(args[2]) if len(args) > 2 else TOTAL_BLOCKS - first
    j = HS3Jtag(freq=15e6)          # JTAG reads are unreliable above 20 MHz on the HS3
    t0 = time.time()
    try:
        with open(out, "wb") as f:
            for n, block in enumerate(range(first, first + count)):
                data = read_block(j, block).to_bytes(WORDS * 2, "little")
                if not raw:   # bit-reverse each 16-bit word: reverse bits per byte, swap bytes
                    rb = data.translate(REV8)
                    data = bytes(rb[i ^ 1] for i in range(len(rb)))
                f.write(data)
                if n % 4096 == 4095 or n == count - 1:
                    mb = (n + 1) * WORDS * 2 / 2**20
                    rate = mb / (time.time() - t0)
                    print(f"{mb:7.1f} MiB  {rate:5.2f} MiB/s", flush=True)
    finally:
        j.close()


if __name__ == "__main__":
    main()
