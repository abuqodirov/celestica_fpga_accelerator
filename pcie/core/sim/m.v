// PCIe TRN (128-bit, pclk) <-> command / response streams for the LiteX bus bridge (litex/pcie_bridge.py).
//
// Receive: every TLP from the block goes through a DW serialiser (one DW per clock, so TLPs that start in the
// middle of a beat - TRN 128-bit "straddling": SOF at DW2 when trn_rrem[1] = 0 - need no special case) into a
// TLP parser. Memory writes become one write command per data DW, memory reads one read command. Both go into ONE
// command stream in arrival order, so a read always sees the effect of every earlier write (PCIe ordering).
// The PC's little-endian values are byte-swapped on TRN; commands and responses carry the PC's values.
//   cmd = {is_read, dw address in the 2 MB BAR [18:0], byte enables [3:0], data [31:0]}             (56 bits)
//         read: data = {seq [3:0], 17'd0, length in DW [10:0]}, byte enables 4'hf
//   rsp = {seq [3:0], data [31:0]}: exactly `length` entries per read, in order
// Transmit: one completion with data per read (length 1..MAXRD DW; longer reads get an Unsupported Request
// completion). A completion is sent only when all its data is in the assembly buffer, one beat per clock.
// Back-pressure: TRNRDSTRDY is low while the serialiser holds a beat (the block then keeps further TLPs and stops
// returning credits to the PC).
module pcie_trn_bridge #(parameter [15:0] CPL_ID = 16'h0100, parameter MAXRD = 32) (
    input  wire         clk,
    input  wire         rst_n,
    // TRN receive
    input  wire [127:0] rd,
    input  wire         rsof, reof, rsrc_rdy, rsrc_dsc,
    input  wire [1:0]   rrem,
    output wire         rdst_rdy,
    // TRN transmit
    output reg  [127:0] td,
    output reg          tsof, teof, tsrc_rdy,
    output reg  [1:0]   trem,
    input  wire         tdst_rdy,
    input  wire [5:0]   tbuf_av,
    // command stream (to the bus side)
    output reg          cmd_valid,
    input  wire         cmd_ready,
    output reg  [55:0]  cmd_data,
    // response stream (read data, from the bus side)
    input  wire         rsp_valid,
    output wire         rsp_ready,
    input  wire [35:0]  rsp_data,
    // counters
    output reg  [31:0]  n_wr, n_rd, n_cpl, n_dw,
    output reg  [15:0]  n_other, n_ur, n_dsc, n_stale
);
    function [31:0] swap(input [31:0] x);
        swap = {x[7:0], x[15:8], x[23:16], x[31:24]};
    endfunction
    initial begin
        td = 0; tsof = 0; teof = 0; tsrc_rdy = 0; trem = 0; cmd_valid = 0; cmd_data = 0;
        n_wr = 0; n_rd = 0; n_cpl = 0; n_dw = 0; n_other = 0; n_ur = 0; n_dsc = 0; n_stale = 0;
    end

    // ------------------------------------------------------------------ RX: beat holding register -> DW stream
    // DW i of a beat is rd[127-32i -: 32] (header DW0 first).
    reg  [127:0] hb = 0;
    reg  [3:0]   hmask = 0, hsof = 0, heof = 0;    // per DW: valid, first DW of a TLP, last DW of a TLP
    reg          hdsc = 1'b0;                      // the TLP ending in this beat was discontinued
    reg          in_tlp = 1'b0;
    wire         hv = |hmask;
    assign rdst_rdy = !hv && rst_n;

    wire [1:0] sofpos = rrem[1] ? 2'd2 : 2'd0;
    wire [1:0] eofpos = rrem;
    reg  [3:0] vmask, smask, emask;
    integer i;
    always @(*) begin
        vmask = 0; smask = 0; emask = 0;
        for (i = 0; i < 4; i = i + 1) begin
            // the TLP already in progress: DW 0 .. eof (or the whole beat)
            if (in_tlp && (!reof || i <= eofpos)) vmask[i] = 1'b1;
            // a TLP starting in this beat: DW sofpos .. eof (single-beat TLP) or .. 3
            // (a TLP starting at DW2 cannot end in the same beat: an eof there belongs to the previous TLP)
            if (rsof && i >= sofpos && !(reof && sofpos == 2'd0 && i > eofpos)) vmask[i] = 1'b1;
        end
        if (rsof) smask[sofpos] = 1'b1;
        if (reof) emask[eofpos] = 1'b1;
    end

    // DW stream (consumer: parser below)
    reg  [1:0]  pick;
    always @(*) pick = hmask[0] ? 2'd0 : hmask[1] ? 2'd1 : hmask[2] ? 2'd2 : 2'd3;
    wire [31:0] dw = hb[127 - 32 * pick -: 32];
    wire        d_sof = hsof[pick], d_eof = heof[pick];
    wire        d_valid = hv;
    wire        d_take;                             // parser takes the DW this clock

    always @(posedge clk) begin
        if (!rst_n) begin
            hmask <= 0; in_tlp <= 1'b0;
        end else if (rsrc_rdy && rdst_rdy) begin
            hb <= rd; hmask <= vmask; hsof <= smask; heof <= emask; hdsc <= rsrc_dsc;
            in_tlp <= rsof ? !(reof && sofpos == 2'd0) : (in_tlp && !reof);
            if (rsrc_dsc) n_dsc <= n_dsc + 1'b1;
        end else if (d_take)
            hmask[pick] <= 1'b0;
    end

    // ------------------------------------------------------------------ RX: TLP parser (one DW per clock)
    localparam P_H0 = 3'd0, P_H1 = 3'd1, P_H2 = 3'd2, P_H3 = 3'd3, P_DATA = 3'd4, P_SKIP = 3'd5;
    reg  [2:0]  ps = P_H0;
    reg         p_wr = 1'b0, p_hdr4 = 1'b0, p_mem = 1'b0;
    reg  [10:0] p_len = 0, p_left = 0;
    reg  [2:0]  p_tc = 0;
    reg  [1:0]  p_attr = 0;
    reg  [15:0] p_rid = 0;
    reg  [7:0]  p_tag = 0;
    reg  [3:0]  p_fbe = 0, p_lbe = 0;
    reg  [18:0] p_a = 0;                            // DW address of the next data DW
    reg         p_first = 1'b0;
    reg  [3:0]  seq = 0;

    // pending reads (completion headers), in order
    localparam PQ = 8;
    reg  [63:0] pq [0:PQ-1];
    reg  [2:0]  pq_w = 0, pq_r = 0;
    reg  [3:0]  pq_n = 0;
    wire        pq_full = (pq_n == PQ);
    wire        pq_push, pq_pop;

    // a stage that needs to emit a command waits while the previous one is not taken
    wire cmd_free = !cmd_valid || cmd_ready;
    wire [2:0] pe = d_sof ? P_H0 : ps;     // state for this DW: a TLP's first DW always restarts the parser
    wire is_addr = (pe == P_H2 && !p_hdr4) || pe == P_H3;
    wire need_pq  = is_addr && p_mem && !p_wr;                 // memory read: completion header at the address DW
    wire need_cmd = (pe == P_DATA) || need_pq;
    assign d_take = d_valid && (!need_cmd || cmd_free) && (!need_pq || !pq_full);

    // byte count / lower address of a read's completion (PCIe 2.1, 2.3.1.1)
    function [1:0] first_byte(input [3:0] be);
        first_byte = be[0] ? 2'd0 : be[1] ? 2'd1 : be[2] ? 2'd2 : be[3] ? 2'd3 : 2'd0;
    endfunction
    function [1:0] last_byte(input [3:0] be);         // index of the last enabled byte
        last_byte = be[3] ? 2'd3 : be[2] ? 2'd2 : be[1] ? 2'd1 : 2'd0;
    endfunction
    function [11:0] byte_count(input [10:0] l, input [3:0] fbe, input [3:0] lbe);
        begin
            if (l == 11'd1)
                byte_count = (fbe == 4'd0) ? 12'd1 : {10'd0, last_byte(fbe)} - {10'd0, first_byte(fbe)} + 12'd1;
            else
                byte_count = {l[9:0], 2'b00} - {10'd0, first_byte(fbe)} - (12'd3 - {10'd0, last_byte(lbe)});
        end
    endfunction

    wire [18:0] a_dw = dw[20:2];
    wire        rd_ok = (p_len <= MAXRD);
    // pq entry: {ur, seq[3:0], rid[15:0], tag[7:0], tc[2:0], attr[1:0], len[10:0], la[6:0], bc[11:0]} = 64 bits
    wire [63:0] pq_in = {!rd_ok, seq, p_rid, p_tag, p_tc, p_attr, p_len, {dw[6:2], first_byte(p_fbe)},
                         byte_count(p_len, p_fbe, p_lbe)};
    assign pq_push = d_take && need_pq;

    always @(posedge clk) begin
        if (cmd_valid && cmd_ready) cmd_valid <= 1'b0;
        if (!rst_n) begin
            ps <= P_H0; cmd_valid <= 1'b0;
        end else if (d_take) begin
            case (pe)
            P_H0: if (d_sof) begin
                      p_wr <= dw[30]; p_hdr4 <= dw[29]; p_mem <= (dw[28:24] == 5'b00000);
                      p_len <= (dw[9:0] == 10'd0) ? 11'd1024 : {1'b0, dw[9:0]};
                      p_tc <= dw[22:20]; p_attr <= dw[13:12];
                      ps <= d_eof ? P_H0 : P_H1;
                      if (dw[28:24] != 5'b00000) n_other <= n_other + 1'b1;
                  end
            P_H1: begin
                      p_rid <= dw[31:16]; p_tag <= dw[15:8]; p_lbe <= dw[7:4]; p_fbe <= dw[3:0];
                      ps <= d_eof ? P_H0 : P_H2;
                  end
            P_H2, P_H3: begin
                      if (ps == P_H2 && p_hdr4) ps <= d_eof ? P_H0 : P_H3;          // upper address DW
                      else begin
                          p_a <= a_dw; p_left <= p_len; p_first <= 1'b1;
                          if (!p_mem) ps <= d_eof ? P_H0 : P_SKIP;
                          else if (p_wr) begin
                              n_wr <= n_wr + 1'b1;
                              ps <= d_eof ? P_H0 : P_DATA;
                          end else begin                                        // memory read
                              n_rd <= n_rd + 1'b1;
                              if (rd_ok) begin
                                  cmd_valid <= 1'b1;
                                  cmd_data <= {1'b1, a_dw, 4'hf, seq, 17'd0, p_len};
                              end else
                                  n_ur <= n_ur + 1'b1;
                              seq <= seq + 1'b1;
                              ps <= d_eof ? P_H0 : P_SKIP;
                          end
                      end
                  end
            P_DATA: begin
                      cmd_valid <= 1'b1;
                      cmd_data <= {1'b0, p_a, (p_len == 11'd1) ? p_fbe : p_first ? p_fbe :
                                   (p_left == 11'd1) ? p_lbe : 4'hf, swap(dw)};
                      n_dw <= n_dw + 1'b1;
                      p_a <= p_a + 1'b1; p_left <= p_left - 1'b1; p_first <= 1'b0;
                      if (d_eof || p_left == 11'd1) ps <= d_eof ? P_H0 : P_SKIP;
                  end
            P_SKIP: if (d_eof) ps <= P_H0;
            default: ps <= P_H0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (pq_push) begin pq[pq_w] <= pq_in; pq_w <= pq_w + 1'b1; end
        if (pq_pop) pq_r <= pq_r + 1'b1;
        if (!rst_n) begin pq_w <= 0; pq_r <= 0; pq_n <= 0; end
        else pq_n <= pq_n + pq_push - pq_pop;
    end

    // ------------------------------------------------------------------ TX: completions
    wire [63:0] hd = pq[pq_r];
    wire        h_ur = hd[63];
    wire [3:0]  h_seq = hd[62:59];
    wire [15:0] h_rid = hd[58:43];
    wire [7:0]  h_tag = hd[42:35];
    wire [2:0]  h_tc = hd[34:32];
    wire [1:0]  h_attr = hd[31:30];
    wire [10:0] h_len = hd[29:19];
    wire [6:0]  h_la = hd[18:12];
    wire [31:0] h0 = h_ur ? {1'b0, 2'b00, 5'b01010, 1'b0, h_tc, 4'b0, 1'b0, 1'b0, h_attr, 2'b00, 10'd0}
                          : {1'b0, 2'b10, 5'b01010, 1'b0, h_tc, 4'b0, 1'b0, 1'b0, h_attr, 2'b00, h_len[9:0]};
    wire [31:0] h1 = {CPL_ID, h_ur ? 3'b001 : 3'b000, 1'b0, h_ur ? 12'd4 : hd[11:0]};
    wire [31:0] h2 = {h_rid, h_tag, 1'b0, h_la};

    // assembly buffer: data DW j goes to beat (j + 3) / 4, position (j + 3) % 4 (beat 0 starts with 3 header DWs)
    localparam NB = (MAXRD + 3 + 3) / 4;            // beats per completion
    reg  [31:0] ab0 [0:NB-1], ab1 [0:NB-1], ab2 [0:NB-1], ab3 [0:NB-1];
    reg  [10:0] aj = 0;                             // data DWs collected for the head read
    reg  [4:0]  bk = 0;                             // beat being sent
    localparam X_COLLECT = 2'd0, X_SEND = 2'd1, X_DONE = 2'd2;
    reg  [1:0]  xs = X_COLLECT;
    wire        have_head = (pq_n != 0);
    // take response DWs while the head read collects its data; with no read outstanding they are stale (left over
    // from before a link reset) and dropped, as are DWs of another sequence number
    assign rsp_ready = rst_n && (xs == X_COLLECT) && (!have_head || (!h_ur && aj != h_len));
    wire        stale = !have_head || rsp_data[35:32] != h_seq;
    wire [10:0] apos = aj + 11'd3;
    wire [4:0]  nbeats = h_ur ? 5'd1 : (h_len + 11'd3 + 11'd3) >> 2;
    wire [1:0]  last_rem = h_ur ? 2'b10 : (h_len[1:0] + 2'd2);             // (3 + len - 1) mod 4
    assign pq_pop = (xs == X_DONE);

    always @(posedge clk) begin
        if (rsp_valid && rsp_ready && !stale) begin
            case (apos[1:0])
            2'd0: ab0[apos[10:2]] <= swap(rsp_data[31:0]);
            2'd1: ab1[apos[10:2]] <= swap(rsp_data[31:0]);
            2'd2: ab2[apos[10:2]] <= swap(rsp_data[31:0]);
            2'd3: ab3[apos[10:2]] <= swap(rsp_data[31:0]);
            endcase
            aj <= aj + 1'b1;
        end
        if (rsp_valid && rsp_ready && stale) n_stale <= n_stale + 1'b1;
        case (xs)
        X_COLLECT: if (have_head && (h_ur || aj == h_len) && tbuf_av != 6'd0 && !tsrc_rdy) begin
                       bk <= 0; xs <= X_SEND;
                       td <= {h0, h1, h2, h_ur ? 32'd0 : ab3[0]};
                       tsof <= 1'b1; teof <= (nbeats == 5'd1); trem <= (nbeats == 5'd1) ? last_rem : 2'b11;
                       tsrc_rdy <= 1'b1;
                   end
        X_SEND:    if (tdst_rdy) begin
                       if (bk + 1'b1 == nbeats) begin
                           tsrc_rdy <= 1'b0; tsof <= 1'b0; teof <= 1'b0; xs <= X_DONE;
                       end else begin
                           td <= {ab0[bk + 1'b1], ab1[bk + 1'b1], ab2[bk + 1'b1], ab3[bk + 1'b1]};
                           tsof <= 1'b0; teof <= (bk + 5'd2 == nbeats);
                           trem <= (bk + 5'd2 == nbeats) ? last_rem : 2'b11;
                           bk <= bk + 1'b1;
                       end
                   end
        X_DONE:    begin aj <= 0; n_cpl <= n_cpl + 1'b1; xs <= X_COLLECT; end
        default:   xs <= X_COLLECT;
        endcase
        if (!rst_n) begin xs <= X_COLLECT; tsrc_rdy <= 1'b0; aj <= 0; end
    end
endmodule
