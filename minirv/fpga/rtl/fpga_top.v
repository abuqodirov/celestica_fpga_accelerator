// Board top for minirv on the Celestica / YPCB-00338-1P1 XC7K480T card.
// Clock: 50 MHz oscillator (AA28). LEDs: P30 (LED3), M30 (LED5), N30 (LED4).
// The PC drives the SoC debug port through JTAG USER1, 184-bit data register:
//   in : [31:0] wdata, [47:32] word address, [51:48] command, [55:52] tag
//        (a nonzero command is issued at Update-DR)
//   out: [31:0] last result, [35:32] its tag, [36] done, [37] halted, [38] running,
//        [41:39] LEDs, [79:48] pc, [111:80] cycles, [143:112] instret, [175:144] a0,
//        [183:176] 8'h5C (design present)
module fpga_top (
    input  wire       clk50,
    output wire [2:0] led,
    output wire       flash_ce_n,
    output wire       flash_oe_n,
    output wire       flash_we_n,
    output wire       flash_adv_n
);
    assign flash_ce_n  = 1'b1;
    assign flash_oe_n  = 1'b1;
    assign flash_we_n  = 1'b1;
    assign flash_adv_n = 1'b1;

    wire clk50_ibuf, clk;
    IBUF ibuf_50 (.I(clk50), .O(clk50_ibuf));
    BUFG buf_50  (.I(clk50_ibuf), .O(clk));

    // ---- SoC (50 MHz domain) ----
    reg         dbg_valid = 1'b0;
    reg  [3:0]  dbg_cmd = 4'd0;
    reg  [13:0] dbg_addr = 14'd0;
    reg  [31:0] dbg_wdata = 32'd0;
    wire        dbg_done;
    wire [31:0] dbg_result, pc, cycles, instret, a0;
    wire [2:0]  leds;
    wire        running, halted;

    minirv_soc soc (
        .clk(clk), .dbg_valid(dbg_valid), .dbg_cmd(dbg_cmd), .dbg_addr(dbg_addr),
        .dbg_wdata(dbg_wdata), .dbg_done(dbg_done), .dbg_result(dbg_result),
        .leds(leds), .running(running), .halted(halted), .pc(pc),
        .cycles(cycles), .instret(instret), .a0(a0)
    );
    assign led = leds;

    // ---- JTAG USER1 (TCK domain) ----
    localparam DR = 184;
    wire tck_raw, tck, tdi, sel, capture, shift, update;
    reg  [DR-1:0] sr = {DR{1'b0}};
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(update), .TDO(sr[0])
    );
    BUFG tck_buf (.I(tck_raw), .O(tck));

    reg  [31:0] cmd_wdata = 32'd0;
    reg  [15:0] cmd_addr = 16'd0;
    reg  [3:0]  cmd_op = 4'd0, cmd_tag = 4'd0;
    reg         req_tgl = 1'b0;
    reg         ack_tgl = 1'b0;
    reg  [1:0]  ack_sync = 2'b00;
    reg  [31:0] res = 32'd0;
    reg  [3:0]  res_tag = 4'd0;
    reg  [2:0]  st_sync1 = 3'd0, st_sync2 = 3'd0;      // {running, halted} + spare
    wire        done_t = (ack_sync[1] == req_tgl);

    always @(posedge tck) begin
        ack_sync <= {ack_sync[0], ack_tgl};
        st_sync1 <= {1'b0, running, halted};
        st_sync2 <= st_sync1;
        if (sel && capture)
            sr <= {8'h5C, a0, instret, cycles, pc, 6'd0, leds, st_sync2[1], st_sync2[0], done_t, res_tag, res};
        else if (sel && shift)
            sr <= {tdi, sr[DR-1:1]};
        else if (sel && update && sr[51:48] != 4'd0) begin
            cmd_wdata <= sr[31:0];
            cmd_addr  <= sr[47:32];
            cmd_op    <= sr[51:48];
            cmd_tag   <= sr[55:52];
            req_tgl   <= ~req_tgl;
        end
    end

    // ---- command handshake into the 50 MHz domain ----
    reg [2:0] req_sync = 3'b000;
    reg       pend_tgl = 1'b0, busy = 1'b0;
    always @(posedge clk) begin
        req_sync  <= {req_sync[1:0], req_tgl};
        dbg_valid <= 1'b0;
        if (!busy && req_sync[2] != req_sync[1]) begin     // cmd_* are stable by now
            dbg_valid <= 1'b1;
            dbg_cmd   <= cmd_op;
            dbg_addr  <= cmd_addr[13:0];
            dbg_wdata <= cmd_wdata;
            pend_tgl  <= req_sync[1];
            busy      <= 1'b1;
        end
        if (busy && dbg_done) begin
            res     <= dbg_result;
            res_tag <= cmd_tag;
            ack_tgl <= pend_tgl;
            busy    <= 1'b0;
        end
    end
endmodule
