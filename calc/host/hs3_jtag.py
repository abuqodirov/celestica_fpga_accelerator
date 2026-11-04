"""Minimal JTAG driver for the Digilent JTAG-HS3 (FT232H MPSSE) via pyftdi.

Only what the calculator needs: TAP reset, IR and DR scans from Run-Test/Idle.
Pin setup matches openFPGALoader's `digilent_hs3` cable entry.
"""
from pyftdi.ftdi import Ftdi

# Xilinx 7-series instruction codes (IR length 6)
IR_LEN = 6
IR_IDCODE = 0x09
IR_USER1 = 0x02


class HS3Jtag:
    def __init__(self, url="ftdi://0x0403:0x6014/1", freq=6e6):
        self.ftdi = Ftdi()
        # Low byte: TCK=0, TDI=1, TDO=2 (in), TMS=3, bit 7 = HS3 buffer enable.
        self.ftdi.open_mpsse_from_url(url, direction=0x8B, initial=0x88, frequency=freq)
        # High byte: HS3 buffer control (value 0x20, direction 0x30).
        self.ftdi.write_data(bytes([0x82, 0x20, 0x30]))
        self.reset()

    def close(self):
        self.ftdi.close()

    def _read(self, n):
        buf = bytearray()
        for _ in range(200):
            buf += self.ftdi.read_data_bytes(n - len(buf), attempt=4)
            if len(buf) >= n:
                return bytes(buf)
        raise IOError(f"JTAG read timed out ({len(buf)}/{n} bytes)")

    def reset(self):
        """Test-Logic-Reset, then Run-Test/Idle."""
        self.ftdi.write_data(bytes([0x4B, 0x05, 0x1F]))  # TMS 1,1,1,1,1,0

    def _scan(self, value, nbits, entry_tms, entry_len):
        """From Run-Test/Idle: enter Shift-xR, shift nbits LSB first (the last bit with
        TMS=1), return through Update-xR to Run-Test/Idle. Returns the bits shifted out."""
        cmd = bytearray([0x4B, entry_len - 1, entry_tms])
        nbytes, rbits = divmod(nbits - 1, 8)
        if nbytes:
            cmd += bytes([0x39, (nbytes - 1) & 0xFF, (nbytes - 1) >> 8])
            cmd += (value & ((1 << (8 * nbytes)) - 1)).to_bytes(nbytes, "little")
        if rbits:
            cmd += bytes([0x3B, rbits - 1, (value >> (8 * nbytes)) & ((1 << rbits) - 1)])
        last = (value >> (nbits - 1)) & 1
        cmd += bytes([0x6B, 0x00, 0x01 | (last << 7)])  # last bit, TMS=1 -> Exit1
        cmd += bytes([0x4B, 0x01, 0x01])                # TMS 1,0 -> Update -> Idle
        cmd += bytes([0x87])                            # flush
        self.ftdi.write_data(cmd)

        data = self._read(nbytes + (1 if rbits else 0) + 1)
        out = int.from_bytes(data[:nbytes], "little") if nbytes else 0
        pos = 8 * nbytes
        if rbits:
            out |= (data[nbytes] >> (8 - rbits)) << pos
            pos += rbits
        out |= (data[-1] >> 7) << pos
        return out

    def ir(self, value):
        return self._scan(value, IR_LEN, 0x03, 4)   # TMS 1,1,0,0 -> Shift-IR

    def dr(self, value, nbits):
        return self._scan(value, nbits, 0x01, 3)    # TMS 1,0,0 -> Shift-DR

    def idcode(self):
        self.ir(IR_IDCODE)
        return self.dr(0, 32)
