#!/bin/bash
# Create the prjxray-db overlay folders the PCIe flow uses: a symlink to every file of a prjxray-db kintex7 folder,
# except the 6 files we changed (kept here in kintex7/, see README.txt).
#   make_overlay.sh [prjxray-db kintex7 dir] [overlay name]
#     default: nextpnr-xilinx's bundled prjxray-db -> kintex7_llm   (used by litex/build_pcie.sh, litex/pll_patch.sh)
#     the standalone PCIe stages (s1/s2, probe) used ~/tools/prjxray-db/kintex7 -> kintex7 (same 6 files)
set -e
cd "$(dirname "$0")"
SRC=$(readlink -f "${1:-$HOME/tools/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7}")
OUT=${2:-kintex7_llm}
[ -f "$SRC/tilegrid.json" ] || [ -d "$SRC/xc7k480tffg1156-2" ] || { echo "not a prjxray-db kintex7 folder: $SRC"; exit 1; }
mkdir -p "$OUT"
OWN="segbits_gtx_int_interface.db segbits_gtx_channel_0.db segbits_gtx_channel_1.db segbits_gtx_channel_2.db
     segbits_gtx_channel_3.db segbits_gtx_common.db"
for f in "$SRC"/*; do
    n=$(basename "$f")
    case " $OWN " in *" $n "*) continue ;; esac
    [ -e "$OUT/$n" ] || ln -s "$f" "$OUT/$n"
done
if [ "$OUT" != kintex7 ]; then
    for n in $OWN; do cp kintex7/$n "$OUT/$n"; done
fi
echo "$OUT: $(ls "$OUT" | wc -l) entries, overlay files: $OWN" | tr -s ' \n' ' '
echo
