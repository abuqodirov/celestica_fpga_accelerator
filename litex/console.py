#!/usr/bin/env python3
"""LiteX JTAG-UART console over the HS3, without OpenOCD (uses calc/host/hs3_jtag.py).

Usage: console.py [--seconds N] [--cmd "mem_test 0x40000000 0x100000" ...] [--log file]
Protocol (LiteX JTAGPHY on BSCANE2 USER1): each 11-bit DR scan carries
  host->FPGA: bit0 = host ready to receive, bits1-8 = byte, bit9 = byte valid
  FPGA->host: bit0 = FPGA ready to receive, bits1-8 = byte, bit9 = byte valid
Each --cmd is typed (with Enter) once the console has been quiet for --quiet seconds.
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "calc", "host"))
from hs3_jtag import HS3Jtag  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=15)
    ap.add_argument("--cmd", action="append", default=[])
    ap.add_argument("--quiet", type=float, default=1.5)
    ap.add_argument("--log")
    args = ap.parse_args()

    j = HS3Jtag(freq=6e6)
    j.ir(0x02)
    out = bytearray()
    pending = b""
    cmds = list(args.cmd)
    t0 = last = time.time()
    try:
        while time.time() - t0 < args.seconds:
            word = 0x001
            fpga_ready = True
            if pending:
                word = 0x201 | (pending[0] << 1)
            v = j.dr(word, 11)
            fpga_ready = v & 1
            if pending and fpga_ready:
                pending = pending[1:]
            if v & 0x200:
                ch = (v >> 1) & 0xFF
                out.append(ch)
                sys.stdout.write(chr(ch))
                sys.stdout.flush()
                last = time.time()
            if not pending and cmds and time.time() - last > args.quiet:
                pending = cmds.pop(0).encode() + b"\n"
                last = time.time()
    finally:
        j.close()
        if args.log:
            open(args.log, "wb").write(out)
    print()


if __name__ == "__main__":
    main()
