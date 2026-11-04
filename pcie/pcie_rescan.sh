#!/bin/bash
# After loading an FPGA design with PCIe (e.g. the LLM design build_pcie*): let Linux re-enumerate the card and give
# the user (not only root) access to its BAR0, so mustaqi/pcie_link.py / fpga_chat.py --link pcie run without sudo.
#   sudo ~/celestica/pcie/pcie_rescan.sh
# Safe: no hot-plug of the card itself, only Linux's view of it (remove = forget the device, rescan = find it again).
set -e
D=/sys/bus/pci/devices/0000:01:00.0
RP=/sys/bus/pci/devices/0000:00:01.0
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
echo on > $RP/power/control                  # an empty root port may sleep (D3hot) and then forwards nothing
[ -e $D ] && echo 1 > $D/remove
sleep 0.5
echo 1 > /sys/bus/pci/rescan
sleep 0.5
[ -e $D ] || { echo "the card did not show up after the rescan (link down? FPGA not loaded?)"; exit 1; }
echo 1 > $D/enable
U=${SUDO_USER:-ubuntu}
chown "$U" $D/resource0
lspci -nn -s 01:00.0
echo "BAR0: $(head -1 $D/resource | cut -d' ' -f1-2), resource0 owned by $U"
