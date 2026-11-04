// Diagnostic: (1) LiteX's exact MMCM setup on the 200 MHz input, with a Gray counter per
// output; (2) a 16 KB block-RAM ROM preloaded from rom.hex through the bitstream.
// JTAG USER1, 208 bits. in: [11:0] ROM word address for the next scan.
// out: [31:0] ROM data, [63:32] clk200 input, [95:64] out0, [127:96] out1, [159:128] out2,
//      [191:160] out3 (Gray counters), [192] MMCM locked, [207:200] 8'hD1.
module top (
    input  wire clk200_p, input wire clk200_n,
    output wire flash_ce_n, output wire flash_oe_n, output wire flash_we_n, output wire flash_adv_n
);
    assign {flash_ce_n, flash_oe_n, flash_we_n, flash_adv_n} = 4'b1111;
    wire clk200_ibuf, clk200, fb, locked;
    wire [3:0] co, cb;
    IBUFDS ibuf (.I(clk200_p), .IB(clk200_n), .O(clk200_ibuf));
    BUFG buf_in (.I(clk200_ibuf), .O(clk200));
    MMCME2_ADV #(.BANDWIDTH("OPTIMIZED"), .CLKFBOUT_MULT_F(6), .CLKIN1_PERIOD(5.0),
        .CLKOUT0_DIVIDE_F(12), .CLKOUT1_DIVIDE(3), .CLKOUT2_DIVIDE(3), .CLKOUT2_PHASE(135.0),
        .CLKOUT3_DIVIDE(6), .DIVCLK_DIVIDE(1), .REF_JITTER1(0.01)
    ) mmcm (.CLKFBIN(fb), .CLKIN1(clk200), .PWRDWN(1'b0), .RST(1'b0), .CLKFBOUT(fb),
        .CLKOUT0(co[0]), .CLKOUT1(co[1]), .CLKOUT2(co[2]), .CLKOUT3(co[3]), .LOCKED(locked));
    genvar i;
    wire [31:0] g [0:4];
    gray_counter gin (.clk(clk200), .gray(g[4]));
    generate for (i = 0; i < 4; i = i + 1) begin : outs
        BUFG b (.I(co[i]), .O(cb[i]));
        gray_counter gc (.clk(cb[i]), .gray(g[i]));
    end endgenerate

    reg [31:0] rom [0:4095];
    initial $readmemh("rom.hex", rom);

    wire tck_raw, tck, tdi, sel, capture, shift, update;
    reg  [207:0] sr = 208'd0;
    reg  [11:0]  rom_addr = 12'd0;
    reg  [31:0]  rom_q = 32'd0;
    reg  [192:32] s1 = 0, s2 = 0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (.CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel),
        .SHIFT(shift), .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(update), .TDO(sr[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));
    always @(posedge tck) begin
        rom_q <= rom[rom_addr];
        s1 <= {locked, g[3], g[2], g[1], g[0], g[4]};
        s2 <= s1;
        if (sel && capture) sr <= {8'hD1, 7'd0, s2, rom_q};
        else if (sel && shift) sr <= {tdi, sr[207:1]};
        else if (sel && update) rom_addr <= sr[11:0];
    end
endmodule

module gray_counter (input wire clk, output reg [31:0] gray = 32'd0);
    reg [31:0] bin = 32'd0;
    always @(posedge clk) begin bin <= bin + 32'd1; gray <= bin ^ (bin >> 1); end
endmodule
