// JTAG-attached calculator for the Celestica XC7K480T board. Needs no board
// clock and no board I/O: the fabric runs on the internal configuration
// oscillator (STARTUPE2.CFGMCLK) and the host talks to it through BSCANE2 USER1.
//
// USER1 data register, 112 bits, shifted LSB first:
//   in : [31:0] a, [63:32] b, [67:64] op, [68] go (start op at Update-DR)
//   out: [63:0] result, [95:64] cycles, [96] done, [97] busy,
//        [98] clock heartbeat, [111:104] 8'hA5 (design present)
//
// USER2 data register, 2096 bits: 1024-bit x 1024-bit big-integer multiplier.
//   in : [1023:0] a, [2047:1024] b, [2048] go
//   out: [2047:0] product, [2079:2048] cycles, [2080] done, [2081] busy,
//        [2095:2088] 8'h5A (design present)
module top (
    output wire flash_ce_n,
    output wire flash_oe_n,
    output wire flash_we_n,
    output wire flash_adv_n
);
    // Hold the BPI configuration flash idle so the board can still boot from it.
    assign flash_ce_n  = 1'b1;
    assign flash_oe_n  = 1'b1;
    assign flash_we_n  = 1'b1;
    assign flash_adv_n = 1'b1;

    localparam DR_BITS = 112;

    // ---- compute domain: internal ~65 MHz oscillator ----
    wire cfgmclk, clk;
    STARTUPE2 startup (
        .CFGCLK(), .CFGMCLK(cfgmclk), .EOS(), .PREQ(),
        .CLK(1'b0), .GSR(1'b0), .GTS(1'b0), .KEYCLEARB(1'b1), .PACK(1'b0),
        .USRCCLKO(1'b0), .USRCCLKTS(1'b1), .USRDONEO(1'b1), .USRDONETS(1'b1)
    );
    BUFG clk_buf (.I(cfgmclk), .O(clk));

    // ---- JTAG domain ----
    wire tck_raw, tck, tdi, sel, capture, shift, update;
    reg  [DR_BITS-1:0] sr = {DR_BITS{1'b0}};
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(update), .TDO(sr[0])
    );
    BUFG tck_buf (.I(tck_raw), .O(tck));

    // Command registers, written from JTAG. They stay stable while an op runs
    // because the host waits for done before sending the next command.
    reg [31:0] cmd_a = 32'd0, cmd_b = 32'd0;
    reg [3:0]  cmd_op = 4'd0;
    reg        req_tgl = 1'b0;

    // Compute-domain state
    reg [7:0]  rst_cnt = 8'd0;
    reg [2:0]  req_sync = 3'b000;
    reg        pend_tgl = 1'b0, ack_tgl = 1'b0;
    reg [23:0] heartbeat = 24'd0;
    wire       rst = ~rst_cnt[7];
    wire       start = !rst && (req_sync[2] != req_sync[1]);
    wire       core_busy, core_done;
    wire [63:0] result;
    wire [31:0] cycles;

    // JTAG-domain view of compute status
    reg  [1:0] ack_sync = 2'b00;
    reg  [1:0] hb_sync  = 2'b00;
    wire       done_t = (ack_sync[1] == req_tgl);

    always @(posedge tck) begin
        ack_sync <= {ack_sync[0], ack_tgl};
        hb_sync  <= {hb_sync[0], heartbeat[23]};
        if (sel && capture)
            sr <= {8'hA5, 5'd0, hb_sync[1], ~done_t, done_t, cycles, result};
        else if (sel && shift)
            sr <= {tdi, sr[DR_BITS-1:1]};
        else if (sel && update && sr[68]) begin
            cmd_a   <= sr[31:0];
            cmd_b   <= sr[63:32];
            cmd_op  <= sr[67:64];
            req_tgl <= ~req_tgl;
        end
    end

    always @(posedge clk) begin
        if (rst) rst_cnt <= rst_cnt + 8'd1;
        heartbeat <= heartbeat + 24'd1;
        req_sync  <= {req_sync[1:0], req_tgl};
        if (start)     pend_tgl <= req_sync[1];
        if (core_done) ack_tgl  <= pend_tgl;
    end

    calc_core core (
        .clk(clk), .rst(rst), .start(start), .op(cmd_op), .a(cmd_a), .b(cmd_b),
        .busy(core_busy), .done(core_done), .result(result), .cycles(cycles)
    );

    // ---- big-integer multiplier on USER2 (same TCK, same handshake scheme) ----
    localparam BIG_LIMBS = 32;
    localparam BIG_BITS  = BIG_LIMBS * 32;
    localparam DR2_BITS  = 2 * BIG_BITS + 48;

    wire sel2, capture2, shift2, update2, tdi2;
    reg  [DR2_BITS-1:0] sr2 = {DR2_BITS{1'b0}};
    BSCANE2 #(.JTAG_CHAIN(2)) bscan2 (
        .CAPTURE(capture2), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel2), .SHIFT(shift2),
        .TCK(), .TDI(tdi2), .TMS(), .UPDATE(update2), .TDO(sr2[0])
    );

    reg  [BIG_BITS-1:0] big_a = {BIG_BITS{1'b0}}, big_b = {BIG_BITS{1'b0}};
    reg                 big_req = 1'b0;
    reg  [2:0]          big_req_sync = 3'b000;
    reg                 big_pend = 1'b0, big_ack = 1'b0;
    reg  [1:0]          big_ack_sync = 2'b00;
    wire                big_done_t = (big_ack_sync[1] == big_req);
    wire                big_start = !rst && (big_req_sync[2] != big_req_sync[1]);
    wire                big_busy, big_done;
    wire [2*BIG_BITS-1:0] big_product;
    wire [31:0]         big_cycles;

    always @(posedge tck) begin
        big_ack_sync <= {big_ack_sync[0], big_ack};
        if (sel2 && capture2)
            sr2 <= {8'h5A, 6'd0, ~big_done_t, big_done_t, big_cycles, big_product};
        else if (sel2 && shift2)
            sr2 <= {tdi2, sr2[DR2_BITS-1:1]};
        else if (sel2 && update2 && sr2[2*BIG_BITS]) begin
            big_a   <= sr2[BIG_BITS-1:0];
            big_b   <= sr2[2*BIG_BITS-1:BIG_BITS];
            big_req <= ~big_req;
        end
    end

    always @(posedge clk) begin
        big_req_sync <= {big_req_sync[1:0], big_req};
        if (big_start) big_pend <= big_req_sync[1];
        if (big_done)  big_ack  <= big_pend;
    end

    bigmul #(.LIMBS(BIG_LIMBS)) big (
        .clk(clk), .rst(rst), .start(big_start), .a(big_a), .b(big_b),
        .busy(big_busy), .done(big_done), .product(big_product), .cycles(big_cycles)
    );
endmodule
