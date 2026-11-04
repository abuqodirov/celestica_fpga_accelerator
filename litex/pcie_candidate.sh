#!/bin/bash
# Check a build_pcie* bitstream on the card: load it (boottest.sh: DDR3 channel 0 leveling + BIOS memtest), bring up
# DDR3 channel 1 (ch1_init.py), then the PCIe link state over the JTAG console (pcie_csr.py) - no PCIe access.
#   pcie_candidate.sh <build dir> <bit>
cd "$(dirname "$0")"
B=$(readlink -f "$1"); BIT=$(readlink -f "$2")
R=$(YPCB_BUILD=$B ./boottest.sh "$BIT")
echo "$R"
echo "$R" | grep -q "Memtest OK" && ! echo "$R" | grep -q -- "----" || { echo "CANDIDATE FAIL: channel 0"; exit 1; }
C=$(YPCB_BUILD=$B timeout 600 ~/tools/venv/bin/python ch1_init.py 2>&1 | tail -1)
echo "ch1: $C"
echo "$C" | grep -q -- "----" && { echo "CANDIDATE FAIL: channel 1"; exit 1; }
sleep 1
YPCB_BUILD=$B timeout 120 ~/tools/venv/bin/python pcie_csr.py
