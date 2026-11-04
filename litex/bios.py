#!/usr/bin/env python3
"""Scriptable LiteX BIOS over the JTAG UART (same protocol as console.py).

    from bios import Bios
    b = Bios()                       # opens the HS3, waits for a prompt
    out = b.cmd("mem_read 0xf0002000")
    b.write(0xf0002000, 0x0e)        # mem_write
    words = b.read(0xf000201c, 2)    # mem_read, parsed into 32-bit words
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "calc", "host"))
from hs3_jtag import HS3Jtag  # noqa: E402

ANSI = re.compile(rb"\x1b\[[0-9;]*m")

# CSR map of the bitstream in use: set YPCB_BUILD to its build directory (default build_75).
BUILD = os.environ.get("YPCB_BUILD", os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_75"))


def csr(name):
    """Address of CSR register `name` (e.g. "sdram_dfii_control") from BUILD/csr.csv."""
    for line in open(os.path.join(BUILD, "csr.csv")):
        f = line.strip().split(",")
        if f[0] in ("csr_register", "csr_base") and f[1] == name:
            return int(f[2], 16)
    raise KeyError(name)


PROMPT = b"litex> "


class Bios:
    def __init__(self, freq=6e6, log=None):
        self.j = HS3Jtag(freq=freq)
        self.j.ir(0x02)
        self.rx = bytearray()
        self.log = open(log, "ab") if log else None

    def close(self):
        self.j.close()
        if self.log:
            self.log.close()

    def _scan(self, byte=None):
        word = 0x001 if byte is None else 0x201 | (byte << 1)
        v = self.j.dr(word, 11)
        if v & 0x200:
            ch = (v >> 1) & 0xFF
            self.rx.append(ch)
            if self.log:
                self.log.write(bytes([ch]))
        return v & 1  # FPGA ready to accept a byte

    def drain(self, quiet=0.3, limit=60):
        """Read until nothing arrives for `quiet` seconds; return and clear what came in."""
        t0 = last = time.time()
        n = len(self.rx)
        while time.time() - last < quiet and time.time() - t0 < limit:
            self._scan()
            if len(self.rx) != n:
                n = len(self.rx)
                last = time.time()
        out = bytes(self.rx)
        self.rx.clear()
        return out

    def sync(self, timeout=60):
        """Press Enter until a fresh prompt appears."""
        t0 = time.time()
        while time.time() - t0 < timeout:
            self.rx.clear()
            self._send(b"\n")
            if self._wait_prompt(3):
                return
        raise TimeoutError("no BIOS prompt")

    def _send(self, data):
        for b in data:
            while not self._scan(b):
                pass

    def _wait_prompt(self, timeout):
        t0 = time.time()
        while time.time() - t0 < timeout:
            self._scan()
            if ANSI.sub(b"", bytes(self.rx)).endswith(PROMPT):
                return True
        return False

    def cmd(self, line, timeout=30):
        """Type one command and return its output (echo and prompt stripped)."""
        self.rx.clear()
        self._send(line.encode() + b"\n")
        if not self._wait_prompt(timeout):
            raise TimeoutError(f"no prompt after {line!r}: {bytes(self.rx)[-200:]!r}")
        text = ANSI.sub(b"", bytes(self.rx)).decode(errors="replace").replace("\r", "")
        text = text[: -len(PROMPT)]
        first_nl = text.find("\n")
        return text[first_nl + 1:] if first_nl >= 0 else ""

    def write(self, addr, value):
        self.cmd(f"mem_write 0x{addr:08x} 0x{value:x}")

    def read(self, addr, nwords=1):
        out = self.cmd(f"mem_read 0x{addr:08x} {4 * nwords}")
        data = bytearray()
        for line in out.splitlines():
            m = re.match(r"0x[0-9a-f]{8}  ((?:[0-9a-f]{2} )+)", line)
            if m:
                data += bytes(int(x, 16) for x in m.group(1).split())
        return [int.from_bytes(data[i:i + 4], "little") for i in range(0, 4 * nwords, 4)]
