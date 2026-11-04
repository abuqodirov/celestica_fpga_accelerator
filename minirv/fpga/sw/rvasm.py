"""Tiny assembler and reference simulator for the minirv instruction subset.

Instructions: add, sub, addi, lui, lw, lbu, sw, sb, jalr, csrr (csrrs rd, csr, x0), ebreak.
The simulator decodes exactly like minirv/top.v, quirks included (any R-type is add/sub,
any opcode 0x13 is addi, loads are lw or zero-extended byte, stores are sw or sb), and
models the SoC memory map of fpga/rtl/minirv_soc.v.
"""
import struct

BASE = 0x3000_0000
RAM_BYTES = 64 * 1024
CONSOLE, CONSOLE_LSR, LEDS = 0x1000_0000, 0x1000_0005, 0x1000_1000
CSR = {"mvendorid": 0xF11, "marchid": 0xF12, "mcycle": 0xB00, "mcycleh": 0xB80}
REGS = {f"x{i}": i for i in range(32)}
REGS.update(zero=0, ra=1, sp=2, gp=3, tp=4, t0=5, t1=6, t2=7, s0=8, fp=8, s1=9,
            a0=10, a1=11, a2=12, a3=13, a4=14, a5=15, a6=16, a7=17,
            s2=18, s3=19, s4=20, s5=21, s6=22, s7=23, s8=24, s9=25, s10=26, s11=27,
            t3=28, t4=29, t5=30, t6=31)


def _r(name):
    return REGS[name]


def _hi_lo(value):
    """Split a 32-bit constant for lui + addi (addi sign-extends its 12 bits)."""
    value &= 0xFFFFFFFF
    hi = ((value + 0x800) >> 12) & 0xFFFFF
    lo = value - ((hi << 12) & 0xFFFFFFFF)
    lo = ((lo + 0x800) & 0xFFF) - 0x800
    return hi, lo


class Program:
    """Two-pass assembler: items are laid out first, then encoded once labels are known."""

    def __init__(self, base=BASE):
        self.base = base
        self.items = []          # (size, encoder(labels) -> bytes)
        self.labels = {}

    def _addr(self):
        return self.base + sum(size for size, _ in self.items)

    def _value(self, v, labels):
        return labels[v] if isinstance(v, str) else v

    def label(self, name):
        self.labels[name] = self._addr()

    def _inst(self, fn):
        self.items.append((4, lambda L: struct.pack("<I", fn(L) & 0xFFFFFFFF)))

    # --- instructions ---
    def _rtype(self, rd, rs1, rs2, f7):
        self._inst(lambda L: (f7 << 25) | (_r(rs2) << 20) | (_r(rs1) << 15) | (_r(rd) << 7) | 0x33)

    def add(self, rd, rs1, rs2): self._rtype(rd, rs1, rs2, 0x00)
    def sub(self, rd, rs1, rs2): self._rtype(rd, rs1, rs2, 0x20)

    def _itype(self, op, f3, rd, rs1, imm):
        self._inst(lambda L: ((self._value(imm, L) & 0xFFF) << 20) | (_r(rs1) << 15) | (f3 << 12) | (_r(rd) << 7) | op)

    def addi(self, rd, rs1, imm): self._itype(0x13, 0, rd, rs1, imm)
    def lw(self, rd, imm, rs1):   self._itype(0x03, 2, rd, rs1, imm)
    def lbu(self, rd, imm, rs1):  self._itype(0x03, 4, rd, rs1, imm)
    def jalr(self, rd, rs1, imm=0): self._itype(0x67, 0, rd, rs1, imm)

    def _stype(self, f3, rs2, imm, rs1):
        self._inst(lambda L: (((imm >> 5) & 0x7F) << 25) | (_r(rs2) << 20) | (_r(rs1) << 15)
                   | (f3 << 12) | ((imm & 0x1F) << 7) | 0x23)

    def sw(self, rs2, imm, rs1): self._stype(2, rs2, imm, rs1)
    def sb(self, rs2, imm, rs1): self._stype(0, rs2, imm, rs1)

    def lui(self, rd, imm20):
        self._inst(lambda L: ((self._value(imm20, L) & 0xFFFFF) << 12) | (_r(rd) << 7) | 0x37)

    def csrr(self, rd, csr):
        self._inst(lambda L: (CSR[csr] << 20) | (2 << 12) | (_r(rd) << 7) | 0x73)

    def ebreak(self):
        self._inst(lambda L: 0x00100073)

    # --- pseudo-instructions and data ---
    def li(self, rd, value):
        """Load a constant or a label address: always lui + addi (fixed size)."""
        self._inst(lambda L: (_hi_lo(self._value(value, L))[0] << 12) | (_r(rd) << 7) | 0x37)
        self._inst(lambda L: ((_hi_lo(self._value(value, L))[1] & 0xFFF) << 20) | (_r(rd) << 15) | (_r(rd) << 7) | 0x13)

    def jump(self, target, tmp="t6"):
        self.li(tmp, target)
        self.jalr("zero", tmp, 0)

    def word(self, value):
        self.items.append((4, lambda L: struct.pack("<I", self._value(value, L) & 0xFFFFFFFF)))

    def data(self, raw):
        self.items.append((len(raw), lambda L, raw=raw: bytes(raw)))

    def align(self, n=4):
        pad = (-self._addr()) % n
        if pad:
            self.data(b"\0" * pad)

    def image(self):
        return b"".join(enc(self.labels) for _, enc in self.items)


