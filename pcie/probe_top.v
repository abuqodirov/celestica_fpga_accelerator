// PCIe toolchain probe -- NOT FOR LOADING ONTO THE CARD.
// 8 GTX lanes + the PCIE_2_1 hard block with the factory design's settings (factory_params.vh),
// wired lane-for-lane like Xilinx's PIPE wrapper, with placeholder reset/clock logic. Used only to
// check that nextpnr-xilinx places and routes it and that the produced bits match the factory design.
`include "factory_params.vh"

module probe_top (
    input  wire       pcie_refclk_p, pcie_refclk_n,   // J8/J7 = MGTREFCLK0_116, 100 MHz
    input  wire [7:0] pcie_rxp, pcie_rxn,
    output wire [7:0] pcie_txp, pcie_txn,
    input  wire       pcie_perst_n,                   // Y26
    output reg        led
);
    // ---- reference clock and PIPE clocks (stand-in for Xilinx pipe_clock) ----
    wire refclk;
    IBUFDS_GTE2 refclk_ibuf (.I(pcie_refclk_p), .IB(pcie_refclk_n), .CEB(1'b0), .O(refclk), .ODIV2());

    wire [7:0] txoutclk;
    wire txoutclk_bufg, clkfb, clk125, clk250, clk500, clk250u, pll_locked;
    BUFG txoutclk_buf (.I(txoutclk[0]), .O(txoutclk_bufg));
    PLLE2_BASE #(.CLKIN1_PERIOD(10.0), .CLKFBOUT_MULT(10), .DIVCLK_DIVIDE(1),
                 .CLKOUT0_DIVIDE(8), .CLKOUT1_DIVIDE(4), .CLKOUT2_DIVIDE(2), .CLKOUT3_DIVIDE(4))
        pipe_pll (.CLKIN1(txoutclk_bufg), .CLKFBIN(clkfb), .CLKFBOUT(clkfb), .RST(!pcie_perst_n), .PWRDWN(1'b0),
                  .CLKOUT0(clk125), .CLKOUT1(clk250), .CLKOUT2(clk500), .CLKOUT3(clk250u), .CLKOUT4(), .CLKOUT5(),
                  .LOCKED(pll_locked));
    wire pclk, userclk, userclk2, dclk;
    BUFG dclk_buf (.I(clk125), .O(dclk));   // DRP clock (factory: DRP in use, DRPCLK not inverted)
    reg  pclk_sel;  // 0 = Gen1 (125 MHz), 1 = Gen2 (250 MHz)
    BUFGMUX pclk_mux (.I0(clk125), .I1(clk250), .S(pclk_sel), .O(pclk));
    BUFG userclk_buf  (.I(clk500),  .O(userclk));
    BUFG userclk2_buf (.I(clk250u), .O(userclk2));

    // ---- placeholder resets ----
    reg [7:0] rst_cnt = 0;
    always @(posedge pclk or negedge pll_locked)
        if (!pll_locked) rst_cnt <= 0; else if (!rst_cnt[7]) rst_cnt <= rst_cnt + 1;
    wire rst_n = rst_cnt[7] & pcie_perst_n;

    // ---- PIPE signals ----
    wire [15:0] tx_data [0:7];  wire [1:0] tx_charisk [0:7];  wire [7:0] tx_elecidle, tx_compliance;
    wire [1:0]  tx_powerdown [0:7];
    wire [15:0] rx_data [0:7];  wire [1:0] rx_charisk [0:7];  wire [7:0] rx_valid, rx_chanisaligned;
    wire [2:0]  rx_status [0:7]; wire [7:0] rx_phystatus, rx_elecidle, rx_polarity;
    wire        tx_deemph, tx_rate, tx_rcvrdet, tx_reset;  wire [2:0] tx_margin;
    always @(posedge pclk) pclk_sel <= tx_rate;
    wire [4:0]  chbond [0:8];
    assign chbond[0] = 5'd0;

    genvar i;
    generate for (i = 0; i < 8; i = i + 1) begin : lane
        wire [63:0] rxdata; wire [7:0] rxcharisk;
        GTXE2_CHANNEL #(`GTXE2_CHANNEL_FACTORY_PARAMS) gtx (
            .GTREFCLK0(refclk), .GTREFCLK1(1'b0), .GTNORTHREFCLK0(1'b0), .GTNORTHREFCLK1(1'b0),
            .GTSOUTHREFCLK0(1'b0), .GTSOUTHREFCLK1(1'b0), .GTGREFCLK(1'b0),
            .CPLLREFCLKSEL(3'b001), .CPLLPD(1'b0), .CPLLRESET(!pll_locked & !pcie_perst_n),
            .CPLLLOCKEN(1'b1), .CPLLLOCKDETCLK(1'b0), .CPLLLOCK(),
            .QPLLCLK(1'b0), .QPLLREFCLK(1'b0),
            .GTXRXP(pcie_rxp[i]), .GTXRXN(pcie_rxn[i]), .GTXTXP(pcie_txp[i]), .GTXTXN(pcie_txn[i]),
            .GTTXRESET(!pcie_perst_n), .GTRXRESET(!pcie_perst_n), .GTRESETSEL(1'b0), .RESETOVRD(1'b0),
            .TXUSERRDY(rst_n), .RXUSERRDY(rst_n),
            .TXUSRCLK(pclk), .TXUSRCLK2(pclk), .RXUSRCLK(pclk), .RXUSRCLK2(pclk),
            .TXSYSCLKSEL(2'b00), .RXSYSCLKSEL(2'b00),
            .TXOUTCLKSEL(i == 0 ? 3'b011 : 3'b000), .TXOUTCLK(txoutclk[i]),
            .RXOUTCLKSEL(3'b000), .RXOUTCLK(),
            .TXDATA({48'd0, tx_data[i]}), .TXCHARISK({6'd0, tx_charisk[i]}),
            .TXCHARDISPMODE({7'd0, tx_compliance[i]}), .TXCHARDISPVAL(8'd0),
            .TX8B10BEN(1'b1), .RX8B10BEN(1'b1),
            .TXELECIDLE(tx_elecidle[i]), .TXPD(tx_powerdown[i]), .RXPD(tx_powerdown[i]),
            .TXDETECTRX(tx_rcvrdet), .TXDEEMPH(tx_deemph), .TXMARGIN(tx_margin), .TXSWING(1'b0),
            .TXRATE({2'b00, tx_rate}), .RXRATE({2'b00, tx_rate}), .TXRATEDONE(), .RXRATEDONE(),
            .RXPOLARITY(rx_polarity[i]),
            .RXDATA(rxdata), .RXCHARISK(rxcharisk), .RXVALID(rx_valid[i]),
            .RXCHANISALIGNED(rx_chanisaligned[i]), .RXSTATUS(rx_status[i]),
            .PHYSTATUS(rx_phystatus[i]), .RXELECIDLE(rx_elecidle[i]),
            .RXCHBONDEN(1'b1), .RXCHBONDMASTER(i == 0), .RXCHBONDSLAVE(i != 0),
            .RXCHBONDLEVEL(3'd7 - i[2:0]), .RXCHBONDI(chbond[i]), .RXCHBONDO(chbond[i + 1]),
            .RXMCOMMAALIGNEN(1'b1), .RXPCOMMAALIGNEN(1'b1), .RXCOMMADETEN(1'b1),
            .RXLPMEN(1'b0), .RXCDRHOLD(1'b0), .RXBUFRESET(1'b0),
            .DRPCLK(dclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(9'd0), .DRPDI(16'd0)
        );
        assign rx_data[i] = rxdata[15:0];
        assign rx_charisk[i] = rxcharisk[1:0];
    end endgenerate

    // ---- QPLL blocks of both quads (instantiated by Xilinx's IP too; QPLL powered down, CPLLs are used).
    // Quad 115 gets its reference clock from quad 116; nextpnr cannot express that, fasm_patch.py adds the bits.
    (* keep, BEL = "GTXE2_COMMON_X0Y5/GTXE2_COMMON" *) GTXE2_COMMON #(`GTXE2_COMMON_FACTORY_PARAMS) qpll116 (
        .GTREFCLK0(refclk), .GTREFCLK1(1'b0), .QPLLPD(1'b1), .QPLLRESET(1'b1), .QPLLLOCKEN(1'b1),
        .QPLLLOCKDETCLK(1'b0), .QPLLREFCLKSEL(3'b001), .QPLLOUTRESET(1'b0), .BGBYPASSB(1'b1),
        .BGMONITORENB(1'b1), .BGPDB(1'b1), .BGRCALOVRD(5'b11111), .RCALENB(1'b1), .PMARSVD(8'd0),
        .DRPCLK(dclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(8'd0), .DRPDI(16'd0));
    (* keep, BEL = "GTXE2_COMMON_X0Y4/GTXE2_COMMON" *) GTXE2_COMMON #(`GTXE2_COMMON_FACTORY_PARAMS) qpll115 (
        .GTREFCLK0(1'b0), .GTREFCLK1(1'b0), .QPLLPD(1'b1), .QPLLRESET(1'b1), .QPLLLOCKEN(1'b1),
        .QPLLLOCKDETCLK(1'b0), .QPLLREFCLKSEL(3'b010), .QPLLOUTRESET(1'b0), .BGBYPASSB(1'b1),
        .BGMONITORENB(1'b1), .BGPDB(1'b1), .BGRCALOVRD(5'b11111), .RCALENB(1'b1), .PMARSVD(8'd0),
        .DRPCLK(dclk), .DRPEN(1'b0), .DRPWE(1'b0), .DRPADDR(8'd0), .DRPDI(16'd0));

    // ---- PCIe hard block ----
    wire [68:0] mim_tx_wdata, mim_tx_rdata;  wire [12:0] mim_tx_waddr, mim_tx_raddr;  wire mim_tx_wen, mim_tx_ren;
    wire [67:0] mim_rx_wdata, mim_rx_rdata;  wire [12:0] mim_rx_waddr, mim_rx_raddr;  wire mim_rx_wen, mim_rx_ren;
    wire [127:0] trn_rd;  wire trn_lnk_up, trn_rsrc_rdy;

    PCIE_2_1 #(`PCIE_2_1_FACTORY_PARAMS) pcie (
        .PIPECLK(pclk), .USERCLK(userclk), .USERCLK2(userclk2), .DRPCLK(1'b0),
        .SYSRSTN(rst_n), .CMRSTN(rst_n), .CMSTICKYRSTN(rst_n), .DLRSTN(rst_n), .TLRSTN(rst_n),
        .FUNCLVLRSTN(rst_n), .PLRSTN(rst_n),
        .CFGVENDID(16'h10ee), .CFGDEVID(16'h7028), .CFGREVID(8'h00),
        .CFGSUBSYSVENDID(16'h10ee), .CFGSUBSYSID(16'h0007),
        .PIPETX0DATA(tx_data[0]), .PIPETX1DATA(tx_data[1]), .PIPETX2DATA(tx_data[2]), .PIPETX3DATA(tx_data[3]),
        .PIPETX4DATA(tx_data[4]), .PIPETX5DATA(tx_data[5]), .PIPETX6DATA(tx_data[6]), .PIPETX7DATA(tx_data[7]),
        .PIPETX0CHARISK(tx_charisk[0]), .PIPETX1CHARISK(tx_charisk[1]), .PIPETX2CHARISK(tx_charisk[2]),
        .PIPETX3CHARISK(tx_charisk[3]), .PIPETX4CHARISK(tx_charisk[4]), .PIPETX5CHARISK(tx_charisk[5]),
        .PIPETX6CHARISK(tx_charisk[6]), .PIPETX7CHARISK(tx_charisk[7]),
        .PIPETX0ELECIDLE(tx_elecidle[0]), .PIPETX1ELECIDLE(tx_elecidle[1]), .PIPETX2ELECIDLE(tx_elecidle[2]),
        .PIPETX3ELECIDLE(tx_elecidle[3]), .PIPETX4ELECIDLE(tx_elecidle[4]), .PIPETX5ELECIDLE(tx_elecidle[5]),
        .PIPETX6ELECIDLE(tx_elecidle[6]), .PIPETX7ELECIDLE(tx_elecidle[7]),
        .PIPETX0COMPLIANCE(tx_compliance[0]), .PIPETX1COMPLIANCE(tx_compliance[1]),
        .PIPETX2COMPLIANCE(tx_compliance[2]), .PIPETX3COMPLIANCE(tx_compliance[3]),
        .PIPETX4COMPLIANCE(tx_compliance[4]), .PIPETX5COMPLIANCE(tx_compliance[5]),
        .PIPETX6COMPLIANCE(tx_compliance[6]), .PIPETX7COMPLIANCE(tx_compliance[7]),
        .PIPETX0POWERDOWN(tx_powerdown[0]), .PIPETX1POWERDOWN(tx_powerdown[1]),
        .PIPETX2POWERDOWN(tx_powerdown[2]), .PIPETX3POWERDOWN(tx_powerdown[3]),
        .PIPETX4POWERDOWN(tx_powerdown[4]), .PIPETX5POWERDOWN(tx_powerdown[5]),
        .PIPETX6POWERDOWN(tx_powerdown[6]), .PIPETX7POWERDOWN(tx_powerdown[7]),
        .PIPETXDEEMPH(tx_deemph), .PIPETXMARGIN(tx_margin), .PIPETXRATE(tx_rate),
        .PIPETXRCVRDET(tx_rcvrdet), .PIPETXRESET(tx_reset),
        .PIPERX0DATA(rx_data[0]), .PIPERX1DATA(rx_data[1]), .PIPERX2DATA(rx_data[2]), .PIPERX3DATA(rx_data[3]),
        .PIPERX4DATA(rx_data[4]), .PIPERX5DATA(rx_data[5]), .PIPERX6DATA(rx_data[6]), .PIPERX7DATA(rx_data[7]),
        .PIPERX0CHARISK(rx_charisk[0]), .PIPERX1CHARISK(rx_charisk[1]), .PIPERX2CHARISK(rx_charisk[2]),
        .PIPERX3CHARISK(rx_charisk[3]), .PIPERX4CHARISK(rx_charisk[4]), .PIPERX5CHARISK(rx_charisk[5]),
        .PIPERX6CHARISK(rx_charisk[6]), .PIPERX7CHARISK(rx_charisk[7]),
        .PIPERX0VALID(rx_valid[0]), .PIPERX1VALID(rx_valid[1]), .PIPERX2VALID(rx_valid[2]),
        .PIPERX3VALID(rx_valid[3]), .PIPERX4VALID(rx_valid[4]), .PIPERX5VALID(rx_valid[5]),
        .PIPERX6VALID(rx_valid[6]), .PIPERX7VALID(rx_valid[7]),
        .PIPERX0CHANISALIGNED(rx_chanisaligned[0]), .PIPERX1CHANISALIGNED(rx_chanisaligned[1]),
        .PIPERX2CHANISALIGNED(rx_chanisaligned[2]), .PIPERX3CHANISALIGNED(rx_chanisaligned[3]),
        .PIPERX4CHANISALIGNED(rx_chanisaligned[4]), .PIPERX5CHANISALIGNED(rx_chanisaligned[5]),
        .PIPERX6CHANISALIGNED(rx_chanisaligned[6]), .PIPERX7CHANISALIGNED(rx_chanisaligned[7]),
        .PIPERX0STATUS(rx_status[0]), .PIPERX1STATUS(rx_status[1]), .PIPERX2STATUS(rx_status[2]),
        .PIPERX3STATUS(rx_status[3]), .PIPERX4STATUS(rx_status[4]), .PIPERX5STATUS(rx_status[5]),
        .PIPERX6STATUS(rx_status[6]), .PIPERX7STATUS(rx_status[7]),
        .PIPERX0PHYSTATUS(rx_phystatus[0]), .PIPERX1PHYSTATUS(rx_phystatus[1]),
        .PIPERX2PHYSTATUS(rx_phystatus[2]), .PIPERX3PHYSTATUS(rx_phystatus[3]),
        .PIPERX4PHYSTATUS(rx_phystatus[4]), .PIPERX5PHYSTATUS(rx_phystatus[5]),
        .PIPERX6PHYSTATUS(rx_phystatus[6]), .PIPERX7PHYSTATUS(rx_phystatus[7]),
        .PIPERX0ELECIDLE(rx_elecidle[0]), .PIPERX1ELECIDLE(rx_elecidle[1]), .PIPERX2ELECIDLE(rx_elecidle[2]),
        .PIPERX3ELECIDLE(rx_elecidle[3]), .PIPERX4ELECIDLE(rx_elecidle[4]), .PIPERX5ELECIDLE(rx_elecidle[5]),
        .PIPERX6ELECIDLE(rx_elecidle[6]), .PIPERX7ELECIDLE(rx_elecidle[7]),
        .PIPERX0POLARITY(rx_polarity[0]), .PIPERX1POLARITY(rx_polarity[1]), .PIPERX2POLARITY(rx_polarity[2]),
        .PIPERX3POLARITY(rx_polarity[3]), .PIPERX4POLARITY(rx_polarity[4]), .PIPERX5POLARITY(rx_polarity[5]),
        .PIPERX6POLARITY(rx_polarity[6]), .PIPERX7POLARITY(rx_polarity[7]),
        .MIMTXWDATA(mim_tx_wdata), .MIMTXWADDR(mim_tx_waddr), .MIMTXWEN(mim_tx_wen),
        .MIMTXRADDR(mim_tx_raddr), .MIMTXREN(mim_tx_ren), .MIMTXRDATA(mim_tx_rdata),
        .MIMRXWDATA(mim_rx_wdata), .MIMRXWADDR(mim_rx_waddr), .MIMRXWEN(mim_rx_wen),
        .MIMRXRADDR(mim_rx_raddr), .MIMRXREN(mim_rx_ren), .MIMRXRDATA(mim_rx_rdata),
        .TRNRD(trn_rd), .TRNRSRCRDY(trn_rsrc_rdy), .TRNRDSTRDY(1'b1), .TRNRNPOK(1'b1), .TRNRNPREQ(1'b1),
        .TRNLNKUP(trn_lnk_up), .TRNTSRCRDY(1'b0), .TRNTD(128'd0), .TRNTSOF(1'b0), .TRNTEOF(1'b0),
        .TRNTREM(2'd0), .TRNTSRCDSC(1'b0), .TRNTSTR(1'b0), .TRNTERRFWD(1'b0), .TRNTECRCGEN(1'b0),
        .TRNTCFGGNT(1'b1), .TRNFCSEL(3'd0), .TRNRFCPRET(1'b0),
        .CFGMGMTRDENN(1'b1), .CFGMGMTWRENN(1'b1), .CFGMGMTBYTEENN(4'hf), .CFGMGMTDI(32'd0),
        .CFGMGMTDWADDR(10'd0), .CFGMGMTWRREADONLYN(1'b1), .CFGMGMTWRRW1CASRWN(1'b1),
        .CFGERRCORN(1'b1), .CFGERRURN(1'b1), .CFGERRECRCN(1'b1), .CFGERRCPLTIMEOUTN(1'b1),
        .CFGERRCPLABORTN(1'b1), .CFGERRCPLUNEXPECTN(1'b1), .CFGERRPOISONEDN(1'b1), .CFGERRPOSTEDN(1'b1),
        .CFGERRLOCKEDN(1'b1), .CFGERRACSN(1'b1), .CFGERRINTERNALCORN(1'b1), .CFGERRINTERNALUNCORN(1'b1),
        .CFGERRMALFORMEDN(1'b1), .CFGERRMCBLOCKEDN(1'b1), .CFGERRNORECOVERYN(1'b1),
        .CFGERRATOMICEGRESSBLOCKEDN(1'b1), .CFGINTERRUPTN(1'b1), .CFGINTERRUPTASSERTN(1'b1),
        .CFGINTERRUPTSTATN(1'b1), .CFGPMWAKEN(1'b1), .CFGPMTURNOFFOKN(1'b1), .CFGTRNPENDINGN(1'b1),
        .CFGPMHALTASPML0SN(1'b1), .CFGPMHALTASPML1N(1'b1), .CFGPMFORCESTATEENN(1'b1), .CFGPMSENDPMETON(1'b1),
        .CFGDSN(64'h0000_0001_0000_0000), .PLDIRECTEDLINKAUTON(1'b0), .PLDIRECTEDLINKCHANGE(2'd0),
        .PLDIRECTEDLINKSPEED(1'b0), .PLDIRECTEDLINKWIDTH(2'd0), .PLUPSTREAMPREFERDEEMPH(1'b1),
        .PLTRANSMITHOTRST(1'b0), .PLDOWNSTREAMDEEMPHSOURCE(1'b0), .PLDIRECTEDLTSSMNEWVLD(1'b0),
        .PLDIRECTEDLTSSMSTALL(1'b0)
    );

    // ---- TX/RX buffers of the hard block (stand-in for Xilinx pcie_bram_7x) ----
    RAMB36E1 #(.RAM_MODE("SDP"), .READ_WIDTH_A(72), .WRITE_WIDTH_B(72), .DOB_REG(1), .DOA_REG(1))
        tx_bram (.CLKARDCLK(userclk), .CLKBWRCLK(userclk), .ENARDEN(mim_tx_ren), .ENBWREN(mim_tx_wen),
                 .WEBWE({8{mim_tx_wen}}), .WEA(4'd0), .REGCEAREGCE(1'b1), .REGCEB(1'b1),
                 .RSTRAMARSTRAM(1'b0), .RSTRAMB(1'b0), .RSTREGARSTREG(1'b0), .RSTREGB(1'b0),
                 .ADDRARDADDR({1'b1, mim_tx_raddr[8:0], 6'd0}), .ADDRBWRADDR({1'b1, mim_tx_waddr[8:0], 6'd0}),
                 .DIADI(mim_tx_wdata[31:0]), .DIBDI(mim_tx_wdata[63:32]), .DIPADIP(mim_tx_wdata[67:64]),
                 .DIPBDIP({3'd0, mim_tx_wdata[68]}),
                 .DOADO(mim_tx_rdata[31:0]), .DOBDO(mim_tx_rdata[63:32]), .DOPADOP(mim_tx_rdata[67:64]),
                 .DOPBDOP(), .CASCADEINA(1'b0), .CASCADEINB(1'b0), .INJECTDBITERR(1'b0), .INJECTSBITERR(1'b0));
    assign mim_tx_rdata[68] = 1'b0;
    RAMB36E1 #(.RAM_MODE("SDP"), .READ_WIDTH_A(72), .WRITE_WIDTH_B(72), .DOB_REG(1), .DOA_REG(1))
        rx_bram (.CLKARDCLK(userclk), .CLKBWRCLK(userclk), .ENARDEN(mim_rx_ren), .ENBWREN(mim_rx_wen),
                 .WEBWE({8{mim_rx_wen}}), .WEA(4'd0), .REGCEAREGCE(1'b1), .REGCEB(1'b1),
                 .RSTRAMARSTRAM(1'b0), .RSTRAMB(1'b0), .RSTREGARSTREG(1'b0), .RSTREGB(1'b0),
                 .ADDRARDADDR({1'b1, mim_rx_raddr[8:0], 6'd0}), .ADDRBWRADDR({1'b1, mim_rx_waddr[8:0], 6'd0}),
                 .DIADI(mim_rx_wdata[31:0]), .DIBDI(mim_rx_wdata[63:32]), .DIPADIP(mim_rx_wdata[67:64]),
                 .DIPBDIP(4'd0),
                 .DOADO(mim_rx_rdata[31:0]), .DOBDO(mim_rx_rdata[63:32]), .DOPADOP(mim_rx_rdata[67:64]),
                 .DOPBDOP(), .CASCADEINA(1'b0), .CASCADEINB(1'b0), .INJECTDBITERR(1'b0), .INJECTSBITERR(1'b0));

    // keep the user side alive
    always @(posedge userclk2) led <= trn_lnk_up ^ trn_rsrc_rdy ^ (^trn_rd);
endmodule
