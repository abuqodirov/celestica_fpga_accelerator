#!/usr/bin/env python3
"""Run a minirv program on the FPGA over JTAG (load minirv.bit first).

Usage: run_minirv.py prog.bin [--regions addr:words ...] [--json out.json] [--no-wait]
Holds the CPU in reset, writes the program into RAM at 0x3000_0000, releases it, waits
for ebreak (unless --no-wait), then collects console output, counters and RAM regions.
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "..", "calc", "host"))
from hs3_jtag import HS3Jtag, IR_USER1  # noqa: E402

DR = 184
CMD_WRITE, CMD_READ, CMD_CTRL, CMD_POP = 1, 2, 3, 4


class Minirv:
    def __init__(self, jtag):
        self.j = jtag
        self.j.ir(IR_USER1)
        self.tag = 0
        self.status()

    def _scan(self, cmd=0, addr=0, wdata=0, tag=0):
        v = self.j.dr(wdata | (addr << 32) | (cmd << 48) | (tag << 52), DR)
        st = {"result": v & 0xFFFFFFFF, "tag": (v >> 32) & 0xF, "done": (v >> 36) & 1,
              "halted": (v >> 37) & 1, "running": (v >> 38) & 1, "leds": (v >> 39) & 7,
              "pc": (v >> 48) & 0xFFFFFFFF, "cycles": (v >> 80) & 0xFFFFFFFF,
              "instret": (v >> 112) & 0xFFFFFFFF, "a0": (v >> 144) & 0xFFFFFFFF,
              "magic": (v >> 176) & 0xFF}
        if st["magic"] != 0x5C:
            raise RuntimeError(f"minirv design not found (magic 0x{st['magic']:02x}); run `make load`")
        return st

    def status(self):
        return self._scan()

    def command(self, cmd, addr=0, wdata=0):
        self.tag = (self.tag % 15) + 1
        self._scan(cmd, addr, wdata, self.tag)
        for _ in range(100):
            st = self._scan()
            if st["done"] and st["tag"] == self.tag:
                return st["result"]
        raise RuntimeError(f"command {cmd} got no answer")

    def load(self, image):
        self.command(CMD_CTRL, 0, 0)
        image += b"\0" * (-len(image) % 4)
        for i in range(0, len(image), 4):
            self.command(CMD_WRITE, i // 4, int.from_bytes(image[i:i + 4], "little"))

    def run(self):
        self.command(CMD_CTRL, 0, 1)

    def pop_console(self):
        out = bytearray()
        while True:
            r = self.command(CMD_POP)
            if not r & 0x100:
                return out.decode(errors="replace")
            out.append(r & 0xFF)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("program")
    ap.add_argument("--regions", nargs="*", default=[])
    ap.add_argument("--json")
    ap.add_argument("--no-wait", action="store_true")
    ap.add_argument("--timeout", type=float, default=10.0)
    args = ap.parse_args()

    j = HS3Jtag(freq=6e6)
    try:
        m = Minirv(j)
        image = open(args.program, "rb").read()
        t0 = time.time()
        m.load(image)
        t_load = time.time() - t0
        m.run()
        if args.no_wait:
            print(f"loaded {len(image)} bytes in {t_load:.2f} s; running. Console:")
            print(m.pop_console(), end="")
            st = m.status()
            print(f"pc=0x{st['pc']:08x}  instret={st['instret']}  LEDs={st['leds']:03b} (left running)")
            return
        while not m.status()["halted"]:
            if time.time() - t0 > args.timeout:
                raise TimeoutError("program did not reach ebreak")
        st = m.status()
        console = m.pop_console()
        m.command(CMD_CTRL, 0, 0)               # hold the CPU so RAM is stable to read
        regions = {}
        for r in args.regions:
            addr, words = r.split(":")
            addr, words = int(addr, 16), int(words)
            regions[f"{addr:08x}"] = [m.command(CMD_READ, ((addr - 0x3000_0000) >> 2) + w) for w in range(words)]
        result = {"halted": True, "console": console, "a0": st["a0"], "pc": st["pc"],
                  "instret": st["instret"], "cycles": st["cycles"], "leds": st["leds"], "regions": regions}
        print(f"{os.path.basename(args.program)}: loaded {len(image)} bytes in {t_load:.2f} s; "
              f"{st['instret']} instructions in {st['cycles']} cycles = {st['cycles'] / 50:.1f} us at 50 MHz")
        if console:
            print("console:", console, end="" if console.endswith("\n") else "\n")
        if args.json:
            json.dump(result, open(args.json, "w"))
    finally:
        j.close()


if __name__ == "__main__":
    main()
