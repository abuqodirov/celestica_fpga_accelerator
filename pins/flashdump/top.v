// Read-only BPI flash dumper. The FPGA reads 512-word blocks from the flash at
// 50 MHz; the PC collects them over JTAG. WE# is tied high: no write path exists.
// USER2 (32 bits, in):  [24:0] block start word address, [31] go
// USER1 (8256 bits, out): [8191:0] 512 words (word i at [16i+15:16i]),
//                         [8216:8192] block start address, [8224] done, [8239:8232] 8'hF1
module top (
    input  wire        clk50,
    output reg  [25:1] flash_a = 25'd0,
    input  wire [15:0] flash_d,
    output reg         flash_ce_n = 1'b1,
    output reg         flash_oe_n = 1'b1,
    output wire        flash_we_n,
    output reg         flash_adv_n = 1'b1
);
    assign flash_we_n = 1'b1;              // never write

    localparam WORDS = 512, WAIT = 10;     // 10 cycles at 50 MHz = 200 ns per word
    localparam DR1 = WORDS * 16 + 64;

    wire clk50_ibuf, clk;
    IBUF ibuf_50 (.I(clk50), .O(clk50_ibuf));
    BUFG buf_50  (.I(clk50_ibuf), .O(clk));

    // ---- JTAG: USER1 = data out, USER2 = command in (shared TCK) ----
    wire tck_raw, tck, tdi, sel1, sel2, capture, shift, update, tdi2, shift2, update2;
    reg  [DR1-1:0] sr1 = {DR1{1'b0}};
    reg  [31:0]    sr2 = 32'd0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan1 (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel1), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(update), .TDO(sr1[0]));
    // USER2 uses its own SHIFT/UPDATE/TDI (taking them from bscan1 corrupted bits 24-30).
    BSCANE2 #(.JTAG_CHAIN(2)) bscan2 (
        .CAPTURE(), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel2), .SHIFT(shift2),
        .TCK(), .TDI(tdi2), .TMS(), .UPDATE(update2), .TDO(sr2[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));

    reg [24:0] req_addr = 25'd0;
    reg        req_tgl = 1'b0;
    reg        ack_tgl = 1'b0;
    reg [1:0]  ack_sync = 2'b00;
    reg [WORDS*16-1:0] buffer = {WORDS*16{1'b0}};
    reg [24:0] buf_addr = 25'd0;
    wire       done_t = (ack_sync[1] == req_tgl);

    always @(posedge tck) begin
        ack_sync <= {ack_sync[0], ack_tgl};
        if (sel1 && capture)      sr1 <= {8'hF1, 7'd0, done_t, 7'd0, buf_addr, buffer};
        else if (sel1 && shift)   sr1 <= {tdi, sr1[DR1-1:1]};
        if (sel2 && shift2)       sr2 <= {tdi2, sr2[31:1]};
        else if (sel2 && update2 && sr2[31]) begin
            req_addr <= sr2[24:0];
            req_tgl  <= ~req_tgl;
        end
    end

    // ---- flash read engine (50 MHz) ----
    reg [2:0]  req_sync = 3'b000;
    reg        busy = 1'b0, pend = 1'b0;
    reg [9:0]  idx = 10'd0;
    reg [3:0]  wait_cnt = 4'd0;
    reg [15:0] dq_r = 16'd0;
    always @(posedge clk) begin
        req_sync <= {req_sync[1:0], req_tgl};
        dq_r     <= flash_d;
        if (!busy) begin
            flash_ce_n <= 1'b1; flash_oe_n <= 1'b1; flash_adv_n <= 1'b1;
            if (req_sync[2] != req_sync[1]) begin      // new request (req_addr is stable)
                busy     <= 1'b1;
                pend     <= req_sync[1];
                buf_addr <= req_addr;
                flash_a  <= req_addr;
                idx      <= 10'd0;
                wait_cnt <= WAIT;
                flash_ce_n <= 1'b0; flash_oe_n <= 1'b0; flash_adv_n <= 1'b0;
            end
        end else if (wait_cnt != 0) begin
            wait_cnt <= wait_cnt - 4'd1;
        end else begin
            buffer <= {dq_r, buffer[WORDS*16-1:16]};   // word idx ends up at [16*idx +: 16]
            if (idx == WORDS - 1) begin
                busy    <= 1'b0;
                ack_tgl <= pend;
            end else begin
                idx      <= idx + 10'd1;
                flash_a  <= flash_a + 25'd1;
                wait_cnt <= WAIT;
            end
        end
    end
endmodule
