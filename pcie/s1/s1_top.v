// PCIe stage 1: the card talks to itself.
//
// The 8 GTX lanes of the PCIe slot with the factory design's settings (../factory_params.vh, bit-identical to the
// flash), every transceiver input tied the way the factory design ties it (factory_ties.txt) or driven by the
// test logic below. The PCIe hard block is NOT instantiated, so no link can train with the PC. By default the
// lanes run in near-end PMA loopback with the built-in PRBS-7 generator/checker and the transmitters held in
// electrical idle. Everything is controlled and read over JTAG (BSCANE2 USER1, host/s1.py).
//
// Clocks: CFGMCLK (~63.6 MHz, sclk) runs the reset sequencer; lane 0 TXOUTCLK = the 100 MHz reference clock
// (TXOUTCLKSEL 011) feeds a PLL for pclk (125 MHz at 2.5 GT/s, 250 MHz at 5 GT/s, BUFGMUX) and dclk (125 MHz);
// oobclk = dclk / 2 feeds CLKRSVD[0] (electrical-idle detector clock, PCS_RSVD_ATTR[3] = 1 in the factory).
`include "factory_params.vh"

module s1_top (
    input  wire       pcie_refclk_p, pcie_refclk_n,   // J8/J7 = MGTREFCLK0_116
    input  wire [7:0] pcie_rxp, pcie_rxn,
    output wire [7:0] pcie_txp, pcie_txn,
    input  wire       pcie_perst_n,                   // Y26, read only
    output wire       led,                            // P30 (LED3): pclk heartbeat
    output wire       flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n
);
    assign {flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n} = 4'b1111;   // keep the BPI flash idle

    localparam DR_BITS = 512;

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
    reg  pclk_sel = 1'b0;   // 0 = 125 MHz (2.5 GT/s), 1 = 250 MHz (5 GT/s)
    wire pclk, dclk;
    BUFGMUX pclk_mux (.I0(clk125), .I1(clk250), .S(pclk_sel), .O(pclk));
    BUFG dclk_buf (.I(clk125), .O(dclk));
    reg oobclk = 1'b0;
    always @(posedge dclk) oobclk <= ~oobclk;

    // ------------------------------------------------------------------ JTAG register
    wire tck_raw, tck, tdi, sel, capture, shift, update;
    reg  [DR_BITS-1:0] sr = 0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(update), .TDO(sr[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));

    // control word (see host/s1.py): static bits are synchronised where used, pulses are toggles
    reg  [31:0] ctl = 32'h0000_3250;   // rate 0, loopback 010, PRBS-7, TX idle, manual sync, LPM
    reg         restart_t = 1'b0, clear_t = 1'b0;
    wire        c_rate     = ctl[2];   // the other fields are used in the pclk domain (ctl_p)
    wire [DR_BITS-1:0] status;
    always @(posedge tck)
        if (sel && capture) sr <= status;
        else if (sel && shift) sr <= {tdi, sr[DR_BITS-1:1]};
        else if (sel && update && sr[0]) begin
            ctl <= sr[31:0];
            if (sr[1])  restart_t <= ~restart_t;
            if (sr[10]) clear_t   <= ~clear_t;
        end

    // ------------------------------------------------------------------ transceiver signals
    wire [7:0] cplllock, txresetdone, rxresetdone, txdlysresetdone, txphinitdone, txphaligndone;
    wire [7:0] txratedone, rxratedone, rxelecidle, rxbyteisaligned, phystatus, rxvalid, rxprbserr;
    wire [7:0] cpllrefclklost;
    wire [15:0] rxdata [0:7];
    wire [1:0]  rxcharisk [0:7];
    reg  [7:0] txdlysreset = 0, txphinit = 0, txphalign = 0, txdlyen = 0;
    reg        cpllpd = 1'b1, cpllreset = 1'b0, gtreset = 1'b1, userrdy = 1'b0;
    reg        gt_rate = 1'b0;          // pclk domain
    reg  [2:0] p_prbs = 0, p_loopback = 3'b010;
    reg        p_elecidle = 1'b1, p_forceerr = 1'b0, p_manual = 1'b1, p_lpm = 1'b1, p_datamode = 1'b0;
    wire [15:0] txdata   = p_datamode ? 16'hB5BC : 16'h0000;   // D21.5 K28.5
    wire [1:0]  txcharisk = p_datamode ? 2'b01 : 2'b00;

    genvar i;
    generate for (i = 0; i < 8; i = i + 1) begin : lane
        wire [63:0] rxd; wire [7:0] rxk;
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
            // TX phase alignment (TXBUF_EN = FALSE)
            .TXPHALIGNEN(p_manual), .TXDLYBYPASS(1'b0), .TXDLYSRESET(txdlysreset[i]),
            .TXPHINIT(txphinit[i]), .TXPHALIGN(txphalign[i]), .TXDLYEN(txdlyen[i]),
            .TXPHDLYRESET(1'b0), .TXDLYHOLD(1'b0), .TXDLYUPDOWN(1'b0), .TXDLYOVRDEN(1'b0), .TXPHOVRDEN(1'b0),
            .TXPHDLYPD(1'b0), .TXDLYSRESETDONE(txdlysresetdone[i]), .TXPHINITDONE(txphinitdone[i]),
            .TXPHALIGNDONE(txphaligndone[i]),
            // RX buffer is used: RX phase alignment bypassed
            .RXDLYBYPASS(1'b1), .RXPHALIGNEN(1'b0), .RXDLYSRESET(1'b0), .RXPHALIGN(1'b0), .RXDLYEN(1'b0),
            .RXPHDLYRESET(1'b0), .RXDLYOVRDEN(1'b0), .RXPHOVRDEN(1'b0), .RXPHDLYPD(1'b0), .RXDDIEN(1'b0),
            // TX data path
            .TXDATA({48'd0, txdata}), .TXCHARISK({6'd0, txcharisk}), .TXCHARDISPMODE(8'd0),
            .TXCHARDISPVAL(8'd0), .TX8B10BEN(1'b1), .TX8B10BBYPASS(8'd0), .TXHEADER(3'd0), .TXSEQUENCE(7'd0),
            .TXSTARTSEQ(1'b0), .TXPOLARITY(1'b0), .TXINHIBIT(1'b0),
            .TXPRBSSEL(p_prbs), .TXPRBSFORCEERR(p_forceerr),
            // TX driver (PIPE mode: TXDEEMPH/TXMARGIN/TXSWING; cursors are unused at Gen1/2)
            .TXELECIDLE(p_elecidle), .TXPD(2'b00), .TXDETECTRX(1'b0), .TXDEEMPH(1'b1), .TXMARGIN(3'b000),
            .TXSWING(1'b0), .TXDIFFCTRL(4'b1100), .TXBUFDIFFCTRL(3'b100), .TXMAINCURSOR(7'd0),
            .TXPOSTCURSOR(5'd0), .TXPRECURSOR(5'd0), .TXPOSTCURSORINV(1'b0), .TXPRECURSORINV(1'b0),
            .TXDIFFPD(1'b0), .TXPISOPD(1'b0), .TXPDELECIDLEMODE(1'b0),
            .TXQPIBIASEN(1'b0), .TXQPISTRONGPDOWN(1'b0), .TXQPIWEAKPUP(1'b0),
            .TXCOMINIT(1'b0), .TXCOMSAS(1'b0), .TXCOMWAKE(1'b0),
            .TXRATE({2'b00, gt_rate}), .TXRATEDONE(txratedone[i]),
            // RX data path
            .RXDATA(rxd), .RXCHARISK(rxk), .RX8B10BEN(1'b1), .RXPOLARITY(1'b0), .RXPRBSSEL(p_prbs),
            .RXPRBSERR(rxprbserr[i]), .RXCOMMADETEN(1'b1), .RXMCOMMAALIGNEN(1'b1), .RXPCOMMAALIGNEN(1'b1),
            .RXSLIDE(1'b0), .RXGEARBOXSLIP(1'b0), .RXBYTEISALIGNED(rxbyteisaligned[i]),
            .RXCHBONDEN(1'b0), .RXCHBONDMASTER(1'b0), .RXCHBONDSLAVE(1'b0),
            .RXCHBONDLEVEL(i == 0 ? 3'b001 : 3'b000), .RXCHBONDI(5'd0), .RXCHBONDO(),
            .RXVALID(rxvalid[i]), .RXSTATUS(), .PHYSTATUS(phystatus[i]), .RXELECIDLE(rxelecidle[i]),
            .RXELECIDLEMODE(2'b00), .RXPD(2'b00), .RXRATE({2'b00, gt_rate}), .RXRATEDONE(rxratedone[i]),
            .LOOPBACK(p_loopback), .SETERRSTATUS(1'b0), .RXQPIEN(1'b0),
            // RX equaliser: LPM (factory drives RXLPMEN at run time), DFE overrides as in the factory
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
            .DRPCLK(dclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(9'd0), .DRPDI(16'd0), .DRPDO(), .DRPRDY(),
            .GTRSVD(16'd0), .PCSRSVDIN(16'd0), .PCSRSVDIN2(5'd0), .PMARSVDIN(5'd0), .PMARSVDIN2(5'd0),
            .TSTIN(20'hfffff)
        );
        assign rxdata[i] = rxd[15:0];
        assign rxcharisk[i] = rxk[1:0];
    end endgenerate

    // QPLL blocks of both quads: powered down (the lanes use their CPLLs), band gap and RCAL on.
    // Quad 115 gets the reference clock from quad 116; nextpnr cannot express that, ../fasm_patch.py adds the bits.
    (* keep, BEL = "GTXE2_COMMON_X0Y5/GTXE2_COMMON" *) GTXE2_COMMON #(`GTXE2_COMMON_FACTORY_PARAMS) qpll116 (
        .GTREFCLK0(refclk), .GTREFCLK1(1'b0), .GTNORTHREFCLK0(1'b0), .GTNORTHREFCLK1(1'b0),
        .GTSOUTHREFCLK0(1'b0), .GTSOUTHREFCLK1(1'b0), .GTGREFCLK(1'b0),
        .QPLLPD(1'b1), .QPLLRESET(1'b1), .QPLLLOCKEN(1'b1), .QPLLLOCKDETCLK(1'b1), .QPLLREFCLKSEL(3'b001),
        .QPLLOUTRESET(1'b0), .BGBYPASSB(1'b1), .BGMONITORENB(1'b1), .BGPDB(1'b1), .BGRCALOVRD(5'b11111),
        .RCALENB(1'b1), .PMARSVD(8'd0), .QPLLRSVD1(16'd0), .QPLLRSVD2(5'b11111),
        .DRPCLK(dclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(8'd0), .DRPDI(16'd0));
    (* keep, BEL = "GTXE2_COMMON_X0Y4/GTXE2_COMMON" *) GTXE2_COMMON #(`GTXE2_COMMON_FACTORY_PARAMS) qpll115 (
        .GTREFCLK0(1'b0), .GTREFCLK1(1'b0), .GTNORTHREFCLK0(1'b0), .GTNORTHREFCLK1(1'b0),
        .GTSOUTHREFCLK0(1'b0), .GTSOUTHREFCLK1(1'b0), .GTGREFCLK(1'b0),
        .QPLLPD(1'b1), .QPLLRESET(1'b1), .QPLLLOCKEN(1'b1), .QPLLLOCKDETCLK(1'b1), .QPLLREFCLKSEL(3'b010),
        .QPLLOUTRESET(1'b0), .BGBYPASSB(1'b1), .BGMONITORENB(1'b1), .BGPDB(1'b1), .BGRCALOVRD(5'b11111),
        .RCALENB(1'b1), .PMARSVD(8'd0), .QPLLRSVD1(16'd0), .QPLLRSVD2(5'b11111),
        .DRPCLK(dclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(8'd0), .DRPDI(16'd0));

    // ------------------------------------------------------------------ sclk: reset / rate sequencer
    localparam S_START = 0, S_PDREL = 1, S_CPLLRST = 2, S_LOCK = 3, S_GTRST = 4, S_SYNC = 5, S_SYNCW = 6,
               S_READY = 7, S_RPCLK = 8, S_RSEL = 9, S_RDONE = 10, S_RRST = 11, S_ERROR = 15;
    reg  [3:0]  st = S_START, err_st = 0;
    reg  [21:0] tmr = 0;
    reg  [31:0] ready_time = 0, run_time = 0;
    reg  [15:0] restarts = 0, rate_changes = 0;
    reg         cur_rate = 1'b0, sync_req = 1'b0;
    reg  [2:0]  restart_s = 0;
    reg  [1:0]  rate_s = 0;
    wire [7:0]  cplllock_s, txrd_s, rxrd_s, txratedone_st_s, rxratedone_st_s;
    wire        pll_locked_s, sync_ack_s, perst_s;
    reg  [7:0]  txratedone_st = 0, rxratedone_st = 0;   // pclk domain, below
    sync2 #(8) s_cl (sclk, cplllock, cplllock_s);
    sync2 #(8) s_tr (sclk, txresetdone, txrd_s);
    sync2 #(8) s_rr (sclk, rxresetdone, rxrd_s);
    sync2 #(8) s_ts (sclk, txratedone_st, txratedone_st_s);
    sync2 #(8) s_rs (sclk, rxratedone_st, rxratedone_st_s);
    sync2 #(1) s_pl (sclk, pll_locked, pll_locked_s);
    reg sync_ack = 1'b0;   // pclk domain, below
    sync2 #(1) s_sa (sclk, sync_ack, sync_ack_s);
    sync2 #(1) s_pe (sclk, pcie_perst_n, perst_s);

    wire all_lock = &cplllock_s && pll_locked_s, all_rd = &txrd_s && &rxrd_s;
    always @(posedge sclk) begin
        restart_s <= {restart_s[1:0], restart_t};
        rate_s    <= {rate_s[0], c_rate};
        tmr       <= tmr + 1'b1;
        run_time  <= run_time + 1'b1;
        case (st)
        S_START:   begin cpllpd <= 1; cpllreset <= 0; gtreset <= 1; userrdy <= 0; pll_rst <= 1;
                         pclk_sel <= 0; cur_rate <= 0;
                         if (tmr[16]) begin st <= S_PDREL; tmr <= 0; end end              // ~1 ms
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
        S_READY:   if (rate_s[1] != cur_rate) begin st <= S_RPCLK; tmr <= 0; end
        S_RPCLK:   begin pclk_sel <= rate_s[1]; if (tmr[10]) begin st <= S_RSEL; tmr <= 0; end end
        S_RSEL:    if (tmr[7]) begin st <= S_RDONE; tmr <= 0; end      // pclk side applies pclk_sel as the rate
        S_RDONE:   if (&txratedone_st_s && &rxratedone_st_s) begin st <= S_RRST; tmr <= 0; end
                   else if (tmr[21]) begin err_st <= st; st <= S_ERROR; end
        S_RRST:    if (all_rd) begin cur_rate <= pclk_sel; rate_changes <= rate_changes + 1'b1; st <= S_SYNC; end
                   else if (tmr[21]) begin err_st <= st; st <= S_ERROR; end
        default:   ;
        endcase
        if (restart_s[2] != restart_s[1]) begin
            st <= S_START; tmr <= 0; err_st <= 0; run_time <= 0; ready_time <= 0; restarts <= restarts + 1'b1;
        end
    end

    // ------------------------------------------------------------------ pclk: rate, TX phase alignment, checkers
    reg [1:0] prate_s = 0, ready_ps = 0;
    reg [2:0] clear_ps = 0;
    reg [15:0] ctl_p = 16'h3250;
    always @(posedge pclk) begin
        prate_s  <= {prate_s[0], pclk_sel};
        ready_ps <= {ready_ps[0], st == S_READY};
        clear_ps <= {clear_ps[1:0], clear_t};
        ctl_p <= ctl[15:0];
        p_prbs <= ctl_p[8:6]; p_loopback <= ctl_p[5:3]; p_elecidle <= ctl_p[9]; p_forceerr <= ctl_p[11];
        p_manual <= ctl_p[12]; p_lpm <= ctl_p[13]; p_datamode <= ctl_p[14];
        if (gt_rate != prate_s[1]) begin   // the rate follows the clock select, after the clock has switched
            gt_rate <= prate_s[1]; txratedone_st <= 0; rxratedone_st <= 0;
        end else begin
            txratedone_st <= txratedone_st | txratedone;
            rxratedone_st <= rxratedone_st | rxratedone;
        end
    end

    // TX phase alignment (UG476 TX buffer bypass). Manual mode = multi-lane, lane 0 master, like the factory
    // design (TXPHALIGNEN = 1); auto mode = every lane on its own (TXPHALIGNEN = 0). The TXDLYSRESET/TXPHINIT/
    // TXPHALIGN/TXDLYEN inputs and the *DONE outputs are asynchronous, so this runs on the fixed 125 MHz dclk.
    localparam T_IDLE = 0, T_DLYSRST = 1, T_MINIT = 2, T_MALIGN = 3, T_MDLYEN = 4, T_SINIT = 5, T_SALIGN = 6,
               T_MDLYEN2 = 7, T_DONE = 8, T_AUTO = 9, T_ERR = 15;
    reg  [3:0] ts = T_IDLE, ts_err = 0;
    reg  [7:0] seen = 0;
    reg  [15:0] rises = 0;   // rising edges of TXPHALIGNDONE per lane (auto mode), 2 bits each
    reg         req_cur = 1'b0;
    reg  [16:0] ttmr = 0;
    wire [7:0] dlysrd_s, phinitd_s, phalignd_s;
    reg  [7:0] phinitd_r = 0, phalignd_r = 0, init_rise = 0, align_rise = 0;
    wire [1:0] sreq_d;
    wire       d_manual;
    sync2 #(8) s_dr (dclk, txdlysresetdone, dlysrd_s);
    sync2 #(8) s_pi (dclk, txphinitdone, phinitd_s);
    sync2 #(8) s_pa (dclk, txphaligndone, phalignd_s);
    sync2 #(1) s_sq (dclk, sync_req, sreq_d[0]);
    sync2 #(1) s_mm (dclk, ctl[12], d_manual);
    integer k;
    always @(posedge dclk) begin
        phinitd_r <= phinitd_s; phalignd_r <= phalignd_s;
        init_rise <= phinitd_s & ~phinitd_r; align_rise <= phalignd_s & ~phalignd_r;
        ttmr <= ttmr + 1'b1;
        case (ts)   // per-lane steps: a lane's request drops once its done is seen; next state when all are seen
        T_IDLE, T_DONE, T_ERR: ;
        T_DLYSRST: begin
            seen <= seen | dlysrd_s; txdlysreset <= ~(seen | dlysrd_s);
            if (&seen) begin
                txdlysreset <= 0; seen <= 0; ttmr <= 0;
                rises <= 0;
                ts <= d_manual ? T_MINIT : T_AUTO;
            end
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
        T_AUTO: begin
            for (k = 0; k < 8; k = k + 1) begin
                if (align_rise[k] && rises[2*k +: 2] != 2'd2) rises[2*k +: 2] <= rises[2*k +: 2] + 1'b1;
                seen[k] <= (rises[2*k +: 2] == 2'd2);
            end
            if (&seen) ts <= T_DONE;
        end
        default: ts <= T_ERR;
        endcase
        if (ts != T_IDLE && ts != T_DONE && ts != T_ERR && ttmr[16]) begin   // ~0.5 ms
            ts_err <= ts; ts <= T_ERR; txdlysreset <= 0; txphinit <= 0; txphalign <= 0; txdlyen <= 0;
        end
        if (ts == T_DONE || ts == T_ERR) sync_ack <= req_cur;
        if (sreq_d[0] != req_cur) begin   // new request (from the sequencer)
            req_cur <= sreq_d[0]; ts <= T_DLYSRST; seen <= 0; ttmr <= 0; ts_err <= 0;
            txdlysreset <= 0; txphinit <= 0; txphalign <= 0; txdlyen <= 0;
        end
    end

    // error counters: PRBS errors, or (data mode) words that are not D21.5 K28.5 in either byte order
    wire [127:0] errs;
    genvar j;
    generate for (j = 0; j < 8; j = j + 1) begin : chk
        wire bad_word = !((rxdata[j] == 16'hB5BC && rxcharisk[j] == 2'b01) ||
                          (rxdata[j] == 16'hBCB5 && rxcharisk[j] == 2'b10));
        // registered per lane (the lanes sit far apart, so each gets its own copy of the mode and enable bits)
        reg dm = 0, en = 0, clr = 0, err = 0;
        reg [15:0] e = 0;
        always @(posedge pclk) begin
            dm <= p_datamode; en <= ready_ps[1]; clr <= clear_ps[2] != clear_ps[1];
            err <= en && (dm ? bad_word : rxprbserr[j]);
            if (clr) e <= 0;
            else if (err && e != 16'hffff) e <= e + 1'b1;
        end
        assign errs[16*j +: 16] = e;
    end endgenerate

    // ------------------------------------------------------------------ frequency counters (per ~0.26 s window)
    reg [23:0] win = 0;
    reg [31:0] windows = 0;
    reg        win_tick = 1'b0;
    always @(posedge sclk) begin
        win <= win + 1'b1; win_tick <= &win;
        if (win_tick) windows <= windows + 1'b1;
    end
    wire [31:0] f_ref, f_pclk, f_dclk;
    freq_count fc_ref  (.clk(refclk_fab), .sclk(sclk), .tick(win_tick), .count(f_ref));
    freq_count fc_pclk (.clk(pclk),       .sclk(sclk), .tick(win_tick), .count(f_pclk));
    freq_count fc_dclk (.clk(dclk),       .sclk(sclk), .tick(win_tick), .count(f_dclk));

    // ------------------------------------------------------------------ heartbeat LED
    reg [26:0] hb = 0;
    always @(posedge pclk) hb <= hb + 1'b1;
    OBUF led_obuf (.I(hb[26]), .O(led));

    // ------------------------------------------------------------------ status word (JTAG capture)
    wire [7:0] elecidle_t, aligned_t, phy_t, valid_t, crl_t;
    sync2 #(8) s_ei (tck, rxelecidle, elecidle_t);
    sync2 #(8) s_ba (tck, rxbyteisaligned, aligned_t);
    sync2 #(8) s_ph (tck, phystatus, phy_t);
    sync2 #(8) s_rv (tck, rxvalid, valid_t);
    sync2 #(8) s_rl (tck, cpllrefclklost, crl_t);
    assign status = {
        rate_changes, restarts,                                   // [511:480]
        ready_time,                                               // [479:448]
        ctl,                                                      // [447:416]
        errs,                                                     // [415:288] lane 0 lowest
        windows, f_dclk, f_pclk, f_ref,                           // [287:160]
        crl_t, seen, ts_err, ts,                                  // [159:136] seen = txsync lane mask
        {pll_locked_s, pclk_sel, cur_rate, perst_s, p_manual, gt_rate, cpllpd, gtreset},   // [135:128]
        valid_t, phy_t, aligned_t, elecidle_t,                    // [127:96]
        rxratedone_st_s, txratedone_st_s, phalignd_s, phinitd_s, dlysrd_s,   // [95:56]
        rxrd_s, txrd_s, cplllock_s,                               // [55:32]
        4'd0, err_st, 4'd0, st,                                   // [31:16]
        8'h01, 8'hC1                                              // [15:0] version, magic
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
