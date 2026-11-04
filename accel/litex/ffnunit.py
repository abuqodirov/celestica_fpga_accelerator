"""LiteX integration of the FFN unit (accel/rtl/ffn_unit.v): SiLU(gate) * up from the two engines' result streams,
quantized to MXINT8 and written into both engines' activation buffers (down_proj's input stays on the card).

Registers (CSR prefix ffn_*), in this order so that one 2-word loader write [nrows, 1] arms the unit:
    nrows   rows of the coming gate_up runs (9728 for MustaqiLLM; a multiple of 32, <= 10240)
    arm     write anything: take the next nrows result rows of both engines
    status  bit0 busy (until the activations are in both engines), bit1 err (a FIFO overflowed; cleared by arm)
st = Cat(busy, err) for the JTAG status word (ypcb_soc.py _JtagLoader)."""
import os

from migen import Cat, ClockSignal, Instance, ResetSignal, Signal

from litex.gen import LiteXModule
from litex.soc.interconnect.csr import CSRStatus, CSRStorage

RTL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rtl")


class FFNUnit(LiteXModule):
    def __init__(self, platform, eng_gate, eng_up):
        """eng_gate / eng_up: the MVAccel engines whose runs produce the gate rows (channel 0) and the up rows"""
        for f in ("ffn_unit.v", "fp32.v"):
            platform.add_source(os.path.abspath(os.path.join(RTL, f)))
        platform.add_verilog_include_path(os.path.abspath(RTL))         # ffn_tables.vh
        self.nrows = CSRStorage(14)
        self.arm = CSRStorage(1)
        self.status = CSRStatus(2)
        busy, err = Signal(), Signal()
        aw_en, aw_addr, aw_data = Signal(), Signal(13), Signal(32)
        _, g_data, g_valid = eng_gate._r
        _, u_data, u_valid = eng_up._r
        self.specials += Instance("ffn_unit",
            i_clk=ClockSignal(), i_rst=ResetSignal(), i_arm=self.arm.re, i_nrows=self.nrows.storage,
            i_g_valid=g_valid, i_g_data=g_data[:32], i_u_valid=u_valid, i_u_data=u_data[:32],
            o_aw_en=aw_en, o_aw_addr=aw_addr, o_aw_data=aw_data, o_busy=busy, o_err=err)
        for e in (eng_gate, eng_up):
            self.comb += [e.ext_aw_en.eq(aw_en), e.ext_aw_addr.eq(aw_addr), e.ext_aw_data.eq(aw_data)]
        self.st = Signal(2)
        self.comb += [self.st.eq(Cat(busy, err)), self.status.status.eq(self.st)]
