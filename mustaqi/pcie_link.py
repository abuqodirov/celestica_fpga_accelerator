"""PC <-> FPGA link for MustaqiLLM over PCIe (gateware: litex/pcie_bridge.py in a YPCB_PCIE build, e.g. build_pcie4).
Same interface as fpga_link.Link (set_activation, start, ffn_arm, wait, results, status, stats, ...), plus
upload(ch, offset, data) / evict(ch) for the weights. The JTAG cable is only needed to load the FPGA and bring up
DDR3 channel 1 (fpga_chat.load_bitstream); after every FPGA load the PC must re-enumerate the card:
    sudo ~/celestica/pcie/pcie_rescan.sh          (remove + rescan, enable, resource0 owned by the user)
BAR0 slots (256 KB windows onto the SoC bus, bases set here; slot 7 = bridge registers):
    0 engine 0 window, mirrored to engine 1 (one write -> both activation buffers)
    1 engine 0 window   2 engine 1 window   3 CSRs (0xF0000000)   4 results (moved per read)   5 / 6 DDR3 windows
Bulk copies use c/pcie_io.so: 64-byte MOVDIR64B writes and 32-byte AVX2 reads (one PCIe packet each)."""
import ctypes
import mmap
import os
import struct
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
BUILD = os.path.join(ROOT, "litex", os.environ.get("MUSTAQI_BUILD", "build_pcie4"))
os.environ.setdefault("YPCB_BUILD", BUILD)
sys.path.insert(0, os.path.join(ROOT, "litex"))
from bios import csr  # noqa: E402

DEV = os.environ.get("MUSTAQI_PCIE_DEV", "0000:01:00.0")
WIN = [0xC0000000, 0xC0100000]
ACT_SUB = 0x1000 * 4
SLOT = 1 << 18
REG = 7 * SLOT
MAGIC = 0x50434901
S_BOTH, S_E0, S_E1, S_CSR, S_RES, S_D0, S_D1 = range(7)


def _lib():
    src = os.path.join(HERE, "c", "pcie_io.c")
    so = os.path.join(HERE, "c", "pcie_io.so")
    if not os.path.exists(so) or os.path.getmtime(so) < os.path.getmtime(src):
        subprocess.run(["gcc", "-O2", "-mavx2", "-mmovdir64b", "-shared", "-fPIC", "-o", so, src], check=True)
    lib = ctypes.CDLL(so)
    for f in (lib.bar_read, lib.bar_write, lib.bar_write32):
        f.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
        f.restype = None
    lib.bar_write32_pair.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32]
    lib.bar_write32_pair.restype = None
    lib.bar_read32.argtypes = [ctypes.c_void_p]
    lib.bar_read32.restype = ctypes.c_uint32
    return lib


def gray2bin(g):
    b = g
    while g:
        g >>= 1
        b ^= g
    return b


