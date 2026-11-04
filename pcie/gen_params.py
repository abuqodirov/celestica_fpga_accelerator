#!/usr/bin/env python3
"""Turn the factory design's decoded PCIe/GTX settings into Verilog parameter lists.

Reads the features of one tile from pins/factory.fasm (factory readback, decoded by prjxray)
and the matching nextpnr-xilinx FASM writer (xilinx/fasm.cc), and inverts the writer: for each
parameter the writer knows, find the value that makes nextpnr emit the same feature bits as
the factory design. Parameters with non-trivial encodings are handled in SPECIAL.

  gen_params.py > params.vh
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
FASM = os.path.join(HERE, "factory_pcie_raw.fasm")
NPNR = os.path.expanduser("~/tools/nextpnr-xilinx/xilinx/fasm.cc")

TILES = {  # cell type -> (factory tile, feature prefix, writer function)
    "GTXE2_CHANNEL": ("GTX_CHANNEL_3_X309Y306", "GTXE2_CHANNEL.", "write_gtx_channel"),
    "PCIE_2_1":      ("PCIE_BOT_X279Y219",      "PCIE.",          "write_pcie_2_1"),
}


def factory_features(tile, prefix):
    """{feature name: integer value} for one tile (bools -> 1)."""
    feats = {}
    for line in open(FASM):
        if not line.startswith(tile + "." + prefix):
            continue
        f = line.strip()[len(tile) + 1 + len(prefix):]
        m = re.match(r"(\w+)\[(\d+):(\d+)\] = \d+'b([01]+)$", f)
        if m:
            name, lo, val = m.group(1), int(m.group(3)), int(m.group(4), 2)
            feats[name] = feats.get(name, 0) | (val << lo)
            continue
        m = re.match(r"(\w+)\[(\d+)\]$", f)
        if m:
            feats[m.group(1)] = feats.get(m.group(1), 0) | (1 << int(m.group(2)))
            continue
        feats[f] = 1  # plain bit, or NAME.VALUE enum bit
    return feats


def writer_body(func):
    src = open(NPNR).read()
    i = src.index("void " + func + "(")
    depth, j = 0, src.index("{", i)
    for k in range(j, len(src)):
        depth += {"{": 1, "}": -1}.get(src[k], 0)
        if depth == 0:
            return src[j:k]
    raise RuntimeError(func)


# Parameters whose FASM encoding is not the plain value (from the writer code), as
# feature value -> parameter value. Checked by decoding our own bitstream afterwards.
CPLL_DIV = {16: 1, 0: 2, 1: 3, 2: 4, 3: 5, 5: 6, 6: 8, 7: 10, 13: 12, 14: 16, 15: 20}
WIDTH = {2: 16, 3: 20, 4: 32, 5: 40, 6: 64, 7: 80}
SPECIAL_GTX = {
    "CPLL_FBDIV":        lambda f: CPLL_DIV[f.get("CPLL_FBDIV", 0)],
    "CPLL_REFCLK_DIV":   lambda f: CPLL_DIV[f.get("CPLL_REFCLK_DIV", 0)],
    "CPLL_FBDIV_45":     lambda f: 5 if f.get("CPLL_FBDIV_45") else 4,
    "RX_DATA_WIDTH":     lambda f: WIDTH[f.get("RX_DATA_WIDTH", 0)],
    "TX_DATA_WIDTH":     lambda f: WIDTH[f.get("TX_DATA_WIDTH", 0)],
    "RXOUT_DIV":         lambda f: 1 << f.get("RXOUT_DIV", 0),
    "TXOUT_DIV":         lambda f: 1 << f.get("TXOUT_DIV", 0),
    "RX_CLK25_DIV":      lambda f: f.get("RX_CLK25_DIV", 0) + 1,
    "TX_CLK25_DIV":      lambda f: f.get("TX_CLK25_DIV", 0) + 1,
    "RX_SIG_VALID_DLY":  lambda f: f.get("RX_SIG_VALID_DLY", 0) + 1,
    "CHAN_BOND_SEQ_LEN": lambda f: f.get("CHAN_BOND_SEQ_LEN", 0) + 1,
    "CLK_COR_SEQ_LEN":   lambda f: f.get("CLK_COR_SEQ_LEN", 0) + 1,
    "RXSLIDE_MODE":      lambda f: '"PMA"' if f.get("RXSLIDE_MODE.PMA") else
                                   '"AUTO"' if f.get("RXSLIDE_MODE.AUTO") else
                                   '"PCS"' if f.get("RXSLIDE_MODE.PCS") else '"OFF"',
    "TX_DRIVE_MODE":     lambda f: '"PIPE"' if f.get("TX_DRIVE_MODE.PIPE") else
                                   '"PIPEGEN3"' if f.get("TX_DRIVE_MODE.PIPEGEN3") else '"DIRECT"',
    "RX_XCLK_SEL":       lambda f: '"RXUSR"' if f.get("RX_XCLK_SEL.RXUSR") else '"RXREC"',
    "TX_XCLK_SEL":       lambda f: '"TXUSR"' if f.get("TX_XCLK_SEL.TXUSR") else '"TXOUT"',
    "RXBUF_ADDR_MODE":   lambda f: '"FAST"' if f.get("RXBUF_ADDR_MODE.FAST") else '"FULL"',
    "CBCC_DATA_SOURCE_SEL": lambda f: '"DECODED"' if f.get("CBCC_DATA_SOURCE_SEL.DECODED") else '"ENCODED"',
    "SATA_CPLL_CFG":     lambda f: '"VCO_1500MHZ"' if f.get("SATA_CPLL_CFG.VCO_1500MHZ") else
                                   '"VCO_750MHZ"' if f.get("SATA_CPLL_CFG.VCO_750MHZ") else '"VCO_3000MHZ"',
}


def gen(cell):
    tile, prefix, func = TILES[cell]
    feats = factory_features(tile, prefix)
    body = writer_body(func)
    special = SPECIAL_GTX if cell == "GTXE2_CHANNEL" else {}
    params, used = {}, set()
    var = {}  # C++ variable -> parameter name
    for m in re.finditer(r'auto (\w+) = (int|bool|str)_or_default\(ci->params, ctx->id\("(\w+)"\)', body):
        var[m.group(1)] = (m.group(3), m.group(2))
    for m in re.finditer(r'auto (\w+) = get_or_default\(ci->params, ctx->id\("(\w+)"\)', body):
        var[m.group(1)] = (m.group(2), "bits")
    for m in re.finditer(r'auto (\w+) = std::log2\(int_or_default\(ci->params, ctx->id\("(\w+)"\)', body):
        var[m.group(1)] = (m.group(2), "int")
    # write_int_vector / write_vector with a variable
    for m in re.finditer(r'write_(?:int_)?vector\("(\w+)\[(\d+):0\]", (\w+)(?:\.as_bits\(\))?,? ?(\d*)\)', body):
        feat, hi, v = m.group(1), int(m.group(2)), m.group(3)
        if v not in var:
            continue
        p, kind = var[v]
        used.add(feat)
        if p in special:
            continue
        val = feats.get(feat, 0)
        params[p] = f"{hi + 1}'h{val:x}" if kind in ("int", "bits") else str(val)
    # write_bit("FEAT", var) for bools
    for m in re.finditer(r'write_bit\("([\w\[\].]+)", (\w+)\)', body):
        feat, v = re.sub(r"\[0\]$", "", m.group(1)), m.group(2)
        if v in var and var[v][1] == "bool" and var[v][0] not in special:
            used.add(feat)
            params[var[v][0]] = "1" if feats.get(feat) else "0"
    # write_str_bool("ATTR"[, "BIT"][, "DEFAULT"])
    for m in re.finditer(r'write_str_bool\("(\w+)"(?:, "(\w+)")?(?:, "(\w+)")?\)', body):
        attr = m.group(1)
        bit = m.group(2) if (cell == "GTXE2_CHANNEL" and m.group(2)) else attr
        if cell == "GTXE2_CHANNEL" and m.group(2) in ("TRUE", "FALSE"):
            bit = attr
        used.add(bit)
        params[attr] = '"TRUE"' if feats.get(bit) else '"FALSE"'
    # inverted clock pins: write_inv("NAME") -> INV_NAME <- IS_NAME_INVERTED
    for m in re.finditer(r'write_inv\("(\w+)"\)', body):
        used.add("INV_" + m.group(1))
        params[f"IS_{m.group(1)}_INVERTED"] = "1'b1" if feats.get("INV_" + m.group(1)) else "1'b0"
    for p, fn in special.items():
        params[p] = str(fn(feats))
        used.add(p)
    leftover = sorted(f for f in feats if f.split(".")[0] not in used and f not in used)
    return params, leftover


# not declared in yosys' cells_xtra.v; only listed if the factory value differs from nextpnr's default
YOSYS_LACKS = {"LOOPBACK_DRIVE_HIZ": '"FALSE"', "ENABLE_JTAG_DBG": '"FALSE"'}

# GTXE2_COMMON (factory, flash copy): QPLL_FBDIV 9'b100100000, QPLL_FBDIV_RATIO 1, QPLL_REFCLK_DIV feature 16 = /1.
# QPLL_LPF (factory 4'b1101, nextpnr hard-codes 4'b1111) is fixed by fasm_patch.py.
COMMON_PARAMS = {"QPLL_FBDIV": "10'h120", "QPLL_FBDIV_RATIO": "1'b1", "QPLL_REFCLK_DIV": "1",
                 "IS_QPLLLOCKDETCLK_INVERTED": "1'b1"}

if __name__ == "__main__":
    print("`define GTXE2_COMMON_FACTORY_PARAMS \\")
    print(",\\\n".join(f"    .{k}({v})" for k, v in sorted(COMMON_PARAMS.items())))
    print()
    for cell in TILES:
        params, leftover = gen(cell)
        for k, default in YOSYS_LACKS.items():
            if params.get(k) == default:
                del params[k]
        name = cell.lower()
        print(f"// {cell}: {len(params)} parameters from the factory design ({TILES[cell][0]})")
        print(f"`define {cell}_FACTORY_PARAMS \\")
        print(",\\\n".join(f"    .{k}({v})" for k, v in sorted(params.items())))
        print()
        if leftover:
            print(f"// factory features with no parameter in the nextpnr writer: {' '.join(leftover)}")
            print()
