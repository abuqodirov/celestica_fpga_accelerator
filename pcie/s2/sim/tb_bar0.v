`timescale 1ns/1ps
// bar0.v testbench: a 1-DW write, a 4-DW write, a scratch-RAM write, then 1-DW / 2-DW reads -> print completions
module tb;
    reg clk = 0; always #4 clk = ~clk;
    reg rst_n = 0, rd_en = 1;
    reg [127:0] rd = 0; reg rsof = 0, reof = 0, rsrc_rdy = 0; reg [7:0] bar_hit = 0;
    wire [127:0] td; wire tsof, teof, tsrc_rdy; wire [1:0] trem;
    reg tdst_rdy = 1;
    wire [31:0] n_wr, n_bytes, sum, scratch, d0, d2; wire [15:0] n_rd, n_cpl, n_other;
    bar0 dut (.clk(clk), .rst_n(rst_n), .rd_en(rd_en), .rd(rd), .rsof(rsof), .reof(reof), .rsrc_rdy(rsrc_rdy),
              .bar_hit(bar_hit), .td(td), .tsof(tsof), .teof(teof), .tsrc_rdy(tsrc_rdy), .trem(trem),
              .tdst_rdy(tdst_rdy), .tbuf_av(6'd29), .n_wr(n_wr), .n_bytes(n_bytes), .sum(sum), .scratch(scratch),
              .last_dw0(d0), .last_dw2(d2), .n_rd(n_rd), .n_cpl(n_cpl), .n_other(n_other));
    function [31:0] sw(input [31:0] x); sw = {x[7:0], x[15:8], x[23:16], x[31:24]}; endfunction
    task beat(input [127:0] d, input s, input e);
        begin @(negedge clk); rd = d; rsof = s; reof = e; rsrc_rdy = 1; bar_hit = 8'h01;
              @(negedge clk); rsrc_rdy = 0; rsof = 0; reof = 0; end
    endtask
    always @(posedge clk) if (tsrc_rdy && tdst_rdy)
        $display("%0t TX sof %b eof %b rem %b  %08x %08x %08x %08x", $time, tsof, teof, trem,
                 td[127:96], td[95:64], td[63:32], td[31:0]);
    initial begin
        repeat (3) @(posedge clk); rst_n = 1;
        // MWr32 len 1 to 0x80800004 (scratch reg), CPU value 0x11223344, req 0x0008 tag 01, fbe F
        beat({32'h40000001, 32'h0008010F, 32'h80800004, sw(32'h11223344)}, 1, 1);
        // MWr32 len 4 to 0x80802000: values 1,2,3,4 (first DW in beat 0, then 3 DWs)
        beat({32'h40000004, 32'h000802FF, 32'h80802000, sw(32'd1)}, 1, 0);
        beat({sw(32'd2), sw(32'd3), sw(32'd4), 32'hdeadbeef}, 0, 1);
        // MWr32 len 1 to scratch RAM word 5 (0x80801014) = 0xCAFEF00D
        beat({32'h40000001, 32'h0008030F, 32'h80801014, sw(32'hCAFEF00D)}, 1, 1);
        repeat (3) @(posedge clk);
        $display("scratch %08x n_wr %0d bytes %0d sum %08x (expect 11223344 4 24 %08x)", scratch, n_wr, n_bytes, sum,
                 32'h11223344 + 32'd10 + 32'hCAFEF00D);
        // MRd32 len 1 at 0x80800000 (magic), tag 0x10
        beat({32'h00000001, 32'h0008100F, 32'h80800000, 32'h0}, 1, 1);
        repeat (12) @(posedge clk);
        // MRd32 len 2 at 0x80801014 (scratch RAM word 5,6), tag 0x11, fbe F lbe F
        beat({32'h00000002, 32'h000811FF, 32'h80801014, 32'h0}, 1, 1);
        repeat (12) @(posedge clk);
        // MRd32 len 1, 2 bytes at offset 0x...06 (fbe 1100) of scratch reg -> byte count 2, lower addr 0x06
        beat({32'h00000001, 32'h0008120C, 32'h80800004, 32'h0}, 1, 1);
        repeat (12) @(posedge clk);
        $display("n_rd %0d n_cpl %0d n_other %0d", n_rd, n_cpl, n_other);
        $finish;
    end
endmodule
