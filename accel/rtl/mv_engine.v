// mv_engine.v - streaming 4-bit matrix x MXINT8 vector engine (one per DDR3 channel).
//
// Arithmetic: bit-exact with accel/golden/golden.h (q4h_row_acc + acc_to_float). Weight rows arrive as Q4H
// 64-byte words, one per clock while w_valid (gaps allowed, never back-pressured): per row SW = ceil(NG/16) scale
// words, then NG code words (one group of 128 weights each). B activation vectors share every weight word.
//
// Pipeline (v2: every stage registered, short combinational paths for the 75 MHz domain of a large SoC):
//   I0  input register                          F   row parse, group index k, scale/offset select
//   R   activation buffer read at registered k   P1  4-bit x 8-bit products (shift-and-add), sums of 4
//   P2  sums of 32 -> D_i (4 subgroups)          P3  m_s*D_i, m_lo*S_i (DSP), shift amounts E+e+ACC_FRAC
//   P4  shift onto the 64-bit accumulator grid   P5  8 terms -> 4 (pair sums)
//   P6  4 -> 1                                   P7  acc = (first ? 0 : acc) + sum
//   P8  capture |acc| of a finished row          P9  leading-one position
//   P10 normalize                                P11 round to nearest even, pack float32 -> r_data
// Row hand-off: every row starts with at least one scale word, so the next row's first code word reaches P7 at
// least 2 clocks after the previous row's last one; P8 captures acc in between.
// Activation buffer write port (32-bit words, per vector aw_vec):
//   aw_addr[12] = 0: bytes of a, word w = a[4w..4w+3] (little endian), w < 2560 (K <= 10240)
//   aw_addr[12] = 1: subgroup sg = aw_addr[8:0]: {8'b0, e[7:0], S[15:0]}
module mv_engine #(
    parameter B = 1,                       // activation vectors per weight pass (1..4)
    parameter ACC_FRAC = 30
) (
    input  wire              clk,
    input  wire              rst,
    input  wire [6:0]        cfg_ng,       // groups of 128 per row (K/128), 1..80
    input  wire              start,        // clears row/word counters and the overflow flag
    input  wire              w_valid,
    input  wire [511:0]      w_data,
    input  wire              aw_en,
    input  wire [1:0]        aw_vec,
    input  wire [12:0]       aw_addr,
    input  wire [31:0]       aw_data,
    output reg               r_valid,
    output reg  [15:0]       r_row,
    output reg  [32*B-1:0]   r_data,       // float32 per vector
    output reg               ovf,          // sticky: accumulator overflow or inf/nan scale seen
    output wire [15:0]       rows_done
);
    // ---------------------------------------------------------------- I0: input register
    reg          wv0;
    reg  [511:0] wd0;
    always @(posedge clk) begin
        wv0 <= w_valid && !rst && !start;
        wd0 <= w_data;
    end

    // ---------------------------------------------------------------- F: row parsing
    wire [6:0] sw = (cfg_ng + 7'd15) >> 4;        // scale words per row
    reg  [6:0]  wcnt;                      // word index within the row
    reg  [15:0] row;
    reg  [511:0] sreg [0:4];               // scale words of the current row (80 groups max)
    wire is_code = wcnt >= sw;
    wire [6:0] k = wcnt - sw;              // group index of a code word
    wire [2:0] kw = k[6:4];
    wire [31:0] sl = sreg[kw][{k[3:0], 5'd0} +: 32];
    assign rows_done = row;

    always @(posedge clk) begin
        if (rst || start) begin
            wcnt <= 0; row <= 0;
        end else if (wv0) begin
            if (!is_code) sreg[wcnt[2:0]] <= wd0;
            if (wcnt == sw + cfg_ng - 1) begin wcnt <= 0; row <= row + 1'b1; end
            else wcnt <= wcnt + 1'b1;
        end
    end

    reg         vF, firstF, lastF;
    reg [6:0]   kF;
    reg [15:0]  rowF, sF, loF;
    reg [511:0] codeF;
    always @(posedge clk) begin
        vF <= wv0 && is_code && !rst && !start;
        kF <= k; firstF <= k == 0; lastF <= k == cfg_ng - 1;
        rowF <= row; codeF <= wd0; sF <= sl[15:0]; loF <= sl[31:16];
    end

    // ---------------------------------------------------------------- R: buffer read (per vector), stage 1 regs
    reg         v1, first1, last1;
    reg [15:0]  row1;
    reg [511:0] code1;
    reg [15:0]  s1, lo1;
    always @(posedge clk) begin
        v1 <= vF && !rst && !start; first1 <= firstF; last1 <= lastF;
        row1 <= rowF; code1 <= codeF; s1 <= sF; lo1 <= loF;
    end

    // fp16 -> signed 12-bit mantissa, exponent (exact), inf/nan flag
    /* verilator lint_off BLKSEQ */
    function [11:0] h_m(input [15:0] h);
        reg [10:0] m;
        begin m = {h[14:10] != 0, h[9:0]}; h_m = h[15] ? -{1'b0, m} : {1'b0, m}; end
    endfunction
    function signed [7:0] h_e(input [15:0] h);
        begin h_e = (h[14:10] != 0 ? {3'b0, h[14:10]} : 8'd1) - 8'sd25; end
    endfunction

    // 64-bit grid shift: v * 2^sh, floor for right shifts; flag when |result| >= 2^62
    function [64:0] gshift(input signed [30:0] v, input signed [8:0] sh);   // {overflow, value}
        reg signed [127:0] w;
        begin
            w = {{97{v[30]}}, v};
            if (sh >= 0) begin
                if (sh > 9'sd62) gshift = {v != 0, 64'd0};
                else begin
                    w = w <<< sh;               // golden: flag when |result| >= 2^62
                    gshift = {w[127] ? !(w[127:62] == {66{1'b1}} && w[61:0] != 0) : (w[127:62] != 0), w[63:0]};
                end
            end else if (sh <= -9'sd63) gshift = {1'b0, {64{v[30]}}};
            else begin
                w = w >>> (-sh);
                gshift = {1'b0, w[63:0]};
            end
        end
    endfunction

    // 4-bit code x int8 activation as shift-and-add: tiny products belong in LUT adders. Written with '*',
    // yosys maps every one of them to its own DSP48 (128 per vector), which scatters the engine over the DSP
    // columns of the die.
    function signed [17:0] qmul(input [3:0] q, input [7:0] a);
        reg signed [17:0] x;
        begin
            x = {{10{a[7]}}, a};
            qmul = (q[0] ? x : 18'sd0) + (q[1] ? (x <<< 1) : 18'sd0) + (q[2] ? (x <<< 2) : 18'sd0) + (q[3] ? (x <<< 3) : 18'sd0);
        end
    endfunction
    /* verilator lint_on BLKSEQ */

    // shared pipeline: valid/flags/row/scale decode travel with the data
    reg v2, v3, v4, v5, v6, v7, v8, v9, v10, v11;
    reg first2, first3, first4, first5, first6, first7;
    reg last2, last3, last4, last5, last6, last7, last8, last9, last10, last11;
    reg [15:0] row2, row3, row4, row5, row6, row7, row8, row9, row10, row11;
    reg signed [11:0] ms2, ml2, ms3, ml3;
    reg signed [7:0]  es2, el2, es3, el3;
    reg bad2, bad3, bad4;
    always @(posedge clk) begin
        v2 <= v1; v3 <= v2; v4 <= v3; v5 <= v4; v6 <= v5; v7 <= v6; v8 <= v7; v9 <= v8; v10 <= v9; v11 <= v10;
        first2 <= first1; first3 <= first2; first4 <= first3; first5 <= first4; first6 <= first5; first7 <= first6;
        last2 <= last1; last3 <= last2; last4 <= last3; last5 <= last4; last6 <= last5; last7 <= last6;
        last8 <= last7; last9 <= last8; last10 <= last9; last11 <= last10;
        row2 <= row1; row3 <= row2; row4 <= row3; row5 <= row4; row6 <= row5; row7 <= row6;
        row8 <= row7; row9 <= row8; row10 <= row9; row11 <= row10;
        ms2 <= h_m(s1); es2 <= h_e(s1); ml2 <= h_m(lo1); el2 <= h_e(lo1);
        ms3 <= ms2; es3 <= es2; ml3 <= ml2; el3 <= el2;
        bad2 <= v1 && (s1[14:10] == 5'd31 || lo1[14:10] == 5'd31); bad3 <= bad2; bad4 <= bad3;
    end

    wire [B-1:0] ovf_vec;
    always @(posedge clk) begin
        if (rst || start) ovf <= 0;
        else if (|ovf_vec || (v4 && bad4)) ovf <= 1;
    end

    // ---------------------------------------------------------------- per-vector datapath
    genvar b, ln, sl_i, j;
    generate for (b = 0; b < B; b = b + 1) begin : vec
        // activation buffer: 32 lanes x 128 chunks of 32 bits, 4 subgroup slots x 128 chunks of {e, S}
        wire [1023:0] arow;
        wire [95:0]   mrow;
        for (ln = 0; ln < 32; ln = ln + 1) begin : al
            reg [31:0] mem [0:127];
            reg [31:0] q;
            always @(posedge clk) begin
                if (aw_en && aw_vec == b && !aw_addr[12] && aw_addr[4:0] == ln) mem[aw_addr[11:5]] <= aw_data;
                q <= mem[kF];
            end
            assign arow[32*ln +: 32] = q;
        end
        for (sl_i = 0; sl_i < 4; sl_i = sl_i + 1) begin : ml
            reg [23:0] mem [0:127];
            reg [23:0] q;
            always @(posedge clk) begin
                if (aw_en && aw_vec == b && aw_addr[12] && aw_addr[1:0] == sl_i) mem[aw_addr[8:2]] <= aw_data[23:0];
                q <= mem[kF];
            end
            assign mrow[24*sl_i +: 24] = q;
        end

        // P1 -> P2: products and sums of 4 (32 partial sums, 8 per subgroup)
        reg signed [17:0] p4 [0:31];
        for (j = 0; j < 32; j = j + 1) begin : pr
            wire signed [17:0] t0 = qmul(code1[16*j +  3:16*j +  0], arow[32*j +  7:32*j +  0]);
            wire signed [17:0] t1 = qmul(code1[16*j +  7:16*j +  4], arow[32*j + 15:32*j +  8]);
            wire signed [17:0] t2 = qmul(code1[16*j + 11:16*j +  8], arow[32*j + 23:32*j + 16]);
            wire signed [17:0] t3 = qmul(code1[16*j + 15:16*j + 12], arow[32*j + 31:32*j + 24]);
            always @(posedge clk) p4[j] <= t0 + t1 + t2 + t3;
        end
        reg [95:0] m2;
        always @(posedge clk) m2 <= mrow;

        // P2 -> P3: D_i = sum of 8 partial sums
        reg signed [17:0] d3 [0:3];
        reg [95:0] m3;
        for (sl_i = 0; sl_i < 4; sl_i = sl_i + 1) begin : dsum
            always @(posedge clk)
                d3[sl_i] <= ((p4[8*sl_i+0] + p4[8*sl_i+1]) + (p4[8*sl_i+2] + p4[8*sl_i+3]))
                          + ((p4[8*sl_i+4] + p4[8*sl_i+5]) + (p4[8*sl_i+6] + p4[8*sl_i+7]));
        end
        always @(posedge clk) m3 <= m2;

        // P3 -> P4: mantissa products and shift amounts
        reg signed [30:0] ps4 [0:3], pl4 [0:3];
        reg signed [8:0]  shs4 [0:3], shl4 [0:3];
        for (sl_i = 0; sl_i < 4; sl_i = sl_i + 1) begin : mul
            wire signed [7:0]  e = m3[24*sl_i + 23:24*sl_i + 16];
            wire signed [15:0] S = m3[24*sl_i + 15:24*sl_i + 0];
            always @(posedge clk) begin
                ps4[sl_i] <= ms3 * d3[sl_i];
                pl4[sl_i] <= ml3 * S;
                shs4[sl_i] <= es3 + e + ACC_FRAC;
                shl4[sl_i] <= el3 + e + ACC_FRAC;
            end
        end

        // P4 -> P5: onto the 64-bit grid
        reg signed [63:0] g5 [0:7];
        reg [7:0] o5;
        for (sl_i = 0; sl_i < 4; sl_i = sl_i + 1) begin : sh
            wire [64:0] a_s = gshift(ps4[sl_i], shs4[sl_i]);
            wire [64:0] a_l = gshift(pl4[sl_i], shl4[sl_i]);
            always @(posedge clk) begin
                g5[2*sl_i] <= a_s[63:0]; g5[2*sl_i+1] <= a_l[63:0];
                o5[2*sl_i] <= v4 && a_s[64]; o5[2*sl_i+1] <= v4 && a_l[64];
            end
        end
        assign ovf_vec[b] = |o5;

        // P5 -> P6: pair sums;  P6 -> P7: sum of 4;  P7: accumulate
        reg signed [63:0] h6 [0:3];
        reg signed [63:0] s7;
        always @(posedge clk) begin
            h6[0] <= g5[0] + g5[1]; h6[1] <= g5[2] + g5[3]; h6[2] <= g5[4] + g5[5]; h6[3] <= g5[6] + g5[7];
            s7 <= (h6[0] + h6[1]) + (h6[2] + h6[3]);
        end
        reg signed [63:0] acc;
        always @(posedge clk)
            if (v7) acc <= (first7 ? 64'sd0 : acc) + s7;

        // P8: capture |acc| of a finished row (cycle after its last accumulate)
        reg [63:0] mag9;
        reg        sgn9;
        always @(posedge clk) if (v8 && last8) begin
            sgn9 <= acc[63];
            mag9 <= acc[63] ? -acc : acc;
        end
        // P9: leading-one position (127 = zero)
        reg [6:0]  msb;
        reg [6:0]  msb10;
        reg [63:0] mag10;
        reg        sgn10;
        integer t;
        always @(*) begin
            msb = 7'd127;
            for (t = 0; t < 64; t = t + 1) if (mag9[t]) msb = t[6:0];
        end
        always @(posedge clk) begin msb10 <= msb; mag10 <= mag9; sgn10 <= sgn9; end
        // P10: normalize (leading one to bit 63)
        reg [63:0] nrm11;
        reg [6:0]  msb11;
        reg        sgn11;
        always @(posedge clk) begin
            nrm11 <= mag10 << (7'd63 - msb10);
            msb11 <= msb10; sgn11 <= sgn10;
        end
        // P11: round to nearest even, pack (value * 2^-ACC_FRAC)
        reg [24:0] keep;
        reg [7:0]  fexp;
        reg [31:0] f;
        always @(*) begin
            keep = {1'b0, nrm11[63:40]};
            if (nrm11[39] && (|nrm11[38:0] || keep[0])) keep = keep + 1'b1;
            fexp = msb11 + 8'd127 - ACC_FRAC;
            if (keep[24]) begin keep = keep >> 1; fexp = fexp + 1'b1; end
            f = msb11 == 7'd127 ? 32'd0 : {sgn11, fexp, keep[22:0]};
        end
        always @(posedge clk) if (v11 && last11) r_data[32*b +: 32] <= f;
    end endgenerate

    always @(posedge clk) begin
        r_valid <= !rst && v11 && last11;
        r_row <= row11;
    end
endmodule
