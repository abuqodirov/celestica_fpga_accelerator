// ffn_unit.v - SiLU(gate) * up on the card, straight from the two matvec engines' result streams, quantized to MXINT8
// and written into both engines' activation buffers: the input of down_proj never crosses the JTAG cable.
//
// Use, once per layer: arm with nrows = 9728 (the FFN width), then run gate_up on both engines, one run each:
// engine 0 streams the gate rows, engine 1 the up rows (mustaqi/out/q4h_index.json: channel 0 holds gate, channel 1
// up). Row pairs (gate_i, up_i) go through silu_mul (float32; the bit-exact spec is mustaqi/fpga_llm.py silu_mul_hw),
// groups of 32 are quantized exactly like accel/golden/golden.h mx_quantize, and the activation image (nrows/4
// words of a, then nrows/32 subgroup words) is collected here. Only after the last group is it copied into both
// engines' buffers (mv_engine.v aw port format), because gate_up reads the old activations until it ends. busy falls
// when the copy is done: down_proj can start then. err (sticky until the next arm): a FIFO overflowed.
//
// The engines deliver a row every >= 30 clocks; pairs are taken at most every 4th clock, so a quantizer that needs
// ~34 clocks per group of 32 always finishes a group before its buffer half is reused.

module ffn_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire        arm,
    input  wire [13:0] nrows,          // multiple of 32, <= 10240
    input  wire        g_valid,
    input  wire [31:0] g_data,
    input  wire        u_valid,
    input  wire [31:0] u_data,
    output reg         aw_en,
    output reg  [12:0] aw_addr,
    output reg  [31:0] aw_data,
    output wire        busy,
    output reg         err
);
    localparam IDLE = 2'd0, RUN = 2'd1, COPY = 2'd2;
    reg [1:0] state;

    // ---------------------------------------------------------------- inputs (the engines sit on opposite die halves)
    reg        gv, uv;
    reg [31:0] gd, ud;
    always @(posedge clk) begin
        gv <= g_valid; uv <= u_valid; gd <= g_data; ud <= u_data;
    end

    // ---------------------------------------------------------------- one FIFO per engine (they drift apart a little)
    reg [31:0] gmem [0:511];
    reg [31:0] umem [0:511];
    reg  [9:0] gw, gr, uw, ur;
    reg [13:0] gin, uin;
    wire gpush = state == RUN && gv && gin != nrows;
    wire upush = state == RUN && uv && uin != nrows;
    wire gfull = (gw - gr) == 10'd512, ufull = (uw - ur) == 10'd512;
    reg  [1:0] cool;
    wire pop = gw != gr && uw != ur && cool == 0;
    reg        pv;
    reg [31:0] pg, pu;
    always @(posedge clk) begin
        if (gpush) gmem[gw[8:0]] <= gd;
        if (upush) umem[uw[8:0]] <= ud;
        pg <= gmem[gr[8:0]];
        pu <= umem[ur[8:0]];
        pv <= pop;
        if (rst || arm) begin
            gw <= 0; gr <= 0; uw <= 0; ur <= 0; gin <= 0; uin <= 0; cool <= 0;
        end else begin
            if (gpush) begin gw <= gw + 1'b1; gin <= gin + 1'b1; end
            if (upush) begin uw <= uw + 1'b1; uin <= uin + 1'b1; end
            if (pop) begin gr <= gr + 1'b1; ur <= ur + 1'b1; cool <= 2'd3; end
            else if (cool != 0) cool <= cool - 1'b1;
        end
    end

    // ---------------------------------------------------------------- h = silu(g) * u
    wire        hv;
    wire [31:0] h;
    silu_mul sm (.clk(clk), .rst(rst || arm), .in_v(pv), .g(pg), .u(pu), .out_v(hv), .h(h));

    // ---------------------------------------------------------------- groups of 32: buffer (two halves) + |max|
    reg [31:0] gbuf [0:63];
    reg [13:0] hcnt;
    reg [30:0] amax, qmax;
    reg        qgo;
    reg  [8:0] qgo_grp;
    wire [30:0] habs = h[30:0];
    wire [30:0] amax_n = habs > amax ? habs : amax;
    always @(posedge clk) begin
        qgo <= 0;
        if (hv) gbuf[hcnt[5:0]] <= h;
        if (rst || arm) begin
            hcnt <= 0; amax <= 0;
        end else if (hv) begin
            hcnt <= hcnt + 1'b1;
            if (hcnt[4:0] == 5'd31) begin
                amax <= 0; qmax <= amax_n; qgo <= 1; qgo_grp <= hcnt[13:5];
            end else
                amax <= amax_n;
        end
    end

    // ---------------------------------------------------------------- quantizer (golden.h mx_quantize)
    // exponent: smallest ex with amax <= 127 * 2^ex = 1.984375 * 2^(ex+6), clamped to [-64, 63]; 0 for amax = 0
    wire signed [9:0] ea = $signed({2'b0, qmax[30:23]}) - 10'sd127;
    wire signed [9:0] ex_raw = qmax == 0 ? 10'sd0 : (qmax[22:0] <= 23'h7E0000 ? ea - 10'sd6 : ea - 10'sd5);
    wire signed [7:0] ex_c = ex_raw < -10'sd64 ? -8'sd64 : ex_raw > 10'sd63 ? 8'sd63 : ex_raw[7:0];
    reg        qrun, q1v, q2v;
    reg  [5:0] qj;
    reg        qb;
    reg  [8:0] qg, qg1, qg2;
    reg signed [7:0] qex;
    reg  [4:0] qj1, qj2;
    reg [31:0] hq;
    always @(posedge clk) begin
        q1v <= 0;
        if (rst || arm) qrun <= 0;
        else if (qgo) begin
            qrun <= 1; qj <= 0; qb <= qgo_grp[0]; qg <= qgo_grp; qex <= ex_c;
        end else if (qrun) begin
            hq <= gbuf[{qb, qj[4:0]}]; q1v <= 1; qj1 <= qj[4:0]; qg1 <= qg;
            if (qj == 6'd31) qrun <= 0;
            qj <= qj + 1'b1;
        end
    end
    // a = round_even(h * 2^-ex), |a| <= 127: |h| = M * 2^(eh-150) -> shift M right by sh = 150 + ex - eh (>= 17)
    wire signed [10:0] sh_raw = 11'sd150 + qex - $signed({3'b0, hq[30:23]});
    wire        hz  = hq[30:23] == 0;
    wire        clip = !hz && sh_raw < 11'sd17;              // only if ex was clamped at 63
    wire  [4:0] sh  = sh_raw > 11'sd26 ? 5'd26 : sh_raw < 11'sd17 ? 5'd17 : sh_raw[4:0];
    wire [23:0] M   = {1'b1, hq[22:0]};
    wire [23:0] qv  = M >> sh;
    wire [25:0] rem = {2'b0, M} & ((26'd1 << sh) - 1'b1);
    wire [25:0] half = 26'd1 << (sh - 1'b1);
    reg   [6:0] mag2;
    reg         up2, neg2, clip2, z2;
    reg signed [7:0] qex2;
    always @(posedge clk) begin
        q2v <= q1v; qj2 <= qj1; qg2 <= qg1; qex2 <= qex;
        mag2 <= qv[6:0];
        up2 <= rem > half || (rem == half && qv[0]);
        neg2 <= hq[31]; clip2 <= clip; z2 <= hz;
    end
    wire  [7:0] mag = z2 ? 8'd0 : clip2 ? 8'd127 : {1'b0, mag2} + {7'b0, up2};
    wire  [7:0] a8  = neg2 ? -mag : mag;
    // collect: 4 bytes per a word, S per group; the image lives here until the copy
    reg [31:0] amem [0:2559];
    reg [31:0] smem [0:319];
    reg [23:0] abytes;
    reg signed [15:0] S;
    wire signed [15:0] S_n = (qj2 == 0 ? 16'sd0 : S) + {{8{a8[7]}}, a8};
    reg  [8:0] qdone;
    always @(posedge clk) begin
        if (q2v) begin
            abytes <= {a8, abytes[23:8]};
            S <= S_n;
            if (qj2[1:0] == 2'd3) amem[{qg2, qj2[4:2]}] <= {a8, abytes};
            if (qj2 == 5'd31) smem[qg2] <= {8'b0, qex2, S_n};
        end
        if (rst || arm) qdone <= 0;
        else if (q2v && qj2 == 5'd31) qdone <= qdone + 1'b1;
    end

    // ---------------------------------------------------------------- state, copy into both engines' buffers
    wire [11:0] na = nrows[13:2];                            // a words
    wire  [8:0] ns = nrows[13:5];                            // subgroup words
    reg  [12:0] ci;
    reg         cv, cs;
    reg  [11:0] cw;
    reg  [31:0] ca, cs_d;
    assign busy = state != IDLE || cv || aw_en;              // until the last word is written
    always @(posedge clk) begin
        cv <= 0;
        ca <= amem[ci[11:0]];
        cs_d <= smem[ci[8:0] - na[8:0]];
        aw_en <= cv;
        aw_addr <= cs ? {4'b1000, cw[8:0]} : {1'b0, cw};
        aw_data <= cs ? cs_d : ca;
        if (rst) begin
            state <= IDLE; err <= 0; aw_en <= 0;
        end else if (arm) begin
            state <= RUN; err <= 0;
        end else begin
            if ((gpush && gfull) || (upush && ufull)) err <= 1;
            case (state)
                RUN: if (qdone == ns && ns != 0) begin state <= COPY; ci <= 0; end
                COPY: begin
                    cv <= 1; cs <= ci >= {1'b0, na}; cw <= ci >= {1'b0, na} ? ci[11:0] - na : ci[11:0];
                    if (ci == {1'b0, na} + {4'b0, ns} - 1'b1) state <= IDLE;
                    ci <= ci + 1'b1;
                end
                default: ;
            endcase
        end
    end
endmodule

// h = silu(g) * u, float32, bit-exact with mustaqi/fpga_llm.py silu_mul_hw; a new pair every clock, 36 clocks.
module silu_mul (
    input  wire        clk,
    input  wire        rst,
    input  wire        in_v,
    input  wire [31:0] g,
    input  wire [31:0] u,
    output wire        out_v,
    output wire [31:0] h
);
    `include "ffn_tables.vh"
    localparam [31:0] C = 32'hbfb8aa3b;                     // float32(-log2(e))
    localparam LAT = 36;
    reg [LAT-1:0] vsh;
    always @(posedge clk) vsh <= rst ? {LAT{1'b0}} : {vsh[LAT-2:0], in_v};
    assign out_v = vsh[LAT-1];

    // 0 -> 3: t = g * C
    wire [31:0] t;
    fp_mul m1 (.clk(clk), .a(g), .b(C), .y(t));
    // 3 -> 4: |t| >= 64 cases; P = round_even(|t| * 2^22): M = 1.m * 2^23, |t| * 2^22 = M * 2^(E-1), E = et - 127 <= 5
    wire [7:0]  et = t[30:23];
    reg         hi4, lo4, tz4, neg4, left4;
    reg  [2:0]  ls4;                                         // E - 1 when E >= 1 (0..4)
    reg  [7:0]  rs4;                                         // 1 - E when E <= 0 (1..)
    reg [23:0]  M4;
    always @(posedge clk) begin
        hi4 <= !t[31] && et >= 8'd133;
        lo4 <= t[31] && et >= 8'd133;
        tz4 <= et == 0; neg4 <= t[31];
        left4 <= et >= 8'd128;
        ls4 <= et[2:0];                                      // et - 128 for et in 128..132
        rs4 <= 8'd128 - et;                                  // 1 - E = 128 - et for et <= 127
        M4 <= {1'b1, t[22:0]};
    end
    // 4 -> 5: shift + round to nearest even, sign; idx = P >> 16, f = P & 0xFFFF
    wire [4:0]  rsc = rs4 > 8'd26 ? 5'd26 : rs4[4:0];
    wire [27:0] Pl  = {4'b0, M4} << ls4;
    wire [23:0] q   = M4 >> rsc;
    wire [25:0] rem = {2'b0, M4} & ((26'd1 << rsc) - 1'b1);
    wire [25:0] hf  = 26'd1 << (rsc - 1'b1);
    wire [27:0] Pr  = {4'b0, q} + {27'b0, rem > hf || (rem == hf && q[0])};
    wire [27:0] Pm  = tz4 ? 28'd0 : left4 ? Pl : Pr;
    wire [28:0] P   = neg4 ? -{1'b0, Pm} : {1'b0, Pm};
    reg  [12:0] idx5;
    reg  [15:0] f5;
    always @(posedge clk) begin
        idx5 <= P[28:16];
        f5 <= P[15:0];
    end
    // 5 -> 6: f as float32 (f * 2^-16, exact); table entries T[i], D[i], i = idx & 63
    /* verilator lint_off BLKSEQ */
    function [31:0] u2f16(input [15:0] v);                  // v * 2^-16, exact
        integer k;
        reg [4:0] p;
        reg [22:0] fr;
        begin
            p = 0;
            for (k = 0; k < 16; k = k + 1) if (v[k]) p = k;
            fr = {7'b0, v} << (5'd23 - p);                   // the leading one shifts out
            u2f16 = v == 0 ? 32'b0 : {1'b0, 8'd111 + {3'b0, p}, fr};
        end
    endfunction
    /* verilator lint_on BLKSEQ */
    reg [31:0] f6, T6, D6;
    always @(posedge clk) begin
        f6 <= u2f16(f5);
        {D6, T6} <= tab_td(idx5[5:0]);
    end
    // 6 -> 9: D * f;  9 -> 14: m = T + D * f
    wire [31:0] df, m;
    reg  [31:0] T7, T8, T9;
    always @(posedge clk) begin T7 <= T6; T8 <= T7; T9 <= T8; end
    fp_mul m2 (.clk(clk), .a(D6), .b(f6), .y(df));
    fp_add a1 (.clk(clk), .a(T9), .b(df), .y(m));
    // 14 -> 15: e = m * 2^n, n = idx >> 6 (exact: exponent field + n)
    wire [6:0] n5 = idx5[12:6];
    wire [6:0] n14;
    ffn_dly #(7, 9) dn (.clk(clk), .d(n5), .q(n14));
    reg [31:0] e15;
    always @(posedge clk) e15 <= {m[31], m[30:23] + {n14[6], n14}, m[22:0]};
    // 15 -> 20: x = 1 + e
    wire [31:0] x;
    fp_add a2 (.clk(clk), .a(32'h3f800000), .b(e15), .y(x));
    // 20 -> 21: x = mx * 2^k: j = top 6 mantissa bits, fr = the other 17 as a fraction (exact); R[j], DR[j]
    /* verilator lint_off BLKSEQ */
    function [31:0] u2f17(input [16:0] v);                  // v * 2^-17, exact
        integer k;
        reg [4:0] p;
        reg [22:0] fr;
        begin
            p = 0;
            for (k = 0; k < 17; k = k + 1) if (v[k]) p = k;
            fr = {6'b0, v} << (5'd23 - p);
            u2f17 = v == 0 ? 32'b0 : {1'b0, 8'd110 + {3'b0, p}, fr};
        end
    endfunction
    /* verilator lint_on BLKSEQ */
    reg [31:0] fr21, R21, DR21;
    reg  [7:0] k21;
    always @(posedge clk) begin
        fr21 <= u2f17(x[16:0]);
        {DR21, R21} <= tab_rdr(x[22:17]);
        k21 <= x[30:23] - 8'd127;
    end
    // 21 -> 24: DR * fr;  24 -> 29: rm = R + DR * fr
    wire [31:0] dfr, rm;
    reg  [31:0] R22, R23, R24;
    always @(posedge clk) begin R22 <= R21; R23 <= R22; R24 <= R23; end
    fp_mul m3 (.clk(clk), .a(DR21), .b(fr21), .y(dfr));
    fp_add a3 (.clk(clk), .a(R24), .b(dfr), .y(rm));
    // 29 -> 30: r = rm * 2^-k (exact), or 0 (t >= 64) / 1 (t <= -64)
    wire [7:0] k29;
    wire       hi29, lo29;
    ffn_dly #(8, 8) dk (.clk(clk), .d(k21), .q(k29));
    ffn_dly #(2, 25) dhl (.clk(clk), .d({hi4, lo4}), .q({hi29, lo29}));
    reg [31:0] r30;
    always @(posedge clk) r30 <= hi29 ? 32'b0 : lo29 ? 32'h3f800000 : {rm[31], rm[30:23] - k29, rm[22:0]};
    // 30 -> 33: s = g * r;  33 -> 36: h = s * u
    wire [31:0] g30, u33, s;
    ffn_dly #(32, 30) dg (.clk(clk), .d(g), .q(g30));
    ffn_dly #(32, 33) du (.clk(clk), .d(u), .q(u33));
    fp_mul m4 (.clk(clk), .a(g30), .b(r30), .y(s));
    fp_mul m5 (.clk(clk), .a(s), .b(u33), .y(h));
endmodule

// N-clock delay line (plain registers: this toolchain's SRL primitives are broken, synth_xilinx -nosrl)
module ffn_dly #(parameter W = 1, parameter N = 1) (
    input  wire         clk,
    input  wire [W-1:0] d,
    output wire [W-1:0] q
);
    reg [W-1:0] r [0:N-1];
    integer i;
    always @(posedge clk) begin
        r[0] <= d;
        for (i = 1; i < N; i = i + 1) r[i] <= r[i - 1];
    end
    assign q = r[N-1];
endmodule
