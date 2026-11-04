// Multi-cycle calculator. Pulse `start` for one cycle with op/a/b valid; `done`
// pulses for one cycle when `result` is ready. `cycles` is the number of clock
// cycles the operation took, which is identical in simulation and on hardware.
module calc_core (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [3:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg         busy   = 1'b0,
    output reg         done   = 1'b0,
    output reg  [63:0] result = 64'd0,
    output reg  [31:0] cycles = 32'd0
);
    localparam [3:0] OP_ADD     = 4'd0,  // a + b
                     OP_MUL     = 4'd1,  // a * b (64-bit product)
                     OP_GCD     = 4'd2,  // gcd(a, b), binary (Stein) algorithm
                     OP_ISQRT   = 4'd3,  // floor(sqrt(a)), digit by digit
                     OP_FIB     = 4'd4,  // fib(a[15:0]) mod 2^64
                     OP_COLLATZ = 4'd5,  // steps for a to reach 1
                     OP_DIVMOD  = 4'd6,  // {a % b, a / b}; b = 0 gives {a, 32'hFFFFFFFF}
                     OP_TICK    = 4'd7;  // free-running cycle counter (clock measurement)

    reg [3:0]  cur_op = 4'd0;
    reg [31:0] opa = 32'd0, opb = 32'd0;
    reg [63:0] tick = 64'd0, tstamp = 64'd0;

    // GCD state
    reg [31:0] gx = 32'd0, gy = 32'd0;
    reg [5:0]  gk = 6'd0;                // common power of two
    reg        gdone = 1'b0;             // one operand reached zero; gx holds the odd part
    // ISQRT state
    reg [31:0] snum = 32'd0;
    reg [19:0] srem = 20'd0;
    reg [15:0] sroot = 16'd0;
    reg [4:0]  si = 5'd0;
    // FIB state
    reg [63:0] fa = 64'd0, fb = 64'd0;
    reg [15:0] fn = 16'd0;
    // COLLATZ state
    reg [63:0] cv = 64'd0;
    reg [31:0] cs = 32'd0;
    // DIVMOD state (restoring division)
    reg [31:0] dq = 32'd0, dr = 32'd0;
    reg [5:0]  di = 6'd0;

    /* verilator lint_off WIDTHEXPAND */
    wire [63:0] prod    = opa * opb;
    wire [63:0] sum     = opa + opb;
    /* verilator lint_on WIDTHEXPAND */
    wire [19:0] srem_sh = {srem[17:0], snum[31:30]};
    wire [19:0] stest   = {2'b00, sroot, 2'b01};
    wire [32:0] dr_sh   = {dr, dq[31]};
    wire [32:0] ddiff   = dr_sh - {1'b0, opb};

    // Does the current operation finish this cycle, and with what result?
    reg        fin;
    reg [63:0] fin_val;
    always @* begin
        fin     = 1'b0;
        fin_val = 64'd0;
        case (cur_op)
            OP_ADD:     begin fin = 1'b1; fin_val = sum; end
            OP_MUL:     begin fin = 1'b1; fin_val = prod; end
            OP_GCD:     if (gdone)         begin fin = 1'b1; fin_val = {32'd0, gx} << gk; end
            OP_ISQRT:   if (si == 5'd0)    begin fin = 1'b1; fin_val = {48'd0, sroot}; end
            OP_FIB:     if (fn == 16'd0)   begin fin = 1'b1; fin_val = fa; end
            OP_COLLATZ: if (cv <= 64'd1)   begin fin = 1'b1; fin_val = {32'd0, cs}; end
            OP_DIVMOD:  if (di == 6'd0)    begin fin = 1'b1; fin_val = {dr, dq}; end
            OP_TICK:    begin fin = 1'b1; fin_val = tstamp; end
            default:    begin fin = 1'b1; fin_val = 64'hDEAD_BEEF_DEAD_BEEF; end
        endcase
    end

    always @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            busy <= 1'b0;
            tick <= 64'd0;
        end else begin
            tick <= tick + 64'd1;
            if (!busy) begin
                if (start) begin
                    busy   <= 1'b1;
                    cur_op <= op;
                    opa    <= a;
                    opb    <= b;
                    cycles <= 32'd0;
                    tstamp <= tick;
                    gx <= a;  gy <= b;  gk <= 6'd0;  gdone <= 1'b0;
                    snum <= a;  srem <= 20'd0;  sroot <= 16'd0;  si <= 5'd16;
                    fa <= 64'd0;  fb <= 64'd1;  fn <= a[15:0];
                    cv <= {32'd0, a};  cs <= 32'd0;
                    dq <= a;  dr <= 32'd0;  di <= 6'd32;
                end
            end else begin
                cycles <= cycles + 32'd1;
                if (fin) begin
                    result <= fin_val;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                end else begin
                    case (cur_op)
                        OP_GCD:
                            // Finish in two steps (zero test, then shift) to keep the path short.
                            if (gx == 32'd0 || gy == 32'd0) begin
                                gx    <= gx | gy;
                                gdone <= 1'b1;
                            end
                            else if (!gx[0] && !gy[0]) begin
                                gx <= gx >> 1;  gy <= gy >> 1;  gk <= gk + 6'd1;
                            end
                            else if (!gx[0])  gx <= gx >> 1;
                            else if (!gy[0])  gy <= gy >> 1;
                            else if (gx >= gy) gx <= (gx - gy) >> 1;
                            else               gy <= (gy - gx) >> 1;
                        OP_ISQRT: begin
                            snum <= snum << 2;
                            si   <= si - 5'd1;
                            if (srem_sh >= stest) begin
                                srem  <= srem_sh - stest;
                                sroot <= {sroot[14:0], 1'b1};
                            end else begin
                                srem  <= srem_sh;
                                sroot <= {sroot[14:0], 1'b0};
                            end
                        end
                        OP_FIB: begin
                            fa <= fb;
                            fb <= fa + fb;
                            fn <= fn - 16'd1;
                        end
                        OP_COLLATZ: begin
                            cv <= cv[0] ? (cv << 1) + cv + 64'd1 : cv >> 1;
                            cs <= cs + 32'd1;
                        end
                        OP_DIVMOD: begin
                            di <= di - 6'd1;
                            if (!ddiff[32]) begin
                                dr <= ddiff[31:0];
                                dq <= {dq[30:0], 1'b1};
                            end else begin
                                dr <= dr_sh[31:0];
                                dq <= {dq[30:0], 1'b0};
                            end
                        end
                        default: ;
                    endcase
                end
            end
        end
    end
endmodule
