// LED blink test for the XC7K480T accelerator (YPCB-00338-1P1 pinout).
// Clock: 50 MHz oscillator on AA28. LEDs (YPCB): P30, M30, N30, driven at 4 mA.
// Auto mode: P30 slow (~2.7 s cycle), M30 medium (~0.67 s), N30 fast (~6 Hz).
// JTAG USER1, 16 bits: in [2:0] manual LED values, [3] manual mode;
//                      out [2:0] LED outputs, [3] manual mode, [15:8] 8'hB1.
module top (
    output wire       flash_ce_n,
    output wire       flash_oe_n,
    output wire       flash_we_n,
    output wire       flash_adv_n,
    input  wire       clk50,
    output wire [2:0] led
);
    assign flash_ce_n  = 1'b1;
    assign flash_oe_n  = 1'b1;
    assign flash_we_n  = 1'b1;
    assign flash_adv_n = 1'b1;

    wire clk50_ibuf, clk;
    IBUF ibuf_50 (.I(clk50), .O(clk50_ibuf));
    BUFG buf_50  (.I(clk50_ibuf), .O(clk));

    // ---- JTAG control (TCK domain) ----
    wire tck_raw, tck, tdi, sel, capture, shift, update;
    reg  [15:0] sr = 16'd0;
    reg  [3:0]  ctrl = 4'd0;            // {manual, led[2:0]}
    reg  [2:0]  led_r = 3'd0;
    BSCANE2 #(.JTAG_CHAIN(1)) bscan (
        .CAPTURE(capture), .DRCK(), .RESET(), .RUNTEST(), .SEL(sel), .SHIFT(shift),
        .TCK(tck_raw), .TDI(tdi), .TMS(), .UPDATE(update), .TDO(sr[0])
    );
    BUFG tck_buf (.I(tck_raw), .O(tck));
    always @(posedge tck) begin
        if (sel && capture)      sr <= {8'hB1, 4'd0, ctrl[3], led_r};
        else if (sel && shift)   sr <= {tdi, sr[15:1]};
        else if (sel && update)  ctrl <= sr[3:0];
    end

    // ---- LEDs (50 MHz domain) ----
    reg [26:0] cnt = 27'd0;
    reg [3:0]  ctrl_s1 = 4'd0, ctrl_s2 = 4'd0;
    always @(posedge clk) begin
        cnt     <= cnt + 27'd1;
        ctrl_s1 <= ctrl;
        ctrl_s2 <= ctrl_s1;
        led_r   <= ctrl_s2[3] ? ctrl_s2[2:0] : {cnt[22], cnt[24], cnt[26]};
    end
    assign led = led_r;
endmodule
