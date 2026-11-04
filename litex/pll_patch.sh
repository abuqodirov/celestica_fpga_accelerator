#!/bin/bash
# Run a routed build_pcie* seed at another sys clock WITHOUT re-P&R: rewrite the main (CRG) PLL's input divider and
# feedback multiplier in the finished FASM (seeds/s<N>.pn.fasm), make the bitstream. The CLKOUT dividers stay
# (sys = VCO/12, sys4x = VCO/3, idelay = VCO/5) and so do the CK/DQS phases in degrees. Clock in = 200 MHz:
#   VCO = 200 MHz * M / D (800..1866 MHz, PFD 200/D >= 19 MHz); sys = VCO / 12; idelay ref = VCO / 5 (190..210 MHz)
#   pll_patch.sh <build dir> <seed> <D> <M>     e.g. D=5 M=24 -> 80 MHz (DDR3-640), D=10 M=49 -> 81.67 MHz
# Lock / loop-filter tables from nextpnr-xilinx's fasm.cc (Vivado-harvested, BANDWIDTH=OPTIMIZED).
# NOTE: the gateware's DRAM refresh interval (tREFI) is in clocks for the built frequency: a slower clock stretches it.
# Output: <build>/gateware/seeds/s<N>_d<D>m<M>.bit. fasm2frames ~10 GB: under the shared lock, memory-capped.
set -e
cd "$(dirname "$0")"
. ./env.sh
B=$(readlink -f "$1"); S=$2; D=$3; M=$4
P=xc7k480tffg1156-2; DB=$HOME/celestica/pcie/db/kintex7_llm
G=$B/gateware/seeds; T=s${S}_d${D}m${M}
python3 - "$G/s$S.pn.fasm" "$G/$T.fasm" "$D" "$M" ~/tools/nextpnr-xilinx/xilinx/fasm.cc <<'PY'
import re, sys
src, dst, D, M, cc = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), open(sys.argv[5]).read()
vco = 200.0 * M / D
assert 800 <= vco <= 1866 and 200.0 / D >= 19, f"VCO {vco} / PFD {200 / D} out of range"
assert 190 <= vco / 5 <= 210, f"IDELAYCTRL ref {vco / 5} MHz out of 200 +- 10"
def table(name, conv):
    body = re.search(name + r"\[63\] = \{(.*?)\};", cc, re.S).group(1)
    return [conv(v) for v in re.findall(r"0x[0-9A-Fa-f]+", body)]
lk = table("plle2_lock_table", lambda v: int(v, 16))
flt = table("plle2_filter_optimized", lambda v: int(v, 16))
assert len(lk) == 63 and len(flt) == 63
lines = open(src).read().splitlines()
pfx = {l.split(".PLLE2_ADV.")[0] for l in lines if ".PLLE2_ADV.CLKOUT4_CLKOUT1_OUTPUT_ENABLE" in l}
assert len(pfx) == 1, pfx
pfx = pfx.pop()
mine = lambda l: l.startswith(pfx + ".PLLE2_ADV.")
# sanity: the current settings are D=1, M=5 with the tables nextpnr wrote for M=5
cur = [l for l in lines if mine(l)]
assert any("LKTABLE[39:0] = 40'b" + format(lk[5 - 2], "040b") in l for l in cur), "unexpected current LKTABLE"
drop = re.compile(r"\.PLLE2_ADV\.(DIVCLK_|CLKFBOUT_|LKTABLE|TABLE\[)")
out = [l for l in lines if not (mine(l) and drop.search(l))]
def hl(d):
    h = d // 2
    return h, d - h, h != d - h
a = pfx + ".PLLE2_ADV."
if D == 1:
    out += [a + "DIVCLK_DIVCLK_HIGH_TIME[5:0] = 6'b000001", a + "DIVCLK_DIVCLK_LOW_TIME[5:0] = 6'b000001",
            a + "DIVCLK_DIVCLK_NO_COUNT[0]"]
else:
    h, lo, e = hl(D)
    out += [a + f"DIVCLK_DIVCLK_HIGH_TIME[5:0] = 6'b{h:06b}", a + f"DIVCLK_DIVCLK_LOW_TIME[5:0] = 6'b{lo:06b}"]
    if e:
        out.append(a + "DIVCLK_DIVCLK_EDGE[0]")
h, lo, e = hl(M)
out += [a + "CLKFBOUT_CLKOUT1_OUTPUT_ENABLE[0]", a + f"CLKFBOUT_CLKOUT1_HIGH_TIME[5:0] = 6'b{h:06b}",
        a + f"CLKFBOUT_CLKOUT1_LOW_TIME[5:0] = 6'b{lo:06b}", a + "CLKFBOUT_CLKOUT1_PHASE_MUX[2:0] = 3'b000",
        a + "CLKFBOUT_CLKOUT2_DELAY_TIME[5:0] = 6'b000000"]
if e:
    out.append(a + "CLKFBOUT_CLKOUT2_EDGE[0]")
out += [a + f"LKTABLE[39:0] = 40'b{lk[M - 2]:040b}", a + f"TABLE[9:0] = 10'b{flt[M - 2]:010b}"]
open(dst, "w").write("\n".join(out) + "\n")
print(f"{pfx}: D={D} M={M}: VCO {vco:.1f} MHz, sys {vco / 12:.3f} MHz (DDR3-{vco / 12 * 8:.0f}), "
      f"idelay ref {vco / 5:.1f} MHz; {len(cur)} PLL lines -> {len([l for l in out if mine(l)])}")
for l in out:
    if mine(l) and drop.search(l):
        print("   ", l.split(".PLLE2_ADV.")[1])
PY
flock ${TMPDIR:-/tmp}/fasm2frames.lock systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=3G \
    fasm2frames --part $P --db-root $DB $G/$T.fasm > $G/$T.frames 2> $G/$T.f2f.log
xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file $G/$T.frames --output_file $G/$T.bit > /dev/null
rm -f $G/$T.frames $G/$T.fasm
ls -la $G/$T.bit
