// PCIe stage 3a: a register / scratch window behind BAR0 (2 MB), on the PCIE_2_1 TRN interface (128-bit, pclk).
//
// RX: every TLP is accepted (TRNRDSTRDY is tied high, nothing back-pressures). A TLP is assumed to start at the
// beginning of a beat (header DW0 in rd[127:96]); the TRN RX snoop in s2_top.v logs the real beats so this can be
// checked. Data DWs are byte-swapped so the PC sees its own little-endian values.
//   Memory writes to BAR0: the FIRST data DW of each TLP goes to the register / scratch RAM it addresses; ALL data
//   DWs are counted (bytes) and summed (32-bit sum of the PC's values) -> bulk-write integrity and bandwidth tests.
//   Memory reads of BAR0 (1 or 2 DW): answered with a completion (CplD) only while rd_en = 1 (JTAG); otherwise the
//   read is counted and dropped (the PC then sees a completion timeout, 0xFFFFFFFF).
// Map (byte offsets):  0x0000 magic C0DE5303 (RO)   0x0004 scratch register (RW)   0x0008 write TLPs (RO)
//   0x000C bytes written (RO)   0x0010 sum of written DWs (RO)   0x0014 read TLPs (RO)   0x0018 cycle counter (RO)
//   0x1000-0x1FFF scratch RAM (1024 DW, RW)   anything else: reads return the byte offset itself.
module bar0 #(parameter [15:0] CPL_ID = 16'h0100) (   // completer ID: bus 1, device 0, function 0 (this PC)
    input  wire         clk,
    input  wire         rst_n,
    input  wire         rd_en,
    // TRN RX
    input  wire [127:0] rd,
    input  wire         rsof, reof, rsrc_rdy,
    input  wire [7:0]   bar_hit,
    // TRN TX
    output reg  [127:0] td,
    output reg          tsof, teof, tsrc_rdy,
    output reg  [1:0]   trem,
    input  wire         tdst_rdy,
    input  wire [5:0]   tbuf_av,
    // status
    output reg  [31:0]  n_wr, n_bytes, sum, scratch, last_dw0, last_dw2,
    output reg  [15:0]  n_rd, n_cpl, n_other
);
    initial begin
        td = 0; tsof = 0; teof = 0; tsrc_rdy = 0; trem = 0;
        n_wr = 0; n_bytes = 0; sum = 0; scratch = 0; last_dw0 = 0; last_dw2 = 0; n_rd = 0; n_cpl = 0; n_other = 0;
    end
    function [31:0] swap(input [31:0] x);
        swap = {x[7:0], x[15:8], x[23:16], x[31:24]};
    endfunction

    reg [31:0] cycles = 0;
    always @(posedge clk) cycles <= cycles + 1'b1;

    // scratch RAM (1024 x 32, one write port, one read port)
    reg [31:0] sram [0:1023];
    reg        s_we = 1'b0;
    reg [9:0]  s_wa = 0, s_ra = 0;
    reg [31:0] s_wd = 0, s_rd = 0;
    always @(posedge clk) begin
        if (s_we) sram[s_wa] <= s_wd;
        s_rd <= sram[s_ra];
    end

    // ---------------------------------------------------------------- RX
    wire [31:0] dw0 = rd[127:96], dw1 = rd[95:64], dw2 = rd[63:32], dw3 = rd[31:0];
    wire [1:0]  fmt = dw0[30:29];
    wire [4:0]  typ = dw0[28:24];
    wire [10:0] len = (dw0[9:0] == 10'd0) ? 11'd1024 : {1'b0, dw0[9:0]};
    wire        is_mem = (typ == 5'b00000);
    reg         in_wr = 1'b0;          // inside a BAR0 write, collecting data beats
    reg  [10:0] remain = 0;            // data DWs still to come
    // pending read
    reg         rq = 1'b0;
    reg  [15:0] rq_id = 0;
    reg  [7:0]  rq_tag = 0;
    reg  [2:0]  rq_tc = 0;
    reg  [1:0]  rq_attr = 0, rq_len = 0;
    reg  [3:0]  rq_fbe = 0, rq_lbe = 0;
    reg  [20:0] rq_addr = 0;
    wire        rq_done;

    // first data DW of a write -> register / scratch RAM
    task automatic first_write(input [20:0] a, input [31:0] v);
        begin
            if (a[20:2] == 19'd1) scratch <= v;
            if (a[20:12] == 9'd1) begin s_we <= 1'b1; s_wa <= a[11:2]; s_wd <= v; end
        end
    endtask

    // sum and count of the valid data DWs of one beat (n = 0..4, taken from the top: rd[127:96] first)
    function [31:0] beat_sum(input [127:0] d, input [2:0] n);
        beat_sum = (n > 0 ? swap(d[127:96]) : 32'd0) + (n > 1 ? swap(d[95:64]) : 32'd0) +
                   (n > 2 ? swap(d[63:32]) : 32'd0) + (n > 3 ? swap(d[31:0]) : 32'd0);
    endfunction

    wire [2:0] n_next = (remain >= 11'd4) ? 3'd4 : remain[2:0];
    always @(posedge clk) begin
        s_we <= 1'b0;
        if (rq_done) rq <= 1'b0;
        if (!rst_n) begin
            in_wr <= 1'b0; rq <= 1'b0;
        end else if (rsrc_rdy) begin
            if (in_wr) begin                                   // data beat of a write
                sum <= sum + beat_sum(rd, n_next);
                n_bytes <= n_bytes + {n_next, 2'b00};
                remain <= remain - n_next;
                if (reof || remain <= 11'd4) in_wr <= 1'b0;
            end else if (rsof) begin
                last_dw0 <= dw0; last_dw2 <= dw2;
                if (is_mem && bar_hit[0] && fmt[1]) begin       // memory write
                    n_wr <= n_wr + 1'b1;
                    if (!fmt[0]) begin                         // 3DW header: the first data DW is in this beat
                        first_write(dw2[20:0], swap(dw3));
                        sum <= sum + swap(dw3);
                        n_bytes <= n_bytes + 3'd4;
                        remain <= len - 1'b1;
                        in_wr <= (len > 11'd1) && !reof;
                    end else begin                             // 4DW header: data starts in the next beat
                        remain <= len;
                        in_wr <= !reof;
                        // the first data DW of a 4DW write is not stored (32-bit BAR addresses use 3DW headers)
                    end
                end else if (is_mem && bar_hit[0] && !fmt[1]) begin   // memory read
                    n_rd <= n_rd + 1'b1;
                    if (rd_en && !rq && len <= 11'd2) begin
                        rq <= 1'b1; rq_id <= dw1[31:16]; rq_tag <= dw1[15:8]; rq_fbe <= dw1[3:0];
                        rq_lbe <= dw1[7:4]; rq_tc <= dw0[22:20]; rq_attr <= dw0[13:12]; rq_len <= len[1:0];
                        rq_addr <= fmt[0] ? dw3[20:0] : dw2[20:0];
                    end
                end else
                    n_other <= n_other + 1'b1;
            end
        end
    end

    // ---------------------------------------------------------------- TX: completion with data (1 or 2 DW)
    // read value of DW address a (scratch RAM data arrives one cycle after s_ra)
    function [31:0] reg_val(input [20:0] a);
        case (a[20:2])
            19'd0: reg_val = 32'hC0DE5303;
            19'd1: reg_val = scratch;
            19'd2: reg_val = n_wr;
            19'd3: reg_val = n_bytes;
            19'd4: reg_val = sum;
            19'd5: reg_val = {16'd0, n_rd};
            19'd6: reg_val = cycles;
            default: reg_val = {11'd0, a};
        endcase
    endfunction
    // byte count and lower address of the completion (PCIe 2.1, 2.3.1.1)
    function [1:0] first_byte(input [3:0] be);
        first_byte = be[0] ? 2'd0 : be[1] ? 2'd1 : be[2] ? 2'd2 : be[3] ? 2'd3 : 2'd0;
    endfunction
    function [11:0] byte_count(input [1:0] l, input [3:0] fbe, input [3:0] lbe);
        reg [2:0] lo, hi;
        begin
            lo = {1'b0, first_byte(fbe)};
            if (l == 2'd1) begin
                hi = fbe[3] ? 3'd4 : fbe[2] ? 3'd3 : fbe[1] ? 3'd2 : 3'd1;
                byte_count = (fbe == 4'd0) ? 12'd1 : {9'd0, hi} - lo;
            end else
                byte_count = 12'd4 + (lbe[3] ? 12'd4 : lbe[2] ? 12'd3 : lbe[1] ? 12'd2 : 12'd1) - lo;
        end
    endfunction

    localparam X_IDLE = 3'd0, X_RAM1 = 3'd1, X_RAM2 = 3'd2, X_B0 = 3'd3, X_B1 = 3'd4, X_DONE = 3'd5;
    reg [2:0]  xs = X_IDLE;
    reg [31:0] d0 = 0, d1 = 0;
    wire       sram_rd = (rq_addr[20:12] == 9'd1);
    assign rq_done = (xs == X_DONE);
    wire [31:0] h0 = {1'b0, 2'b10, 5'b01010, 1'b0, rq_tc, 4'b0, 1'b0, 1'b0, rq_attr, 2'b00, 8'd0, rq_len};
    wire [31:0] h1 = {CPL_ID, 3'b000, 1'b0, byte_count(rq_len, rq_fbe, rq_lbe)};
    wire [31:0] h2 = {rq_id, rq_tag, 1'b0, rq_addr[6:2], first_byte(rq_fbe)};
    always @(posedge clk) begin
        if (!rst_n) begin
            xs <= X_IDLE; tsrc_rdy <= 1'b0;
        end else case (xs)
        X_IDLE: if (rq && tbuf_av != 6'd0) begin
                    s_ra <= rq_addr[11:2];
                    d0 <= reg_val(rq_addr); d1 <= reg_val(rq_addr + 21'd4);
                    xs <= X_RAM1;
                end
        X_RAM1: begin s_ra <= rq_addr[11:2] + 1'b1; xs <= X_RAM2; end          // s_rd = word 0 next cycle
        X_RAM2: begin
                    if (sram_rd) d0 <= s_rd;
                    xs <= X_B0;
                end
        X_B0:   begin
                    if (!tsrc_rdy) begin
                        if (sram_rd && rq_len == 2'd2) d1 <= s_rd;         // word 1 arrived meanwhile
                        td <= {h0, h1, h2, swap(d0)};
                        tsof <= 1'b1; teof <= (rq_len == 2'd1); trem <= 2'b11; tsrc_rdy <= 1'b1;
                    end else if (tdst_rdy) begin
                        tsrc_rdy <= 1'b0;
                        xs <= (rq_len == 2'd1) ? X_DONE : X_B1;
                    end
                end
        X_B1:   begin
                    if (!tsrc_rdy) begin
                        td <= {swap(d1), 96'd0}; tsof <= 1'b0; teof <= 1'b1; trem <= 2'b00; tsrc_rdy <= 1'b1;
                    end else if (tdst_rdy) begin
                        tsrc_rdy <= 1'b0; xs <= X_DONE;
                    end
                end
        X_DONE: begin n_cpl <= n_cpl + 1'b1; xs <= X_IDLE; end
        default: xs <= X_IDLE;
        endcase
    end
endmodule
