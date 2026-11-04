// PCIe stage 2: the first link with the PC, 2.5 GT/s (Gen1) x8.
//
// Stage 1 (../s1) proved the 8 lanes: same transceiver settings, same input ties, same reset and TX phase
// alignment sequence. This adds the PCIe hard block (factory parameters, limited to Gen1 by gen_params_s2.py),
// its two TX/RX buffer RAMs and the PIPE connections between the block and the lanes. The user side only
// watches: received TLPs are accepted and dropped, nothing is transmitted (the block answers configuration
// requests by itself). A recorder logs every change of the link state machine (LTSSM) into a RAM.
// JTAG: USER1 = control + status (2048 bits), USER2 = RAM read-out (72 bits per entry). host/s2.py.
//
// v2 (diagnostics, after v1 linked up but never answered the PC's configuration reads): snoop RAMs log every
// write into and every read out of the block's RX and TX buffer RAMs (what arrived, what the block sends);
// counters on the block's data-link / transaction-layer error and debug outputs; the received DLLPs; and a
// JTAG-driven read of the block's own configuration space through its management port (CFGMGMT).
//
// Clocks: CFGMCLK (~64 MHz, sclk) runs the reset sequencer; lane 0 TXOUTCLK = 100 MHz reference (refclk_fab)
// -> PLL -> pclk 125 MHz (PIPE clock, also USERCLK2 and the TX alignment clock) and userclk 250 MHz (block core
// clock and buffer RAMs). oobclk = refclk_fab / 2 = 50 MHz (pg054: 50 MHz OOB clock) -> CLKRSVD[0].
`include "factory_params.vh"
`include "s2_params.vh"