class Sim:
    """Reference model of minirv + SoC. Cycle model: 3 cycles per instruction, 5 for loads/stores."""

    def __init__(self, image, base=BASE):
        self.ram = bytearray(RAM_BYTES)
        self.ram[:len(image)] = image
        self.base = base
        self.x = [0] * 32
        self.pc = base
        self.console = bytearray()
        self.leds = 0
        self.instret = 0
        self.cycles = 0
        self.halted = False

    def _ram_word(self, addr):
        i = addr & 0xFFFC
        return struct.unpack_from("<I", self.ram, i)[0]

    def _load_word(self, addr):
        top16, top20 = addr >> 16, addr >> 12
        if top16 == 0x3000:
            return self._ram_word(addr)
        if top20 == 0x10000 and (addr & 0xFFC) == 4:
            return 0x60 << 8
        if top20 == 0x10001:
            return self.leds
        return 0

    def step(self):
        inst = self._ram_word(self.pc)          # fetch ignores the upper address bits, like the SoC
        op, rd, f3 = inst & 0x7F, (inst >> 7) & 31, (inst >> 12) & 7
        rs1, rs2, f7 = (inst >> 15) & 31, (inst >> 20) & 31, inst >> 25
        imm_i = (inst >> 20) - (0x1000 if inst & 0x8000_0000 else 0)
        imm_s = ((inst >> 25) << 5 | ((inst >> 7) & 31)) - (0x1000 if inst & 0x8000_0000 else 0)
        a, b = self.x[rs1], self.x[rs2]
        exec_cycle = self.cycles + 2
        next_pc, wdata, wen, mem = (self.pc + 4) & 0xFFFFFFFF, None, False, False
        if inst == 0x00100073:
            self.halted = True
        elif op == 0x33:
            wdata, wen = (a - b if f7 & 0x20 else a + b), True
        elif op == 0x13:
            wdata, wen = a + imm_i, True
        elif op == 0x37:
            wdata, wen = inst & 0xFFFFF000, True
        elif op == 0x67:
            wdata, wen = self.pc + 4, True
            next_pc = (a + imm_i) & 0xFFFFFFFE
        elif op == 0x03:
            mem = True
            addr = (a + imm_i) & 0xFFFFFFFF
            word = self._load_word(addr)
            wdata = word if f3 == 2 else (word >> (8 * (addr & 3))) & 0xFF
            wen = True
        elif op == 0x23:
            mem = True
            addr = (a + imm_s) & 0xFFFFFFFF
            if f3 == 2:
                wd, mask = b, 0xF
            else:
                wd, mask = (b & 0xFF) * 0x01010101, 1 << (addr & 3)
            if addr >> 16 == 0x3000:
                i = addr & 0xFFFC
                for k in range(4):
                    if mask >> k & 1:
                        self.ram[i + k] = (wd >> (8 * k)) & 0xFF
            elif addr >> 12 == 0x10000 and (addr & 0xFFC) == 0 and mask & 1:
                self.console.append(wd & 0xFF)
            elif addr >> 12 == 0x10001 and mask & 1:
                self.leds = wd & 7
        elif op == 0x73 and f3 == 2:
            csr = inst >> 20
            wdata = {0xF11: 0x79737978, 0xF12: 0, 0xB00: exec_cycle, 0xB80: 0}.get(csr, 0)
            wen = True
        if wen and rd:
            self.x[rd] = wdata & 0xFFFFFFFF
        self.cycles += 5 if mem else 3
        self.instret += 1
        self.pc = next_pc

    def run(self, max_steps=10_000_000):
        while not self.halted and self.instret < max_steps:
            self.step()
        return self

    def read_words(self, addr, n):
        return [self._ram_word(addr + 4 * i) for i in range(n)]
