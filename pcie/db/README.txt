Private overlay of prjxray-db kintex7 for the PCIe work (the original in ~/tools/prjxray-db is untouched).
Everything is a symlink except:
  segbits_gtx_int_interface.db  GT input delay pips: Artix-7 segbits_gtp_int_interface.db renamed GTP->GTX.
                                Verified: decodes 288 factory bits, all on driven inputs (NOTES 2026-10-30).
  segbits_gtx_channel_{0..3}.db + XF_REFCLK_31_10   factory-only bit in the 4 quad-115 channels (refclk from quad 116)
  segbits_gtx_common.db         + XF_REFCLK_30_1486 factory-only bit in the quad-116 common (refclk to quad 115)
XF_* = bits copied from the factory bitstream whose meaning is not fuzzed; only used for the exact factory setup.

To (re)create the overlay folders from a prjxray-db checkout: make_overlay.sh [prjxray-db/kintex7] [name]
(default: nextpnr-xilinx's bundled prjxray-db -> kintex7_llm, the one litex/build_pcie.sh uses).
