// Big-integer multiplier: (LIMBS*32)-bit x (LIMBS*32)-bit -> (LIMBS*64)-bit.
//
// Operand scanning with LIMBS 32x32 multipliers in parallel: every cycle the whole
// of `a` is multiplied by one 32-bit limb of `b`. The accumulator keeps one limb per
// position (33 bits) and passes each limb's carry one position up while the whole
// accumulator shifts down one limb, so there is no long carry chain and one finished
// product limb leaves the bottom every cycle. Once `b` is used up, the same datapath
// keeps running with zero rows to flush the upper half.
// Latency: 1 cycle to fill the multiplier registers + 2*LIMBS cycles.
module bigmul #(
    parameter LIMBS = 32
) (
    input  wire                clk,
    input  wire                rst,
    input  wire                start,
    input  wire [LIMBS*32-1:0] a,
    input  wire [LIMBS*32-1:0] b,
    output reg                 busy    = 1'b0,
    output reg                 done    = 1'b0,
    output reg  [LIMBS*64-1:0] product = {LIMBS*64{1'b0}},
    output reg  [31:0]         cycles  = 32'd0
);
    localparam W = LIMBS * 32;

    reg [W-1:0]             a_r   = {W{1'b0}};
    reg [W-1:0]             b_sh  = {W{1'b0}};            // b, shifted down one limb per cycle
    reg [LIMBS*64-1:0]      p     = {LIMBS*64{1'b0}};     // partial products a[i] * b_j
    reg [(LIMBS+1)*33-1:0]  acc   = {(LIMBS+1)*33{1'b0}}; // accumulator, one limb per position
    reg                     primed = 1'b0;
    reg [7:0]               left   = 8'd0;                // accumulate cycles remaining

    // s[k] = acc[k] + low half of p[k] + high half of p[k-1]; always < 2^34.
    wire [(LIMBS+1)*34-1:0] s;
    genvar k;
    generate
        for (k = 0; k <= LIMBS; k = k + 1) begin : g_sum
            wire [33:0] acc_k = {1'b0, acc[k*33 +: 33]};
            if (k == 0)
                assign s[k*34 +: 34] = acc_k + {2'b00, p[31:0]};
            else if (k == LIMBS)
                assign s[k*34 +: 34] = acc_k + {2'b00, p[(k-1)*64 + 32 +: 32]};
            else
                assign s[k*34 +: 34] = acc_k + {2'b00, p[k*64 +: 32]} + {2'b00, p[(k-1)*64 + 32 +: 32]};
        end
    endgenerate

    integer i;
    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            busy <= 1'b0;
        end else if (!busy) begin
            if (start) begin
                busy   <= 1'b1;
                cycles <= 32'd0;
                a_r    <= a;
                b_sh   <= b;
                acc    <= {(LIMBS+1)*33{1'b0}};
                primed <= 1'b0;
                left   <= 2 * LIMBS;
            end
        end else begin
            cycles <= cycles + 32'd1;
            // Next row of partial products (all zero once b has been shifted out).
            for (i = 0; i < LIMBS; i = i + 1)
                /* verilator lint_off WIDTHEXPAND */
                p[i*64 +: 64] <= a_r[i*32 +: 32] * b_sh[31:0];
                /* verilator lint_on WIDTHEXPAND */
            b_sh   <= b_sh >> 32;
            primed <= 1'b1;
            if (primed) begin
                // Shift down one limb; each position's carry (s >> 32) moves up one.
                for (i = 0; i < LIMBS; i = i + 1)
                    acc[i*33 +: 33] <= {1'b0, s[(i+1)*34 +: 32]} + {31'd0, s[i*34 + 32 +: 2]};
                acc[LIMBS*33 +: 33] <= {31'd0, s[LIMBS*34 + 32 +: 2]};
                product <= {s[31:0], product[LIMBS*64-1:32]};
                left    <= left - 8'd1;
                if (left == 8'd1) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule
