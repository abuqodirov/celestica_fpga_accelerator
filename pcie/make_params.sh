#!/bin/bash
# Generate the PCIe hard-block and transceiver parameter files from YOUR OWN card's factory design. They are not in
# the repository: they hold settings read out of the factory bitstream, which belongs to the card's makers.
#   pcie/make_params.sh <factory bitstream .bit>
# Get the bitstream with tools/readback.py while the card runs its factory design (power-on state; read-only, ~11 s):
#   python3 tools/readback.py factory.bin <any full .bit built with this flow, as a template> factory.bit
# Writes pcie/factory_params.vh, pcie/s2/s2_params.vh and pcie/core/pcie_x8_params.vh. Takes a few minutes.
set -e
BIT=$(readlink -f "$1")
[ -f "$BIT" ] || { echo "usage: $0 <factory bitstream .bit>"; exit 1; }
cd "$(dirname "$0")"
. ../litex/env.sh
P=xc7k480tffg1156-2
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
python3 "$HOME/tools/prjxray/utils/bit2fasm.py" --db-root "$PRJXRAY_DB_DIR/kintex7" --part $P \
    --bitread "$HOME/tools/prjxray/build/tools/bitread" --verbose "$BIT" > "$TMP/factory.fasm" 2> /dev/null
# lane 0's transceiver, both quads' common blocks, the PCIe block
grep -E '^(GTX_CHANNEL_3_X309Y306|GTX_COMMON_X309Y231|GTX_COMMON_X309Y283|PCIE_BOT_X279Y219)\.' "$TMP/factory.fasm" \
    > factory_pcie_raw.fasm
[ -s factory_pcie_raw.fasm ] || { echo "no PCIe/transceiver settings found: is this the factory bitstream?"; exit 1; }
python3 gen_params.py > factory_params.vh
(cd s2 && python3 gen_params_s2.py)
cp s2/s2_params.vh core/pcie_x8_params.vh
echo "wrote pcie/factory_params.vh, pcie/s2/s2_params.vh, pcie/core/pcie_x8_params.vh"
