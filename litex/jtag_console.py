#!/usr/bin/env python3
"""Non-interactive LiteX JTAG-UART console: capture BIOS output, optionally send commands.

Usage: jtag_console.py [--seconds N] [--cmd "sdram_test" ...] [--log file]
Runs OpenOCD's jtagstream bridge (LiteX's own implementation) with the HS3 config and
reads the console over TCP. Each --cmd is typed after the output goes quiet.
"""
import argparse
import os
import socket
import threading
import time

from litex.build.openocd import OpenOCD

CFG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "openocd_hs3_xc7.cfg")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=20)
    ap.add_argument("--cmd", action="append", default=[])
    ap.add_argument("--quiet-time", type=float, default=2.0, help="idle seconds before sending the next command")
    ap.add_argument("--log")
    ap.add_argument("--port", type=int, default=20000)
    args = ap.parse_args()

    stop = threading.Event()
    bridge = threading.Thread(target=lambda: OpenOCD(CFG).stream(args.port, 1, stop_event=stop), daemon=True)
    bridge.start()
    sock = None
    for _ in range(100):
        try:
            sock = socket.create_connection(("127.0.0.1", args.port), timeout=0.2)
            break
        except OSError:
            time.sleep(0.1)
    if sock is None:
        raise SystemExit("could not connect to the OpenOCD jtagstream bridge")
    sock.settimeout(0.1)

    out = bytearray()
    cmds = list(args.cmd)
    t0 = last = time.time()
    while time.time() - t0 < args.seconds:
        try:
            data = sock.recv(4096)
            if data:
                out += data
                last = time.time()
                print(data.decode(errors="replace"), end="", flush=True)
        except socket.timeout:
            pass
        if cmds and time.time() - last > args.quiet_time:
            cmd = cmds.pop(0)
            sock.sendall(cmd.encode() + b"\n")
            last = time.time()
    sock.close()
    stop.set()
    if args.log:
        open(args.log, "wb").write(out)


if __name__ == "__main__":
    main()
