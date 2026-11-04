// tb_fp32_top.v - both float32 units on the same operands, for tb_fp32.cpp
module tb_fp32_top (input wire clk, input wire [31:0] a, input wire [31:0] b, output wire [31:0] p, output wire [31:0] s);
    fp_mul m (.clk(clk), .a(a), .b(b), .y(p));
    fp_add d (.clk(clk), .a(a), .b(b), .y(s));
endmodule
