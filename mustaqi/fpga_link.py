"""PC <-> FPGA link for MustaqiLLM on the card (build_dacc10: YPCB_DUAL + JTAGLOAD + ACCEL=1 + DDR0WIN + BUSPIPE +
JTAGREAD), all over the HS3 JTAG cable:
    console (JTAG chain 1, IR USER1)  BIOS commands (crc, mem_write) - slow, used for setup and checks only
    loader  (JTAG chain 2, IR USER2)  write scans: any bus address (engine activations, engine CSRs, DRAM windows);
                                      read scans: engine results + engine status (litex/jtag_shift.py)
build_dacc11 and later (detected at start, Link.packed): read scans can return results packed as bfloat16 (half the
bits) and one activation write can go to both engines (half the bits out).
YPCB_FFN builds (Link.has_ffn, CSRs ffn_*): the FFN unit computes SiLU(gate) * up on the card (ffn_arm, wait(ffn=True)).
Writes are queued and sent in one USB transfer with the next read, so a matvec costs two USB round trips.
"""
import os
import struct
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
BUILD = os.path.join(ROOT, "litex", os.environ.get("MUSTAQI_BUILD", "build_dacc12"))
os.environ.setdefault("YPCB_BUILD", BUILD)
sys.path.insert(0, os.path.join(ROOT, "litex"))
sys.path.insert(0, os.path.join(ROOT, "llm"))
from bios import Bios, csr  # noqa: E402

IR_CONSOLE, IR_LOADER = 0x02, 0x03
WIN = [0xC0000000, 0xC0100000]          # engine windows: activations (write), results (read via the bus)
ACT_SUB = 0x1000 * 4                    # byte offset of the subgroup words {e<<16 | S} in a window
MAX_ROWS = 8192                         # result memory per engine run


def gray2bin(g):
    b = g
    while g:
        g >>= 1
        b ^= g
    return b


def read_scan_cmd(header, nwords, neg=False):
    """MPSSE commands for one chain-2 read scan from Run-Test/Idle: the header word out (and its 32 TDO bits in),
    then read-only clocks (TDI stays at the header's last bit, 0) for the rest. A read-only command keeps the USB
    command tiny: sending kilobytes of TDI zeros in the same write as a long read deadlocks the FT232H (its output
    buffer fills before the host starts reading, then it stops taking commands -> USB timeout, build_dacc10 s1).
    neg: sample TDO on the falling TCK edge, half a clock later than JTAG's usual rising edge. The FPGA changes TDO
    on a falling edge; the cable + FPGA delay back to the FT232H is longer than half a 30 MHz clock (rising-edge
    reads fail there) but should be shorter than a whole one - then the falling edge still sees the same bit."""
    assert header >> 31 == 0
    r = 0x04 if neg else 0                                    # MPSSE command bit 2: read on the -ve edge
    nbytes = (32 * nwords - 1) // 8                           # whole bytes, then 7 bits, then the last bit
    cmd = bytearray([0x4B, 0x02, 0x01])                       # Idle -> Shift-DR
    cmd += bytes([0x39 | r, 0x03, 0x00]) + header.to_bytes(4, "little")
    left = nbytes - 4
    while left:
        n = min(left, 65536)
        cmd += bytes([0x28 | r, (n - 1) & 0xFF, (n - 1) >> 8])   # bytes in only, LSB first
        left -= n
    cmd += bytes([0x2A | r, 0x06, 0x6B | r, 0x00, 0x01, 0x4B, 0x01, 0x01, 0x87])   # 7 bits in, last + TMS, -> Idle
    return bytes(cmd)


def read_scan_result(ftdi, nwords, timeout=10.0):
    nbytes = (32 * nwords - 1) // 8
    want, buf, t0 = nbytes + 2, bytearray(), time.time()
    while len(buf) < want:
        buf += ftdi.read_data_bytes(want - len(buf), attempt=2)
        if time.time() - t0 > timeout:
            raise IOError(f"JTAG read scan: {len(buf)}/{want} bytes")
    tail = (buf[nbytes] >> 1) | ((buf[nbytes + 1] >> 7) << 7)  # 7 bits arrive MSB-aligned, then 1 bit
    return np.frombuffer(bytes(buf[:nbytes]) + bytes([tail]), dtype="<u4")


def _div(freq):
    return max(0, round(30e6 / freq) - 1)


