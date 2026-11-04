#!/usr/bin/env python3
"""Read back the configuration memory of the running FPGA over JTAG (read-only).

Usage: readback.py <out.bin> [template.bit] [out.bit]

Writes the raw FDRO words (big-endian) to out.bin. If a template .bit for the same
part is given (any full uncompressed bitstream, e.g. one from xc7frames2bit), also
writes out.bit: the template with its frame data replaced by the readback, so
prjxray's bit2fasm can decode it.

Sequence (UG470 configuration readback via JTAG): CFG_IN with sync, RCRC, RCFG,
FAR=0 and an FDRO read request; CFG_OUT streams the frames; CFG_IN with DESYNC.
The first frame that comes out is a pipeline dummy and is dropped.
"""
import os
import struct
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "calc", "host"))
from hs3_jtag import HS3Jtag  # noqa: E402

IR_CFG_OUT = 0x04
IR_CFG_IN = 0x05
FRAME_WORDS = 101
FDRI_WORDS = 4683168          # full XC7K480T frame payload incl. row pad frames
NOOP = 0x20000000

REV8 = bytes(int(f"{b:08b}"[::-1], 2) for b in range(256))


def words_to_scan(words):
    """Pack 32-bit words so each is shifted MSB first, first word first."""
    return int.from_bytes(b"".join(struct.pack(">I", w) for w in words).translate(REV8), "little")


def cfg_in(j, words):
    j.ir(IR_CFG_IN)
    j.dr(words_to_scan(words), 32 * len(words))


def read_dr_stream(j, nbits, chunk=65536):
    """Shift nbits out of the current DR (TDI held low), streaming in chunks."""
    ftdi = j.ftdi
    ftdi.write_data(bytes([0x4B, 0x02, 0x01]))            # Idle -> Shift-DR
    nbytes, rbits = divmod(nbits - 1, 8)
    out = bytearray()
    done = 0
    while done < nbytes:
        n = min(chunk, nbytes - done)
        ftdi.write_data(bytes([0x28, (n - 1) & 0xFF, (n - 1) >> 8, 0x87]))  # read bytes, LSB first
        out += j._read(n)
        done += n
    tail = bytearray()
    if rbits:
        tail += bytes([0x2A, rbits - 1])                  # read remaining bits
    tail += bytes([0x6B, 0x00, 0x01])                     # last bit, TMS=1 -> Exit1-DR
    tail += bytes([0x4B, 0x01, 0x01, 0x87])               # -> Update-DR -> Idle
    ftdi.write_data(bytes(tail))
    rest = j._read((1 if rbits else 0) + 1)
    last_byte = 0
    if rbits:
        last_byte = rest[0] >> (8 - rbits)
    last_byte |= (rest[-1] >> 7) << rbits
    out.append(last_byte)
    return bytes(out)


def readback(j, nwords):
    cfg_in(j, [0xFFFFFFFF, 0xAA995566, NOOP,
               0x30008001, 0x00000007,          # CMD = RCRC
               NOOP, NOOP,
               0x30008001, 0x00000004,          # CMD = RCFG
               NOOP,
               0x30002001, 0x00000000,          # FAR = 0
               0x28006000,                      # type 1 read FDRO, 0 words
               0x48000000 | nwords]             # type 2 read FDRO, nwords
           + [NOOP] * 32)
    j.ir(IR_CFG_OUT)
    raw = read_dr_stream(j, 32 * nwords)
    cfg_in(j, [0x30008001, 0x0000000D, NOOP, NOOP])   # CMD = DESYNC
    j.reset()
    return raw.translate(REV8)                          # -> big-endian words


def wrap_in_template(template_path, payload, out_path):
    d = bytearray(open(template_path, "rb").read())
    i = d.find(bytes.fromhex("aa995566")) + 4
    while i + 4 <= len(d):
        h = struct.unpack(">I", d[i:i + 4])[0]
        t = h >> 29
        if t == 1:
            i += 4 + 4 * (h & 0x7FF)
        elif t == 2:
            n = h & 0x7FFFFFF
            assert n * 4 == len(payload), f"template FDRI {n} words, readback {len(payload) // 4}"
            d[i + 4:i + 4 + 4 * n] = payload
            open(out_path, "wb").write(d)
            return
        else:
            i += 4
    raise ValueError("no FDRI payload in template")


def main():
    out_bin = sys.argv[1]
    nwords = FRAME_WORDS + FDRI_WORDS
    # Reads (TDO) are unreliable at 30 MHz on the HS3 (one-bit slip); 20 MHz and below are clean.
    j = HS3Jtag(freq=15e6)
    try:
        idc = j.idcode()
        print(f"IDCODE 0x{idc:08x}; reading {nwords} words ({nwords * 4 / 1e6:.1f} MB)...")
        t0 = time.time()
        raw = readback(j, nwords)
        print(f"read in {time.time() - t0:.1f} s")
    finally:
        j.close()
    open(out_bin, "wb").write(raw)
    if len(sys.argv) > 3:
        wrap_in_template(sys.argv[2], raw[FRAME_WORDS * 4:], sys.argv[3])
        print(f"wrote {sys.argv[3]}")


if __name__ == "__main__":
    main()
