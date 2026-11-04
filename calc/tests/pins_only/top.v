// Bisect test 2: no logic at all, only the flash control pins held high.
module top (
    output wire flash_ce_n, output wire flash_oe_n,
    output wire flash_we_n, output wire flash_adv_n
);
    assign flash_ce_n = 1'b1; assign flash_oe_n = 1'b1;
    assign flash_we_n = 1'b1; assign flash_adv_n = 1'b1;
endmodule