class PcieLink:
    freq = 0                                    # (fpga_link.Link compatibility)

    def __init__(self, dev=DEV):
        path = f"/sys/bus/pci/devices/{dev}/resource0"
        if not os.path.exists(path):
            sys.exit(f"{path} missing: after loading the FPGA run  sudo ~/celestica/pcie/pcie_rescan.sh")
        try:
            self.fd = os.open(path, os.O_RDWR | os.O_SYNC)
        except PermissionError:
            sys.exit(f"no access to {path}: run  sudo ~/celestica/pcie/pcie_rescan.sh")
        self.mm = mmap.mmap(self.fd, 2 << 20, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)
        self.bar = ctypes.addressof(ctypes.c_char.from_buffer(self.mm))
        self.lib = _lib()
        magic = self.rd32(REG)
        if magic != MAGIC:
            sys.exit(f"BAR0 register 0 reads {magic:#010x}, expected {MAGIC:#010x}: not a YPCB_PCIE design, or the "
                     f"card needs  sudo ~/celestica/pcie/pcie_rescan.sh  (FPGA reloaded since the last rescan?)")
        self.csr_eng = [csr("mvacc_base"), csr("mvacc1_base")]
        self.rows_off = [S_CSR * SLOT + (csr(n) - 0xF0000000) for n in ("mvacc_rows", "mvacc1_rows")]
        try:
            self.csr_ffn = csr("ffn_nrows")
        except KeyError:
            self.csr_ffn = None
        self.has_ffn = self.csr_ffn is not None
        self.packed = True                      # bfloat16 result reads (bridge fast path)
        self.base = [None] * 7
        self.set_base(S_BOTH, WIN[0] | 1)
        self.set_base(S_E0, WIN[0])
        self.set_base(S_E1, WIN[1])
        self.set_base(S_CSR, 0xF0000000)
        self.stats = dict(read_bytes=0, write_bytes=0, reads=0, retries=0, polls=0, t_wait=0.0, t_results=0.0, t_act=0.0)
        st = self.status()
        self.fin = [st["eng"][0]["fin"], st["eng"][1]["fin"]]

    # ---- low level -------------------------------------------------------------------------------------------
    def rd32(self, off):
        return self.lib.bar_read32(self.bar + off)

    def wr32(self, off, *vals):
        b = struct.pack(f"<{len(vals)}I", *vals)
        self.lib.bar_write32(self.bar + off, b, len(b))

    def set_base(self, slot, addr):
        if self.base[slot] != addr:
            self.wr32(REG + 4 * (8 + slot), addr)
            self.base[slot] = addr

    def bar_write(self, off, data):
        """data: bytes / numpy array (contiguous), length a multiple of 4"""
        a = np.ascontiguousarray(np.frombuffer(data, np.uint8) if isinstance(data, (bytes, bytearray)) else data)
        self.lib.bar_write(self.bar + off, a.ctypes.data, a.nbytes)
        self.stats["write_bytes"] += a.nbytes

    def bar_read(self, off, nbytes):
        out = np.empty(nbytes // 4, np.uint32)
        self.lib.bar_read(out.ctypes.data, self.bar + off, nbytes)
        self.stats["read_bytes"] += nbytes
        self.stats["reads"] += 1
        return out

    def write(self, addr, data):
        """data (bytes, multiple of 4) to any bus address (movable slot 5; must not cross 256 KB of the slot)"""
        b = bytes(data)
        pos = 0
        while pos < len(b):
            a = addr + pos
            base = a & ~(SLOT - 1)
            self.set_base(S_D0, base)
            n = min(len(b) - pos, base + SLOT - a)
            self.bar_write(S_D0 * SLOT + (a - base), b[pos:pos + n])
            pos += n

    def reg(self, i):
        return self.rd32(REG + 4 * i)

    # ---- engine ----------------------------------------------------------------------------------------------
    def set_activation(self, img, engines=(0, 1)):
        n = len(img)
        K = n * 32 // 9
        K4 = K // 4
        img = np.ascontiguousarray(img, np.uint32)
        slots = [S_BOTH] if tuple(engines) == (0, 1) else [(S_E0, S_E1)[e] for e in engines]
        t0 = time.time()
        for s in slots:
            self.bar_write(s * SLOT, img[:K4])
            self.bar_write(s * SLOT + ACT_SUB, img[K4:])
        self.stats["t_act"] += time.time() - t0

    def start(self, eng, base_word, nrows, K):
        ng = K // 128
        rw = (ng + 15) // 16 + ng
        self.wr32(S_CSR * SLOT + (self.csr_eng[eng] - 0xF0000000), base_word, nrows * rw, ng, nrows, 1)
        self.fin[eng] = (self.fin[eng] + 1) & 15

    def start_pair(self, jobs):
        """start two runs [(engine, base_word, nrows, K), ...] with both start registers written back to back (one C
        call, ~100 ns apart). Needed for the FFN unit: it pairs gate rows (engine 0) with up rows (engine 1) through
        512-row FIFOs, so one engine must not start more than ~250 us before the other (measured 2026-11-03: 220 us
        ok, 250 us overflow). With start() twice, a Linux interrupt between the two calls did that ~1 in 30,000 FFN
        runs (fpga_llm.FpgaBackend.ffn_q also re-runs a failed FFN)."""
        offs = []
        for e, bw, nrows, K in jobs:
            ng = K // 128
            rw = (ng + 15) // 16 + ng
            off = S_CSR * SLOT + (self.csr_eng[e] - 0xF0000000)
            self.wr32(off, bw, nrows * rw, ng, nrows)        # run parameters; the 5th register (+16) is start
            offs.append(off + 16)
            self.fin[e] = (self.fin[e] + 1) & 15
        assert len(offs) == 2
        self.lib.bar_write32_pair(self.bar + offs[0], 1, self.bar + offs[1], 1)

    def ffn_arm(self, nrows):
        self.wr32(S_CSR * SLOT + (self.csr_ffn - 0xF0000000), nrows, 1)

    @staticmethod
    def parse_est(v):
        eng = []
        for i in range(2):
            e = (v >> (6 * i)) & 0x3F
            eng.append(dict(fin=gray2bin(e & 0xF), ovf=(e >> 4) & 1, busy=(e >> 5) & 1))
        return dict(eng=eng, ffn=dict(busy=(v >> 12) & 1, err=(v >> 13) & 1))

    def status(self):
        return self.parse_est(self.reg(1))

    def wait(self, engines=(0, 1), timeout=5.0, ffn=False):
        t0 = time.time()
        while True:
            st = self.status()
            if all(st["eng"][e]["fin"] == self.fin[e] and not st["eng"][e]["busy"] for e in engines) and \
                    not (ffn and st["ffn"]["busy"]):
                self.stats["t_wait"] += time.time() - t0
                if ffn and st["ffn"]["err"]:
                    raise RuntimeError("FFN unit: FIFO overflow")
                return
            self.stats["polls"] += 1
            if time.time() - t0 > timeout:
                raise TimeoutError(f"engines {engines}: runs not finished ({st['eng']}, expected fin {self.fin})")

    def results(self, eng, nrows, timeout=5.0, packed=False):
        t0 = time.time()
        while True:
            e = self.status()["eng"][eng]
            if e["fin"] == self.fin[eng] and not e["busy"]:
                break
            self.stats["retries"] += 1
            if time.time() - t0 > timeout:
                raise TimeoutError(f"engine {eng}: run not finished (status {e}, expected fin {self.fin[eng]})")
        if e["ovf"]:
            raise RuntimeError(f"engine {eng}: accumulator overflow")
        self.set_base(S_RES, WIN[eng] + (0xC0000 if packed else 0x80000))
        ndw = (nrows + 1) // 2 if packed else nrows
        w = self.bar_read(S_RES * SLOT, (ndw + 7) // 8 * 32)[:ndw]
        self.stats["t_results"] += time.time() - t0
        if packed:
            return (w.view(np.uint16)[:nrows].astype(np.uint32) << 16).view(np.float32)
        return w.view(np.float32).copy()

    def run(self, jobs, packed=True, timeout=5.0):
        """Start jobs = [(engine, base_word, nrows, K), ...] together and read their results WHILE the engines run:
        each engine's `rows` CSR counts the results written so far (rows 0..n-1 of the run, in order), so every poll
        reads the newly finished rows (whole 32-byte blocks = 16 bfloat16 results; 8 float32) and only the last
        block is left after the run ends. Returns one float32 array per job. Bit-identical to start + wait +
        results (same result memory, same rounding); hides the result reads behind the weight streaming."""
        per = 16 if packed else 8
        for e, bw, n, K in jobs:
            self.start(e, bw, n, K)
        outs = [np.empty(n, np.float32) for _, _, n, _ in jobs]
        got = [0] * len(jobs)
        t0 = time.time()
        while True:
            busy = False
            for j, (e, _, n, _) in enumerate(jobs):
                if got[j] >= n:
                    continue
                w = self.rd32(self.rows_off[e])
                avail = n if w >= n else w - w % per
                if avail > got[j]:
                    self._read_rows(e, got[j], avail, outs[j], packed)
                    got[j] = avail
                busy |= got[j] < n
            if not busy:
                break
            self.stats["polls"] += 1
            if time.time() - t0 > timeout:
                raise TimeoutError(f"engines: runs not finished (rows {got} of {[j[2] for j in jobs]}, "
                                   f"status {self.status()})")
        st = self.status()                       # all rows are in; the run is (about to be) done: check overflow
        for e, _, _, _ in jobs:
            if st["eng"][e]["ovf"]:
                raise RuntimeError(f"engine {e}: accumulator overflow")
        self.stats["t_wait"] += time.time() - t0   # engines with the result reads hidden inside
        self.wait([e for e, _, _, _ in jobs])    # normally returns at once (busy drops 1-2 clocks after the last row)
        return outs

    def _read_rows(self, eng, r0, r1, out, packed):
        """results r0..r1-1 of engine eng's last run into out[r0:r1] (r0 a multiple of 16 / 8)"""
        self.set_base(S_RES, WIN[eng] + (0xC0000 if packed else 0x80000))
        if packed:
            d0, d1 = r0 // 2, (r1 + 1) // 2
            w = self.bar_read(S_RES * SLOT + 4 * d0, (d1 - d0 + 7) // 8 * 32)[:d1 - d0]
            out[r0:r1] = (w.view(np.uint16)[:r1 - r0].astype(np.uint32) << 16).view(np.float32)
        else:
            w = self.bar_read(S_RES * SLOT + 4 * r0, (r1 - r0 + 7) // 8 * 32)[:r1 - r0]
            out[r0:r1] = w.view(np.float32)

    def resync(self):
        st = self.status()
        self.fin = [st["eng"][0]["fin"], st["eng"][1]["fin"]]

    # ---- DDR3 (weights) --------------------------------------------------------------------------------------
    def upload(self, ch, offset, data, progress=None):
        """data -> channel ch at byte offset (through the paged CPU window: page CSR + slot 5/6)"""
        import dram
        s = (S_D0, S_D1)[ch]
        pos = 0
        for page, addr, o, n in dram._pieces(ch, offset, len(data)):
            self.wr32(S_CSR * SLOT + (csr(dram.WIN[ch]["page"]) - 0xF0000000), page)
            for a in range(addr, addr + n, SLOT):
                m = min(SLOT, addr + n - a)
                self.set_base(s, a)
                self.bar_write(s * SLOT, data[o + (a - addr):o + (a - addr) + m])
                if progress:
                    progress(m)

    def evict(self, ch):
        """write the window cache back to DRAM (read 16 KiB of another page), then page 0"""
        import dram
        s = (S_D0, S_D1)[ch]
        w = dram.WIN[ch]
        npages = dram.CH_SIZE // w["size"]
        pcsr = S_CSR * SLOT + (csr(w["page"]) - 0xF0000000)
        self.wr32(pcsr, 1 % npages)
        self.set_base(s, w["base"] + dram.EVICT_OFF)
        self.bar_read(s * SLOT, 16384)
        self.wr32(pcsr, 0)

    # ---- compatibility -----------------------------------------------------------------------------------------
    def console(self):
        from bios import Bios
        if not hasattr(self, "b"):
            self.b = Bios(freq=15e6)
            self.b.sync()
        return self.b

    def set_tck(self, freq):
        pass

    def close(self):
        if hasattr(self, "b"):
            self.b.close()
        self.mm.close()
        os.close(self.fd)