module s2_top (
    input  wire       pcie_refclk_p, pcie_refclk_n,   // J8/J7 = MGTREFCLK0_116
    input  wire [7:0] pcie_rxp, pcie_rxn,
    output wire [7:0] pcie_txp, pcie_txn,
    input  wire       pcie_perst_n,                   // Y26
    output wire       led,                            // P30 (LED3): on = link up, blinking = no link
    output wire       flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n
);
    assign {flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n} = 4'b1111;   // keep the BPI flash idle

    localparam DR_BITS = 2048;
    localparam [31:0] CTL_DEFAULT = 32'h0000_0044;   // pcie_en = 1, lpm = 1

    // ------------------------------------------------------------------ clocks
    wire cfgmclk, sclk;
    STARTUPE2 startup (
        .CFGCLK(), .CFGMCLK(cfgmclk), .EOS(), .PREQ(),
        .CLK(1'b0), .GSR(1'b0), .GTS(1'b0), .KEYCLEARB(1'b1), .PACK(1'b0),
        .USRCCLKO(1'b0), .USRCCLKTS(1'b1), .USRDONEO(1'b1), .USRDONETS(1'b1));
    BUFG sclk_buf (.I(cfgmclk), .O(sclk));

    wire refclk;
    IBUFDS_GTE2 refclk_ibuf (.I(pcie_refclk_p), .IB(pcie_refclk_n), .CEB(1'b0), .O(refclk), .ODIV2());

    wire [7:0] txoutclk;
    wire refclk_fab, clkfb, clk125, clk250, pll_locked;
    reg  pll_rst = 1'b1;
    BUFG txoutclk_buf (.I(txoutclk[0]), .O(refclk_fab));
    PLLE2_BASE #(.CLKIN1_PERIOD(10.0), .CLKFBOUT_MULT(10), .DIVCLK_DIVIDE(1),
                 .CLKOUT0_DIVIDE(8), .CLKOUT1_DIVIDE(4))
        pipe_pll (.CLKIN1(refclk_fab), .CLKFBIN(clkfb), .CLKFBOUT(clkfb), .RST(pll_rst), .PWRDWN(1'b0),
                  .CLKOUT0(clk125), .CLKOUT1(clk250), .CLKOUT2(), .CLKOUT3(), .CLKOUT4(), .CLKOUT5(),
                  .LOCKED(pll_locked));
    wire pclk, userclk;
    BUFG pclk_buf (.I(clk125), .O(pclk));
    BUFG uclk_buf (.I(clk250), .O(userclk));
    reg oobclk = 1'b0;
    always @(posedge refclk_fab) oobclk <= ~oobclk;

    // ------------------------------------------------------------------ JTAG USER1: control + status
    wire tck_raw, tck, tdi, sel1, sel2, capture, shift, update;
    reg  [DR_BITS-1:0] sr = 0;
    reg  [71:0] sr2 = 0;
    wire tdo2;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan1 (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel1), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(update), .TDO(sr[0]));
    BSCANE2 #(.JTAG_CHAIN(2)) bscan2 (
        .CAPTURE(), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel2), .SHIFT(),
        .TCK(), .TDI(), .TMS(), .UPDATE(), .TDO(sr2[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));

    // control word (host/s2.py): level bits are synchronised where used, pulses are toggles
    reg  [31:0] ctl = CTL_DEFAULT;
    reg         restart_t = 1'b0, rearm_t = 1'b0, clear_t = 1'b0;
    reg  [8:0]  trp = 0;            // RAM read pointer (tck domain)
    reg         mgmt_t = 1'b0;
    wire        c_pcie_en = ctl[2], c_mode = ctl[4], c_lpm = ctl[6];
    wire [9:0]  c_mg_addr = ctl[21:12];   // config space DW address for the management read
    wire [2:0]  c_rsel = ctl[26:24];      // USER2 source: 0 recorder, 1 RX writes, 2 RX reads, 3 TX writes, 4 TX reads
    wire [DR_BITS-1:0] status;
    wire [71:0] trace_rd, snp_rxw_rd, snp_rxr_rd, snp_txw_rd, snp_txr_rd;
    wire [71:0] user2_rd = c_rsel == 3'd1 ? snp_rxw_rd : c_rsel == 3'd2 ? snp_rxr_rd :
                           c_rsel == 3'd3 ? snp_txw_rd : c_rsel == 3'd4 ? snp_txr_rd : trace_rd;
    always @(posedge tck) begin
        if (sel1 && capture) sr <= status;
        else if (sel1 && shift) sr <= {tdi, sr[DR_BITS-1:1]};
        else if (sel1 && update && sr[0]) begin
            ctl <= sr[31:0];
            if (sr[1])  restart_t <= ~restart_t;
            if (sr[3])  rearm_t   <= ~rearm_t;
            if (sr[5])  trp       <= 0;
            if (sr[10]) clear_t   <= ~clear_t;
            if (sr[11]) mgmt_t    <= ~mgmt_t;
        end
        if (sel2 && capture) begin sr2 <= user2_rd; trp <= trp + 1'b1; end
        else if (sel2 && shift) sr2 <= {tdi, sr2[71:1]};
    end

    // ------------------------------------------------------------------ PIPE signals (block <-> lanes)
    wire [127:0] pipe_tx_data;  wire [15:0] pipe_tx_charisk, pipe_tx_powerdown;
    wire [7:0]   pipe_tx_elecidle, pipe_tx_compliance, pipe_rx_polarity;
    wire         pipe_tx_deemph, pipe_tx_rate, pipe_tx_rcvrdet, pipe_tx_reset;
    wire [2:0]   pipe_tx_margin;
    wire [127:0] pipe_rx_data;  wire [15:0] pipe_rx_charisk;  wire [23:0] pipe_rx_status;
    wire [7:0]   pipe_rx_valid, pipe_rx_chanisaligned, pipe_rx_phystatus, pipe_rx_elecidle;

    // ------------------------------------------------------------------ transceivers
    wire [7:0] cplllock, txresetdone, rxresetdone, txdlysresetdone, txphinitdone, txphaligndone;
    wire [7:0] cpllrefclklost, rxbyteisaligned, gt_phystatus;
    wire [4:0] chbond0;            // lane 0 (bonding master) -> all other lanes (star, as in the factory design)
    reg  [7:0] txdlysreset = 0, txphinit = 0, txphalign = 0, txdlyen = 0;
    reg        cpllpd = 1'b1, cpllreset = 1'b0, gtreset = 1'b1, userrdy = 1'b0;
    reg        p_lpm = 1'b1, phy_gate = 1'b0;   // pclk domain
    assign pipe_rx_phystatus = phy_gate ? gt_phystatus : 8'hff;   // PHY status stays high until the PHY is ready

    genvar i;
    generate for (i = 0; i < 8; i = i + 1) begin : lane
        wire [63:0] rxd; wire [7:0] rxk; wire [4:0] cbo;
        GTXE2_CHANNEL #(`GTXE2_CHANNEL_FACTORY_PARAMS) gtx (
            // clocks and PLL
            .GTREFCLK0(refclk), .GTREFCLK1(1'b0), .GTNORTHREFCLK0(1'b0), .GTNORTHREFCLK1(1'b0),
            .GTSOUTHREFCLK0(1'b0), .GTSOUTHREFCLK1(1'b0), .GTGREFCLK(1'b0), .QPLLCLK(1'b0), .QPLLREFCLK(1'b0),
            .CPLLREFCLKSEL(3'b001), .CPLLPD(cpllpd), .CPLLRESET(cpllreset), .CPLLLOCKEN(1'b1),
            .CPLLLOCKDETCLK(1'b1), .CPLLLOCK(cplllock[i]), .CPLLREFCLKLOST(cpllrefclklost[i]), .CPLLFBCLKLOST(),
            .TXSYSCLKSEL(2'b00), .RXSYSCLKSEL(2'b00),
            .TXUSRCLK(pclk), .TXUSRCLK2(pclk), .RXUSRCLK(pclk), .RXUSRCLK2(pclk),
            .TXOUTCLKSEL(i == 0 ? 3'b011 : 3'b000), .TXOUTCLK(txoutclk[i]), .TXOUTCLKFABRIC(), .TXOUTCLKPCS(),
            .RXOUTCLKSEL(3'b000), .RXOUTCLK(), .RXOUTCLKFABRIC(), .RXOUTCLKPCS(),
            .CLKRSVD({3'b000, oobclk}), .TXPHDLYTSTCLK(1'b1),
            // serial pins
            .GTXRXP(pcie_rxp[i]), .GTXRXN(pcie_rxn[i]), .GTXTXP(pcie_txp[i]), .GTXTXN(pcie_txn[i]),
            // resets
            .GTTXRESET(gtreset), .GTRXRESET(gtreset), .TXUSERRDY(userrdy), .RXUSERRDY(userrdy),
            .GTRESETSEL(1'b0), .RESETOVRD(1'b0), .CFGRESET(1'b0),
            .TXPCSRESET(1'b0), .TXPMARESET(1'b0), .RXPCSRESET(1'b0), .RXPMARESET(1'b0),
            .RXBUFRESET(1'b0), .RXCDRRESET(1'b0), .RXCDRFREQRESET(1'b0), .RXCDRRESETRSV(1'b0),
            .RXDFELPMRESET(1'b0), .RXOOBRESET(1'b0), .EYESCANRESET(1'b0), .RXPRBSCNTRESET(1'b0),
            .TXRESETDONE(txresetdone[i]), .RXRESETDONE(rxresetdone[i]),
            // TX phase alignment (TXBUF_EN = FALSE), multi-lane manual mode as in the factory design
            .TXPHALIGNEN(1'b1), .TXDLYBYPASS(1'b0), .TXDLYSRESET(txdlysreset[i]),
            .TXPHINIT(txphinit[i]), .TXPHALIGN(txphalign[i]), .TXDLYEN(txdlyen[i]),
            .TXPHDLYRESET(1'b0), .TXDLYHOLD(1'b0), .TXDLYUPDOWN(1'b0), .TXDLYOVRDEN(1'b0), .TXPHOVRDEN(1'b0),
            .TXPHDLYPD(1'b0), .TXDLYSRESETDONE(txdlysresetdone[i]), .TXPHINITDONE(txphinitdone[i]),
            .TXPHALIGNDONE(txphaligndone[i]),
            // RX buffer is used: RX phase alignment bypassed
            .RXDLYBYPASS(1'b1), .RXPHALIGNEN(1'b0), .RXDLYSRESET(1'b0), .RXPHALIGN(1'b0), .RXDLYEN(1'b0),
            .RXPHDLYRESET(1'b0), .RXDLYOVRDEN(1'b0), .RXPHOVRDEN(1'b0), .RXPHDLYPD(1'b0), .RXDDIEN(1'b0),
            // TX data path <- PCIe block
            .TXDATA({48'd0, pipe_tx_data[16*i +: 16]}), .TXCHARISK({6'd0, pipe_tx_charisk[2*i +: 2]}),
            .TXCHARDISPMODE({7'd0, pipe_tx_compliance[i]}), .TXCHARDISPVAL(8'd0),
            .TX8B10BEN(1'b1), .TX8B10BBYPASS(8'd0), .TXHEADER(3'd0), .TXSEQUENCE(7'd0),
            .TXSTARTSEQ(1'b0), .TXPOLARITY(1'b0), .TXINHIBIT(1'b0), .TXPRBSSEL(3'd0), .TXPRBSFORCEERR(1'b0),
            // TX driver: PIPE mode (TXDEEMPH/TXMARGIN/TXSWING; the cursors are unused at Gen1/2)
            .TXELECIDLE(pipe_tx_elecidle[i]), .TXPD(pipe_tx_powerdown[2*i +: 2]), .TXDETECTRX(pipe_tx_rcvrdet),
            .TXDEEMPH(pipe_tx_deemph), .TXMARGIN(pipe_tx_margin), .TXSWING(1'b0),
            .TXDIFFCTRL(4'b1100), .TXBUFDIFFCTRL(3'b100), .TXMAINCURSOR(7'd0),
            .TXPOSTCURSOR(5'd0), .TXPRECURSOR(5'd0), .TXPOSTCURSORINV(1'b0), .TXPRECURSORINV(1'b0),
            .TXDIFFPD(1'b0), .TXPISOPD(1'b0), .TXPDELECIDLEMODE(1'b0),
            .TXQPIBIASEN(1'b0), .TXQPISTRONGPDOWN(1'b0), .TXQPIWEAKPUP(1'b0),
            .TXCOMINIT(1'b0), .TXCOMSAS(1'b0), .TXCOMWAKE(1'b0),
            .TXRATE(3'b000), .TXRATEDONE(),     // Gen1 only: the rate never changes
            // RX data path -> PCIe block
            .RXDATA(rxd), .RXCHARISK(rxk), .RX8B10BEN(1'b1), .RXPOLARITY(pipe_rx_polarity[i]),
            .RXPRBSSEL(3'd0), .RXPRBSERR(), .RXCOMMADETEN(1'b1), .RXMCOMMAALIGNEN(1'b1), .RXPCOMMAALIGNEN(1'b1),
            .RXSLIDE(1'b0), .RXGEARBOXSLIP(1'b0), .RXBYTEISALIGNED(rxbyteisaligned[i]),
            .RXCHBONDEN(1'b1), .RXCHBONDMASTER(i == 0), .RXCHBONDSLAVE(i != 0),
            .RXCHBONDLEVEL(i == 0 ? 3'b001 : 3'b000), .RXCHBONDI(i == 0 ? 5'd0 : chbond0), .RXCHBONDO(cbo),
            .RXCHANISALIGNED(pipe_rx_chanisaligned[i]), .RXVALID(pipe_rx_valid[i]),
            .RXSTATUS(pipe_rx_status[3*i +: 3]), .PHYSTATUS(gt_phystatus[i]), .RXELECIDLE(pipe_rx_elecidle[i]),
            .RXELECIDLEMODE(2'b00), .RXPD(pipe_tx_powerdown[2*i +: 2]), .RXRATE(3'b000), .RXRATEDONE(),
            .LOOPBACK(3'b000), .SETERRSTATUS(1'b0), .RXQPIEN(1'b0),
            // RX equaliser: LPM, DFE overrides as in the factory design
            .RXLPMEN(p_lpm), .RXDFELFOVRDEN(1'b1), .RXDFEAGCHOLD(1'b0), .RXDFEAGCOVRDEN(1'b0),
            .RXDFECM1EN(1'b0), .RXDFELFHOLD(1'b0), .RXDFETAP2HOLD(1'b0), .RXDFETAP2OVRDEN(1'b0),
            .RXDFETAP3HOLD(1'b0), .RXDFETAP3OVRDEN(1'b0), .RXDFETAP4HOLD(1'b0), .RXDFETAP4OVRDEN(1'b0),
            .RXDFETAP5HOLD(1'b0), .RXDFETAP5OVRDEN(1'b0), .RXDFEUTHOLD(1'b0), .RXDFEUTOVRDEN(1'b0),
            .RXDFEVPHOLD(1'b0), .RXDFEVPOVRDEN(1'b0), .RXDFEVSEN(1'b0), .RXDFEXYDEN(1'b0),
            .RXDFEXYDHOLD(1'b0), .RXDFEXYDOVRDEN(1'b0), .RXLPMHFHOLD(1'b0), .RXLPMHFOVRDEN(1'b0),
            .RXLPMLFHOLD(1'b0), .RXLPMLFKLOVRDEN(1'b0), .RXOSHOLD(1'b0), .RXOSOVRDEN(1'b0),
            .RXCDRHOLD(1'b0), .RXCDROVRDEN(1'b0), .RXMONITORSEL(2'b00),
            // eye scan, DRP, reserved
            .EYESCANMODE(1'b0), .EYESCANTRIGGER(1'b0),
            .DRPCLK(pclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(9'd0), .DRPDI(16'd0), .DRPDO(), .DRPRDY(),
            .GTRSVD(16'd0), .PCSRSVDIN(16'd0), .PCSRSVDIN2(5'd0), .PMARSVDIN(5'd0), .PMARSVDIN2(5'd0),
            .TSTIN(20'hfffff)
        );
        assign pipe_rx_data[16*i +: 16] = rxd[15:0];
        assign pipe_rx_charisk[2*i +: 2] = rxk[1:0];
        if (i == 0) begin : master
            assign chbond0 = cbo;
        end
    end endgenerate

    // QPLL blocks of both quads: powered down (the lanes use their CPLLs), band gap and RCAL on.
    // Quad 115 gets the reference clock from quad 116; nextpnr cannot express that, ../fasm_patch.py adds the bits.
    (* keep, BEL = "GTXE2_COMMON_X0Y5/GTXE2_COMMON" *) GTXE2_COMMON #(`GTXE2_COMMON_FACTORY_PARAMS) qpll116 (
        .GTREFCLK0(refclk), .GTREFCLK1(1'b0), .GTNORTHREFCLK0(1'b0), .GTNORTHREFCLK1(1'b0),
        .GTSOUTHREFCLK0(1'b0), .GTSOUTHREFCLK1(1'b0), .GTGREFCLK(1'b0),
        .QPLLPD(1'b1), .QPLLRESET(1'b1), .QPLLLOCKEN(1'b1), .QPLLLOCKDETCLK(1'b1), .QPLLREFCLKSEL(3'b001),
        .QPLLOUTRESET(1'b0), .BGBYPASSB(1'b1), .BGMONITORENB(1'b1), .BGPDB(1'b1), .BGRCALOVRD(5'b11111),
        .RCALENB(1'b1), .PMARSVD(8'd0), .QPLLRSVD1(16'd0), .QPLLRSVD2(5'b11111),
        .DRPCLK(pclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(8'd0), .DRPDI(16'd0));
    (* keep, BEL = "GTXE2_COMMON_X0Y4/GTXE2_COMMON" *) GTXE2_COMMON #(`GTXE2_COMMON_FACTORY_PARAMS) qpll115 (
        .GTREFCLK0(1'b0), .GTREFCLK1(1'b0), .GTNORTHREFCLK0(1'b0), .GTNORTHREFCLK1(1'b0),
        .GTSOUTHREFCLK0(1'b0), .GTSOUTHREFCLK1(1'b0), .GTGREFCLK(1'b0),
        .QPLLPD(1'b1), .QPLLRESET(1'b1), .QPLLLOCKEN(1'b1), .QPLLLOCKDETCLK(1'b1), .QPLLREFCLKSEL(3'b010),
        .QPLLOUTRESET(1'b0), .BGBYPASSB(1'b1), .BGMONITORENB(1'b1), .BGPDB(1'b1), .BGRCALOVRD(5'b11111),
        .RCALENB(1'b1), .PMARSVD(8'd0), .QPLLRSVD1(16'd0), .QPLLRSVD2(5'b11111),
        .DRPCLK(pclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(8'd0), .DRPDI(16'd0));

    // ------------------------------------------------------------------ sclk: reset sequencer
    // Starts on PERST# high (and on a JTAG restart), runs the stage-1 sequence, then releases the PCIe block
    // (if enabled). PERST# low at any time = back to the start, block held in reset.
    localparam S_START = 0, S_PDREL = 1, S_CPLLRST = 2, S_LOCK = 3, S_GTRST = 4, S_SYNC = 5, S_SYNCW = 6,
               S_READY = 7, S_ERROR = 15;
    reg  [3:0]  st = S_START, err_st = 0;
    reg  [21:0] tmr = 0;
    reg  [31:0] ready_time = 0, run_time = 0;
    reg  [15:0] restarts = 0, perst_falls = 0;
    reg         sync_req = 1'b0, core_rst_n = 1'b0, perst_q = 1'b0;
    reg  [2:0]  restart_s = 0;
    wire [7:0]  cplllock_s, txrd_s, rxrd_s;
    wire        pll_locked_s, sync_ack_s, perst_s, pcie_en_s;
    reg         sync_ack = 1'b0;   // pclk domain, below
    sync2 #(8) s_cl (sclk, cplllock, cplllock_s);
    sync2 #(8) s_tr (sclk, txresetdone, txrd_s);
    sync2 #(8) s_rr (sclk, rxresetdone, rxrd_s);
    sync2 #(1) s_pl (sclk, pll_locked, pll_locked_s);
    sync2 #(1) s_sa (sclk, sync_ack, sync_ack_s);
    sync2 #(1) s_pe (sclk, pcie_perst_n, perst_s);
    sync2 #(1) s_en (sclk, c_pcie_en, pcie_en_s);

    wire all_lock = &cplllock_s && pll_locked_s, all_rd = &txrd_s && &rxrd_s;
    always @(posedge sclk) begin
        restart_s <= {restart_s[1:0], restart_t};
        perst_q   <= perst_s;
        tmr       <= tmr + 1'b1;
        run_time  <= run_time + 1'b1;
        core_rst_n <= (st == S_READY) && pcie_en_s && perst_s;
        case (st)
        S_START:   begin cpllpd <= 1; cpllreset <= 0; gtreset <= 1; userrdy <= 0; pll_rst <= 1;
                         if (!perst_s) tmr <= 0;
                         else if (tmr[16]) begin st <= S_PDREL; tmr <= 0; end end              // ~1 ms
        S_PDREL:   begin cpllpd <= 0;   if (tmr[10]) begin st <= S_CPLLRST; tmr <= 0; end end
        S_CPLLRST: begin cpllreset <= 1; if (tmr[8]) begin st <= S_LOCK; tmr <= 0; end end
        S_LOCK:    begin cpllreset <= 0; pll_rst <= 0;
                         if (all_lock && tmr[10]) begin st <= S_GTRST; tmr <= 0; end
                         else if (tmr[21]) begin err_st <= st; st <= S_ERROR; end end      // ~33 ms
        S_GTRST:   begin gtreset <= 0; userrdy <= 1;
                         if (all_rd) begin st <= S_SYNC; tmr <= 0; end
                         else if (tmr[21]) begin err_st <= st; st <= S_ERROR; end end
        S_SYNC:    begin sync_req <= ~sync_req; st <= S_SYNCW; tmr <= 0; end
        S_SYNCW:   if (sync_ack_s == sync_req) begin st <= S_READY; ready_time <= run_time; end
                   else if (tmr[21]) begin err_st <= st; st <= S_ERROR; end
        default:   ;
        endcase
        if (perst_q && !perst_s) perst_falls <= perst_falls + 1'b1;
        if ((restart_s[2] != restart_s[1]) || (!perst_s && st != S_START)) begin
            st <= S_START; tmr <= 0; err_st <= 0; run_time <= 0; ready_time <= 0; core_rst_n <= 0;
            if (restart_s[2] != restart_s[1]) restarts <= restarts + 1'b1;
        end
    end

    // ------------------------------------------------------------------ pclk: block reset, TX phase alignment
    reg  [1:0] rst_ps = 0;
    reg        pcie_rst_n = 1'b0;    // SYSRSTN, one pclk after the PHY status opens
    reg  [1:0] lpm_ps = 2'b11;
    always @(posedge pclk) begin
        rst_ps <= {rst_ps[0], core_rst_n};
        phy_gate <= rst_ps[1];
        pcie_rst_n <= phy_gate;
        lpm_ps <= {lpm_ps[0], c_lpm};
        p_lpm <= lpm_ps[1];
    end

    // TX phase alignment (UG476 TX buffer bypass), multi-lane manual mode with lane 0 as master (stage 1).
    localparam T_IDLE = 0, T_DLYSRST = 1, T_MINIT = 2, T_MALIGN = 3, T_MDLYEN = 4, T_SINIT = 5, T_SALIGN = 6,
               T_MDLYEN2 = 7, T_DONE = 8, T_ERR = 15;
    reg  [3:0] ts = T_IDLE, ts_err = 0;
    reg  [7:0] seen = 0;
    reg        req_cur = 1'b0;
    reg  [16:0] ttmr = 0;
    wire [7:0] dlysrd_s, phinitd_s, phalignd_s;
    reg  [7:0] phinitd_r = 0, phalignd_r = 0, init_rise = 0, align_rise = 0;
    wire       sreq_d;
    sync2 #(8) s_dr (pclk, txdlysresetdone, dlysrd_s);
    sync2 #(8) s_pi (pclk, txphinitdone, phinitd_s);
    sync2 #(8) s_pa (pclk, txphaligndone, phalignd_s);
    sync2 #(1) s_sq (pclk, sync_req, sreq_d);
    always @(posedge pclk) begin
        phinitd_r <= phinitd_s; phalignd_r <= phalignd_s;
        init_rise <= phinitd_s & ~phinitd_r; align_rise <= phalignd_s & ~phalignd_r;
        ttmr <= ttmr + 1'b1;
        case (ts)   // per-lane steps: a lane's request drops once its done is seen; next state when all are seen
        T_IDLE, T_DONE, T_ERR: ;
        T_DLYSRST: begin
            seen <= seen | dlysrd_s; txdlysreset <= ~(seen | dlysrd_s);
            if (&seen) begin txdlysreset <= 0; seen <= 0; ttmr <= 0; ts <= T_MINIT; end
        end
        T_MINIT:   begin txphinit[0] <= 1;
                         if (init_rise[0]) begin txphinit[0] <= 0; ts <= T_MALIGN; ttmr <= 0; end end
        T_MALIGN:  begin txphalign[0] <= 1;
                         if (align_rise[0]) begin txphalign[0] <= 0; ts <= T_MDLYEN; ttmr <= 0; end end
        T_MDLYEN:  begin txdlyen[0] <= 1;
                         if (align_rise[0]) begin txdlyen[0] <= 0; ts <= T_SINIT; seen <= 8'h01; ttmr <= 0; end end
        T_SINIT:   begin seen <= seen | init_rise; txphinit <= ~(seen | init_rise);
                         if (&seen) begin txphinit <= 0; seen <= 8'h01; ts <= T_SALIGN; ttmr <= 0; end end
        T_SALIGN:  begin seen <= seen | align_rise; txphalign <= ~(seen | align_rise);
                         if (&seen) begin txphalign <= 0; ts <= T_MDLYEN2; ttmr <= 0; end end
        T_MDLYEN2: begin txdlyen[0] <= 1;
                         if (align_rise[0]) begin txdlyen[0] <= 0; ts <= T_DONE; end end
        default: ts <= T_ERR;
        endcase
        if (ts != T_IDLE && ts != T_DONE && ts != T_ERR && ttmr[16]) begin   // ~1 ms
            ts_err <= ts; ts <= T_ERR; txdlysreset <= 0; txphinit <= 0; txphalign <= 0; txdlyen <= 0;
        end
        if (ts == T_DONE || ts == T_ERR) sync_ack <= req_cur;
        if (sreq_d != req_cur) begin   // new request (from the sequencer)
            req_cur <= sreq_d; ts <= T_DLYSRST; seen <= 0; ttmr <= 0; ts_err <= 0;
            txdlysreset <= 0; txphinit <= 0; txphalign <= 0; txdlyen <= 0;
        end
    end

    // ------------------------------------------------------------------ PCIe hard block
    wire [5:0]   pl_ltssm;   wire [1:0] pl_sel_width, pl_lane_rev, pl_rx_pm, cfg_cur_speed, cfg_pm_state;
    wire [2:0]   pl_init_width, pl_tx_pm, cfg_link_state;
    wire [3:0]   cfg_neg_width;
    wire         pl_phy_lnk_up_n, pl_sel_rate, pl_gen2_cap, pl_partner_gen2, pl_upcfg_cap, pl_hot_rst;
    wire         trn_lnk_up, user_rst_n, cfg_mem_en, cfg_bm_en, cfg_dll_active, cfg_link_training;
    wire         cfg_err_cor, cfg_err_nonfatal, cfg_err_fatal, cfg_err_ur;
    wire         cfg_trans, cfg_trans_type, cfg_msg, cfg_msg_pme_to;
    wire [6:0]   cfg_trans_addr;
    wire         trn_rsof, trn_rsrc_rdy, trn_tcfg_req;
    wire [127:0] trn_rd;
    wire [7:0]   trn_rbar_hit;
    wire [5:0]   trn_tbuf_av;
    wire [68:0]  mim_tx_wdata, mim_tx_rdata;  wire [12:0] mim_tx_waddr, mim_tx_raddr;  wire mim_tx_wen, mim_tx_ren;
    wire [67:0]  mim_rx_wdata, mim_rx_rdata;  wire [12:0] mim_rx_waddr, mim_rx_raddr;  wire mim_rx_wen, mim_rx_ren;
    // v2 diagnostics
    wire         mg_done_n;  wire [31:0] mg_do_w;  reg mg_busy = 1'b0;
    wire         mg_rd_en_n = ~mg_busy;  wire [3:0] mg_be_n = mg_busy ? 4'h0 : 4'hf;
    wire [9:0]   mg_addr;
    wire         ll2_badtlp, ll2_baddllp, ll2_protocol, ll2_receiver, ll2_replayro, ll2_replayto;
    wire         pl2_receiver, pl2_recovery, tl2_malformed, tl2_fcpe, tl2_rxoverflow, trn_terrdrop;
    wire [1:0]   trn_rdllp_rdy;  wire [63:0] trn_rdllp_data;
    wire [4:0]   ll2_link_status;
    wire         ll2_tfc1, ll2_tfc2, pl2_linkup, pl2_l0req, pl2_rxei, ll2_txidle, ll2_suspendok;
    wire [11:0]  pl_dbg_vec;
`include "s2_pcie_inst.vh"

    // TX and RX buffers of the block, as Xilinx's pcie_bram_top_7x builds them for these parameters:
    // 2 x RAMB36 of 1024 x 36 each (TX: 29 packets x (256 + 24) bytes = 8120 bytes; RX: VC0_RX_RAM_LIMIT 0x3ff),
    // read latency 2 (TL_*_RAM_RDATA_LATENCY 2 = output register on), no write/address pipeline (latency 0).
    // Placed where the factory design has them (BRAM_L_X108 rows 200/205 = TX, 215/220 = RX, next to the MIM pins),
    // with the factory's port use: write on B, read on A through the output register.
    wire [71:0] mim_tx_rd72, mim_rx_rd72;
`define MIM_RAM(name, loc, wen, waddr, wdata, ren, raddr, rdata) \
    (* BEL = loc *) RAMB36E1 #(.RAM_MODE("TDP"), .READ_WIDTH_A(36), .WRITE_WIDTH_A(36), .READ_WIDTH_B(36), \
        .WRITE_WIDTH_B(36), .DOA_REG(1), .DOB_REG(0), .WRITE_MODE_A("NO_CHANGE"), .WRITE_MODE_B("NO_CHANGE")) \
    name (.CLKARDCLK(userclk), .CLKBWRCLK(userclk), .ENARDEN(ren), .ENBWREN(wen), .REGCEAREGCE(1'b1), .REGCEB(1'b0), \
        .RSTRAMARSTRAM(1'b0), .RSTRAMB(1'b0), .RSTREGARSTREG(1'b0), .RSTREGB(1'b0), .WEA(4'd0), .WEBWE({4'd0, {4{wen}}}), \
        .ADDRARDADDR({1'b1, raddr, 5'd0}), .ADDRBWRADDR({1'b1, waddr, 5'd0}), \
        .DIADI(32'd0), .DIPADIP(4'd0), .DIBDI(wdata[31:0]), .DIPBDIP(wdata[35:32]), \
        .DOADO(rdata[31:0]), .DOPADOP(rdata[35:32]), .DOBDO(), .DOPBDOP(), \
        .CASCADEINA(1'b0), .CASCADEINB(1'b0), .INJECTDBITERR(1'b0), .INJECTSBITERR(1'b0));
    // (the macro indexes its data arguments, so they must be plain 36-bit wires)
    wire [35:0] tx_wd0 = mim_tx_wdata[35:0], tx_wd1 = {3'd0, mim_tx_wdata[68:36]};
    wire [35:0] rx_wd0 = mim_rx_wdata[35:0], rx_wd1 = {4'd0, mim_rx_wdata[67:36]};
    wire [35:0] tx_rd0, tx_rd1, rx_rd0, rx_rd1;
    wire [9:0]  tx_wa = mim_tx_waddr[9:0], tx_ra = mim_tx_raddr[9:0], rx_wa = mim_rx_waddr[9:0], rx_ra = mim_rx_raddr[9:0];
    `MIM_RAM(tx_ram0, "RAMB36_X10Y40/RAMB36E1", mim_tx_wen, tx_wa, tx_wd0, mim_tx_ren, tx_ra, tx_rd0)
    `MIM_RAM(tx_ram1, "RAMB36_X10Y41/RAMB36E1", mim_tx_wen, tx_wa, tx_wd1, mim_tx_ren, tx_ra, tx_rd1)
    `MIM_RAM(rx_ram0, "RAMB36_X10Y43/RAMB36E1", mim_rx_wen, rx_wa, rx_wd0, mim_rx_ren, rx_ra, rx_rd0)
    `MIM_RAM(rx_ram1, "RAMB36_X10Y44/RAMB36E1", mim_rx_wen, rx_wa, rx_wd1, mim_rx_ren, rx_ra, rx_rd1)
    assign mim_tx_rd72 = {tx_rd1, tx_rd0};
    assign mim_rx_rd72 = {rx_rd1, rx_rd0};
    assign mim_tx_rdata = mim_tx_rd72[68:0];
    assign mim_rx_rdata = mim_rx_rd72[67:0];

    // ------------------------------------------------------------------ v2: buffer RAM snoops (userclk)
    // Each snoop RAM keeps the first 512 accesses since the block left reset (or a JTAG re-arm):
    // RX writes {waddr[3:0], wdata[67:0]}, RX reads {raddr[3:0], rdata[67:0]} (the data the block gets back,
    // 2 cycles after the read enable), TX writes {waddr[2:0], wdata[68:0]}, TX reads {raddr[2:0], rdata[68:0]}.
    reg  [2:0]  rearm_us = 0, clear_us = 0;
    reg  [1:0]  prst_us = 0;
    reg         prst_uq = 1'b0;
    always @(posedge userclk) begin
        rearm_us <= {rearm_us[1:0], rearm_t}; clear_us <= {clear_us[1:0], clear_t};
        prst_us <= {prst_us[0], pcie_rst_n}; prst_uq <= prst_us[1];
    end
    wire        snp_rearm = (rearm_us[2] != rearm_us[1]) || (prst_us[1] && !prst_uq);
    wire        u_clear = clear_us[2] != clear_us[1];
    reg  [9:0]  rxw_p = 0, rxr_p = 0, txw_p = 0, txr_p = 0;   // entries written, [9] = full
    reg  [1:0]  rxr_d = 0, txr_d = 0;
    reg  [3:0]  rxr_a1 = 0, rxr_a2 = 0;
    reg  [2:0]  txr_a1 = 0, txr_a2 = 0;
    reg  [31:0] n_rxw = 0, n_rxr = 0, n_txw = 0, n_txr = 0;
    always @(posedge userclk) begin
        rxr_d <= {rxr_d[0], mim_rx_ren}; rxr_a1 <= mim_rx_raddr[3:0]; rxr_a2 <= rxr_a1;
        txr_d <= {txr_d[0], mim_tx_ren}; txr_a1 <= mim_tx_raddr[2:0]; txr_a2 <= txr_a1;
        if (mim_rx_wen && !rxw_p[9]) rxw_p <= rxw_p + 1'b1;
        if (rxr_d[1]   && !rxr_p[9]) rxr_p <= rxr_p + 1'b1;
        if (mim_tx_wen && !txw_p[9]) txw_p <= txw_p + 1'b1;
        if (txr_d[1]   && !txr_p[9]) txr_p <= txr_p + 1'b1;
        if (mim_rx_wen) n_rxw <= n_rxw + 1'b1;
        if (mim_rx_ren) n_rxr <= n_rxr + 1'b1;
        if (mim_tx_wen) n_txw <= n_txw + 1'b1;
        if (mim_tx_ren) n_txr <= n_txr + 1'b1;
        if (snp_rearm) begin rxw_p <= 0; rxr_p <= 0; txw_p <= 0; txr_p <= 0; end
        if (u_clear) begin n_rxw <= 0; n_rxr <= 0; n_txw <= 0; n_txr <= 0; end
    end
    ram512x72 snp_rxw (.wclk(userclk), .we(mim_rx_wen && !rxw_p[9]), .wa(rxw_p[8:0]),
                       .wd({mim_rx_waddr[3:0], mim_rx_wdata}), .rclk(tck), .ra(trp), .rd(snp_rxw_rd));
    ram512x72 snp_rxr (.wclk(userclk), .we(rxr_d[1] && !rxr_p[9]), .wa(rxr_p[8:0]),
                       .wd({rxr_a2, mim_rx_rdata}), .rclk(tck), .ra(trp), .rd(snp_rxr_rd));
    ram512x72 snp_txw (.wclk(userclk), .we(mim_tx_wen && !txw_p[9]), .wa(txw_p[8:0]),
                       .wd({mim_tx_waddr[2:0], mim_tx_wdata}), .rclk(tck), .ra(trp), .rd(snp_txw_rd));
    ram512x72 snp_txr (.wclk(userclk), .we(txr_d[1] && !txr_p[9]), .wa(txr_p[8:0]),
                       .wd({txr_a2, mim_tx_rdata}), .rclk(tck), .ra(trp), .rd(snp_txr_rd));

    // v2: the block's error / debug outputs, counted as cycles high at userclk (their clock domain is not
    // documented; 250 MHz sampling catches pulses of either block clock)
    wire [14:0] ev = {pl2_recovery, trn_terrdrop, tl2_rxoverflow, tl2_fcpe, tl2_malformed, pl2_receiver,
                      ll2_replayto, ll2_replayro, ll2_receiver, ll2_protocol, ll2_baddllp, ll2_badtlp,
                      cfg_trans, trn_tcfg_req, |trn_rdllp_rdy};
    reg  [14:0]  ev_q = 0;
    reg  [239:0] n_ev = 0;          // 15 x 16-bit saturating counters
    integer e;
    always @(posedge userclk) begin
        ev_q <= ev;
        for (e = 0; e < 15; e = e + 1) begin
            if (ev_q[e] && n_ev[16*e +: 16] != 16'hffff) n_ev[16*e +: 16] <= n_ev[16*e +: 16] + 1'b1;
            if (u_clear) n_ev[16*e +: 16] <= 16'd0;
        end
    end

    // v2: received DLLPs (TRN, pclk): count, first and last; TRN link up cycles (second, independent use)
    reg  [63:0] first_dllp = 0, last_dllp = 0;
    reg  [15:0] n_dllp = 0;
    reg  [31:0] trn_up_cycles = 0;
    reg  [2:0]  clear_pd = 0;
    always @(posedge pclk) begin
        clear_pd <= {clear_pd[1:0], clear_t};
        if (|trn_rdllp_rdy) begin
            if (n_dllp == 0) first_dllp <= trn_rdllp_data;
            last_dllp <= trn_rdllp_data;
            if (n_dllp != 16'hffff) n_dllp <= n_dllp + 1'b1;
        end
        if (trn_lnk_up) trn_up_cycles <= trn_up_cycles + 1'b1;
        if (clear_pd[2] != clear_pd[1]) begin n_dllp <= 0; first_dllp <= 0; last_dllp <= 0; trn_up_cycles <= 0; end
    end

    // v2: configuration space read through the management port (pclk = USERCLK2): a JTAG toggle starts one
    // read of DW c_mg_addr; rd_en stays low until rd_wr_done (or a 0.5 ms timeout).
    reg  [2:0]  mg_ps = 0;
    reg  [15:0] mg_tmr = 0, mg_n = 0, mg_to = 0;
    reg  [31:0] mg_do = 0;
    reg  [9:0]  mg_addr_r = 0;
    assign mg_addr = mg_addr_r;
    always @(posedge pclk) begin
        mg_ps <= {mg_ps[1:0], mgmt_t};
        if (!mg_busy && mg_ps[2] != mg_ps[1]) begin mg_busy <= 1'b1; mg_tmr <= 0; mg_addr_r <= c_mg_addr; end
        if (mg_busy) begin
            mg_tmr <= mg_tmr + 1'b1;
            if (!mg_done_n) begin mg_busy <= 1'b0; mg_do <= mg_do_w; mg_n <= mg_n + 1'b1; end
            else if (&mg_tmr) begin mg_busy <= 1'b0; mg_to <= mg_to + 1'b1; mg_do <= 32'hdead_beef; end
        end
    end

    // ------------------------------------------------------------------ pclk: link recorder + counters
    // Entry (72 bits): [31:0] time (pclk cycles since armed), [37:32] LTSSM, [38] PHY link up, [39] TRN link up,
    // [41:40] width, [42] rate, [43] hot reset received, [45:44] lane 0 power state, [46] receiver detect,
    // [47] PIPE rate, [55:48] RX electrical idle, [63:56] RX channel aligned, [71:64] RX valid.
    // An entry is written when bits [47:32] change (mode 0) or [71:32] change (mode 1). Armed when the block
    // leaves reset and by JTAG; stops when the 512 entries are full.
    wire [39:0] tr_now = {pipe_rx_valid, pipe_rx_chanisaligned, pipe_rx_elecidle,
                          pipe_tx_rate, pipe_tx_rcvrdet, pipe_tx_powerdown[1:0], pl_hot_rst, pl_sel_rate,
                          pl_sel_width, trn_lnk_up, ~pl_phy_lnk_up_n, pl_ltssm};
    reg  [39:0] tr_prev = 0;
    reg  [31:0] tr_time = 0;
    reg  [9:0]  twp = 0;           // entries written (512 = full)
    reg         tr_first = 1'b1, tr_we = 1'b0, mode_p = 1'b0;
    reg  [71:0] tr_wd = 0;
    reg  [2:0]  rearm_ps = 0, clear_ps = 0;
    reg         rst_q = 1'b0;
    wire        tr_change = mode_p ? (tr_now != tr_prev) : (tr_now[15:0] != tr_prev[15:0]);
    // counters
    reg  [15:0] n_l0 = 0, n_recovery = 0, n_detect = 0, n_hot_rst = 0, n_cfg_rd = 0, n_cfg_wr = 0;
    reg  [15:0] n_rx_tlp = 0, n_msg = 0, n_pme_to = 0;
    reg  [6:0]  last_cfg_addr = 0;
    reg         last_cfg_wr = 1'b0;
    reg  [31:0] lnk_time = 0, t_since_rst = 0;
    reg         lnk_seen = 1'b0;
    reg  [127:0] first_tlp = 0, last_tlp = 0;
    reg  [7:0]  rcv_found = 0, rcv_done = 0;   // receiver detection result per lane (RXSTATUS = 3 with PHYSTATUS)
    reg  [5:0]  ltssm_q = 0;
    integer k;
    always @(posedge pclk) begin
        rearm_ps <= {rearm_ps[1:0], rearm_t};
        clear_ps <= {clear_ps[1:0], clear_t};
        mode_p   <= c_mode;
        rst_q    <= pcie_rst_n;
        tr_time  <= tr_time + 1'b1;
        tr_we    <= 1'b0;
        if (tr_first || tr_change) begin
            tr_prev <= tr_now; tr_first <= 1'b0;
            if (!twp[9]) begin
                tr_we <= 1'b1; tr_wd <= {tr_now, tr_time}; twp <= twp + 1'b1;
            end
        end
        if ((pcie_rst_n && !rst_q) || (rearm_ps[2] != rearm_ps[1])) begin
            twp <= 0; tr_time <= 0; tr_first <= 1'b1;
        end

        ltssm_q <= pl_ltssm;
        if (pl_ltssm != ltssm_q) begin
            if (pl_ltssm == 6'h16) n_l0 <= n_l0 + 1'b1;
            if (pl_ltssm == 6'h1c) n_recovery <= n_recovery + 1'b1;
            if (pl_ltssm == 6'h00 || (pl_ltssm == 6'h01 && ltssm_q != 6'h00)) n_detect <= n_detect + 1'b1;
            if (pl_ltssm == 6'h21) n_hot_rst <= n_hot_rst + 1'b1;
        end
        if (cfg_trans) begin
            if (cfg_trans_type) n_cfg_wr <= n_cfg_wr + 1'b1; else n_cfg_rd <= n_cfg_rd + 1'b1;
            last_cfg_addr <= cfg_trans_addr; last_cfg_wr <= cfg_trans_type;
        end
        if (cfg_msg) n_msg <= n_msg + 1'b1;
        if (cfg_msg_pme_to) n_pme_to <= n_pme_to + 1'b1;
        if (trn_rsof && trn_rsrc_rdy) begin
            if (n_rx_tlp == 0) first_tlp <= trn_rd;
            last_tlp <= trn_rd; n_rx_tlp <= n_rx_tlp + 1'b1;
        end
        for (k = 0; k < 8; k = k + 1)
            if (pipe_tx_rcvrdet && gt_phystatus[k]) begin
                rcv_done[k] <= 1'b1; rcv_found[k] <= (pipe_rx_status[3*k +: 3] == 3'b011);
            end
        if (!pcie_rst_n) begin t_since_rst <= 0; lnk_seen <= 1'b0; end
        else begin
            t_since_rst <= t_since_rst + 1'b1;
            if (trn_lnk_up && !lnk_seen) begin lnk_seen <= 1'b1; lnk_time <= t_since_rst; end
        end
        if (clear_ps[2] != clear_ps[1]) begin
            n_l0 <= 0; n_recovery <= 0; n_detect <= 0; n_hot_rst <= 0; n_cfg_rd <= 0; n_cfg_wr <= 0;
            n_rx_tlp <= 0; n_msg <= 0; n_pme_to <= 0; first_tlp <= 0; last_tlp <= 0; rcv_done <= 0; rcv_found <= 0;
        end
    end

    // recorder RAM: 512 x 72 (RAMB36 SDP), written on pclk, read on tck at the JTAG read pointer
    RAMB36E1 #(.RAM_MODE("SDP"), .READ_WIDTH_A(72), .WRITE_WIDTH_B(72), .DOA_REG(0), .DOB_REG(0))
        trace_ram (.CLKARDCLK(tck), .CLKBWRCLK(pclk), .ENARDEN(1'b1), .ENBWREN(tr_we),
                   .WEBWE({8{tr_we}}), .WEA(4'd0), .REGCEAREGCE(1'b0), .REGCEB(1'b0),
                   .RSTRAMARSTRAM(1'b0), .RSTRAMB(1'b0), .RSTREGARSTREG(1'b0), .RSTREGB(1'b0),
                   .ADDRARDADDR({1'b1, trp, 6'd0}), .ADDRBWRADDR({1'b1, twp[8:0], 6'd0}),
                   .DIADI(tr_wd[31:0]), .DIBDI(tr_wd[63:32]), .DIPADIP(tr_wd[67:64]), .DIPBDIP(tr_wd[71:68]),
                   .DOADO(trace_rd[31:0]), .DOBDO(trace_rd[63:32]), .DOPADOP(trace_rd[67:64]),
                   .DOPBDOP(trace_rd[71:68]),
                   .CASCADEINA(1'b0), .CASCADEINB(1'b0), .INJECTDBITERR(1'b0), .INJECTSBITERR(1'b0));

    // ------------------------------------------------------------------ frequency counters (per ~0.26 s window)
    reg [23:0] win = 0;
    reg [31:0] windows = 0;
    reg        win_tick = 1'b0;
    always @(posedge sclk) begin
        win <= win + 1'b1; win_tick <= &win;
        if (win_tick) windows <= windows + 1'b1;
    end
    wire [31:0] f_ref, f_pclk, f_uclk;
    freq_count fc_ref  (.clk(refclk_fab), .sclk(sclk), .tick(win_tick), .count(f_ref));
    freq_count fc_pclk (.clk(pclk),       .sclk(sclk), .tick(win_tick), .count(f_pclk));
    freq_count fc_uclk (.clk(userclk),    .sclk(sclk), .tick(win_tick), .count(f_uclk));

    // ------------------------------------------------------------------ LED: on = link up, blinking = no link
    reg [26:0] hb = 0;
    always @(posedge pclk) hb <= hb + 1'b1;
    OBUF led_obuf (.I(trn_lnk_up | hb[26]), .O(led));

    // ------------------------------------------------------------------ status word (JTAG capture)
    // Slow or static values cross into tck through plain 2-flop synchronisers; the host reads twice.
    wire [7:0] elecidle_t, valid_t, aligned_t, phy_t, bytealign_t, txei_t, crl_t;
    sync2 #(8) s_ei (tck, pipe_rx_elecidle, elecidle_t);
    sync2 #(8) s_rv (tck, pipe_rx_valid, valid_t);
    sync2 #(8) s_ca (tck, pipe_rx_chanisaligned, aligned_t);
    sync2 #(8) s_ph (tck, gt_phystatus, phy_t);
    sync2 #(8) s_ba (tck, rxbyteisaligned, bytealign_t);
    sync2 #(8) s_te (tck, pipe_tx_elecidle, txei_t);
    sync2 #(8) s_rl (tck, cpllrefclklost, crl_t);
    wire [63:0] link_t;   // LSB first: see LINK in host/s2.py
    sync2 #(64) s_lk (tck, {6'd0, pipe_tx_rate, pipe_tx_rcvrdet, pipe_tx_powerdown[1:0], trn_tcfg_req, trn_tbuf_av,
                            cfg_neg_width, cfg_cur_speed, cfg_link_state, cfg_pm_state,
                            cfg_err_ur, cfg_err_fatal, cfg_err_nonfatal, cfg_err_cor,
                            cfg_mem_en, cfg_bm_en, cfg_dll_active, cfg_link_training,
                            pl_rx_pm, pl_tx_pm, pl_lane_rev, pl_upcfg_cap, pl_partner_gen2, pl_gen2_cap,
                            pl_init_width, pl_hot_rst, pl_sel_rate, pl_sel_width,
                            phy_gate, pcie_rst_n, user_rst_n, trn_lnk_up, ~pl_phy_lnk_up_n, pl_ltssm}, link_t);
    wire [15:0] ts_t;
    sync2 #(16) s_ts (tck, {ts_err, ts, seen}, ts_t);
    wire [8:0] twp_t;
    wire       twp_t_full;
    sync2 #(10) s_wp (tck, twp, {twp_t_full, twp_t});
    wire [31:0] dbg_t;
    sync2 #(32) s_dbg (tck, {8'd0, pl_dbg_vec, ll2_suspendok, ll2_txidle, pl2_rxei, pl2_l0req, pl2_linkup,
                             ll2_tfc2, ll2_tfc1, ll2_link_status}, dbg_t);
    wire [255:0] n_ev_flat = {16'd0, n_ev};
    assign status = {
        304'd0, n_dllp,                                           // [2047:1728] [1743:1728] = received DLLPs
        last_dllp, first_dllp,                                    // [1727:1600]
        dbg_t,                                                    // [1599:1568]
        trn_up_cycles,                                            // [1567:1536]
        n_ev_flat,                                                // [1535:1280] 15 x 16 (see EV in host/s2.py)
        n_txr, n_txw, n_rxr, n_rxw,                               // [1279:1152]
        6'd0, txr_p, 6'd0, txw_p, 6'd0, rxr_p, 6'd0, rxw_p,       // [1151:1088]
        mg_to, mg_n,                                              // [1087:1056]
        mg_do,                                                    // [1055:1024]
        last_tlp, first_tlp,                                      // [1023:768]
        n_pme_to, n_msg, n_rx_tlp, n_cfg_wr, n_cfg_rd, n_hot_rst, n_detect, n_recovery, n_l0,   // [767:624]
        lnk_time,                                                 // [623:592]
        8'd0, rcv_done, rcv_found, last_cfg_wr, last_cfg_addr,    // [591:560]
        perst_falls, restarts,                                    // [559:528]
        ready_time,                                               // [527:496]
        windows, f_uclk, f_pclk, f_ref,                           // [495:368]
        5'd0, twp_t_full, twp_t, trp,                             // [367:344]
        ts_t,                                                     // [343:328]
        link_t,                                                   // [327:264]
        crl_t, txei_t, bytealign_t, phy_t, aligned_t, valid_t, elecidle_t,   // [263:208]
        phalignd_s, rxrd_s, txrd_s, cplllock_s,                   // [207:176]
        {pll_locked_s, perst_s, pcie_en_s, core_rst_n, 4'd0},     // [175:168]
        err_st, st,                                               // [167:160]
        ctl,                                                      // [159:128]
        64'd0, 32'd0,                                             // [127:32] reserved
        8'd0, 8'd0, 8'h02, 8'hC2                                  // [31:0] version 2, magic C2
    };
endmodule

// two-flop synchroniser
module sync2 #(parameter W = 1) (input wire clk, input wire [W-1:0] d, output reg [W-1:0] q);
    reg [W-1:0] m = 0;
    initial q = 0;
    always @(posedge clk) begin m <= d; q <= m; end
endmodule

// cycles of clk per sclk window: a Gray-coded free-running counter crosses into sclk
module freq_count (input wire clk, input wire sclk, input wire tick, output reg [31:0] count);
    reg [31:0] c = 0, g = 0;
    always @(posedge clk) begin c <= c + 1'b1; g <= c ^ (c >> 1); end
    reg [31:0] g1 = 0, g2 = 0, last = 0;
    initial count = 0;
    wire [31:0] b;
    genvar n;
    generate for (n = 0; n < 32; n = n + 1) begin : g2b
        assign b[n] = ^(g2 >> n);
    end endgenerate
    always @(posedge sclk) begin
        g1 <= g; g2 <= g1;
        if (tick) begin count <= b - last; last <= b; end
    end
endmodule

// 512 x 72 simple dual-port RAM (RAMB36 SDP), separate write and read clocks, read data registered once (tck)
module ram512x72 (input wire wclk, input wire we, input wire [8:0] wa, input wire [71:0] wd,
                  input wire rclk, input wire [8:0] ra, output wire [71:0] rd);
    RAMB36E1 #(.RAM_MODE("SDP"), .READ_WIDTH_A(72), .WRITE_WIDTH_B(72), .DOA_REG(0), .DOB_REG(0))
        ram (.CLKARDCLK(rclk), .CLKBWRCLK(wclk), .ENARDEN(1'b1), .ENBWREN(we),
             .WEBWE({8{we}}), .WEA(4'd0), .REGCEAREGCE(1'b0), .REGCEB(1'b0),
             .RSTRAMARSTRAM(1'b0), .RSTRAMB(1'b0), .RSTREGARSTREG(1'b0), .RSTREGB(1'b0),
             .ADDRARDADDR({1'b1, ra, 6'd0}), .ADDRBWRADDR({1'b1, wa, 6'd0}),
             .DIADI(wd[31:0]), .DIBDI(wd[63:32]), .DIPADIP(wd[67:64]), .DIPBDIP(wd[71:68]),
             .DOADO(rd[31:0]), .DOBDO(rd[63:32]), .DOPADOP(rd[67:64]), .DOPBDOP(rd[71:68]),
             .CASCADEINA(1'b0), .CASCADEINB(1'b0), .INJECTDBITERR(1'b0), .INJECTSBITERR(1'b0));
endmodule
