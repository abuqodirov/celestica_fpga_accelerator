#!/usr/bin/env python3
"""Chat with fpgachat, the tiny transformer running on the FPGA's RISC-V CPU.
Loads the LiteX SoC (DDR3 + JTAG loader), uploads weights + firmware into DDR3 over JTAG, verifies
them with the BIOS crc command, boots the firmware, then relays your lines over the JTAG UART.
usage: chat.py [--no-bit] [--say "hi" --say "bye"]     (no --say: interactive)"""
import argparse
import os
import re
import select
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "litex"))
# build_llm4: DDR3 lanes 0-3 (1 GiB); the 8-lane build_llm has two dead lanes (see NOTES)
BUILD = os.path.join(HERE, "..", "litex", os.environ.get("LLM_BUILD", "build_llm4"))
os.environ.setdefault("YPCB_BUILD", BUILD)
from bios import Bios  # noqa: E402

BIT = os.path.join(BUILD, "gateware", "ypcb_00338_1p1.bit")
FW, WEIGHTS = os.path.join(HERE, "fw", "fpgachat.bin"), os.path.join(HERE, "out", "chat_q80.bin")
FW_ADDR, W_ADDR = 0x40000000, 0x41000000


def upload(b, addr, data, chunk=65536):
    """Stream data into memory through the JTAG loader (BSCANE2 USER2): [addr32][words...] per scan."""
    data = data + bytes(-len(data) % 4)
    b.j.ir(0x03)
    for off in range(0, len(data), chunk):
        part = (addr + off).to_bytes(4, "little") + data[off:off + chunk]
        body, last = part[:-1], part[-1]
        cmd = bytearray([0x4B, 0x02, 0x01])                       # -> Shift-DR
        for i in range(0, len(body), 65536):
            p = body[i:i + 65536]
            cmd += bytes([0x19, (len(p) - 1) & 0xFF, (len(p) - 1) >> 8]) + p
        cmd += bytes([0x1B, 0x06, last & 0x7F, 0x4B, 0x00, 0x01 | ((last >> 7) << 7), 0x4B, 0x01, 0x01])
        b.j.ftdi.write_data(cmd)
    b.j.ir(0x02)                                                   # back to the console (USER1)


def check_crc(b, addr, data):
    out = b.cmd(f"crc 0x{addr:08x} {len(data)}", timeout=60)
    m = re.search(r"([0-9a-fA-F]{8})\s*$", out.strip())
    got, want = int(m.group(1), 16) if m else None, zlib.crc32(data)
    print(f"  crc 0x{addr:08x} +{len(data)}: fpga {got:08x} host {want:08x} {'OK' if got == want else 'MISMATCH'}"
          if got is not None else f"  crc: unexpected output {out!r}")
    return got == want


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-bit", action="store_true")
    ap.add_argument("--say", action="append", default=[])
    args = ap.parse_args()
    if not args.no_bit:
        print("loading the SoC bitstream (DDR3 calibrates at boot) ...")
        subprocess.run([os.path.expanduser("~/.local/bin/openFPGALoader"), "-c", "digilent_hs3", "--freq", "30M",
                        BIT], check=True, capture_output=True)
        time.sleep(25)
    b = Bios(freq=15e6)
    b.sync(timeout=60)
    b.drain(1.0)                                                   # drop any queued extra prompts
    fw, w = open(FW, "rb").read(), open(WEIGHTS, "rb").read()
    t = time.time()
    upload(b, W_ADDR, w); upload(b, FW_ADDR, fw)
    print(f"uploaded {len(w)} B weights + {len(fw)} B firmware in {time.time() - t:.1f} s")
    if not (check_crc(b, W_ADDR, w) and check_crc(b, FW_ADDR, fw)):
        sys.exit("upload corrupted")
    b._send(f"boot 0x{FW_ADDR:08x}\n".encode())
    out = bytearray()

    def pump(until=None, timeout=120):
        t0 = time.time()
        while time.time() - t0 < timeout:
            b._scan()
            if b.rx:
                s = bytes(b.rx); b.rx.clear(); out.extend(s)
                sys.stdout.write(s.decode(errors="replace").replace("\r", "")); sys.stdout.flush()
            if until and out.endswith(until):
                return True
        return False

    pump(b"you> ", 60)
    if args.say:
        for line in args.say:
            out.clear(); b._send(line.encode() + b"\n")
            pump(b"you> ", 300)
        print()
    else:
        print("\n(type a line and press Enter; Ctrl-C quits)")
        while True:
            b._scan()
            if b.rx:
                s = bytes(b.rx); b.rx.clear()
                sys.stdout.write(s.decode(errors="replace").replace("\r", "")); sys.stdout.flush()
            if select.select([sys.stdin], [], [], 0)[0]:
                b._send(sys.stdin.readline().rstrip("\n").encode() + b"\n")
    b.close()


if __name__ == "__main__":
    main()
