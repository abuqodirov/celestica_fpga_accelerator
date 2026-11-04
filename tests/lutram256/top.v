// RAM256X1S self-test (the shape LiteX's L2 cache uses): two 256-deep memories written with
// pseudo-random data and read back, pass after pass, at 50 MHz.
//   shape D: 256 x 8, async read            -> RAM256X1S
//   shape E: 256 x 32, byte write enables, registered read (like wishbone.Cache) -> RAM256X1S + FFs
// JTAG USER1 (96 bits, out): [31:0] passes, [63:32] error count, [71:64] first failing address,
// [72] shape of first failure (0 = D, 1 = E), [95:88] 8'hD8.
module top (
    input  wire clk50,
    output wire flash_ce_n, output wire flash_oe_n, output wire flash_we_n, output wire flash_adv_n
);
    assign {flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n} = 4'b1111;
    wire clk50_ibuf, clk;
    IBUF ibuf_50 (.I(clk50), .O(clk50_ibuf));
    BUFG buf_50  (.I(clk50_ibuf), .O(clk));

    reg [7:0]  md [0:255];
    reg [31:0] me [0:255];
    reg [31:0] lfsr = 32'hACE1_2345, lfsr_start = 32'hACE1_2345;
    reg [7:0]  addr = 8'd0;
    reg        phase = 1'b0;                 // 0 = write, 1 = check
    reg [31:0] passes = 32'd0, errors = 32'd0;
    reg [8:0]  first_bad = 9'h1FF;
    wire [31:0] next = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

    // byte enables vary with the data so partial writes are exercised: each pass first writes
    // ~lfsr fully, then overwrites the enabled bytes with lfsr; expected = merge of the two.
    wire [3:0]  be = lfsr[3:0] | 4'b0001;
    wire [31:0] merged = {be[3] ? lfsr[31:24] : ~lfsr[31:24], be[2] ? lfsr[23:16] : ~lfsr[23:16],
                          be[1] ? lfsr[15:8]  : ~lfsr[15:8],  lfsr[7:0]};
    reg         sub = 1'b0;                  // write phase: 0 = full ~lfsr write, 1 = byte-enabled lfsr write
    reg  [31:0] rde = 32'd0;                 // registered read port of me
    reg  [31:0] exp_e = 32'd0;
    reg  [7:0]  exp_a = 8'd0;
    reg         chk_e = 1'b0;
    wire [7:0]  rdd = md[addr];

    always @(posedge clk) begin
        rde <= me[addr];
        chk_e <= 1'b0;
        if (!phase) begin
            if (!sub) begin
                me[addr] <= ~lfsr;
            end else begin
                if (be[0]) me[addr][7:0]   <= lfsr[7:0];
                if (be[1]) me[addr][15:8]  <= lfsr[15:8];
                if (be[2]) me[addr][23:16] <= lfsr[23:16];
                if (be[3]) me[addr][31:24] <= lfsr[31:24];
                md[addr] <= lfsr[15:8] ^ lfsr[31:24];
            end
            lfsr <= next;
            addr <= addr + 8'd1;
            if (addr == 8'd255) begin
                lfsr <= lfsr_start;
                if (sub) phase <= 1'b1;
                sub <= ~sub;
            end
        end else begin
            if (rdd != (lfsr[15:8] ^ lfsr[31:24])) begin
                errors <= errors + 32'd1;
                if (first_bad == 9'h1FF) first_bad <= {1'b0, addr};
            end
            exp_e <= merged; exp_a <= addr; chk_e <= 1'b1;
            lfsr <= next;
            addr <= addr + 8'd1;
            if (addr == 8'd255) begin
                phase <= 1'b0; passes <= passes + 32'd1;
                lfsr_start <= next; lfsr <= next;  // new data every pass
            end
        end
        if (chk_e && rde != exp_e) begin
            errors <= errors + 32'd1;
            if (first_bad == 9'h1FF) first_bad <= {1'b1, exp_a};
        end
    end

    wire tck_raw, tck, tdi, sel, capture, shift;
    reg  [95:0] sr = 96'd0;
    reg  [95:0] snap1 = 96'd0, snap2 = 96'd0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (.CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel),
        .SHIFT(shift), .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(), .TDO(sr[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));
    always @(posedge tck) begin
        snap1 <= {8'hD8, 15'd0, first_bad, errors, passes};
        snap2 <= snap1;
        if (sel && capture) sr <= snap2;
        else if (sel && shift) sr <= {tdi, sr[95:1]};
    end
endmodule