class Link:
    def __init__(self, freq=15e6, write_freq=30e6, read_freq=None, read_neg=False):
        """freq: TCK for the console and IR scans (15 MHz: rising-edge TDO reads fail at 30 MHz);
        write_freq: TCK for loader write scans (30 MHz works, CRC-checked);
        read_freq, read_neg: TCK and TDO sampling edge for read scans (default freq, rising edge)
        self.packed: the gateware has packed (bfloat16) reads and both-engine writes"""
        self.freq, self.write_freq = freq, write_freq
        self.read_freq, self.read_neg = read_freq or freq, read_neg
        self.tck = freq
        self.b = Bios(freq=freq)
        self.b.sync()
        self.b.drain(0.5)
        self.j = self.b.j
        self.ftdi = self.j.ftdi
        self.ir_cur = IR_CONSOLE
        self.pending = bytearray()
        self.csr_eng = [csr("mvacc_base"), csr("mvacc1_base")]
        try:
            self.csr_ffn = csr("ffn_nrows")
        except KeyError:
            self.csr_ffn = None
        self.has_ffn = self.csr_ffn is not None
        self.stats = dict(read_bytes=0, write_bytes=0, reads=0, retries=0, polls=0, t_wait=0.0, t_results=0.0)
        st = self.status()
        self.fin = [st["eng"][0]["fin"], st["eng"][1]["fin"]]   # finished-run counters (binary, mod 16)
        # feature probe: a 'both' write of one word is two loader bus writes on build_dacc11+ (words counter +2),
        # one on older builds (+1). Activation word 0 of engine 0 is harmless: every run writes its activations.
        self.write(WIN[0] | 2, bytes(4))
        self.packed = (self.status()["nwords"] - st["nwords"]) & 0xFFFF == 2

    # ---- low level -------------------------------------------------------------------------------------------
    def _ir(self, v):
        if self.ir_cur != v:
            self._tck(self.freq)                              # IR scans read TDO: slow clock
            self.flush()
            self.j.ir(v)
            self.ir_cur = v

    def console(self):
        """the BIOS console (flushes queued writes first)"""
        self._ir(IR_CONSOLE)
        self._tck(self.freq)
        self.flush()
        return self.b

    def flush(self):
        if self.pending:
            self.ftdi.write_data(bytes(self.pending))
            self.pending.clear()

    def _tck(self, freq):
        """queue a TCK change (MPSSE clock divisor) in the pending command stream"""
        if freq != self.tck:
            d = _div(freq)
            self.pending += bytes([0x86, d & 0xFF, d >> 8])
            self.tck = freq

    def write(self, addr, data):
        """queue a loader write scan: data (bytes, multiple of 4) to bus address addr onwards"""
        self._ir(IR_LOADER)
        self._tck(self.write_freq)
        part = addr.to_bytes(4, "little") + bytes(data)
        body, last = part[:-1], part[-1]
        cmd = self.pending
        cmd += bytes([0x4B, 0x02, 0x01])                      # Idle -> Shift-DR
        for i in range(0, len(body), 65536):
            p = body[i:i + 65536]
            cmd += bytes([0x19, (len(p) - 1) & 0xFF, (len(p) - 1) >> 8]) + p
        cmd += bytes([0x1B, 0x06, last & 0x7F, 0x4B, 0x00, 0x01 | ((last >> 7) << 7), 0x4B, 0x01, 0x01])
        self.stats["write_bytes"] += len(data)

    def _read_scan(self, header, nwords):
        """one read scan: header word, then nwords - 1 more words; returns the nwords words shifted out"""
        self._ir(IR_LOADER)
        self._tck(self.read_freq)
        cmd = self.pending
        cmd += read_scan_cmd(header, nwords, self.read_neg)
        self.flush()
        out = read_scan_result(self.ftdi, nwords)
        self.stats["read_bytes"] += 4 * nwords
        self.stats["reads"] += 1
        return out

    @staticmethod
    def parse_status(w0, w1):
        st = int(w0) | int(w1) << 32
        eng = []
        for i in range(2):
            e = (st >> (49 + 6 * i)) & 0x3F
            eng.append(dict(fin=gray2bin(e & 0xF), ovf=(e >> 4) & 1, busy=(e >> 5) & 1))
        return dict(addr=st & 0xFFFFFFFF, nwords=(st >> 32) & 0xFFFF, overflow=(st >> 48) & 1, eng=eng,
                    ffn=dict(busy=(st >> 61) & 1, err=(st >> 62) & 1))

    def status(self):
        w = self._read_scan(1, 2)          # a read scan of no rows: just the status (a write header would write)
        return self.parse_status(w[0], w[1])

    # ---- engine ----------------------------------------------------------------------------------------------
    def set_activation(self, img, engines=(0, 1)):
        """img: the engine activation image (uint32: K/4 words of a, then K/32 subgroup words)"""
        n = len(img)
        K = n * 32 // 9                    # n = K/4 + K/32 = 9K/32
        K4 = K // 4
        if self.packed and tuple(engines) == (0, 1):
            self.write(WIN[0] | 2, img[:K4].tobytes())                # | 2: also into engine 1's window
            self.write((WIN[0] + ACT_SUB) | 2, img[K4:].tobytes())
            return
        for e in engines:
            self.write(WIN[e], img[:K4].tobytes())
            self.write(WIN[e] + ACT_SUB, img[K4:].tobytes())

    def start(self, eng, base_word, nrows, K):
        ng = K // 128
        rw = (ng + 15) // 16 + ng
        self.write(self.csr_eng[eng], struct.pack("<5I", base_word, nrows * rw, ng, nrows, 1))
        self.fin[eng] = (self.fin[eng] + 1) & 15

    def ffn_arm(self, nrows):
        """the FFN unit takes the next nrows result rows of both engines (gate on engine 0, up on engine 1)"""
        self.write(self.csr_ffn, struct.pack("<2I", nrows, 1))         # ffn_nrows, ffn_arm

    def wait(self, engines=(0, 1), timeout=5.0, ffn=False):
        """poll the status (a 2-word scan, both engines' run counters) until the engines' last runs are done -
        a full-length result read of a still-running engine would be wasted; ffn: also until the FFN unit has
        written its activations into the engines"""
        t0 = time.time()
        while True:
            st = self.status()
            if all(st["eng"][e]["fin"] == self.fin[e] and not st["eng"][e]["busy"] for e in engines) and \
                    not (ffn and st["ffn"]["busy"]):
                self.stats["t_wait"] += time.time() - t0     # queued writes + engine time + status round trips
                if ffn and st["ffn"]["err"]:
                    raise RuntimeError("FFN unit: FIFO overflow")
                return
            self.stats["polls"] += 1
            if time.time() - t0 > timeout:
                raise TimeoutError(f"engines {engines}: runs not finished ({st['eng']}, expected fin {self.fin})")

    def results(self, eng, nrows, timeout=5.0, packed=False):
        """float32 results of the engine's last started run (waits for it; call wait() first to avoid retries);
        packed: read them as bfloat16 (half the JTAG bits; needs self.packed), returned widened to float32"""
        t0 = time.time()
        assert not packed or self.packed, "this FPGA design has no packed reads"
        while True:
            w = self._read_scan(1 | eng << 1 | packed << 15, ((nrows + 1) // 2 if packed else nrows) + 2)
            st = self.parse_status(w[0], w[1])
            e = st["eng"][eng]
            if e["fin"] == self.fin[eng] and not e["busy"]:
                if e["ovf"]:
                    raise RuntimeError(f"engine {eng}: accumulator overflow")
                self.stats["t_results"] += time.time() - t0
                if packed:
                    return (w[2:].view(np.uint16)[:nrows].astype(np.uint32) << 16).view(np.float32)
                return w[2:].view(np.float32)
            self.stats["retries"] += 1
            if time.time() - t0 > timeout:
                raise TimeoutError(f"engine {eng}: run not finished (status {e}, expected fin {self.fin[eng]})")

    def resync(self):
        """after an interrupted transfer: drop queued/unread bytes, re-read the engines' run counters"""
        self.pending.clear()
        self.ftdi.purge_buffers()
        self.set_tck(self.freq)
        time.sleep(0.05)
        self.ir_cur = None
        st = self.status()
        self.fin = [st["eng"][0]["fin"], st["eng"][1]["fin"]]

    def set_tck(self, freq):
        self.flush()
        self.ftdi.set_frequency(freq)
        self.tck = freq

    def close(self):
        self.flush()
        self._ir(IR_CONSOLE)
        self.b.close()
