// LUT-RAM self-test: three distributed-RAM shapes written with pseudo-random data and
// read back, pass after pass, at 50 MHz. JTAG USER1 (96 bits, out): [31:0] passes,
// [63:32] error count, [79:64] first failing address+shape, [95:88] 8'hD7.
module top (
    input  wire clk50,
    output wire flash_ce_n, output wire flash_oe_n, output wire flash_we_n, output wire flash_adv_n
);
    assign {flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n} = 4'b1111;
    wire clk50_ibuf, clk;
    IBUF ibuf_50 (.I(clk50), .O(clk50_ibuf));
    BUFG buf_50  (.I(clk50_ibuf), .O(clk));

    // shape A: 32 x 32, 1 write + 2 async reads (register-file style -> RAM32M)
    reg [31:0] rf [0:31];
    // shape B: 64 x 8, 1 write + 1 async read (-> RAM64M / RAM64X1D)
    reg [7:0]  m64 [0:63];
    // shape C: 128 x 4, 1 write + 1 async read (-> RAM128X1D)
    reg [3:0]  m128 [0:127];

    reg [31:0] lfsr = 32'hACE1_2345, lfsr_start = 32'hACE1_2345;
    reg [7:0]  addr = 8'd0;
    reg        phase = 1'b0;                 // 0 = write, 1 = check
    reg [31:0] passes = 32'd0, errors = 32'd0;
    reg [15:0] first_bad = 16'hFFFF;
    wire [31:0] next = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

    wire [31:0] rd1 = rf[addr[4:0]];
    wire [31:0] rd2 = rf[~addr[4:0]];        // second port reads a different entry
    wire [7:0]  rdb = m64[addr[5:0]];
    wire [3:0]  rdc = m128[addr[6:0]];
    reg  [31:0] exp2 [0:31];                 // expected values for port 2 (kept in flip-flops)
    integer k;

    always @(posedge clk) begin
        if (!phase) begin
            if (addr < 32) begin rf[addr[4:0]] <= lfsr; exp2[addr[4:0]] <= lfsr; end
            if (addr < 64) m64[addr[5:0]] <= lfsr[15:8];
            m128[addr[6:0]] <= lfsr[27:24];
            lfsr <= next;
            addr <= addr + 8'd1;
            if (addr == 8'd127) begin phase <= 1'b1; addr <= 8'd0; lfsr <= lfsr_start; end
        end else begin
            if ((addr < 32 && (rd1 != lfsr || rd2 != exp2[~addr[4:0]])) ||
                (addr < 64 && rdb != lfsr[15:8]) || rdc != lfsr[27:24]) begin
                errors <= errors + 32'd1;
                if (first_bad == 16'hFFFF) first_bad <= {8'd0, addr};
            end
            lfsr <= next;
            addr <= addr + 8'd1;
            if (addr == 8'd127) begin
                phase <= 1'b0; addr <= 8'd0; passes <= passes + 32'd1;
                lfsr_start <= next; lfsr <= next;  // new data every pass
            end
        end
    end

    wire tck_raw, tck, tdi, sel, capture, shift;
    reg  [95:0] sr = 96'd0;
    reg  [95:0] snap1 = 96'd0, snap2 = 96'd0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (.CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel),
        .SHIFT(shift), .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(), .TDO(sr[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));
    always @(posedge tck) begin
        snap1 <= {8'hD7, 8'd0, first_bad, errors, passes};
        snap2 <= snap1;
        if (sel && capture) sr <= snap2;
        else if (sel && shift) sr <= {tdi, sr[95:1]};
    end
endmodule
