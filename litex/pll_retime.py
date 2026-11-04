#!/usr/bin/env python3
"""Same bitstream, different clock: re-encode only the PLL of a built LiteX SoC for another sys clock, keeping
placement and routing identical (a real timing-margin test on silicon).

The PLL's FASM bits (counters, phases, filter/lock tables) are produced by nextpnr itself from a tiny design
holding just a PLLE2_ADV with the new parameters at the same BEL, then spliced over the original PLLE2_ADV lines.
Clock plan (clk200 in): CLKOUT0 sys, CLKOUT1 sys4x = 4*sys, CLKOUT2 sys4x DQS phase, CLKOUT3 200 MHz IDELAY ref,
CLKOUT4 sys4x CK phase; VCO <= 1866 MHz, IDELAY ref 190..210 MHz.
usage: pll_retime.py <build dir> <preset: 75|80|85|87.5> [--seed N] [out.bit]   (75 = check: must reproduce the original)
  --seed N: retime seeds/sN (seed_sweep.sh); default: the build's own seed-1 FASM"""
import os
import re
import subprocess
import sys

PRESETS = {   # sys MHz: (mult, divclk, sys div, sys4x div, idelay div)
    "75":   (9, 1, 24, 6, 9),     # VCO 1800, 75 / 300 / 200
    "80":   (8, 1, 20, 5, 8),     # VCO 1600, 80 / 320 / 200
    "85":   (34, 5, 16, 4, 7),    # VCO 1360, 85 / 340 / 194.3
    "87.5": (7, 1, 16, 4, 7),     # VCO 1400, 87.5 / 350 / 200
}
ENV = ". ~/celestica/litex/env.sh; "
PART = "xc7k480tffg1156-2"


def pll_params(build):
    v = open(os.path.join(build, "gateware", "ypcb_00338_1p1.v")).read()
    blk = re.search(r"PLLE2_ADV #\((.*?)\)\s*PLLE2_ADV", v, re.S).group(1)
    return {k: float(x) for k, x in re.findall(r"\.(CLKOUT[0-9]_PHASE)\s*\(([\d.]+)\)", blk)}


def main():
    args = sys.argv[1:]
    seed = 1
    if "--seed" in args:
        i = args.index("--seed"); seed = int(args[i + 1]); del args[i:i + 2]
    build, preset = args[0], args[1]
    out = args[2] if len(args) > 2 else os.path.join(build, "gateware", "retime", f"s{seed}_sys{preset}.bit")
    mult, divclk, dsys, d4x, didel = PRESETS[preset]
    ph = pll_params(build)
    work = os.path.join(os.path.dirname(out), f"s{seed}_pll{preset}")
    os.makedirs(work, exist_ok=True)
    open(os.path.join(work, "pll.v"), "w").write(f"""
module top(input clk_p, input clk_n, output [4:0] o);
    wire clk, fb; wire [4:0] c, g; reg [4:0] t = 0;
    IBUFDS ib (.I(clk_p), .IB(clk_n), .O(clk));
    PLLE2_ADV #(.CLKIN1_PERIOD(5.0), .CLKFBOUT_MULT({mult}), .DIVCLK_DIVIDE({divclk}),
        .CLKOUT0_DIVIDE({dsys}), .CLKOUT0_PHASE({ph.get('CLKOUT0_PHASE', 0)}),
        .CLKOUT1_DIVIDE({d4x}), .CLKOUT1_PHASE({ph.get('CLKOUT1_PHASE', 0)}),
        .CLKOUT2_DIVIDE({d4x}), .CLKOUT2_PHASE({ph.get('CLKOUT2_PHASE', 0)}),
        .CLKOUT3_DIVIDE({didel}), .CLKOUT3_PHASE({ph.get('CLKOUT3_PHASE', 0)}),
        .CLKOUT4_DIVIDE({d4x}), .CLKOUT4_PHASE({ph.get('CLKOUT4_PHASE', 0)}), .STARTUP_WAIT("FALSE"))
    pll (.CLKIN1(clk), .CLKFBIN(fb), .CLKFBOUT(fb), .RST(1'b0), .PWRDWN(1'b0),
        .CLKOUT0(c[0]), .CLKOUT1(c[1]), .CLKOUT2(c[2]), .CLKOUT3(c[3]), .CLKOUT4(c[4]));
    genvar i;
    for (i = 0; i < 5; i = i + 1) begin : b
        BUFG bg (.I(c[i]), .O(g[i]));
        always @(posedge g[i]) t[i] <= ~t[i];
    end
    assign o = t;
endmodule
""")
    open(os.path.join(work, "pll.xdc"), "w").write(
        "set_property LOC AH27 [get_ports clk_p]\nset_property LOC AH28 [get_ports clk_n]\n"
        "set_property IOSTANDARD LVDS_25 [get_ports clk_p]\nset_property IOSTANDARD LVDS_25 [get_ports clk_n]\n"
        + "".join(f"set_property IOSTANDARD LVCMOS15 [get_ports {{o[{i}]}}]\n" for i in range(5))
        + "set_property BEL PLLE2_ADV_X0Y1/PLLE2_ADV [get_cells pll]\n")
    subprocess.run(ENV + f"cd {work} && yosys -q -p 'read_verilog pll.v; synth_xilinx -flatten -nosrl -arch xc7 -top top;"
                   f" write_json pll.json' && nextpnr-xilinx --json pll.json --xdc pll.xdc --fasm pll.fasm "
                   f"--chipdb $CHIPDB/{PART}.bin --timing-allow-fail --log pnr.log > /dev/null 2>&1",
                   shell=True, check=True, executable="/bin/bash")
    # pin-inversion bits (ZINV_RST, ZINV_PWRDWN) depend on how the real design drives the pins: keep the original's
    src = os.path.join(build, "gateware", "ypcb_00338_1p1_pn.fasm" if seed == 1 else f"seeds/s{seed}.pn.fasm")
    old = [l for l in open(src) if ".PLLE2_ADV." in l]
    new = [l for l in open(os.path.join(work, "pll.fasm")) if ".PLLE2_ADV." in l and ".ZINV_" not in l] \
        + [l for l in old if ".ZINV_" in l]
    tiles = {l.split(".")[0] for l in old} | {l.split(".")[0] for l in new}
    assert len(tiles) == 1, f"PLL not at the same tile: {tiles}"
    if preset == "75":
        same = sorted(old) == sorted(new)
        print(f"75 MHz re-encode reproduces the original PLL bits: {same}")
        if not same:
            for l in sorted(set(old) ^ set(new)):
                print(("  orig " if l in old else "  new  ") + l.rstrip())
        return
    fasm = os.path.join(work, "retimed.fasm")
    with open(fasm, "w") as f:
        f.writelines(l for l in open(src) if ".PLLE2_ADV." not in l)
        f.writelines(new)
    subprocess.run(ENV + f"DB=$PRJXRAY_DB_DIR/kintex7; fasm2frames --part {PART} --db-root $DB {fasm} > {work}/r.frames"
                   f" 2> {work}/f2f.log && xc7frames2bit --part_file $DB/{PART}/part.yaml --part_name {PART}"
                   f" --frm_file {work}/r.frames --output_file {out} > /dev/null && rm -f {work}/r.frames",
                   shell=True, check=True, executable="/bin/bash")
    vco = 200 * mult / divclk
    print(f"{out}: sys {vco / dsys:.2f} MHz, sys4x {vco / d4x:.1f} MHz, idelay ref {vco / didel:.1f} MHz (VCO {vco:.0f})")


if __name__ == "__main__":
    main()
