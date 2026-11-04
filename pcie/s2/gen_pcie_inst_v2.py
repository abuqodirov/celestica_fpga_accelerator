#!/usr/bin/env python3
"""Write s2_pcie_inst.vh: the PCIE_2_1 instance with EVERY input connected (an unconnected hard-block input is
left unrouted by nextpnr and reads 1). Inputs not listed in CONN get the inactive value: all ones for the
active-low ...N ports (not NOT_ACTIVE_LOW), zero for the rest. Outputs not listed stay open."""
import collections

ports = collections.OrderedDict()
for l in open("pcie_ports.txt"):
    c, base, idx, pin, d = l.split()
    w = ports.setdefault(base, [d, 0])
    w[1] = max(w[1], int(idx) + 1 if idx != "-1" else 1)

CONN = {
    # clocks and resets (CRM_MODULE_RSTS = 0: the module resets are tied off, as in Xilinx's core_top)
    "PIPECLK": "pclk", "USERCLK": "userclk", "USERCLK2": "pclk", "DRPCLK": "1'b0",
    "SYSRSTN": "core_rst_n", "PLUPSTREAMPREFERDEEMPH": "1'b1",
    # identity
    "CFGVENDID": "16'h10ee", "CFGDEVID": "16'h7028", "CFGREVID": "8'h02",
    "CFGSUBSYSVENDID": "16'h10ee", "CFGSUBSYSID": "16'h0007", "CFGDSN": "64'h0000_0001_0000_0002",
    # TRN: accept and drop everything received; transmit nothing; let the core send its own config completions
    "TRNRDSTRDY": "1'b1", "TRNRNPOK": "1'b1", "TRNRNPREQ": "1'b1", "TRNTCFGGNT": "1'b1",
    "TRNRFCPRET": "1'b1",   # return posted credits (factory ties it to 1, as Xilinx's wrapper does)
    # outputs used
    "PLLTSSMSTATE": "pl_ltssm", "PLPHYLNKUPN": "pl_phy_lnk_up_n", "PLSELLNKRATE": "pl_sel_rate",
    "PLSELLNKWIDTH": "pl_sel_width", "PLINITIALLINKWIDTH": "pl_init_width", "PLLINKGEN2CAP": "pl_gen2_cap",
    "PLLINKPARTNERGEN2SUPPORTED": "pl_partner_gen2", "PLLINKUPCFGCAP": "pl_upcfg_cap",
    "PLLANEREVERSALMODE": "pl_lane_rev", "PLRECEIVEDHOTRST": "pl_hot_rst", "PLRXPMSTATE": "pl_rx_pm",
    "PLTXPMSTATE": "pl_tx_pm", "TRNLNKUP": "trn_lnk_up", "USERRSTN": "user_rst_n",
    "CFGCOMMANDMEMENABLE": "cfg_mem_en", "CFGCOMMANDBUSMASTERENABLE": "cfg_bm_en",
    "CFGLINKSTATUSDLLACTIVE": "cfg_dll_active", "CFGLINKSTATUSLINKTRAINING": "cfg_link_training",
    "CFGLINKSTATUSCURRENTSPEED": "cfg_cur_speed", "CFGLINKSTATUSNEGOTIATEDWIDTH": "cfg_neg_width",
    "CFGPCIELINKSTATE": "cfg_link_state", "CFGPMCSRPOWERSTATE": "cfg_pm_state",
    "CFGDEVSTATUSCORRERRDETECTED": "cfg_err_cor", "CFGDEVSTATUSNONFATALERRDETECTED": "cfg_err_nonfatal",
    "CFGDEVSTATUSFATALERRDETECTED": "cfg_err_fatal", "CFGDEVSTATUSURDETECTED": "cfg_err_ur",
    "CFGTRANSACTION": "cfg_trans", "CFGTRANSACTIONTYPE": "cfg_trans_type", "CFGTRANSACTIONADDR": "cfg_trans_addr",
    "CFGMSGRECEIVED": "cfg_msg", "CFGMSGRECEIVEDPMETO": "cfg_msg_pme_to",
    "TRNRSOF": "trn_rsof", "TRNRSRCRDY": "trn_rsrc_rdy", "TRNRD": "trn_rd", "TRNRBARHIT": "trn_rbar_hit",
    "TRNTBUFAV": "trn_tbuf_av", "TRNTCFGREQ": "trn_tcfg_req",
    # PIPE (lane signals below) and the TX/RX buffer RAMs
    "PIPETXDEEMPH": "pipe_tx_deemph", "PIPETXMARGIN": "pipe_tx_margin", "PIPETXRATE": "pipe_tx_rate",
    "PIPETXRCVRDET": "pipe_tx_rcvrdet", "PIPETXRESET": "pipe_tx_reset",
    "MIMTXWDATA": "mim_tx_wdata", "MIMTXWADDR": "mim_tx_waddr", "MIMTXWEN": "mim_tx_wen",
    "MIMTXRADDR": "mim_tx_raddr", "MIMTXREN": "mim_tx_ren", "MIMTXRDATA": "mim_tx_rdata",
    "MIMRXWDATA": "mim_rx_wdata", "MIMRXWADDR": "mim_rx_waddr", "MIMRXWEN": "mim_rx_wen",
    "MIMRXRADDR": "mim_rx_raddr", "MIMRXREN": "mim_rx_ren", "MIMRXRDATA": "mim_rx_rdata",
    # v2 diagnostics: configuration management read port (JTAG reads the block's config space) and the block's
    # data-link / transaction-layer debug outputs
    "CFGMGMTRDENN": "mg_rd_en_n", "CFGMGMTDWADDR": "mg_addr", "CFGMGMTBYTEENN": "mg_be_n",
    "CFGMGMTDO": "mg_do_w", "CFGMGMTRDWRDONEN": "mg_done_n",
    "LL2BADTLPERR": "ll2_badtlp", "LL2BADDLLPERR": "ll2_baddllp", "LL2PROTOCOLERR": "ll2_protocol",
    "LL2RECEIVERERR": "ll2_receiver", "LL2REPLAYROERR": "ll2_replayro", "LL2REPLAYTOERR": "ll2_replayto",
    "PL2RECEIVERERR": "pl2_receiver", "PL2RECOVERY": "pl2_recovery", "TL2ERRMALFORMED": "tl2_malformed",
    "TL2ERRFCPE": "tl2_fcpe", "TL2ERRRXOVERFLOW": "tl2_rxoverflow", "TRNTERRDROP": "trn_terrdrop",
    "TRNRDLLPSRCRDY": "trn_rdllp_rdy", "TRNRDLLPDATA": "trn_rdllp_data",
    "LL2LINKSTATUS": "ll2_link_status", "LL2TFCINIT1SEQ": "ll2_tfc1", "LL2TFCINIT2SEQ": "ll2_tfc2",
    "PL2LINKUP": "pl2_linkup", "PL2L0REQ": "pl2_l0req", "PL2RXELECIDLE": "pl2_rxei", "LL2TXIDLE": "ll2_txidle",
    "LL2SUSPENDOK": "ll2_suspendok", "PLDBGVEC": "pl_dbg_vec",
}
for i in range(8):
    for p, w in (("TX{}DATA", "pipe_tx_data[{}*16 +: 16]"), ("TX{}CHARISK", "pipe_tx_charisk[{}*2 +: 2]"),
                 ("TX{}ELECIDLE", "pipe_tx_elecidle[{}]"), ("TX{}COMPLIANCE", "pipe_tx_compliance[{}]"),
                 ("TX{}POWERDOWN", "pipe_tx_powerdown[{}*2 +: 2]"), ("RX{}POLARITY", "pipe_rx_polarity[{}]"),
                 ("RX{}DATA", "pipe_rx_data[{}*16 +: 16]"), ("RX{}CHARISK", "pipe_rx_charisk[{}*2 +: 2]"),
                 ("RX{}VALID", "pipe_rx_valid[{}]"), ("RX{}CHANISALIGNED", "pipe_rx_chanisaligned[{}]"),
                 ("RX{}STATUS", "pipe_rx_status[{}*3 +: 3]"), ("RX{}PHYSTATUS", "pipe_rx_phystatus[{}]"),
                 ("RX{}ELECIDLE", "pipe_rx_elecidle[{}]")):
        CONN["PIPE" + p.format(i)] = w.format(i)

# ports whose names end in N but are active-high (pcie_ties.py found these against the factory ties)
NOT_ACTIVE_LOW = {"CFGFORCEEXTENDEDSYNCON", "DRPEN", "PLDIRECTEDLINKAUTON", "TRNTECRCGEN", "CFGDSN"}
missing = [k for k in CONN if k not in ports]
if missing:
    raise SystemExit(f"not PCIE_2_1 ports: {missing}")
lines, tied = [], 0
for name, (d, width) in ports.items():
    if name in CONN:
        lines.append(f"        .{name}({CONN[name]})")
    elif d == "input":
        v = ((1 << width) - 1) if name.endswith("N") and name not in NOT_ACTIVE_LOW else 0
        lines.append(f"        .{name}({width}'h{v:x})")
        tied += 1
open("s2_pcie_inst.vh", "w").write(
    "// generated by gen_pcie_inst.py -- every PCIE_2_1 input is connected\n"
    "    PCIE_2_1 #(`PCIE_2_1_S2_PARAMS) pcie (\n" + ",\n".join(lines) + "\n    );\n")
print(f"{len(ports)} ports, {len(CONN)} connected by name, {tied} inputs tied to their inactive value")
