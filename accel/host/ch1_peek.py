#!/usr/bin/env python3
"""Where did channel 1's weights land? Read one 64-byte DRAM word of channel 1 two ways and compare with the image:
  - DFII (software control of the sdram1 core: activate row, read column) at the engine's native address
  - the CPU window (0x80000000 + offset) for the same offset
usage: ch1_peek.py <native word address> <expected image file> <image byte offset>   (YPCB_BUILD = the dual SoC)"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "litex"))
from bios import Bios, csr  # noqa: E402
from ch1_init import CS, RAS, RDEN, WE, CAS, Channel  # noqa: E402

nat, img, off = int(sys.argv[1], 0), sys.argv[2], int(sys.argv[3], 0)
exp = open(img, "rb").read()[off:off + 64]
col, bank, row = (nat & 0x7F) * 8, (nat >> 7) & 7, nat >> 10       # ROW_BANK_COL, 8 columns per 64-byte burst
b = Bios(freq=15e6); b.sync(); b.drain(1.0)
c = Channel(b, "sdram1", "ddrphy1")
b.write(c.ctrl, 0x0E)                                               # software control (CKE|ODT|RESET_N)
c.issue(0, RAS | WE | CS, 0x400)
c.issue(0, RAS | CS, row, bank)
c.issue(3, CAS | CS | RDEN, col, bank)
beats = c.get_burst()
c.issue(0, RAS | WE | CS, 0x400)
b.write(c.ctrl, 0x01)                                               # hardware control
dfii = bytes(x for beat in beats for x in beat)                     # beat-major, lane = byte within the 64-bit beat
win = b"".join(w.to_bytes(4, "little") for w in b.read(0x80000000 + nat * 64, 16))
print(f"native 0x{nat:x} = row {row} bank {bank} col {col}")
print("expected :", exp.hex())
print("DFII     :", dfii.hex(), "MATCH" if dfii == exp else "differs")
print("window   :", win.hex(), "MATCH" if win == exp else "differs")
b.close()
