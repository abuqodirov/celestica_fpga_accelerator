// fp32.v - pipelined float32 multiply and add for the FPGA's vector work (FFN unit, later the stage D vector unit).
//
// IEEE 754 binary32 with round to nearest, ties to even - the same bits as a float32 multiply/add on the PC (numpy,
// C without -ffast-math) - for normal numbers and zeros. Not supported (never produced by the engines' results or
// the FFN math, see mustaqi/fpga_llm.py silu_mul_hw): subnormal inputs are read as zero, results below 2^-126
// become zero (keeping the sign), results above the largest float become infinity, inf/NaN inputs are not handled.
// Zero results follow IEEE: x - x = +0, (-0) + (-0) = -0, sign of a product = xor of the signs.
//
// fp_mul: y = a * b, 3 clocks.   fp_add: y = a + b, 5 clocks.   Both take a new operand pair every clock.

module fp_mul (
    input  wire        clk,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);
    // 1: unpack
    reg        s1, z1;
    reg  [9:0] e1;                         // ea + eb (biased twice)
    reg [23:0] ma1, mb1;
    always @(posedge clk) begin
        s1  <= a[31] ^ b[31];
        z1  <= a[30:23] == 0 || b[30:23] == 0;
        e1  <= {2'b0, a[30:23]} + {2'b0, b[30:23]};
        ma1 <= {1'b1, a[22:0]};
        mb1 <= {1'b1, b[22:0]};
    end
    // 2: 24 x 24 mantissa product (DSPs)
    reg        s2, z2;
    reg  [9:0] e2;
    reg [47:0] p2;
    always @(posedge clk) begin
        s2 <= s1; z2 <= z1; e2 <= e1;
        p2 <= ma1 * mb1;
    end
    // 3: normalize (product in [1, 4)), round to nearest even, pack
    wire        hi = p2[47];
    wire [22:0] mf = hi ? p2[46:24] : p2[45:23];
    wire        g  = hi ? p2[23] : p2[22];
    wire        st = hi ? |p2[22:0] : |p2[21:0];
    wire        up = g & (st | mf[0]);
    wire [23:0] mr = {1'b0, mf} + {23'b0, up};                  // carry into bit 23: mantissa overflowed to 2.0
    wire signed [11:0] er = $signed({2'b0, e2}) - 12'sd127 + $signed({11'b0, hi}) + $signed({11'b0, mr[23]});
    always @(posedge clk)
        if (z2 || er <= 0) y <= {s2, 31'b0};
        else if (er >= 255) y <= {s2, 8'hFF, 23'b0};
        else y <= {s2, er[7:0], mr[22:0]};
endmodule

module fp_add (
    input  wire        clk,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);
    // 1: unpack (subnormals -> 0), order by magnitude: x = the larger, w = the smaller
    wire        za = a[30:23] == 0, zb = b[30:23] == 0;
    wire [30:0] ma = za ? 31'b0 : a[30:0], mb = zb ? 31'b0 : b[30:0];
    wire        swap = mb > ma;
    reg         sx1, sub1, bothneg1;
    reg  [7:0]  ex1, d1;
    reg  [23:0] mx1, mw1;
    always @(posedge clk) begin
        sx1  <= swap ? b[31] : a[31];
        sub1 <= a[31] ^ b[31];
        bothneg1 <= a[31] & b[31];
        ex1  <= swap ? mb[30:23] : ma[30:23];
        d1   <= swap ? mb[30:23] - ma[30:23] : ma[30:23] - mb[30:23];
        mx1  <= swap ? (zb ? 24'b0 : {1'b1, mb[22:0]}) : (za ? 24'b0 : {1'b1, ma[22:0]});
        mw1  <= swap ? (za ? 24'b0 : {1'b1, ma[22:0]}) : (zb ? 24'b0 : {1'b1, mb[22:0]});
    end
    // 2: align the smaller one: 24 bits + guard + round, then a sticky bit for everything shifted out
    wire [49:0] wsh = {mw1, 26'b0} >> (d1 > 8'd49 ? 8'd49 : d1);
    reg         sx2, sub2, bothneg2;
    reg  [7:0]  ex2;
    reg  [26:0] mx2, mw2;                  // {mantissa, guard, round, sticky}
    always @(posedge clk) begin
        sx2 <= sx1; sub2 <= sub1; bothneg2 <= bothneg1; ex2 <= ex1;
        mx2 <= {mx1, 3'b0};
        mw2 <= {wsh[49:24], |wsh[23:0] | (d1 > 8'd49 && mw1 != 0)};
    end
    // 3: add / subtract (the larger minus the smaller is never negative)
    reg         sx3, sub3, bothneg3;
    reg  [7:0]  ex3;
    reg  [27:0] s3;
    always @(posedge clk) begin
        sx3 <= sx2; sub3 <= sub2; bothneg3 <= bothneg2; ex3 <= ex2;
        s3 <= sub2 ? {1'b0, mx2} - {1'b0, mw2} : {1'b0, mx2} + {1'b0, mw2};
    end
    // 4: normalize: carry -> shift right by one (keeping the sticky), else shift left to the leading one
    reg  [4:0]  lz;
    integer     i;
    always @(*) begin
        lz = 5'd27;
        for (i = 0; i <= 26; i = i + 1)
            if (s3[i]) lz = 5'd26 - i[4:0];
    end
    reg         sx4, zero4, bothneg4;
    reg  signed [9:0] e4;
    reg  [26:0] n4;                        // normalized: bit 26 = leading one, then 23 bits, guard, round|sticky
    always @(posedge clk) begin
        sx4 <= sx3; bothneg4 <= bothneg3;
        zero4 <= s3 == 0;
        if (s3[27]) begin
            n4 <= {s3[27:2], s3[1] | s3[0]};
            e4 <= $signed({2'b0, ex3}) + 10'sd1;
        end else begin
            n4 <= s3[26:0] << lz;
            e4 <= $signed({2'b0, ex3}) - $signed({5'b0, lz});
        end
    end
    // 5: round to nearest even, pack
    wire        g5  = n4[2], rs5 = n4[1] | n4[0];
    wire        up5 = g5 & (rs5 | n4[3]);
    wire [24:0] mr5 = {1'b0, n4[26:3]} + {24'b0, up5};
    wire signed [9:0] er5 = e4 + $signed({9'b0, mr5[24]});
    always @(posedge clk)
        if (zero4) y <= {bothneg4, 31'b0};                  // exact zero: +0 unless both inputs were negative
        else if (er5 <= 0) y <= {sx4, 31'b0};
        else if (er5 >= 255) y <= {sx4, 8'hFF, 23'b0};
        else y <= {sx4, er5[7:0], mr5[24] ? mr5[23:1] : mr5[22:0]};
endmodule
