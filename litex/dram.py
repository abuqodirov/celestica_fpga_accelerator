"""Host access to ALL 4 GiB of a YPCB_DUAL + YPCB_DDR0WIN SoC through the JTAG loader and the paged CPU windows.

    channel 0: 256 MiB window at 0xD0000000, CSR ddr0_page (0..7)      (main RAM 0x40000000 = first 512 MiB only)
    channel 1: 1 GiB window at 0x80000000,   CSR ddr1_page (0..1)

Each window has an 8 KiB write-back cache (whole 64-byte lines only: the board has no DM pins). Before another
DRAM reader (an engine, the BIST, or main RAM's L2 for channel 0) looks at data written through a window, call
evict(): it reads 16 KiB of a different page through the window so every dirty line is written back.

    from dram import write, crc, evict
    write(b, ch, offset, data)       # offset = byte offset inside the channel (0 .. 2 GiB)
    crc(b, ch, offset, length)       # CRC32 computed by the CPU through the window
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "llm"))
from bios import csr  # noqa: E402
from chat import upload  # noqa: E402

CH_SIZE = 1 << 31
WIN = {0: dict(base=0xD0000000, size=1 << 28, page="ddr0_page"),
       1: dict(base=0x80000000, size=1 << 30, page="ddr1_page")}


def _pieces(ch, offset, length):
    """Split [offset, offset+length) of channel ch into (page, cpu address, piece offset, piece length)."""
    w = WIN[ch]
    assert 0 <= offset and offset + length <= CH_SIZE, "outside the 2 GiB channel"
    pos = offset
    while pos < offset + length:
        page, inpage = divmod(pos, w["size"])
        n = min(offset + length - pos, w["size"] - inpage)
        yield page, w["base"] + inpage, pos - offset, n
        pos += n


def set_page(b, ch, page):
    b.write(csr(WIN[ch]["page"]), page)


def write(b, ch, offset, data):
    for page, addr, o, n in _pieces(ch, offset, len(data)):
        set_page(b, ch, page)
        upload(b, addr, data[o:o + n])


def crc(b, ch, offset, length):
    """CPU-computed CRC32 of a region that must lie in one window page."""
    (page, addr, _, n), = list(_pieces(ch, offset, length))
    set_page(b, ch, page)
    out = b.cmd(f"crc 0x{addr:08x} {n}", timeout=max(60, n // 200000))
    m = re.search(r"([0-9a-fA-F]{8})\s*$", out.strip())
    return int(m.group(1), 16) if m else None


EVICT_OFF = 0x4010000          # 64 MiB + 64 KiB into a page: away from block-aligned test data


def evict(b, ch, page=None):
    """Write back the window cache: read 16 KiB (2x the direct-mapped cache) of another page (default: the page
    after the current one), at EVICT_OFF inside it - a region that must not hold data still to be written back."""
    w = WIN[ch]
    npages = CH_SIZE // w["size"]
    cur = b.read(csr(w["page"]))[0]
    set_page(b, ch, (cur + 1) % npages if page is None else page)
    b.cmd(f"crc 0x{w['base'] + EVICT_OFF:08x} 16384", timeout=30)
    set_page(b, ch, cur)
