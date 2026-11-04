// Bisect test 1: BSCANE2 only, no STARTUPE2, no internal clock.
// USER1, 64 bits: captures {32'hCAFEF00D, capture count}.
module top (
    output wire flash_ce_n, output wire flash_oe_n,
    output wire flash_we_n, output wire flash_adv_n
);
    assign flash_ce_n = 1'b1; assign flash_oe_n = 1'b1;
    assign flash_we_n = 1'b1; assign flash_adv_n = 1'b1;
    wire tck_raw, tck, tdi, sel, capture, shift;
    reg [63:0] sr = 64'd0;
    reg [31:0] count = 32'd0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(), .TDO(sr[0]));
    BUFG tck_buf (.I(tck_raw), .O(tck));
    always @(posedge tck) begin
        if (sel && capture) begin
            sr <= {32'hCAFEF00D, count};
            count <= count + 32'd1;
        end else if (sel && shift)
            sr <= {tdi, sr[63:1]};
    end
endmodule
