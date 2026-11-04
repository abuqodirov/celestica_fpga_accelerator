// Testbench for pcie_trn_bridge.v: random TLP streams (memory writes with byte enables, 3DW and 4DW headers,
// memory reads of 1..40 DW incl. too long ones -> UR, messages to ignore), packed into 128-bit TRN beats with
// straddling (a TLP starting at DW2 after one ending at DW0/DW1, or at DW2 of an otherwise empty beat), random
// source gaps, random back-pressure on the command stream, the response stream and the TX side. Checks every command
// against the expected sequence and every completion (header DWs + data + trem) against a reference memory.
//   iverilog -g2005 -o tb tb_bridge.v ../pcie_trn_bridge.v && vvp tb +seed=N +ntlp=N
`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 0;
    always #4 clk = ~clk;

    reg  [127:0] rd = 0;
    reg          rsof = 0, reof = 0, rsrc_rdy = 0, rsrc_dsc = 0;
    reg  [1:0]   rrem = 0;
    wire         rdst_rdy;
    wire [127:0] td;
    wire         tsof, teof, tsrc_rdy;
    wire [1:0]   trem;
    reg          tdst_rdy = 1;
    reg  [5:0]   tbuf_av = 6'd8;
    wire         cmd_valid;
    reg          cmd_ready = 1;
    wire [55:0]  cmd_data;
    reg          rsp_valid = 0;
    wire         rsp_ready;
    reg  [35:0]  rsp_data = 0;
    wire [31:0]  n_wr, n_rd, n_cpl, n_dw;
    wire [15:0]  n_other, n_ur, n_dsc, n_stale;

    pcie_trn_bridge #(.MAXRD(32)) dut (.clk(clk), .rst_n(rst_n),
        .rd(rd), .rsof(rsof), .reof(reof), .rsrc_rdy(rsrc_rdy), .rsrc_dsc(rsrc_dsc), .rrem(rrem), .rdst_rdy(rdst_rdy),
        .td(td), .tsof(tsof), .teof(teof), .tsrc_rdy(tsrc_rdy), .trem(trem), .tdst_rdy(tdst_rdy), .tbuf_av(tbuf_av),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_data(cmd_data),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .n_wr(n_wr), .n_rd(n_rd), .n_cpl(n_cpl), .n_dw(n_dw), .n_other(n_other), .n_ur(n_ur), .n_dsc(n_dsc),
        .n_stale(n_stale));

    function [31:0] swap(input [31:0] x);
        swap = {x[7:0], x[15:8], x[23:16], x[31:24]};
    endfunction

    integer seed, ntlp, errors = 0, pgap, pcmd, prsp, ptx;
    // ---------------------------------------------------------------- generation
    localparam MAXDW = 400000, MAXB = 200000, MAXC = 40000;
    localparam [11:0] AMASK = 12'hfff;
    reg [31:0] q_dw [0:MAXDW-1];  reg q_sof [0:MAXDW-1];  reg q_eof [0:MAXDW-1];
    integer nq = 0;
    reg [55:0] ecmd [0:MAXDW-1];  integer necmd = 0, gotcmd = 0;
    reg [31:0] ecpl_h0 [0:MAXC], ecpl_h1 [0:MAXC], ecpl_h2 [0:MAXC];
    integer    ecpl_d0 [0:MAXC];
    reg [31:0] ecpl_data [0:MAXDW-1];
    integer necpl = 0, necpl_data = 0, gotcpl = 0, nmsg = 0, nur = 0, nwr = 0, nrd = 0;
    reg [31:0] refmem [0:4095];
    reg [3:0]  seq = 0;

    task push_dw(input [31:0] d, input s, input e);
        begin q_dw[nq] = d; q_sof[nq] = s; q_eof[nq] = e; nq = nq + 1; end
    endtask

    // packed beats
    reg [127:0] b_d [0:MAXB-1];  reg b_sof [0:MAXB-1];  reg b_eof [0:MAXB-1];  reg [1:0] b_rem [0:MAXB-1];
    integer nb = 0, nstr = 0, nmid = 0;
    task new_beat;
        begin nb = nb + 1; b_d[nb] = 0; b_sof[nb] = 0; b_eof[nb] = 0; b_rem[nb] = 2'b11; end
    endtask

    integer t, k, len, kind, fb, lbi, bc, la, qi, pos, done;
    reg [3:0] fbe, lbe, be;
    reg [18:0] a;
    reg [31:0] v, m;
    reg [7:0] tag;
    initial begin
        if (!$value$plusargs("seed=%d", seed)) seed = 1;
        if (!$value$plusargs("ntlp=%d", ntlp)) ntlp = 3000;
        if (!$value$plusargs("pgap=%d", pgap)) pgap = 25;     // % of cycles with no RX beat offered
        if (!$value$plusargs("pcmd=%d", pcmd)) pcmd = 30;     // % of cycles with the command stream stalled
        if (!$value$plusargs("prsp=%d", prsp)) prsp = 30;
        if (!$value$plusargs("ptx=%d", ptx)) ptx = 20;
        for (k = 0; k < 4096; k = k + 1) refmem[k] = 0;
        for (t = 0; t < ntlp; t = t + 1) begin
            kind = {$random(seed)} % 128;
            a = {$random(seed)} & 19'h7ffff;
            tag = $random(seed);
            if (kind < 70) begin                                  // memory write, 1..20 DW
                nwr = nwr + 1;
                len = 1 + ({$random(seed)} % (kind < 20 ? 20 : 2));
                fbe = $random(seed); lbe = $random(seed);
                if (len == 1) lbe = 0; else begin if (fbe == 0) fbe = 4'hf; if (lbe == 0) lbe = 4'hf; end
                if (kind < 5) begin                               // 4DW header (64-bit address, upper DW 0)
                    push_dw({1'b0, 2'b11, 5'b00000, 14'd0, len[9:0]}, 1, 0);
                    push_dw({16'h0000, tag, lbe, fbe}, 0, 0);
                    push_dw(32'd0, 0, 0);
                    push_dw({11'h404, a, 2'b00}, 0, 0);
                end else begin
                    push_dw({1'b0, 2'b10, 5'b00000, 14'd0, len[9:0]}, 1, 0);
                    push_dw({16'h0000, tag, lbe, fbe}, 0, 0);
                    push_dw({11'h404, a, 2'b00}, 0, 0);              // BAR at 0x80800000: upper bits ignored
                end
                for (k = 0; k < len; k = k + 1) begin
                    v = $random(seed);
                    be = (len == 1) ? fbe : (k == 0) ? fbe : (k == len - 1) ? lbe : 4'hf;
                    push_dw(swap(v), 0, k == len - 1);
                    ecmd[necmd] = {1'b0, a + k[18:0], be, v}; necmd = necmd + 1;
                    m = {{8{be[3]}}, {8{be[2]}}, {8{be[1]}}, {8{be[0]}}};
                    refmem[(a + k) & AMASK] = (refmem[(a + k) & AMASK] & ~m) | (v & m);
                end
            end else if (kind < 120) begin                        // memory read, 1..40 DW
                nrd = nrd + 1;
                len = 1 + ({$random(seed)} % (kind < 100 ? 4 : 40));
                fbe = $random(seed); lbe = $random(seed);
                if (len == 1) lbe = 0; else begin if (fbe == 0) fbe = 4'hf; if (lbe == 0) lbe = 4'hf; end
                push_dw({1'b0, 2'b00, 5'b00000, 1'b0, 3'd2, 4'd0, 1'b0, 1'b0, 2'b01, 2'b00, len[9:0]}, 1, 0);
                push_dw({16'h0010, tag, lbe, fbe}, 0, 0);
                push_dw({11'h404, a, 2'b00}, 0, 1);
                fb = fbe[0] ? 0 : fbe[1] ? 1 : fbe[2] ? 2 : fbe[3] ? 3 : 0;
                lbi = lbe[3] ? 3 : lbe[2] ? 2 : lbe[1] ? 1 : 0;
                if (len == 1) bc = (fbe == 0) ? 1 : ((fbe[3] ? 3 : fbe[2] ? 2 : fbe[1] ? 1 : 0) - fb + 1);
                else bc = len * 4 - fb - (3 - lbi);
                la = {a[4:0], 2'b00} + fb;
                if (len <= 32) begin
                    ecmd[necmd] = {1'b1, a, 4'hf, seq, 17'd0, len[10:0]}; necmd = necmd + 1;
                    ecpl_h0[necpl] = {1'b0, 2'b10, 5'b01010, 1'b0, 3'd2, 4'b0, 2'b00, 2'b01, 2'b00, len[9:0]};
                    ecpl_h1[necpl] = {16'h0100, 3'b000, 1'b0, bc[11:0]};
                    ecpl_d0[necpl] = necpl_data;
                    for (k = 0; k < len; k = k + 1) begin
                        ecpl_data[necpl_data] = refmem[(a + k) & AMASK]; necpl_data = necpl_data + 1;
                    end
                end else begin
                    nur = nur + 1;
                    ecpl_h0[necpl] = {1'b0, 2'b00, 5'b01010, 1'b0, 3'd2, 4'b0, 2'b00, 2'b01, 2'b00, 10'd0};
                    ecpl_h1[necpl] = {16'h0100, 3'b001, 1'b0, 12'd4};
                    ecpl_d0[necpl] = necpl_data;
                end
                ecpl_h2[necpl] = {16'h0010, tag, 1'b0, la[6:0]};
                necpl = necpl + 1;
                seq = seq + 1;
            end else begin                                        // message (ignored), 4DW header, maybe data
                nmsg = nmsg + 1;
                len = {$random(seed)} % 3;
                push_dw({1'b0, len != 0, 1'b1, 5'b10100, 14'd0, len[9:0]}, 1, 0);
                push_dw(32'h0000_7f00, 0, 0);
                push_dw(32'h0, 0, 0);
                push_dw(32'h0, 0, len == 0);
                for (k = 0; k < len; k = k + 1) push_dw($random(seed), 0, k == len - 1);
            end
        end
        // pack into beats
        nb = -1; new_beat; qi = 0; pos = 0;
        while (qi < nq) begin
            if (pos == 1 || pos == 2) begin
                if (({$random(seed)} % 3) != 0) begin pos = 2; nstr = nstr + 1; end   // straddle into this beat
                else begin new_beat; pos = 0; end
            end else if (pos == 3) begin new_beat; pos = 0; end
            else if (({$random(seed)} % 16) == 0) begin pos = 2; nmid = nmid + 1; end   // DW2 of an empty beat
            b_sof[nb] = 1;
            if (!b_eof[nb]) b_rem[nb] = (pos == 0) ? 2'b11 : 2'b01;   // rrem[1] = 1: sof at DW0, 0: at DW2
            done = 0;
            while (!done) begin
                b_d[nb][127 - 32 * pos -: 32] = q_dw[qi];
                if (q_eof[qi]) begin b_eof[nb] = 1; b_rem[nb] = pos; done = 1; end
                qi = qi + 1; pos = pos + 1;
                if (pos == 4) begin new_beat; pos = 0; end
            end
        end
        if (pos != 0) nb = nb + 1;
        $display("generated %0d TLPs (%0d writes, %0d reads incl. %0d UR, %0d messages): %0d DW, %0d beats, %0d straddled, %0d at DW2 of an empty beat",
                 ntlp, nwr, nrd, nur, nmsg, nq, nb, nstr, nmid);
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    // ---------------------------------------------------------------- RX driver
    integer bi = 0;
    always @(posedge clk) if (rst_n) begin
        if (rsrc_rdy && rdst_rdy) bi = bi + 1;
        if (!rsrc_rdy || rdst_rdy) begin
            if (bi < nb && ({$random(seed)} % 100) >= pgap) begin
                rd <= b_d[bi]; rsof <= b_sof[bi]; reof <= b_eof[bi]; rrem <= b_rem[bi]; rsrc_rdy <= 1;
            end else begin
                rsrc_rdy <= 0; rd <= {4{32'hdeadbeef}}; rsof <= ($random(seed) & 1); reof <= ($random(seed) & 1);
            end
        end
    end

    // ---------------------------------------------------------------- bus side model: in-order commands
    reg [31:0] sysmem [0:4095];
    reg [35:0] rq [0:MAXDW-1];
    integer rq_w = 0, rq_r = 0, kk;
    initial for (kk = 0; kk < 4096; kk = kk + 1) sysmem[kk] = 0;
    reg [31:0] mm;
    always @(posedge clk) begin
        cmd_ready <= ({$random(seed)} % 100) >= pcmd;
        if (cmd_valid && cmd_ready) begin
            if (gotcmd >= necmd || cmd_data !== ecmd[gotcmd]) begin
                errors = errors + 1;
                if (errors < 10) $display("CMD %0d: got %h expected %h", gotcmd, cmd_data, ecmd[gotcmd]);
            end
            gotcmd = gotcmd + 1;
            if (!cmd_data[55]) begin
                mm = {{8{cmd_data[35]}}, {8{cmd_data[34]}}, {8{cmd_data[33]}}, {8{cmd_data[32]}}};
                sysmem[cmd_data[47:36] & AMASK] = (sysmem[cmd_data[47:36] & AMASK] & ~mm) | (cmd_data[31:0] & mm);
            end else
                for (kk = 0; kk < cmd_data[10:0]; kk = kk + 1) begin
                    rq[rq_w] = {cmd_data[31:28], sysmem[(cmd_data[47:36] + kk) & AMASK]}; rq_w = rq_w + 1;
                end
        end
    end
    always @(posedge clk) begin
        if (rsp_valid && rsp_ready) rq_r = rq_r + 1;
        if (!rsp_valid || rsp_ready) begin
            if (rq_r < rq_w && ({$random(seed)} % 100) >= prsp) begin rsp_valid <= 1; rsp_data <= rq[rq_r]; end
            else rsp_valid <= 0;
        end
    end

    // ---------------------------------------------------------------- TX checker
    integer ck = 0, clen = 0, cpos = 0, nbeat = 0;
    reg     cur_ur = 0;
    integer p, hi;
    reg [31:0] dwv;
    always @(posedge clk) begin
        tdst_rdy <= ({$random(seed)} % 100) >= ptx;
        if (tsrc_rdy && tdst_rdy) begin
            if (tsof) begin
                if (gotcpl >= necpl) begin errors = errors + 1; $display("unexpected completion"); end
                if (td[127:96] !== ecpl_h0[gotcpl] || td[95:64] !== ecpl_h1[gotcpl] || td[63:32] !== ecpl_h2[gotcpl]) begin
                    errors = errors + 1;
                    if (errors < 10) $display("CPL %0d header: got %h %h %h expected %h %h %h", gotcpl,
                        td[127:96], td[95:64], td[63:32], ecpl_h0[gotcpl], ecpl_h1[gotcpl], ecpl_h2[gotcpl]);
                end
                cur_ur = (ecpl_h1[gotcpl][15:13] != 3'b000);
                clen = cur_ur ? 0 : ecpl_h0[gotcpl][9:0];
                ck = 0; cpos = 3; nbeat = 0;
            end
            // data DWs of this beat
            hi = teof ? trem : 3;
            for (p = (tsof ? 3 : 0); p <= hi; p = p + 1) begin
                dwv = swap(td[127 - 32 * p -: 32]);
                if (ck >= clen) begin
                    errors = errors + 1;
                    if (errors < 10) $display("CPL %0d: extra DW at beat %0d pos %0d (trem %0d)", gotcpl, nbeat, p, trem);
                end else if (dwv !== ecpl_data[ecpl_d0[gotcpl] + ck]) begin
                    errors = errors + 1;
                    if (errors < 10) $display("CPL %0d data %0d: got %h expected %h", gotcpl, ck, dwv,
                                              ecpl_data[ecpl_d0[gotcpl] + ck]);
                end
                ck = ck + 1;
            end
            if (tsof && teof && cur_ur && trem !== 2'b10) begin errors = errors + 1; $display("UR trem %0d", trem); end
            nbeat = nbeat + 1;
            if (teof) begin
                if (ck + (cur_ur ? 0 : 0) != clen && !(cur_ur && ck == 0)) begin
                    errors = errors + 1;
                    if (errors < 10) $display("CPL %0d: %0d data DWs, expected %0d", gotcpl, ck, clen);
                end
                gotcpl = gotcpl + 1;
            end
        end
    end

    // ---------------------------------------------------------------- end
    integer cyc = 0, idle = 0;
    always @(posedge clk) begin
        cyc = cyc + 1;
        idle = (rst_n && bi >= nb && gotcmd == necmd && gotcpl == necpl && !tsrc_rdy) ? idle + 1 : 0;
        if (idle == 10) begin                   // a few clocks for the counters to settle
            if (n_ur != nur || n_other != nmsg || n_wr != nwr || n_rd != nrd || n_cpl != necpl || n_stale != 0) begin
                errors = errors + 1;
                $display("counters: wr %0d/%0d rd %0d/%0d ur %0d/%0d other %0d/%0d cpl %0d/%0d stale %0d",
                         n_wr, nwr, n_rd, nrd, n_ur, nur, n_other, nmsg, n_cpl, necpl, n_stale);
            end
            $display("%s: %0d commands, %0d completions (%0d data DW) in %0d cycles, %0d errors",
                     errors ? "FAIL" : "PASS", gotcmd, gotcpl, necpl_data, cyc, errors);
            $finish;
        end
        if (cyc > 20000000) begin
            $display("FAIL: timeout (beat %0d/%0d, cmd %0d/%0d, cpl %0d/%0d)", bi, nb, gotcmd, necmd, gotcpl, necpl);
            $finish;
        end
    end
endmodule
