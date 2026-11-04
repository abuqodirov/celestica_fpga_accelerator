// Passive pin scan for the XC7K480T accelerator (YPCB-00338-1P1 pinout).
// Drives nothing except the BPI flash control pins, which stay idle-high.
// Candidate clocks feed free-running Gray-code counters (a Gray code can be
// sampled from another clock domain at any instant and is off by at most one);
// candidate signals are sampled as levels. Read over JTAG USER1, 168 bits, LSB first:
//   [31:0]    CFGMCLK counter (internal oscillator, reference)
//   [63:32]   AA28 counter          (YPCB: 50 MHz SYS_CLK)
//   [95:64]   AH27/AH28 counter     (YPCB: 200 MHz clock 1)
//   [127:96]  G25/G26 counter       (YPCB: 200 MHz clock 2)
//   [137:128] levels: P30 M30 N30 R28 N24 N25 P25 R26 R27 Y26
//   [167:160] 8'hC3 (design present)
module top (
    output wire       flash_ce_n,
    output wire       flash_oe_n,
    output wire       flash_we_n,
    output wire       flash_adv_n,
    input  wire       clk50,
    input  wire       clk200a_p,
    input  wire       clk200a_n,
    input  wire       clk200b_p,
    input  wire       clk200b_n,
    input  wire [9:0] lvl
);
    assign flash_ce_n  = 1'b1;
    assign flash_oe_n  = 1'b1;
    assign flash_we_n  = 1'b1;
    assign flash_adv_n = 1'b1;

    // ---- clocks under test ----
    wire cfgmclk, clk_cfg, clk50_ibuf, clk_50, clk200a_ibuf, clk_200a, clk200b_ibuf, clk_200b;
    STARTUPE2 startup (
        .CFGCLK(), .CFGMCLK(cfgmclk), .EOS(), .PREQ(),
        .CLK(1'b0), .GSR(1'b0), .GTS(1'b0), .KEYCLEARB(1'b1), .PACK(1'b0),
        .USRCCLKO(1'b0), .USRCCLKTS(1'b1), .USRDONEO(1'b1), .USRDONETS(1'b1)
    );
    BUFG   buf_cfg  (.I(cfgmclk), .O(clk_cfg));
    IBUF   ibuf_50  (.I(clk50), .O(clk50_ibuf));
    BUFG   buf_50   (.I(clk50_ibuf), .O(clk_50));
    IBUFDS ibuf_a   (.I(clk200a_p), .IB(clk200a_n), .O(clk200a_ibuf));
    BUFG   buf_a    (.I(clk200a_ibuf), .O(clk_200a));
    IBUFDS ibuf_b   (.I(clk200b_p), .IB(clk200b_n), .O(clk200b_ibuf));
    BUFG   buf_b    (.I(clk200b_ibuf), .O(clk_200b));

    wire [31:0] g_cfg, g_50, g_a, g_b;
    gray_counter cnt_cfg (.clk(clk_cfg),  .gray(g_cfg));
    gray_counter cnt_50  (.clk(clk_50),   .gray(g_50));
    gray_counter cnt_a   (.clk(clk_200a), .gray(g_a));
    gray_counter cnt_b   (.clk(clk_200b), .gray(g_b));

    // ---- JTAG USER1 ----
    localparam DR_BITS = 168;
    wire tck_raw, tck, tdi, sel, capture, shift;
    reg  [DR_BITS-1:0] sr = {DR_BITS{1'b0}};
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(), .TDO(sr[0])
    );
    BUFG tck_buf (.I(tck_raw), .O(tck));

    // Two-stage synchronisers into the TCK domain.
    reg [137:0] sync1 = 138'd0, sync2 = 138'd0;
    always @(posedge tck) begin
        sync1 <= {lvl, g_b, g_a, g_50, g_cfg};
        sync2 <= sync1;
        if (sel && capture)
            sr <= {8'hC3, 22'd0, sync2};
        else if (sel && shift)
            sr <= {tdi, sr[DR_BITS-1:1]};
    end
endmodule

module gray_counter (
    input  wire        clk,
    output reg  [31:0] gray = 32'd0
);
    reg [31:0] bin = 32'd0;
    always @(posedge clk) begin
        bin  <= bin + 32'd1;
        gray <= bin ^ (bin >> 1);
    end
endmodule
