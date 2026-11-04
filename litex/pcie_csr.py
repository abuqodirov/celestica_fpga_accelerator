#!/usr/bin/env python3
"""PCIe bridge status of a YPCB_PCIE design over the JTAG console (no PCIe access needed):
    YPCB_BUILD=<build dir> python3 pcie_csr.py [restart]
restart: toggle the lane reset sequence (pcie_restart CSR) first."""
import sys
import time

from bios import Bios, csr

SEQ = {0: "START", 1: "PDREL", 2: "CPLLRST", 3: "LOCK", 4: "GTRST", 5: "SYNC", 6: "SYNCW", 7: "READY", 15: "ERROR"}
EV = "badtlp baddllp replayro replayto ll2_rx pl2_rx malformed recovery".split()


def main():
    b = Bios(freq=15e6)
    b.sync()
    if "restart" in sys.argv[1:]:
        v = b.read(csr("pcie_restart"))[0]
        b.write(csr("pcie_restart"), v ^ 1)
        time.sleep(0.5)
    link = b.read(csr("pcie_link"))[0]
    sp = (link >> 10) & 3
    print(f"link word {link:#010x}: LTSSM {link & 0x3f:#04x}  width x{(link >> 6) & 0xf}  "
          f"speed {['?', '2.5', '5', '?'][sp]} GT/s  bus master {(link >> 12) & 1}  mem enable {(link >> 13) & 1}  "
          f"TRN link up {(link >> 14) & 1}")
    print(f"  lane sequencer {SEQ.get((link >> 16) & 15, (link >> 16) & 15)} (error state {(link >> 20) & 15}),"
          f" TX alignment state {(link >> 24) & 15} (error {(link >> 28) & 15})")
    errs = b.read(csr("pcie_errs"))[0]
    print(f"  TLP writes {b.read(csr('pcie_tlps'))[0]}  reads {b.read(csr('pcie_reads'))[0]}  "
          f"completions {b.read(csr('pcie_cpls'))[0]}  UR {errs & 0xffff}  stale {errs >> 16}")
    ev = b.read(csr("pcie_ev"), 4)
    v = 0
    for w in ev:                       # CSR words: most significant first
        v = (v << 32) | w
    print("  link errors: " + "  ".join(f"{n} {(v >> (16 * i)) & 0xffff}" for i, n in enumerate(EV)))
    b.close()


if __name__ == "__main__":
    main()
