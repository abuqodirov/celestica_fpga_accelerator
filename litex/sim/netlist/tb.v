`timescale 1ns/1ps
module tb;
  reg clk = 0, rst = 1;
  always #6.667 clk = ~clk;
  reg cmd_valid = 0, cmd_we = 0; reg [24:0] cmd_addr = 0; wire cmd_ready;
  reg wdata_valid = 0; reg [255:0] wdata = 0; wire wdata_ready;
  wire rdata_valid; wire [255:0] rdata;
  wire [14:0] a0, a1, a2, a3; wire [2:0] b0, b1, b2, b3;
  wire cs0, cs1, cs2, cs3, ras0, ras1, ras2, ras3, cas0, cas1, cas2, cas3, we0, we1, we2, we3;
  wire wen0, wen1, wen2, wen3, ren0, ren1, ren2, ren3;
  ctrl_top dut(.sys_clk(clk), .sys_rst(rst), .rdphase(2'd3), .wrphase(2'd3),
    .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_payload_we(cmd_we), .cmd_payload_addr(cmd_addr),
    .wdata_valid(wdata_valid), .wdata_ready(wdata_ready), .wdata_payload_data(wdata), .wdata_payload_we(32'hffffffff),
    .rdata_valid(rdata_valid), .rdata_ready(1'b1), .rdata_payload_data(rdata),
    .p0_address(a0), .p1_address(a1), .p2_address(a2), .p3_address(a3),
    .p0_bank(b0), .p1_bank(b1), .p2_bank(b2), .p3_bank(b3),
    .p0_cs_n(cs0), .p1_cs_n(cs1), .p2_cs_n(cs2), .p3_cs_n(cs3),
    .p0_ras_n(ras0), .p1_ras_n(ras1), .p2_ras_n(ras2), .p3_ras_n(ras3),
    .p0_cas_n(cas0), .p1_cas_n(cas1), .p2_cas_n(cas2), .p3_cas_n(cas3),
    .p0_we_n(we0), .p1_we_n(we1), .p2_we_n(we2), .p3_we_n(we3),
    .p0_wrdata_en(wen0), .p1_wrdata_en(wen1), .p2_wrdata_en(wen2), .p3_wrdata_en(wen3),
    .p0_rddata_en(ren0), .p1_rddata_en(ren1), .p2_rddata_en(ren2), .p3_rddata_en(ren3));
  integer cyc = 0;
  task show(input integer ph, input cs, input ras, input cas, input we, input [14:0] a, input [2:0] b);
    begin
      if (!cs && !(ras && cas && we))
        $display("%5d p%0d %s row/col=%0d bank=%0d", cyc, ph,
          (!ras && cas && we) ? "ACT" : (ras && !cas && we) ? "RD " : (ras && !cas && !we) ? "WR " :
          (!ras && cas && !we) ? "PRE" : (!ras && !cas && we) ? "REF" : "???", a, b);
    end
  endtask
  always @(posedge clk) begin
    cyc <= cyc + 1;
    show(0, cs0, ras0, cas0, we0, a0, b0); show(1, cs1, ras1, cas1, we1, a1, b1);
    show(2, cs2, ras2, cas2, we2, a2, b2); show(3, cs3, ras3, cas3, we3, a3, b3);
  end
  integer i;
  initial begin
    repeat (10) @(posedge clk); rst <= 0;
    repeat (200) @(posedge clk);
    for (i = 0; i < 8; i = i + 1) begin
      cmd_valid <= 1; cmd_we <= (i < 4); cmd_addr <= (5 << 10) | (64 >> 3) + (i % 4);
      @(posedge clk); while (!cmd_ready) @(posedge clk);
      cmd_valid <= 0;
      if (i == 3) repeat (20) @(posedge clk);
    end
    repeat (60) @(posedge clk);
    $finish;
  end
  initial begin #200000; $display("WATCHDOG cmd_ready=%b wdata_ready=%b", cmd_ready, wdata_ready); $finish; end
  integer n = 0;
  always @(posedge clk) begin
    wdata_valid <= (n < 4);
    wdata <= {8{n[31:0] + 32'hA0}};
    if (wdata_valid && wdata_ready) n <= n + 1;
  end
endmodule
