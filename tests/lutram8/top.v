// Shallow LUT-RAM self-test: the shape of LiteDRAM's bank-machine command FIFOs.
//   shape F: 8 x 24, 1 write + 1 async read at a different address  -> RAM32M, ADDR[4:3] tied to 0
//   shape G: 16 x 24, same                                           -> RAM32M, ADDR[4] tied to 0
// Each pass writes all entries with pseudo-random data, then reads them in a different order.
// JTAG USER1 (96 bits, out): [31:0] passes, [63:32] errors, [71:64] first bad addr, [72] shape (0=F,1=G),
// [87:80] first bad bit index, [95:88] 8'hD9.
module top (
    input  wire clk50,
    output wire flash_ce_n, output wire flash_oe_n, output wire flash_we_n, output wire flash_adv_n
);
    assign {flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n} = 4'b1111;
    wire clk50_ibuf, clk;
    IBUF ibuf_50 (.I(clk50), .O(clk50_ibuf));
    BUFG buf_50  (.I(clk50_ibuf), .O(clk));

    reg [23:0] mf [0:7];
    reg [23:0] mg [0:15];
    reg [31:0] lfsr = 32'h1234_5678, lfsr_start = 32'h1234_5678;
    reg [4:0]  idx = 5'd0;                   // 0..15
    reg        phase = 1'b0;                 // 0 = write, 1 = check
    reg [31:0] passes = 32'd0, errors = 32'd0;
    reg [8:0]  first_bad = 9'h1FF;
    reg [7:0]  bad_bit = 8'hFF;
    wire [31:0] next = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
    // write order 0..15; read order is bit-reversed so read and write addresses differ
    wire [3:0] waddr = idx[3:0];
    wire [3:0] raddr = {idx[0], idx[1], idx[2], idx[3]};
    wire [23:0] rdf = mf[raddr[2:0]];
    wire [23:0] rdg = mg[raddr];
    reg  [23:0] expf [0:7];                  // expected values, kept in flip-flops
    reg  [23:0] expg [0:15];
    integer k;

    always @(posedge clk) begin
        if (!phase) begin
            if (waddr < 8) begin mf[waddr[2:0]] <= lfsr[23:0]; expf[waddr[2:0]] <= lfsr[23:0]; end
            mg[waddr] <= next[31:8]; expg[waddr] <= next[31:8];
            lfsr <= next;
            idx <= idx + 5'd1;
            if (idx == 5'd15) begin phase <= 1'b1; idx <= 5'd0; end
        end else begin
            if (raddr < 8 && rdf != expf[raddr[2:0]]) begin
                errors <= errors + 32'd1;
                if (first_bad == 9'h1FF) begin
                    first_bad <= {1'b0, 4'd0, raddr};
                    for (k = 23; k >= 0; k = k - 1) if (rdf[k] != expf[raddr[2:0]][k]) bad_bit <= k;
                end
            end else if (rdg != expg[raddr]) begin
                errors <= errors + 32'd1;
                if (first_bad == 9'h1FF) begin
                    first_bad <= {1'b1, 4'd0, raddr};
                    for (k = 23; k >= 0; k = k - 1) if (rdg[k] != expg[raddr][k]) bad_bit <= k;
                end
            end
            idx <= idx + 5'd1;
            if (idx == 5'd15) begin phase <= 1'b0; idx <= 5'd0; passes <= passes + 32'd1; end
        end
    end

    wire tck_raw, tck, tdi, sel, capture, shift;
    reg  [95:0] sr = 96'd0;
    reg  [95:0] snap1 = 96'd0, snap2 = 96'd0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (.CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel),
        .SHIFT(shift), .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(), .TDO(sr[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));
    always @(posedge tck) begin
        snap1 <= {8'hD9, bad_bit, 7'd0, first_bad, errors, passes};
        snap2 <= snap1;
        if (sel && capture) sr <= snap2;
        else if (sel && shift) sr <= {tdi, sr[95:1]};
    end
endmodule
