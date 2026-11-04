/* Machine-generated using Migen */
module ctrl_top(
	input [1:0] rdphase,
	input [1:0] wrphase,
	input cmd_valid,
	output cmd_ready,
	input cmd_payload_we,
	input [24:0] cmd_payload_addr,
	input wdata_valid,
	output wdata_ready,
	input [255:0] wdata_payload_data,
	input [31:0] wdata_payload_we,
	output rdata_valid,
	input rdata_ready,
	output [255:0] rdata_payload_data,
	output [14:0] p0_address,
	output [2:0] p0_bank,
	output p0_cs_n,
	output p0_ras_n,
	output p0_cas_n,
	output p0_we_n,
	output p0_wrdata_en,
	output p0_rddata_en,
	output [14:0] p1_address,
	output [2:0] p1_bank,
	output p1_cs_n,
	output p1_ras_n,
	output p1_cas_n,
	output p1_we_n,
	output p1_wrdata_en,
	output p1_rddata_en,
	output [14:0] p2_address,
	output [2:0] p2_bank,
	output p2_cs_n,
	output p2_ras_n,
	output p2_cas_n,
	output p2_we_n,
	output p2_wrdata_en,
	output p2_rddata_en,
	output [14:0] p3_address,
	output [2:0] p3_bank,
	output p3_cs_n,
	output p3_ras_n,
	output p3_cas_n,
	output p3_we_n,
	output p3_wrdata_en,
	output p3_rddata_en,
	input sys_clk,
	input sys_rst
);

wire [14:0] phy_dfi_p0_address;
wire [2:0] phy_dfi_p0_bank;
wire phy_dfi_p0_cas_n;
wire phy_dfi_p0_cs_n;
wire phy_dfi_p0_ras_n;
wire phy_dfi_p0_we_n;
wire phy_dfi_p0_cke;
wire phy_dfi_p0_odt;
wire phy_dfi_p0_reset_n;
wire phy_dfi_p0_act_n;
wire [63:0] phy_dfi_p0_wrdata;
wire phy_dfi_p0_wrdata_en;
wire [7:0] phy_dfi_p0_wrdata_mask;
wire phy_dfi_p0_rddata_en;
reg [63:0] phy_dfi_p0_rddata = 64'd0;
wire phy_dfi_p0_rddata_valid;
wire [14:0] phy_dfi_p1_address;
wire [2:0] phy_dfi_p1_bank;
wire phy_dfi_p1_cas_n;
wire phy_dfi_p1_cs_n;
wire phy_dfi_p1_ras_n;
wire phy_dfi_p1_we_n;
wire phy_dfi_p1_cke;
wire phy_dfi_p1_odt;
wire phy_dfi_p1_reset_n;
wire phy_dfi_p1_act_n;
wire [63:0] phy_dfi_p1_wrdata;
wire phy_dfi_p1_wrdata_en;
wire [7:0] phy_dfi_p1_wrdata_mask;
wire phy_dfi_p1_rddata_en;
reg [63:0] phy_dfi_p1_rddata = 64'd0;
wire phy_dfi_p1_rddata_valid;
wire [14:0] phy_dfi_p2_address;
wire [2:0] phy_dfi_p2_bank;
wire phy_dfi_p2_cas_n;
wire phy_dfi_p2_cs_n;
wire phy_dfi_p2_ras_n;
wire phy_dfi_p2_we_n;
wire phy_dfi_p2_cke;
wire phy_dfi_p2_odt;
wire phy_dfi_p2_reset_n;
wire phy_dfi_p2_act_n;
wire [63:0] phy_dfi_p2_wrdata;
wire phy_dfi_p2_wrdata_en;
wire [7:0] phy_dfi_p2_wrdata_mask;
wire phy_dfi_p2_rddata_en;
reg [63:0] phy_dfi_p2_rddata = 64'd0;
wire phy_dfi_p2_rddata_valid;
wire [14:0] phy_dfi_p3_address;
wire [2:0] phy_dfi_p3_bank;
wire phy_dfi_p3_cas_n;
wire phy_dfi_p3_cs_n;
wire phy_dfi_p3_ras_n;
wire phy_dfi_p3_we_n;
wire phy_dfi_p3_cke;
wire phy_dfi_p3_odt;
wire phy_dfi_p3_reset_n;
wire phy_dfi_p3_act_n;
wire [63:0] phy_dfi_p3_wrdata;
wire phy_dfi_p3_wrdata_en;
wire [7:0] phy_dfi_p3_wrdata_mask;
wire phy_dfi_p3_rddata_en;
reg [63:0] phy_dfi_p3_rddata = 64'd0;
wire phy_dfi_p3_rddata_valid;
wire [14:0] core_slave_p0_address;
wire [2:0] core_slave_p0_bank;
wire core_slave_p0_cas_n;
wire core_slave_p0_cs_n;
wire core_slave_p0_ras_n;
wire core_slave_p0_we_n;
wire core_slave_p0_cke;
wire core_slave_p0_odt;
wire core_slave_p0_reset_n;
wire core_slave_p0_act_n;
wire [63:0] core_slave_p0_wrdata;
wire core_slave_p0_wrdata_en;
wire [7:0] core_slave_p0_wrdata_mask;
wire core_slave_p0_rddata_en;
reg [63:0] core_slave_p0_rddata;
reg core_slave_p0_rddata_valid;
wire [14:0] core_slave_p1_address;
wire [2:0] core_slave_p1_bank;
wire core_slave_p1_cas_n;
wire core_slave_p1_cs_n;
wire core_slave_p1_ras_n;
wire core_slave_p1_we_n;
wire core_slave_p1_cke;
wire core_slave_p1_odt;
wire core_slave_p1_reset_n;
wire core_slave_p1_act_n;
wire [63:0] core_slave_p1_wrdata;
wire core_slave_p1_wrdata_en;
wire [7:0] core_slave_p1_wrdata_mask;
wire core_slave_p1_rddata_en;
reg [63:0] core_slave_p1_rddata;
reg core_slave_p1_rddata_valid;
wire [14:0] core_slave_p2_address;
wire [2:0] core_slave_p2_bank;
wire core_slave_p2_cas_n;
wire core_slave_p2_cs_n;
wire core_slave_p2_ras_n;
wire core_slave_p2_we_n;
wire core_slave_p2_cke;
wire core_slave_p2_odt;
wire core_slave_p2_reset_n;
wire core_slave_p2_act_n;
wire [63:0] core_slave_p2_wrdata;
wire core_slave_p2_wrdata_en;
wire [7:0] core_slave_p2_wrdata_mask;
wire core_slave_p2_rddata_en;
reg [63:0] core_slave_p2_rddata;
reg core_slave_p2_rddata_valid;
wire [14:0] core_slave_p3_address;
wire [2:0] core_slave_p3_bank;
wire core_slave_p3_cas_n;
wire core_slave_p3_cs_n;
wire core_slave_p3_ras_n;
wire core_slave_p3_we_n;
wire core_slave_p3_cke;
wire core_slave_p3_odt;
wire core_slave_p3_reset_n;
wire core_slave_p3_act_n;
wire [63:0] core_slave_p3_wrdata;
wire core_slave_p3_wrdata_en;
wire [7:0] core_slave_p3_wrdata_mask;
wire core_slave_p3_rddata_en;
reg [63:0] core_slave_p3_rddata;
reg core_slave_p3_rddata_valid;
reg [14:0] core_master_p0_address;
reg [2:0] core_master_p0_bank;
reg core_master_p0_cas_n;
reg core_master_p0_cs_n;
reg core_master_p0_ras_n;
reg core_master_p0_we_n;
reg core_master_p0_cke;
reg core_master_p0_odt;
reg core_master_p0_reset_n;
reg core_master_p0_act_n;
reg [63:0] core_master_p0_wrdata;
reg core_master_p0_wrdata_en;
reg [7:0] core_master_p0_wrdata_mask;
reg core_master_p0_rddata_en;
wire [63:0] core_master_p0_rddata;
wire core_master_p0_rddata_valid;
reg [14:0] core_master_p1_address;
reg [2:0] core_master_p1_bank;
reg core_master_p1_cas_n;
reg core_master_p1_cs_n;
reg core_master_p1_ras_n;
reg core_master_p1_we_n;
reg core_master_p1_cke;
reg core_master_p1_odt;
reg core_master_p1_reset_n;
reg core_master_p1_act_n;
reg [63:0] core_master_p1_wrdata;
reg core_master_p1_wrdata_en;
reg [7:0] core_master_p1_wrdata_mask;
reg core_master_p1_rddata_en;
wire [63:0] core_master_p1_rddata;
wire core_master_p1_rddata_valid;
reg [14:0] core_master_p2_address;
reg [2:0] core_master_p2_bank;
reg core_master_p2_cas_n;
reg core_master_p2_cs_n;
reg core_master_p2_ras_n;
reg core_master_p2_we_n;
reg core_master_p2_cke;
reg core_master_p2_odt;
reg core_master_p2_reset_n;
reg core_master_p2_act_n;
reg [63:0] core_master_p2_wrdata;
reg core_master_p2_wrdata_en;
reg [7:0] core_master_p2_wrdata_mask;
reg core_master_p2_rddata_en;
wire [63:0] core_master_p2_rddata;
wire core_master_p2_rddata_valid;
reg [14:0] core_master_p3_address;
reg [2:0] core_master_p3_bank;
reg core_master_p3_cas_n;
reg core_master_p3_cs_n;
reg core_master_p3_ras_n;
reg core_master_p3_we_n;
reg core_master_p3_cke;
reg core_master_p3_odt;
reg core_master_p3_reset_n;
reg core_master_p3_act_n;
reg [63:0] core_master_p3_wrdata;
reg core_master_p3_wrdata_en;
reg [7:0] core_master_p3_wrdata_mask;
reg core_master_p3_rddata_en;
wire [63:0] core_master_p3_rddata;
wire core_master_p3_rddata_valid;
wire [14:0] core_csr_dfi_p0_address;
wire [2:0] core_csr_dfi_p0_bank;
reg core_csr_dfi_p0_cas_n;
reg core_csr_dfi_p0_cs_n;
reg core_csr_dfi_p0_ras_n;
reg core_csr_dfi_p0_we_n;
wire core_csr_dfi_p0_cke;
wire core_csr_dfi_p0_odt;
wire core_csr_dfi_p0_reset_n;
reg core_csr_dfi_p0_act_n = 1'd1;
wire [63:0] core_csr_dfi_p0_wrdata;
wire core_csr_dfi_p0_wrdata_en;
wire [7:0] core_csr_dfi_p0_wrdata_mask;
wire core_csr_dfi_p0_rddata_en;
reg [63:0] core_csr_dfi_p0_rddata;
reg core_csr_dfi_p0_rddata_valid;
wire [14:0] core_csr_dfi_p1_address;
wire [2:0] core_csr_dfi_p1_bank;
reg core_csr_dfi_p1_cas_n;
reg core_csr_dfi_p1_cs_n;
reg core_csr_dfi_p1_ras_n;
reg core_csr_dfi_p1_we_n;
wire core_csr_dfi_p1_cke;
wire core_csr_dfi_p1_odt;
wire core_csr_dfi_p1_reset_n;
reg core_csr_dfi_p1_act_n = 1'd1;
wire [63:0] core_csr_dfi_p1_wrdata;
wire core_csr_dfi_p1_wrdata_en;
wire [7:0] core_csr_dfi_p1_wrdata_mask;
wire core_csr_dfi_p1_rddata_en;
reg [63:0] core_csr_dfi_p1_rddata;
reg core_csr_dfi_p1_rddata_valid;
wire [14:0] core_csr_dfi_p2_address;
wire [2:0] core_csr_dfi_p2_bank;
reg core_csr_dfi_p2_cas_n;
reg core_csr_dfi_p2_cs_n;
reg core_csr_dfi_p2_ras_n;
reg core_csr_dfi_p2_we_n;
wire core_csr_dfi_p2_cke;
wire core_csr_dfi_p2_odt;
wire core_csr_dfi_p2_reset_n;
reg core_csr_dfi_p2_act_n = 1'd1;
wire [63:0] core_csr_dfi_p2_wrdata;
wire core_csr_dfi_p2_wrdata_en;
wire [7:0] core_csr_dfi_p2_wrdata_mask;
wire core_csr_dfi_p2_rddata_en;
reg [63:0] core_csr_dfi_p2_rddata;
reg core_csr_dfi_p2_rddata_valid;
wire [14:0] core_csr_dfi_p3_address;
wire [2:0] core_csr_dfi_p3_bank;
reg core_csr_dfi_p3_cas_n;
reg core_csr_dfi_p3_cs_n;
reg core_csr_dfi_p3_ras_n;
reg core_csr_dfi_p3_we_n;
wire core_csr_dfi_p3_cke;
wire core_csr_dfi_p3_odt;
wire core_csr_dfi_p3_reset_n;
reg core_csr_dfi_p3_act_n = 1'd1;
wire [63:0] core_csr_dfi_p3_wrdata;
wire core_csr_dfi_p3_wrdata_en;
wire [7:0] core_csr_dfi_p3_wrdata_mask;
wire core_csr_dfi_p3_rddata_en;
reg [63:0] core_csr_dfi_p3_rddata;
reg core_csr_dfi_p3_rddata_valid;
reg [14:0] core_ext_dfi_p0_address = 15'd0;
reg [2:0] core_ext_dfi_p0_bank = 3'd0;
reg core_ext_dfi_p0_cas_n = 1'd1;
reg core_ext_dfi_p0_cs_n = 1'd1;
reg core_ext_dfi_p0_ras_n = 1'd1;
reg core_ext_dfi_p0_we_n = 1'd1;
reg core_ext_dfi_p0_cke = 1'd0;
reg core_ext_dfi_p0_odt = 1'd0;
reg core_ext_dfi_p0_reset_n = 1'd0;
reg core_ext_dfi_p0_act_n = 1'd1;
reg [63:0] core_ext_dfi_p0_wrdata = 64'd0;
reg core_ext_dfi_p0_wrdata_en = 1'd0;
reg [7:0] core_ext_dfi_p0_wrdata_mask = 8'd0;
reg core_ext_dfi_p0_rddata_en = 1'd0;
reg [63:0] core_ext_dfi_p0_rddata;
reg core_ext_dfi_p0_rddata_valid;
reg [14:0] core_ext_dfi_p1_address = 15'd0;
reg [2:0] core_ext_dfi_p1_bank = 3'd0;
reg core_ext_dfi_p1_cas_n = 1'd1;
reg core_ext_dfi_p1_cs_n = 1'd1;
reg core_ext_dfi_p1_ras_n = 1'd1;
reg core_ext_dfi_p1_we_n = 1'd1;
reg core_ext_dfi_p1_cke = 1'd0;
reg core_ext_dfi_p1_odt = 1'd0;
reg core_ext_dfi_p1_reset_n = 1'd0;
reg core_ext_dfi_p1_act_n = 1'd1;
reg [63:0] core_ext_dfi_p1_wrdata = 64'd0;
reg core_ext_dfi_p1_wrdata_en = 1'd0;
reg [7:0] core_ext_dfi_p1_wrdata_mask = 8'd0;
reg core_ext_dfi_p1_rddata_en = 1'd0;
reg [63:0] core_ext_dfi_p1_rddata;
reg core_ext_dfi_p1_rddata_valid;
reg [14:0] core_ext_dfi_p2_address = 15'd0;
reg [2:0] core_ext_dfi_p2_bank = 3'd0;
reg core_ext_dfi_p2_cas_n = 1'd1;
reg core_ext_dfi_p2_cs_n = 1'd1;
reg core_ext_dfi_p2_ras_n = 1'd1;
reg core_ext_dfi_p2_we_n = 1'd1;
reg core_ext_dfi_p2_cke = 1'd0;
reg core_ext_dfi_p2_odt = 1'd0;
reg core_ext_dfi_p2_reset_n = 1'd0;
reg core_ext_dfi_p2_act_n = 1'd1;
reg [63:0] core_ext_dfi_p2_wrdata = 64'd0;
reg core_ext_dfi_p2_wrdata_en = 1'd0;
reg [7:0] core_ext_dfi_p2_wrdata_mask = 8'd0;
reg core_ext_dfi_p2_rddata_en = 1'd0;
reg [63:0] core_ext_dfi_p2_rddata;
reg core_ext_dfi_p2_rddata_valid;
reg [14:0] core_ext_dfi_p3_address = 15'd0;
reg [2:0] core_ext_dfi_p3_bank = 3'd0;
reg core_ext_dfi_p3_cas_n = 1'd1;
reg core_ext_dfi_p3_cs_n = 1'd1;
reg core_ext_dfi_p3_ras_n = 1'd1;
reg core_ext_dfi_p3_we_n = 1'd1;
reg core_ext_dfi_p3_cke = 1'd0;
reg core_ext_dfi_p3_odt = 1'd0;
reg core_ext_dfi_p3_reset_n = 1'd0;
reg core_ext_dfi_p3_act_n = 1'd1;
reg [63:0] core_ext_dfi_p3_wrdata = 64'd0;
reg core_ext_dfi_p3_wrdata_en = 1'd0;
reg [7:0] core_ext_dfi_p3_wrdata_mask = 8'd0;
reg core_ext_dfi_p3_rddata_en = 1'd0;
reg [63:0] core_ext_dfi_p3_rddata;
reg core_ext_dfi_p3_rddata_valid;
reg core_ext_dfi_sel = 1'd0;
reg core_sel = 1'd1;
reg core_cke = 1'd0;
reg core_odt = 1'd0;
reg core_reset_n = 1'd0;
reg core_phaseinjector0_cs = 1'd0;
reg core_phaseinjector0_we = 1'd0;
reg core_phaseinjector0_cas = 1'd0;
reg core_phaseinjector0_ras = 1'd0;
reg core_phaseinjector0_wren = 1'd0;
reg core_phaseinjector0_rden = 1'd0;
reg core_phaseinjector0_cs_top = 1'd0;
reg core_phaseinjector0_cs_bottom = 1'd0;
reg core_phaseinjector0_command_issue_re = 1'd0;
reg [14:0] core_phaseinjector0_address_storage = 15'd0;
reg [2:0] core_phaseinjector0_baddress_storage = 3'd0;
reg [63:0] core_phaseinjector0_wrdata_storage = 64'd0;
reg [63:0] core_phaseinjector0_status = 64'd0;
reg core_phaseinjector1_cs = 1'd0;
reg core_phaseinjector1_we = 1'd0;
reg core_phaseinjector1_cas = 1'd0;
reg core_phaseinjector1_ras = 1'd0;
reg core_phaseinjector1_wren = 1'd0;
reg core_phaseinjector1_rden = 1'd0;
reg core_phaseinjector1_cs_top = 1'd0;
reg core_phaseinjector1_cs_bottom = 1'd0;
reg core_phaseinjector1_command_issue_re = 1'd0;
reg [14:0] core_phaseinjector1_address_storage = 15'd0;
reg [2:0] core_phaseinjector1_baddress_storage = 3'd0;
reg [63:0] core_phaseinjector1_wrdata_storage = 64'd0;
reg [63:0] core_phaseinjector1_status = 64'd0;
reg core_phaseinjector2_cs = 1'd0;
reg core_phaseinjector2_we = 1'd0;
reg core_phaseinjector2_cas = 1'd0;
reg core_phaseinjector2_ras = 1'd0;
reg core_phaseinjector2_wren = 1'd0;
reg core_phaseinjector2_rden = 1'd0;
reg core_phaseinjector2_cs_top = 1'd0;
reg core_phaseinjector2_cs_bottom = 1'd0;
reg core_phaseinjector2_command_issue_re = 1'd0;
reg [14:0] core_phaseinjector2_address_storage = 15'd0;
reg [2:0] core_phaseinjector2_baddress_storage = 3'd0;
reg [63:0] core_phaseinjector2_wrdata_storage = 64'd0;
reg [63:0] core_phaseinjector2_status = 64'd0;
reg core_phaseinjector3_cs = 1'd0;
reg core_phaseinjector3_we = 1'd0;
reg core_phaseinjector3_cas = 1'd0;
reg core_phaseinjector3_ras = 1'd0;
reg core_phaseinjector3_wren = 1'd0;
reg core_phaseinjector3_rden = 1'd0;
reg core_phaseinjector3_cs_top = 1'd0;
reg core_phaseinjector3_cs_bottom = 1'd0;
reg core_phaseinjector3_command_issue_re = 1'd0;
reg [14:0] core_phaseinjector3_address_storage = 15'd0;
reg [2:0] core_phaseinjector3_baddress_storage = 3'd0;
reg [63:0] core_phaseinjector3_wrdata_storage = 64'd0;
reg [63:0] core_phaseinjector3_status = 64'd0;
wire core_interface_bank0_valid;
wire core_interface_bank0_ready;
wire core_interface_bank0_we;
wire [21:0] core_interface_bank0_addr;
wire core_interface_bank0_lock;
wire core_interface_bank0_wdata_ready;
wire core_interface_bank0_rdata_valid;
wire core_interface_bank1_valid;
wire core_interface_bank1_ready;
wire core_interface_bank1_we;
wire [21:0] core_interface_bank1_addr;
wire core_interface_bank1_lock;
wire core_interface_bank1_wdata_ready;
wire core_interface_bank1_rdata_valid;
wire core_interface_bank2_valid;
wire core_interface_bank2_ready;
wire core_interface_bank2_we;
wire [21:0] core_interface_bank2_addr;
wire core_interface_bank2_lock;
wire core_interface_bank2_wdata_ready;
wire core_interface_bank2_rdata_valid;
wire core_interface_bank3_valid;
wire core_interface_bank3_ready;
wire core_interface_bank3_we;
wire [21:0] core_interface_bank3_addr;
wire core_interface_bank3_lock;
wire core_interface_bank3_wdata_ready;
wire core_interface_bank3_rdata_valid;
wire core_interface_bank4_valid;
wire core_interface_bank4_ready;
wire core_interface_bank4_we;
wire [21:0] core_interface_bank4_addr;
wire core_interface_bank4_lock;
wire core_interface_bank4_wdata_ready;
wire core_interface_bank4_rdata_valid;
wire core_interface_bank5_valid;
wire core_interface_bank5_ready;
wire core_interface_bank5_we;
wire [21:0] core_interface_bank5_addr;
wire core_interface_bank5_lock;
wire core_interface_bank5_wdata_ready;
wire core_interface_bank5_rdata_valid;
wire core_interface_bank6_valid;
wire core_interface_bank6_ready;
wire core_interface_bank6_we;
wire [21:0] core_interface_bank6_addr;
wire core_interface_bank6_lock;
wire core_interface_bank6_wdata_ready;
wire core_interface_bank6_rdata_valid;
wire core_interface_bank7_valid;
wire core_interface_bank7_ready;
wire core_interface_bank7_we;
wire [21:0] core_interface_bank7_addr;
wire core_interface_bank7_lock;
wire core_interface_bank7_wdata_ready;
wire core_interface_bank7_rdata_valid;
reg [255:0] core_interface_wdata;
reg [31:0] core_interface_wdata_we;
wire [255:0] core_interface_rdata;
reg [14:0] core_dfi_p0_address = 15'd0;
reg [2:0] core_dfi_p0_bank = 3'd0;
reg core_dfi_p0_cas_n = 1'd1;
reg core_dfi_p0_cs_n = 1'd1;
reg core_dfi_p0_ras_n = 1'd1;
reg core_dfi_p0_we_n = 1'd1;
wire core_dfi_p0_cke;
wire core_dfi_p0_odt;
wire core_dfi_p0_reset_n;
reg core_dfi_p0_act_n = 1'd1;
wire [63:0] core_dfi_p0_wrdata;
reg core_dfi_p0_wrdata_en = 1'd0;
wire [7:0] core_dfi_p0_wrdata_mask;
reg core_dfi_p0_rddata_en = 1'd0;
wire [63:0] core_dfi_p0_rddata;
wire core_dfi_p0_rddata_valid;
reg [14:0] core_dfi_p1_address = 15'd0;
reg [2:0] core_dfi_p1_bank = 3'd0;
reg core_dfi_p1_cas_n = 1'd1;
reg core_dfi_p1_cs_n = 1'd1;
reg core_dfi_p1_ras_n = 1'd1;
reg core_dfi_p1_we_n = 1'd1;
wire core_dfi_p1_cke;
wire core_dfi_p1_odt;
wire core_dfi_p1_reset_n;
reg core_dfi_p1_act_n = 1'd1;
wire [63:0] core_dfi_p1_wrdata;
reg core_dfi_p1_wrdata_en = 1'd0;
wire [7:0] core_dfi_p1_wrdata_mask;
reg core_dfi_p1_rddata_en = 1'd0;
wire [63:0] core_dfi_p1_rddata;
wire core_dfi_p1_rddata_valid;
reg [14:0] core_dfi_p2_address = 15'd0;
reg [2:0] core_dfi_p2_bank = 3'd0;
reg core_dfi_p2_cas_n = 1'd1;
reg core_dfi_p2_cs_n = 1'd1;
reg core_dfi_p2_ras_n = 1'd1;
reg core_dfi_p2_we_n = 1'd1;
wire core_dfi_p2_cke;
wire core_dfi_p2_odt;
wire core_dfi_p2_reset_n;
reg core_dfi_p2_act_n = 1'd1;
wire [63:0] core_dfi_p2_wrdata;
reg core_dfi_p2_wrdata_en = 1'd0;
wire [7:0] core_dfi_p2_wrdata_mask;
reg core_dfi_p2_rddata_en = 1'd0;
wire [63:0] core_dfi_p2_rddata;
wire core_dfi_p2_rddata_valid;
reg [14:0] core_dfi_p3_address = 15'd0;
reg [2:0] core_dfi_p3_bank = 3'd0;
reg core_dfi_p3_cas_n = 1'd1;
reg core_dfi_p3_cs_n = 1'd1;
reg core_dfi_p3_ras_n = 1'd1;
reg core_dfi_p3_we_n = 1'd1;
wire core_dfi_p3_cke;
wire core_dfi_p3_odt;
wire core_dfi_p3_reset_n;
reg core_dfi_p3_act_n = 1'd1;
wire [63:0] core_dfi_p3_wrdata;
reg core_dfi_p3_wrdata_en = 1'd0;
wire [7:0] core_dfi_p3_wrdata_mask;
reg core_dfi_p3_rddata_en = 1'd0;
wire [63:0] core_dfi_p3_rddata;
wire core_dfi_p3_rddata_valid;
reg core_cmd_valid;
reg core_cmd_ready;
reg core_cmd_last;
reg [14:0] core_cmd_payload_a = 15'd0;
reg [2:0] core_cmd_payload_ba = 3'd0;
reg core_cmd_payload_cas = 1'd0;
reg core_cmd_payload_ras = 1'd0;
reg core_cmd_payload_we = 1'd0;
reg core_cmd_payload_is_read = 1'd0;
reg core_cmd_payload_is_write = 1'd0;
wire core_wants_refresh;
wire core_wants_zqcs;
wire core_timer_wait;
wire core_timer_done0;
wire [9:0] core_timer_count0;
wire core_timer_done1;
reg [9:0] core_timer_count1 = 10'd585;
wire core_postponer_req_i;
reg core_postponer_req_o = 1'd0;
reg core_postponer_count = 1'd0;
reg core_sequencer_start0;
wire core_sequencer_done0;
wire core_sequencer_start1;
reg core_sequencer_done1 = 1'd0;
reg [5:0] core_sequencer_trigger = 6'd0;
reg core_sequencer_count = 1'd0;
wire core_zqcs_timer_wait;
wire core_zqcs_timer_done0;
wire [26:0] core_zqcs_timer_count0;
wire core_zqcs_timer_done1;
reg [26:0] core_zqcs_timer_count1 = 27'd74999999;
reg core_zqcs_executer_start;
reg core_zqcs_executer_done = 1'd0;
reg [4:0] core_zqcs_executer_trigger = 5'd0;
wire core_bankmachine0_req_valid;
wire core_bankmachine0_req_ready;
wire core_bankmachine0_req_we;
wire [21:0] core_bankmachine0_req_addr;
wire core_bankmachine0_req_lock;
reg core_bankmachine0_req_wdata_ready;
reg core_bankmachine0_req_rdata_valid;
wire core_bankmachine0_refresh_req;
reg core_bankmachine0_refresh_gnt;
reg core_bankmachine0_cmd_valid;
reg core_bankmachine0_cmd_ready;
reg [14:0] core_bankmachine0_cmd_payload_a;
wire [2:0] core_bankmachine0_cmd_payload_ba;
reg core_bankmachine0_cmd_payload_cas;
reg core_bankmachine0_cmd_payload_ras;
reg core_bankmachine0_cmd_payload_we;
reg core_bankmachine0_cmd_payload_is_cmd;
reg core_bankmachine0_cmd_payload_is_read;
reg core_bankmachine0_cmd_payload_is_write;
reg core_bankmachine0_auto_precharge;
wire core_bankmachine0_sink_valid;
wire core_bankmachine0_sink_ready;
reg core_bankmachine0_sink_first = 1'd0;
reg core_bankmachine0_sink_last = 1'd0;
wire core_bankmachine0_sink_payload_we;
wire [21:0] core_bankmachine0_sink_payload_addr;
wire core_bankmachine0_source_valid;
wire core_bankmachine0_source_ready;
wire core_bankmachine0_source_first;
wire core_bankmachine0_source_last;
wire core_bankmachine0_source_payload_we;
wire [21:0] core_bankmachine0_source_payload_addr;
wire core_bankmachine0_syncfifo0_we;
wire core_bankmachine0_syncfifo0_writable;
wire core_bankmachine0_syncfifo0_re;
wire core_bankmachine0_syncfifo0_readable;
wire [24:0] core_bankmachine0_syncfifo0_din;
wire [24:0] core_bankmachine0_syncfifo0_dout;
reg [3:0] core_bankmachine0_level = 4'd0;
reg core_bankmachine0_replace = 1'd0;
reg [2:0] core_bankmachine0_produce = 3'd0;
reg [2:0] core_bankmachine0_consume = 3'd0;
reg [2:0] core_bankmachine0_wrport_adr;
wire [24:0] core_bankmachine0_wrport_dat_r;
wire core_bankmachine0_wrport_we;
wire [24:0] core_bankmachine0_wrport_dat_w;
wire core_bankmachine0_do_read;
wire [2:0] core_bankmachine0_rdport_adr;
wire [24:0] core_bankmachine0_rdport_dat_r;
wire core_bankmachine0_fifo_in_payload_we;
wire [21:0] core_bankmachine0_fifo_in_payload_addr;
wire core_bankmachine0_fifo_in_first;
wire core_bankmachine0_fifo_in_last;
wire core_bankmachine0_fifo_out_payload_we;
wire [21:0] core_bankmachine0_fifo_out_payload_addr;
wire core_bankmachine0_fifo_out_first;
wire core_bankmachine0_fifo_out_last;
wire core_bankmachine0_sink_sink_valid;
wire core_bankmachine0_sink_sink_ready;
wire core_bankmachine0_sink_sink_first;
wire core_bankmachine0_sink_sink_last;
wire core_bankmachine0_sink_sink_payload_we;
wire [21:0] core_bankmachine0_sink_sink_payload_addr;
wire core_bankmachine0_source_source_valid;
wire core_bankmachine0_source_source_ready;
wire core_bankmachine0_source_source_first;
wire core_bankmachine0_source_source_last;
wire core_bankmachine0_source_source_payload_we;
wire [21:0] core_bankmachine0_source_source_payload_addr;
wire core_bankmachine0_pipe_valid_sink_valid;
wire core_bankmachine0_pipe_valid_sink_ready;
wire core_bankmachine0_pipe_valid_sink_first;
wire core_bankmachine0_pipe_valid_sink_last;
wire core_bankmachine0_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine0_pipe_valid_sink_payload_addr;
reg core_bankmachine0_pipe_valid_source_valid = 1'd0;
wire core_bankmachine0_pipe_valid_source_ready;
reg core_bankmachine0_pipe_valid_source_first = 1'd0;
reg core_bankmachine0_pipe_valid_source_last = 1'd0;
reg core_bankmachine0_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine0_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine0_row = 15'd0;
reg core_bankmachine0_row_opened = 1'd0;
wire core_bankmachine0_row_hit;
reg core_bankmachine0_row_open;
reg core_bankmachine0_row_close;
reg core_bankmachine0_row_col_n_addr_sel;
wire core_bankmachine0_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine0_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine0_twtpcon_count = 3'd0;
wire core_bankmachine0_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine0_trccon_ready = 1'd0;
reg [2:0] core_bankmachine0_trccon_count = 3'd0;
wire core_bankmachine0_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine0_trascon_ready = 1'd0;
reg [1:0] core_bankmachine0_trascon_count = 2'd0;
wire core_bankmachine1_req_valid;
wire core_bankmachine1_req_ready;
wire core_bankmachine1_req_we;
wire [21:0] core_bankmachine1_req_addr;
wire core_bankmachine1_req_lock;
reg core_bankmachine1_req_wdata_ready;
reg core_bankmachine1_req_rdata_valid;
wire core_bankmachine1_refresh_req;
reg core_bankmachine1_refresh_gnt;
reg core_bankmachine1_cmd_valid;
reg core_bankmachine1_cmd_ready;
reg [14:0] core_bankmachine1_cmd_payload_a;
wire [2:0] core_bankmachine1_cmd_payload_ba;
reg core_bankmachine1_cmd_payload_cas;
reg core_bankmachine1_cmd_payload_ras;
reg core_bankmachine1_cmd_payload_we;
reg core_bankmachine1_cmd_payload_is_cmd;
reg core_bankmachine1_cmd_payload_is_read;
reg core_bankmachine1_cmd_payload_is_write;
reg core_bankmachine1_auto_precharge;
wire core_bankmachine1_sink_valid;
wire core_bankmachine1_sink_ready;
reg core_bankmachine1_sink_first = 1'd0;
reg core_bankmachine1_sink_last = 1'd0;
wire core_bankmachine1_sink_payload_we;
wire [21:0] core_bankmachine1_sink_payload_addr;
wire core_bankmachine1_source_valid;
wire core_bankmachine1_source_ready;
wire core_bankmachine1_source_first;
wire core_bankmachine1_source_last;
wire core_bankmachine1_source_payload_we;
wire [21:0] core_bankmachine1_source_payload_addr;
wire core_bankmachine1_syncfifo1_we;
wire core_bankmachine1_syncfifo1_writable;
wire core_bankmachine1_syncfifo1_re;
wire core_bankmachine1_syncfifo1_readable;
wire [24:0] core_bankmachine1_syncfifo1_din;
wire [24:0] core_bankmachine1_syncfifo1_dout;
reg [3:0] core_bankmachine1_level = 4'd0;
reg core_bankmachine1_replace = 1'd0;
reg [2:0] core_bankmachine1_produce = 3'd0;
reg [2:0] core_bankmachine1_consume = 3'd0;
reg [2:0] core_bankmachine1_wrport_adr;
wire [24:0] core_bankmachine1_wrport_dat_r;
wire core_bankmachine1_wrport_we;
wire [24:0] core_bankmachine1_wrport_dat_w;
wire core_bankmachine1_do_read;
wire [2:0] core_bankmachine1_rdport_adr;
wire [24:0] core_bankmachine1_rdport_dat_r;
wire core_bankmachine1_fifo_in_payload_we;
wire [21:0] core_bankmachine1_fifo_in_payload_addr;
wire core_bankmachine1_fifo_in_first;
wire core_bankmachine1_fifo_in_last;
wire core_bankmachine1_fifo_out_payload_we;
wire [21:0] core_bankmachine1_fifo_out_payload_addr;
wire core_bankmachine1_fifo_out_first;
wire core_bankmachine1_fifo_out_last;
wire core_bankmachine1_sink_sink_valid;
wire core_bankmachine1_sink_sink_ready;
wire core_bankmachine1_sink_sink_first;
wire core_bankmachine1_sink_sink_last;
wire core_bankmachine1_sink_sink_payload_we;
wire [21:0] core_bankmachine1_sink_sink_payload_addr;
wire core_bankmachine1_source_source_valid;
wire core_bankmachine1_source_source_ready;
wire core_bankmachine1_source_source_first;
wire core_bankmachine1_source_source_last;
wire core_bankmachine1_source_source_payload_we;
wire [21:0] core_bankmachine1_source_source_payload_addr;
wire core_bankmachine1_pipe_valid_sink_valid;
wire core_bankmachine1_pipe_valid_sink_ready;
wire core_bankmachine1_pipe_valid_sink_first;
wire core_bankmachine1_pipe_valid_sink_last;
wire core_bankmachine1_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine1_pipe_valid_sink_payload_addr;
reg core_bankmachine1_pipe_valid_source_valid = 1'd0;
wire core_bankmachine1_pipe_valid_source_ready;
reg core_bankmachine1_pipe_valid_source_first = 1'd0;
reg core_bankmachine1_pipe_valid_source_last = 1'd0;
reg core_bankmachine1_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine1_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine1_row = 15'd0;
reg core_bankmachine1_row_opened = 1'd0;
wire core_bankmachine1_row_hit;
reg core_bankmachine1_row_open;
reg core_bankmachine1_row_close;
reg core_bankmachine1_row_col_n_addr_sel;
wire core_bankmachine1_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine1_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine1_twtpcon_count = 3'd0;
wire core_bankmachine1_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine1_trccon_ready = 1'd0;
reg [2:0] core_bankmachine1_trccon_count = 3'd0;
wire core_bankmachine1_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine1_trascon_ready = 1'd0;
reg [1:0] core_bankmachine1_trascon_count = 2'd0;
wire core_bankmachine2_req_valid;
wire core_bankmachine2_req_ready;
wire core_bankmachine2_req_we;
wire [21:0] core_bankmachine2_req_addr;
wire core_bankmachine2_req_lock;
reg core_bankmachine2_req_wdata_ready;
reg core_bankmachine2_req_rdata_valid;
wire core_bankmachine2_refresh_req;
reg core_bankmachine2_refresh_gnt;
reg core_bankmachine2_cmd_valid;
reg core_bankmachine2_cmd_ready;
reg [14:0] core_bankmachine2_cmd_payload_a;
wire [2:0] core_bankmachine2_cmd_payload_ba;
reg core_bankmachine2_cmd_payload_cas;
reg core_bankmachine2_cmd_payload_ras;
reg core_bankmachine2_cmd_payload_we;
reg core_bankmachine2_cmd_payload_is_cmd;
reg core_bankmachine2_cmd_payload_is_read;
reg core_bankmachine2_cmd_payload_is_write;
reg core_bankmachine2_auto_precharge;
wire core_bankmachine2_sink_valid;
wire core_bankmachine2_sink_ready;
reg core_bankmachine2_sink_first = 1'd0;
reg core_bankmachine2_sink_last = 1'd0;
wire core_bankmachine2_sink_payload_we;
wire [21:0] core_bankmachine2_sink_payload_addr;
wire core_bankmachine2_source_valid;
wire core_bankmachine2_source_ready;
wire core_bankmachine2_source_first;
wire core_bankmachine2_source_last;
wire core_bankmachine2_source_payload_we;
wire [21:0] core_bankmachine2_source_payload_addr;
wire core_bankmachine2_syncfifo2_we;
wire core_bankmachine2_syncfifo2_writable;
wire core_bankmachine2_syncfifo2_re;
wire core_bankmachine2_syncfifo2_readable;
wire [24:0] core_bankmachine2_syncfifo2_din;
wire [24:0] core_bankmachine2_syncfifo2_dout;
reg [3:0] core_bankmachine2_level = 4'd0;
reg core_bankmachine2_replace = 1'd0;
reg [2:0] core_bankmachine2_produce = 3'd0;
reg [2:0] core_bankmachine2_consume = 3'd0;
reg [2:0] core_bankmachine2_wrport_adr;
wire [24:0] core_bankmachine2_wrport_dat_r;
wire core_bankmachine2_wrport_we;
wire [24:0] core_bankmachine2_wrport_dat_w;
wire core_bankmachine2_do_read;
wire [2:0] core_bankmachine2_rdport_adr;
wire [24:0] core_bankmachine2_rdport_dat_r;
wire core_bankmachine2_fifo_in_payload_we;
wire [21:0] core_bankmachine2_fifo_in_payload_addr;
wire core_bankmachine2_fifo_in_first;
wire core_bankmachine2_fifo_in_last;
wire core_bankmachine2_fifo_out_payload_we;
wire [21:0] core_bankmachine2_fifo_out_payload_addr;
wire core_bankmachine2_fifo_out_first;
wire core_bankmachine2_fifo_out_last;
wire core_bankmachine2_sink_sink_valid;
wire core_bankmachine2_sink_sink_ready;
wire core_bankmachine2_sink_sink_first;
wire core_bankmachine2_sink_sink_last;
wire core_bankmachine2_sink_sink_payload_we;
wire [21:0] core_bankmachine2_sink_sink_payload_addr;
wire core_bankmachine2_source_source_valid;
wire core_bankmachine2_source_source_ready;
wire core_bankmachine2_source_source_first;
wire core_bankmachine2_source_source_last;
wire core_bankmachine2_source_source_payload_we;
wire [21:0] core_bankmachine2_source_source_payload_addr;
wire core_bankmachine2_pipe_valid_sink_valid;
wire core_bankmachine2_pipe_valid_sink_ready;
wire core_bankmachine2_pipe_valid_sink_first;
wire core_bankmachine2_pipe_valid_sink_last;
wire core_bankmachine2_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine2_pipe_valid_sink_payload_addr;
reg core_bankmachine2_pipe_valid_source_valid = 1'd0;
wire core_bankmachine2_pipe_valid_source_ready;
reg core_bankmachine2_pipe_valid_source_first = 1'd0;
reg core_bankmachine2_pipe_valid_source_last = 1'd0;
reg core_bankmachine2_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine2_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine2_row = 15'd0;
reg core_bankmachine2_row_opened = 1'd0;
wire core_bankmachine2_row_hit;
reg core_bankmachine2_row_open;
reg core_bankmachine2_row_close;
reg core_bankmachine2_row_col_n_addr_sel;
wire core_bankmachine2_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine2_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine2_twtpcon_count = 3'd0;
wire core_bankmachine2_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine2_trccon_ready = 1'd0;
reg [2:0] core_bankmachine2_trccon_count = 3'd0;
wire core_bankmachine2_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine2_trascon_ready = 1'd0;
reg [1:0] core_bankmachine2_trascon_count = 2'd0;
wire core_bankmachine3_req_valid;
wire core_bankmachine3_req_ready;
wire core_bankmachine3_req_we;
wire [21:0] core_bankmachine3_req_addr;
wire core_bankmachine3_req_lock;
reg core_bankmachine3_req_wdata_ready;
reg core_bankmachine3_req_rdata_valid;
wire core_bankmachine3_refresh_req;
reg core_bankmachine3_refresh_gnt;
reg core_bankmachine3_cmd_valid;
reg core_bankmachine3_cmd_ready;
reg [14:0] core_bankmachine3_cmd_payload_a;
wire [2:0] core_bankmachine3_cmd_payload_ba;
reg core_bankmachine3_cmd_payload_cas;
reg core_bankmachine3_cmd_payload_ras;
reg core_bankmachine3_cmd_payload_we;
reg core_bankmachine3_cmd_payload_is_cmd;
reg core_bankmachine3_cmd_payload_is_read;
reg core_bankmachine3_cmd_payload_is_write;
reg core_bankmachine3_auto_precharge;
wire core_bankmachine3_sink_valid;
wire core_bankmachine3_sink_ready;
reg core_bankmachine3_sink_first = 1'd0;
reg core_bankmachine3_sink_last = 1'd0;
wire core_bankmachine3_sink_payload_we;
wire [21:0] core_bankmachine3_sink_payload_addr;
wire core_bankmachine3_source_valid;
wire core_bankmachine3_source_ready;
wire core_bankmachine3_source_first;
wire core_bankmachine3_source_last;
wire core_bankmachine3_source_payload_we;
wire [21:0] core_bankmachine3_source_payload_addr;
wire core_bankmachine3_syncfifo3_we;
wire core_bankmachine3_syncfifo3_writable;
wire core_bankmachine3_syncfifo3_re;
wire core_bankmachine3_syncfifo3_readable;
wire [24:0] core_bankmachine3_syncfifo3_din;
wire [24:0] core_bankmachine3_syncfifo3_dout;
reg [3:0] core_bankmachine3_level = 4'd0;
reg core_bankmachine3_replace = 1'd0;
reg [2:0] core_bankmachine3_produce = 3'd0;
reg [2:0] core_bankmachine3_consume = 3'd0;
reg [2:0] core_bankmachine3_wrport_adr;
wire [24:0] core_bankmachine3_wrport_dat_r;
wire core_bankmachine3_wrport_we;
wire [24:0] core_bankmachine3_wrport_dat_w;
wire core_bankmachine3_do_read;
wire [2:0] core_bankmachine3_rdport_adr;
wire [24:0] core_bankmachine3_rdport_dat_r;
wire core_bankmachine3_fifo_in_payload_we;
wire [21:0] core_bankmachine3_fifo_in_payload_addr;
wire core_bankmachine3_fifo_in_first;
wire core_bankmachine3_fifo_in_last;
wire core_bankmachine3_fifo_out_payload_we;
wire [21:0] core_bankmachine3_fifo_out_payload_addr;
wire core_bankmachine3_fifo_out_first;
wire core_bankmachine3_fifo_out_last;
wire core_bankmachine3_sink_sink_valid;
wire core_bankmachine3_sink_sink_ready;
wire core_bankmachine3_sink_sink_first;
wire core_bankmachine3_sink_sink_last;
wire core_bankmachine3_sink_sink_payload_we;
wire [21:0] core_bankmachine3_sink_sink_payload_addr;
wire core_bankmachine3_source_source_valid;
wire core_bankmachine3_source_source_ready;
wire core_bankmachine3_source_source_first;
wire core_bankmachine3_source_source_last;
wire core_bankmachine3_source_source_payload_we;
wire [21:0] core_bankmachine3_source_source_payload_addr;
wire core_bankmachine3_pipe_valid_sink_valid;
wire core_bankmachine3_pipe_valid_sink_ready;
wire core_bankmachine3_pipe_valid_sink_first;
wire core_bankmachine3_pipe_valid_sink_last;
wire core_bankmachine3_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine3_pipe_valid_sink_payload_addr;
reg core_bankmachine3_pipe_valid_source_valid = 1'd0;
wire core_bankmachine3_pipe_valid_source_ready;
reg core_bankmachine3_pipe_valid_source_first = 1'd0;
reg core_bankmachine3_pipe_valid_source_last = 1'd0;
reg core_bankmachine3_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine3_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine3_row = 15'd0;
reg core_bankmachine3_row_opened = 1'd0;
wire core_bankmachine3_row_hit;
reg core_bankmachine3_row_open;
reg core_bankmachine3_row_close;
reg core_bankmachine3_row_col_n_addr_sel;
wire core_bankmachine3_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine3_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine3_twtpcon_count = 3'd0;
wire core_bankmachine3_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine3_trccon_ready = 1'd0;
reg [2:0] core_bankmachine3_trccon_count = 3'd0;
wire core_bankmachine3_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine3_trascon_ready = 1'd0;
reg [1:0] core_bankmachine3_trascon_count = 2'd0;
wire core_bankmachine4_req_valid;
wire core_bankmachine4_req_ready;
wire core_bankmachine4_req_we;
wire [21:0] core_bankmachine4_req_addr;
wire core_bankmachine4_req_lock;
reg core_bankmachine4_req_wdata_ready;
reg core_bankmachine4_req_rdata_valid;
wire core_bankmachine4_refresh_req;
reg core_bankmachine4_refresh_gnt;
reg core_bankmachine4_cmd_valid;
reg core_bankmachine4_cmd_ready;
reg [14:0] core_bankmachine4_cmd_payload_a;
wire [2:0] core_bankmachine4_cmd_payload_ba;
reg core_bankmachine4_cmd_payload_cas;
reg core_bankmachine4_cmd_payload_ras;
reg core_bankmachine4_cmd_payload_we;
reg core_bankmachine4_cmd_payload_is_cmd;
reg core_bankmachine4_cmd_payload_is_read;
reg core_bankmachine4_cmd_payload_is_write;
reg core_bankmachine4_auto_precharge;
wire core_bankmachine4_sink_valid;
wire core_bankmachine4_sink_ready;
reg core_bankmachine4_sink_first = 1'd0;
reg core_bankmachine4_sink_last = 1'd0;
wire core_bankmachine4_sink_payload_we;
wire [21:0] core_bankmachine4_sink_payload_addr;
wire core_bankmachine4_source_valid;
wire core_bankmachine4_source_ready;
wire core_bankmachine4_source_first;
wire core_bankmachine4_source_last;
wire core_bankmachine4_source_payload_we;
wire [21:0] core_bankmachine4_source_payload_addr;
wire core_bankmachine4_syncfifo4_we;
wire core_bankmachine4_syncfifo4_writable;
wire core_bankmachine4_syncfifo4_re;
wire core_bankmachine4_syncfifo4_readable;
wire [24:0] core_bankmachine4_syncfifo4_din;
wire [24:0] core_bankmachine4_syncfifo4_dout;
reg [3:0] core_bankmachine4_level = 4'd0;
reg core_bankmachine4_replace = 1'd0;
reg [2:0] core_bankmachine4_produce = 3'd0;
reg [2:0] core_bankmachine4_consume = 3'd0;
reg [2:0] core_bankmachine4_wrport_adr;
wire [24:0] core_bankmachine4_wrport_dat_r;
wire core_bankmachine4_wrport_we;
wire [24:0] core_bankmachine4_wrport_dat_w;
wire core_bankmachine4_do_read;
wire [2:0] core_bankmachine4_rdport_adr;
wire [24:0] core_bankmachine4_rdport_dat_r;
wire core_bankmachine4_fifo_in_payload_we;
wire [21:0] core_bankmachine4_fifo_in_payload_addr;
wire core_bankmachine4_fifo_in_first;
wire core_bankmachine4_fifo_in_last;
wire core_bankmachine4_fifo_out_payload_we;
wire [21:0] core_bankmachine4_fifo_out_payload_addr;
wire core_bankmachine4_fifo_out_first;
wire core_bankmachine4_fifo_out_last;
wire core_bankmachine4_sink_sink_valid;
wire core_bankmachine4_sink_sink_ready;
wire core_bankmachine4_sink_sink_first;
wire core_bankmachine4_sink_sink_last;
wire core_bankmachine4_sink_sink_payload_we;
wire [21:0] core_bankmachine4_sink_sink_payload_addr;
wire core_bankmachine4_source_source_valid;
wire core_bankmachine4_source_source_ready;
wire core_bankmachine4_source_source_first;
wire core_bankmachine4_source_source_last;
wire core_bankmachine4_source_source_payload_we;
wire [21:0] core_bankmachine4_source_source_payload_addr;
wire core_bankmachine4_pipe_valid_sink_valid;
wire core_bankmachine4_pipe_valid_sink_ready;
wire core_bankmachine4_pipe_valid_sink_first;
wire core_bankmachine4_pipe_valid_sink_last;
wire core_bankmachine4_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine4_pipe_valid_sink_payload_addr;
reg core_bankmachine4_pipe_valid_source_valid = 1'd0;
wire core_bankmachine4_pipe_valid_source_ready;
reg core_bankmachine4_pipe_valid_source_first = 1'd0;
reg core_bankmachine4_pipe_valid_source_last = 1'd0;
reg core_bankmachine4_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine4_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine4_row = 15'd0;
reg core_bankmachine4_row_opened = 1'd0;
wire core_bankmachine4_row_hit;
reg core_bankmachine4_row_open;
reg core_bankmachine4_row_close;
reg core_bankmachine4_row_col_n_addr_sel;
wire core_bankmachine4_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine4_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine4_twtpcon_count = 3'd0;
wire core_bankmachine4_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine4_trccon_ready = 1'd0;
reg [2:0] core_bankmachine4_trccon_count = 3'd0;
wire core_bankmachine4_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine4_trascon_ready = 1'd0;
reg [1:0] core_bankmachine4_trascon_count = 2'd0;
wire core_bankmachine5_req_valid;
wire core_bankmachine5_req_ready;
wire core_bankmachine5_req_we;
wire [21:0] core_bankmachine5_req_addr;
wire core_bankmachine5_req_lock;
reg core_bankmachine5_req_wdata_ready;
reg core_bankmachine5_req_rdata_valid;
wire core_bankmachine5_refresh_req;
reg core_bankmachine5_refresh_gnt;
reg core_bankmachine5_cmd_valid;
reg core_bankmachine5_cmd_ready;
reg [14:0] core_bankmachine5_cmd_payload_a;
wire [2:0] core_bankmachine5_cmd_payload_ba;
reg core_bankmachine5_cmd_payload_cas;
reg core_bankmachine5_cmd_payload_ras;
reg core_bankmachine5_cmd_payload_we;
reg core_bankmachine5_cmd_payload_is_cmd;
reg core_bankmachine5_cmd_payload_is_read;
reg core_bankmachine5_cmd_payload_is_write;
reg core_bankmachine5_auto_precharge;
wire core_bankmachine5_sink_valid;
wire core_bankmachine5_sink_ready;
reg core_bankmachine5_sink_first = 1'd0;
reg core_bankmachine5_sink_last = 1'd0;
wire core_bankmachine5_sink_payload_we;
wire [21:0] core_bankmachine5_sink_payload_addr;
wire core_bankmachine5_source_valid;
wire core_bankmachine5_source_ready;
wire core_bankmachine5_source_first;
wire core_bankmachine5_source_last;
wire core_bankmachine5_source_payload_we;
wire [21:0] core_bankmachine5_source_payload_addr;
wire core_bankmachine5_syncfifo5_we;
wire core_bankmachine5_syncfifo5_writable;
wire core_bankmachine5_syncfifo5_re;
wire core_bankmachine5_syncfifo5_readable;
wire [24:0] core_bankmachine5_syncfifo5_din;
wire [24:0] core_bankmachine5_syncfifo5_dout;
reg [3:0] core_bankmachine5_level = 4'd0;
reg core_bankmachine5_replace = 1'd0;
reg [2:0] core_bankmachine5_produce = 3'd0;
reg [2:0] core_bankmachine5_consume = 3'd0;
reg [2:0] core_bankmachine5_wrport_adr;
wire [24:0] core_bankmachine5_wrport_dat_r;
wire core_bankmachine5_wrport_we;
wire [24:0] core_bankmachine5_wrport_dat_w;
wire core_bankmachine5_do_read;
wire [2:0] core_bankmachine5_rdport_adr;
wire [24:0] core_bankmachine5_rdport_dat_r;
wire core_bankmachine5_fifo_in_payload_we;
wire [21:0] core_bankmachine5_fifo_in_payload_addr;
wire core_bankmachine5_fifo_in_first;
wire core_bankmachine5_fifo_in_last;
wire core_bankmachine5_fifo_out_payload_we;
wire [21:0] core_bankmachine5_fifo_out_payload_addr;
wire core_bankmachine5_fifo_out_first;
wire core_bankmachine5_fifo_out_last;
wire core_bankmachine5_sink_sink_valid;
wire core_bankmachine5_sink_sink_ready;
wire core_bankmachine5_sink_sink_first;
wire core_bankmachine5_sink_sink_last;
wire core_bankmachine5_sink_sink_payload_we;
wire [21:0] core_bankmachine5_sink_sink_payload_addr;
wire core_bankmachine5_source_source_valid;
wire core_bankmachine5_source_source_ready;
wire core_bankmachine5_source_source_first;
wire core_bankmachine5_source_source_last;
wire core_bankmachine5_source_source_payload_we;
wire [21:0] core_bankmachine5_source_source_payload_addr;
wire core_bankmachine5_pipe_valid_sink_valid;
wire core_bankmachine5_pipe_valid_sink_ready;
wire core_bankmachine5_pipe_valid_sink_first;
wire core_bankmachine5_pipe_valid_sink_last;
wire core_bankmachine5_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine5_pipe_valid_sink_payload_addr;
reg core_bankmachine5_pipe_valid_source_valid = 1'd0;
wire core_bankmachine5_pipe_valid_source_ready;
reg core_bankmachine5_pipe_valid_source_first = 1'd0;
reg core_bankmachine5_pipe_valid_source_last = 1'd0;
reg core_bankmachine5_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine5_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine5_row = 15'd0;
reg core_bankmachine5_row_opened = 1'd0;
wire core_bankmachine5_row_hit;
reg core_bankmachine5_row_open;
reg core_bankmachine5_row_close;
reg core_bankmachine5_row_col_n_addr_sel;
wire core_bankmachine5_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine5_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine5_twtpcon_count = 3'd0;
wire core_bankmachine5_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine5_trccon_ready = 1'd0;
reg [2:0] core_bankmachine5_trccon_count = 3'd0;
wire core_bankmachine5_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine5_trascon_ready = 1'd0;
reg [1:0] core_bankmachine5_trascon_count = 2'd0;
wire core_bankmachine6_req_valid;
wire core_bankmachine6_req_ready;
wire core_bankmachine6_req_we;
wire [21:0] core_bankmachine6_req_addr;
wire core_bankmachine6_req_lock;
reg core_bankmachine6_req_wdata_ready;
reg core_bankmachine6_req_rdata_valid;
wire core_bankmachine6_refresh_req;
reg core_bankmachine6_refresh_gnt;
reg core_bankmachine6_cmd_valid;
reg core_bankmachine6_cmd_ready;
reg [14:0] core_bankmachine6_cmd_payload_a;
wire [2:0] core_bankmachine6_cmd_payload_ba;
reg core_bankmachine6_cmd_payload_cas;
reg core_bankmachine6_cmd_payload_ras;
reg core_bankmachine6_cmd_payload_we;
reg core_bankmachine6_cmd_payload_is_cmd;
reg core_bankmachine6_cmd_payload_is_read;
reg core_bankmachine6_cmd_payload_is_write;
reg core_bankmachine6_auto_precharge;
wire core_bankmachine6_sink_valid;
wire core_bankmachine6_sink_ready;
reg core_bankmachine6_sink_first = 1'd0;
reg core_bankmachine6_sink_last = 1'd0;
wire core_bankmachine6_sink_payload_we;
wire [21:0] core_bankmachine6_sink_payload_addr;
wire core_bankmachine6_source_valid;
wire core_bankmachine6_source_ready;
wire core_bankmachine6_source_first;
wire core_bankmachine6_source_last;
wire core_bankmachine6_source_payload_we;
wire [21:0] core_bankmachine6_source_payload_addr;
wire core_bankmachine6_syncfifo6_we;
wire core_bankmachine6_syncfifo6_writable;
wire core_bankmachine6_syncfifo6_re;
wire core_bankmachine6_syncfifo6_readable;
wire [24:0] core_bankmachine6_syncfifo6_din;
wire [24:0] core_bankmachine6_syncfifo6_dout;
reg [3:0] core_bankmachine6_level = 4'd0;
reg core_bankmachine6_replace = 1'd0;
reg [2:0] core_bankmachine6_produce = 3'd0;
reg [2:0] core_bankmachine6_consume = 3'd0;
reg [2:0] core_bankmachine6_wrport_adr;
wire [24:0] core_bankmachine6_wrport_dat_r;
wire core_bankmachine6_wrport_we;
wire [24:0] core_bankmachine6_wrport_dat_w;
wire core_bankmachine6_do_read;
wire [2:0] core_bankmachine6_rdport_adr;
wire [24:0] core_bankmachine6_rdport_dat_r;
wire core_bankmachine6_fifo_in_payload_we;
wire [21:0] core_bankmachine6_fifo_in_payload_addr;
wire core_bankmachine6_fifo_in_first;
wire core_bankmachine6_fifo_in_last;
wire core_bankmachine6_fifo_out_payload_we;
wire [21:0] core_bankmachine6_fifo_out_payload_addr;
wire core_bankmachine6_fifo_out_first;
wire core_bankmachine6_fifo_out_last;
wire core_bankmachine6_sink_sink_valid;
wire core_bankmachine6_sink_sink_ready;
wire core_bankmachine6_sink_sink_first;
wire core_bankmachine6_sink_sink_last;
wire core_bankmachine6_sink_sink_payload_we;
wire [21:0] core_bankmachine6_sink_sink_payload_addr;
wire core_bankmachine6_source_source_valid;
wire core_bankmachine6_source_source_ready;
wire core_bankmachine6_source_source_first;
wire core_bankmachine6_source_source_last;
wire core_bankmachine6_source_source_payload_we;
wire [21:0] core_bankmachine6_source_source_payload_addr;
wire core_bankmachine6_pipe_valid_sink_valid;
wire core_bankmachine6_pipe_valid_sink_ready;
wire core_bankmachine6_pipe_valid_sink_first;
wire core_bankmachine6_pipe_valid_sink_last;
wire core_bankmachine6_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine6_pipe_valid_sink_payload_addr;
reg core_bankmachine6_pipe_valid_source_valid = 1'd0;
wire core_bankmachine6_pipe_valid_source_ready;
reg core_bankmachine6_pipe_valid_source_first = 1'd0;
reg core_bankmachine6_pipe_valid_source_last = 1'd0;
reg core_bankmachine6_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine6_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine6_row = 15'd0;
reg core_bankmachine6_row_opened = 1'd0;
wire core_bankmachine6_row_hit;
reg core_bankmachine6_row_open;
reg core_bankmachine6_row_close;
reg core_bankmachine6_row_col_n_addr_sel;
wire core_bankmachine6_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine6_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine6_twtpcon_count = 3'd0;
wire core_bankmachine6_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine6_trccon_ready = 1'd0;
reg [2:0] core_bankmachine6_trccon_count = 3'd0;
wire core_bankmachine6_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine6_trascon_ready = 1'd0;
reg [1:0] core_bankmachine6_trascon_count = 2'd0;
wire core_bankmachine7_req_valid;
wire core_bankmachine7_req_ready;
wire core_bankmachine7_req_we;
wire [21:0] core_bankmachine7_req_addr;
wire core_bankmachine7_req_lock;
reg core_bankmachine7_req_wdata_ready;
reg core_bankmachine7_req_rdata_valid;
wire core_bankmachine7_refresh_req;
reg core_bankmachine7_refresh_gnt;
reg core_bankmachine7_cmd_valid;
reg core_bankmachine7_cmd_ready;
reg [14:0] core_bankmachine7_cmd_payload_a;
wire [2:0] core_bankmachine7_cmd_payload_ba;
reg core_bankmachine7_cmd_payload_cas;
reg core_bankmachine7_cmd_payload_ras;
reg core_bankmachine7_cmd_payload_we;
reg core_bankmachine7_cmd_payload_is_cmd;
reg core_bankmachine7_cmd_payload_is_read;
reg core_bankmachine7_cmd_payload_is_write;
reg core_bankmachine7_auto_precharge;
wire core_bankmachine7_sink_valid;
wire core_bankmachine7_sink_ready;
reg core_bankmachine7_sink_first = 1'd0;
reg core_bankmachine7_sink_last = 1'd0;
wire core_bankmachine7_sink_payload_we;
wire [21:0] core_bankmachine7_sink_payload_addr;
wire core_bankmachine7_source_valid;
wire core_bankmachine7_source_ready;
wire core_bankmachine7_source_first;
wire core_bankmachine7_source_last;
wire core_bankmachine7_source_payload_we;
wire [21:0] core_bankmachine7_source_payload_addr;
wire core_bankmachine7_syncfifo7_we;
wire core_bankmachine7_syncfifo7_writable;
wire core_bankmachine7_syncfifo7_re;
wire core_bankmachine7_syncfifo7_readable;
wire [24:0] core_bankmachine7_syncfifo7_din;
wire [24:0] core_bankmachine7_syncfifo7_dout;
reg [3:0] core_bankmachine7_level = 4'd0;
reg core_bankmachine7_replace = 1'd0;
reg [2:0] core_bankmachine7_produce = 3'd0;
reg [2:0] core_bankmachine7_consume = 3'd0;
reg [2:0] core_bankmachine7_wrport_adr;
wire [24:0] core_bankmachine7_wrport_dat_r;
wire core_bankmachine7_wrport_we;
wire [24:0] core_bankmachine7_wrport_dat_w;
wire core_bankmachine7_do_read;
wire [2:0] core_bankmachine7_rdport_adr;
wire [24:0] core_bankmachine7_rdport_dat_r;
wire core_bankmachine7_fifo_in_payload_we;
wire [21:0] core_bankmachine7_fifo_in_payload_addr;
wire core_bankmachine7_fifo_in_first;
wire core_bankmachine7_fifo_in_last;
wire core_bankmachine7_fifo_out_payload_we;
wire [21:0] core_bankmachine7_fifo_out_payload_addr;
wire core_bankmachine7_fifo_out_first;
wire core_bankmachine7_fifo_out_last;
wire core_bankmachine7_sink_sink_valid;
wire core_bankmachine7_sink_sink_ready;
wire core_bankmachine7_sink_sink_first;
wire core_bankmachine7_sink_sink_last;
wire core_bankmachine7_sink_sink_payload_we;
wire [21:0] core_bankmachine7_sink_sink_payload_addr;
wire core_bankmachine7_source_source_valid;
wire core_bankmachine7_source_source_ready;
wire core_bankmachine7_source_source_first;
wire core_bankmachine7_source_source_last;
wire core_bankmachine7_source_source_payload_we;
wire [21:0] core_bankmachine7_source_source_payload_addr;
wire core_bankmachine7_pipe_valid_sink_valid;
wire core_bankmachine7_pipe_valid_sink_ready;
wire core_bankmachine7_pipe_valid_sink_first;
wire core_bankmachine7_pipe_valid_sink_last;
wire core_bankmachine7_pipe_valid_sink_payload_we;
wire [21:0] core_bankmachine7_pipe_valid_sink_payload_addr;
reg core_bankmachine7_pipe_valid_source_valid = 1'd0;
wire core_bankmachine7_pipe_valid_source_ready;
reg core_bankmachine7_pipe_valid_source_first = 1'd0;
reg core_bankmachine7_pipe_valid_source_last = 1'd0;
reg core_bankmachine7_pipe_valid_source_payload_we = 1'd0;
reg [21:0] core_bankmachine7_pipe_valid_source_payload_addr = 22'd0;
reg [14:0] core_bankmachine7_row = 15'd0;
reg core_bankmachine7_row_opened = 1'd0;
wire core_bankmachine7_row_hit;
reg core_bankmachine7_row_open;
reg core_bankmachine7_row_close;
reg core_bankmachine7_row_col_n_addr_sel;
wire core_bankmachine7_twtpcon_valid;
(* no_retiming = "true" *) reg core_bankmachine7_twtpcon_ready = 1'd0;
reg [2:0] core_bankmachine7_twtpcon_count = 3'd0;
wire core_bankmachine7_trccon_valid;
(* no_retiming = "true" *) reg core_bankmachine7_trccon_ready = 1'd0;
reg [2:0] core_bankmachine7_trccon_count = 3'd0;
wire core_bankmachine7_trascon_valid;
(* no_retiming = "true" *) reg core_bankmachine7_trascon_ready = 1'd0;
reg [1:0] core_bankmachine7_trascon_count = 2'd0;
wire core_ras_allowed;
wire core_cas_allowed;
wire [1:0] core_nphases;
wire [1:0] core_rdphase;
reg core_choose_cmd_want_reads = 1'd0;
reg core_choose_cmd_want_writes = 1'd0;
reg core_choose_cmd_want_cmds = 1'd0;
reg core_choose_cmd_want_activates;
wire core_choose_cmd_cmd_valid;
reg core_choose_cmd_cmd_ready;
wire [14:0] core_choose_cmd_cmd_payload_a;
wire [2:0] core_choose_cmd_cmd_payload_ba;
reg core_choose_cmd_cmd_payload_cas;
reg core_choose_cmd_cmd_payload_ras;
reg core_choose_cmd_cmd_payload_we;
wire core_choose_cmd_cmd_payload_is_cmd;
wire core_choose_cmd_cmd_payload_is_read;
wire core_choose_cmd_cmd_payload_is_write;
reg [7:0] core_choose_cmd_valids;
wire [7:0] core_choose_cmd_request;
reg [2:0] core_choose_cmd_grant = 3'd0;
wire core_choose_cmd_ce;
reg core_choose_req_want_reads;
reg core_choose_req_want_writes;
reg core_choose_req_want_cmds = 1'd0;
reg core_choose_req_want_activates = 1'd0;
wire core_choose_req_cmd_valid;
reg core_choose_req_cmd_ready;
wire [14:0] core_choose_req_cmd_payload_a;
wire [2:0] core_choose_req_cmd_payload_ba;
reg core_choose_req_cmd_payload_cas;
reg core_choose_req_cmd_payload_ras;
reg core_choose_req_cmd_payload_we;
wire core_choose_req_cmd_payload_is_cmd;
wire core_choose_req_cmd_payload_is_read;
wire core_choose_req_cmd_payload_is_write;
reg [7:0] core_choose_req_valids;
wire [7:0] core_choose_req_request;
reg [2:0] core_choose_req_grant = 3'd0;
wire core_choose_req_ce;
reg [14:0] core_nop_a = 15'd0;
reg [2:0] core_nop_ba = 3'd0;
reg [1:0] core_steerer0;
reg [1:0] core_steerer1;
reg [1:0] core_steerer2;
reg [1:0] core_steerer3;
reg core_steerer4 = 1'd1;
reg core_steerer5 = 1'd1;
reg core_steerer6 = 1'd1;
reg core_steerer7 = 1'd1;
reg core_steerer8 = 1'd1;
reg core_steerer9 = 1'd1;
reg core_steerer10 = 1'd1;
reg core_steerer11 = 1'd1;
wire core_trrdcon_valid;
(* no_retiming = "true" *) reg core_trrdcon_ready = 1'd0;
reg core_trrdcon_count = 1'd0;
wire core_tfawcon_valid;
(* no_retiming = "true" *) reg core_tfawcon_ready = 1'd1;
wire [1:0] core_tfawcon_count;
reg [3:0] core_tfawcon_window = 4'd0;
wire core_tccdcon_valid;
(* no_retiming = "true" *) reg core_tccdcon_ready = 1'd0;
reg core_tccdcon_count = 1'd0;
wire core_twtrcon_valid;
(* no_retiming = "true" *) reg core_twtrcon_ready = 1'd0;
reg [2:0] core_twtrcon_count = 3'd0;
wire core_read_available;
wire core_write_available;
reg core_en0;
wire core_max_time0;
reg [4:0] core_time0 = 5'd0;
reg core_en1;
wire core_max_time1;
reg [3:0] core_time1 = 4'd0;
wire core_go_to_refresh;
reg [1:0] refresher_state = 2'd0;
reg [1:0] refresher_next_state;
reg [2:0] bankmachine0_state = 3'd0;
reg [2:0] bankmachine0_next_state;
reg [2:0] bankmachine1_state = 3'd0;
reg [2:0] bankmachine1_next_state;
reg [2:0] bankmachine2_state = 3'd0;
reg [2:0] bankmachine2_next_state;
reg [2:0] bankmachine3_state = 3'd0;
reg [2:0] bankmachine3_next_state;
reg [2:0] bankmachine4_state = 3'd0;
reg [2:0] bankmachine4_next_state;
reg [2:0] bankmachine5_state = 3'd0;
reg [2:0] bankmachine5_next_state;
reg [2:0] bankmachine6_state = 3'd0;
reg [2:0] bankmachine6_next_state;
reg [2:0] bankmachine7_state = 3'd0;
reg [2:0] bankmachine7_next_state;
reg [3:0] multiplexer_state = 4'd0;
reg [3:0] multiplexer_next_state;
wire roundrobin0_request;
wire roundrobin0_grant;
wire roundrobin0_ce;
wire roundrobin1_request;
wire roundrobin1_grant;
wire roundrobin1_ce;
wire roundrobin2_request;
wire roundrobin2_grant;
wire roundrobin2_ce;
wire roundrobin3_request;
wire roundrobin3_grant;
wire roundrobin3_ce;
wire roundrobin4_request;
wire roundrobin4_grant;
wire roundrobin4_ce;
wire roundrobin5_request;
wire roundrobin5_grant;
wire roundrobin5_ce;
wire roundrobin6_request;
wire roundrobin6_grant;
wire roundrobin6_ce;
wire roundrobin7_request;
wire roundrobin7_grant;
wire roundrobin7_ce;
reg locked0 = 1'd0;
reg locked1 = 1'd0;
reg locked2 = 1'd0;
reg locked3 = 1'd0;
reg locked4 = 1'd0;
reg locked5 = 1'd0;
reg locked6 = 1'd0;
reg locked7 = 1'd0;
reg new_master_wdata_ready0 = 1'd0;
reg new_master_wdata_ready1 = 1'd0;
reg new_master_rdata_valid0 = 1'd0;
reg new_master_rdata_valid1 = 1'd0;
reg new_master_rdata_valid2 = 1'd0;
reg new_master_rdata_valid3 = 1'd0;
reg new_master_rdata_valid4 = 1'd0;
reg new_master_rdata_valid5 = 1'd0;
reg new_master_rdata_valid6 = 1'd0;
reg new_master_rdata_valid7 = 1'd0;
reg new_master_rdata_valid8 = 1'd0;
reg rhs_self0;
reg [14:0] rhs_self1;
reg [2:0] rhs_self2;
reg rhs_self3;
reg rhs_self4;
reg rhs_self5;
reg t_self0;
reg t_self1;
reg t_self2;
reg rhs_self6;
reg [14:0] rhs_self7;
reg [2:0] rhs_self8;
reg rhs_self9;
reg rhs_self10;
reg rhs_self11;
reg t_self3;
reg t_self4;
reg t_self5;
reg [21:0] rhs_self12;
reg rhs_self13;
reg rhs_self14;
reg [21:0] rhs_self15;
reg rhs_self16;
reg rhs_self17;
reg [21:0] rhs_self18;
reg rhs_self19;
reg rhs_self20;
reg [21:0] rhs_self21;
reg rhs_self22;
reg rhs_self23;
reg [21:0] rhs_self24;
reg rhs_self25;
reg rhs_self26;
reg [21:0] rhs_self27;
reg rhs_self28;
reg rhs_self29;
reg [21:0] rhs_self30;
reg rhs_self31;
reg rhs_self32;
reg [21:0] rhs_self33;
reg rhs_self34;
reg rhs_self35;
reg [2:0] self0;
reg [14:0] self1;
reg self2;
reg self3;
reg self4;
reg self5;
reg self6;
reg [2:0] self7;
reg [14:0] self8;
reg self9;
reg self10;
reg self11;
reg self12;
reg self13;
reg [2:0] self14;
reg [14:0] self15;
reg self16;
reg self17;
reg self18;
reg self19;
reg self20;
reg [2:0] self21;
reg [14:0] self22;
reg self23;
reg self24;
reg self25;
reg self26;
reg self27;

// synthesis translate_off
reg dummy_s;
initial dummy_s <= 1'd0;
// synthesis translate_on

assign p0_address = phy_dfi_p0_address;
assign p0_bank = phy_dfi_p0_bank;
assign p0_cs_n = phy_dfi_p0_cs_n;
assign p0_ras_n = phy_dfi_p0_ras_n;
assign p0_cas_n = phy_dfi_p0_cas_n;
assign p0_we_n = phy_dfi_p0_we_n;
assign p0_wrdata_en = phy_dfi_p0_wrdata_en;
assign p0_rddata_en = phy_dfi_p0_rddata_en;
assign phy_dfi_p0_rddata_valid = 1'd0;
assign p1_address = phy_dfi_p1_address;
assign p1_bank = phy_dfi_p1_bank;
assign p1_cs_n = phy_dfi_p1_cs_n;
assign p1_ras_n = phy_dfi_p1_ras_n;
assign p1_cas_n = phy_dfi_p1_cas_n;
assign p1_we_n = phy_dfi_p1_we_n;
assign p1_wrdata_en = phy_dfi_p1_wrdata_en;
assign p1_rddata_en = phy_dfi_p1_rddata_en;
assign phy_dfi_p1_rddata_valid = 1'd0;
assign p2_address = phy_dfi_p2_address;
assign p2_bank = phy_dfi_p2_bank;
assign p2_cs_n = phy_dfi_p2_cs_n;
assign p2_ras_n = phy_dfi_p2_ras_n;
assign p2_cas_n = phy_dfi_p2_cas_n;
assign p2_we_n = phy_dfi_p2_we_n;
assign p2_wrdata_en = phy_dfi_p2_wrdata_en;
assign p2_rddata_en = phy_dfi_p2_rddata_en;
assign phy_dfi_p2_rddata_valid = 1'd0;
assign p3_address = phy_dfi_p3_address;
assign p3_bank = phy_dfi_p3_bank;
assign p3_cs_n = phy_dfi_p3_cs_n;
assign p3_ras_n = phy_dfi_p3_ras_n;
assign p3_cas_n = phy_dfi_p3_cas_n;
assign p3_we_n = phy_dfi_p3_we_n;
assign p3_wrdata_en = phy_dfi_p3_wrdata_en;
assign p3_rddata_en = phy_dfi_p3_rddata_en;
assign phy_dfi_p3_rddata_valid = 1'd0;
assign phy_dfi_p0_address = core_master_p0_address;
assign phy_dfi_p0_bank = core_master_p0_bank;
assign phy_dfi_p0_cas_n = core_master_p0_cas_n;
assign phy_dfi_p0_cs_n = core_master_p0_cs_n;
assign phy_dfi_p0_ras_n = core_master_p0_ras_n;
assign phy_dfi_p0_we_n = core_master_p0_we_n;
assign phy_dfi_p0_cke = core_master_p0_cke;
assign phy_dfi_p0_odt = core_master_p0_odt;
assign phy_dfi_p0_reset_n = core_master_p0_reset_n;
assign phy_dfi_p0_act_n = core_master_p0_act_n;
assign phy_dfi_p0_wrdata = core_master_p0_wrdata;
assign phy_dfi_p0_wrdata_en = core_master_p0_wrdata_en;
assign phy_dfi_p0_wrdata_mask = core_master_p0_wrdata_mask;
assign phy_dfi_p0_rddata_en = core_master_p0_rddata_en;
assign core_master_p0_rddata = phy_dfi_p0_rddata;
assign core_master_p0_rddata_valid = phy_dfi_p0_rddata_valid;
assign phy_dfi_p1_address = core_master_p1_address;
assign phy_dfi_p1_bank = core_master_p1_bank;
assign phy_dfi_p1_cas_n = core_master_p1_cas_n;
assign phy_dfi_p1_cs_n = core_master_p1_cs_n;
assign phy_dfi_p1_ras_n = core_master_p1_ras_n;
assign phy_dfi_p1_we_n = core_master_p1_we_n;
assign phy_dfi_p1_cke = core_master_p1_cke;
assign phy_dfi_p1_odt = core_master_p1_odt;
assign phy_dfi_p1_reset_n = core_master_p1_reset_n;
assign phy_dfi_p1_act_n = core_master_p1_act_n;
assign phy_dfi_p1_wrdata = core_master_p1_wrdata;
assign phy_dfi_p1_wrdata_en = core_master_p1_wrdata_en;
assign phy_dfi_p1_wrdata_mask = core_master_p1_wrdata_mask;
assign phy_dfi_p1_rddata_en = core_master_p1_rddata_en;
assign core_master_p1_rddata = phy_dfi_p1_rddata;
assign core_master_p1_rddata_valid = phy_dfi_p1_rddata_valid;
assign phy_dfi_p2_address = core_master_p2_address;
assign phy_dfi_p2_bank = core_master_p2_bank;
assign phy_dfi_p2_cas_n = core_master_p2_cas_n;
assign phy_dfi_p2_cs_n = core_master_p2_cs_n;
assign phy_dfi_p2_ras_n = core_master_p2_ras_n;
assign phy_dfi_p2_we_n = core_master_p2_we_n;
assign phy_dfi_p2_cke = core_master_p2_cke;
assign phy_dfi_p2_odt = core_master_p2_odt;
assign phy_dfi_p2_reset_n = core_master_p2_reset_n;
assign phy_dfi_p2_act_n = core_master_p2_act_n;
assign phy_dfi_p2_wrdata = core_master_p2_wrdata;
assign phy_dfi_p2_wrdata_en = core_master_p2_wrdata_en;
assign phy_dfi_p2_wrdata_mask = core_master_p2_wrdata_mask;
assign phy_dfi_p2_rddata_en = core_master_p2_rddata_en;
assign core_master_p2_rddata = phy_dfi_p2_rddata;
assign core_master_p2_rddata_valid = phy_dfi_p2_rddata_valid;
assign phy_dfi_p3_address = core_master_p3_address;
assign phy_dfi_p3_bank = core_master_p3_bank;
assign phy_dfi_p3_cas_n = core_master_p3_cas_n;
assign phy_dfi_p3_cs_n = core_master_p3_cs_n;
assign phy_dfi_p3_ras_n = core_master_p3_ras_n;
assign phy_dfi_p3_we_n = core_master_p3_we_n;
assign phy_dfi_p3_cke = core_master_p3_cke;
assign phy_dfi_p3_odt = core_master_p3_odt;
assign phy_dfi_p3_reset_n = core_master_p3_reset_n;
assign phy_dfi_p3_act_n = core_master_p3_act_n;
assign phy_dfi_p3_wrdata = core_master_p3_wrdata;
assign phy_dfi_p3_wrdata_en = core_master_p3_wrdata_en;
assign phy_dfi_p3_wrdata_mask = core_master_p3_wrdata_mask;
assign phy_dfi_p3_rddata_en = core_master_p3_rddata_en;
assign core_master_p3_rddata = phy_dfi_p3_rddata;
assign core_master_p3_rddata_valid = phy_dfi_p3_rddata_valid;
assign core_slave_p0_address = core_dfi_p0_address;
assign core_slave_p0_bank = core_dfi_p0_bank;
assign core_slave_p0_cas_n = core_dfi_p0_cas_n;
assign core_slave_p0_cs_n = core_dfi_p0_cs_n;
assign core_slave_p0_ras_n = core_dfi_p0_ras_n;
assign core_slave_p0_we_n = core_dfi_p0_we_n;
assign core_slave_p0_cke = core_dfi_p0_cke;
assign core_slave_p0_odt = core_dfi_p0_odt;
assign core_slave_p0_reset_n = core_dfi_p0_reset_n;
assign core_slave_p0_act_n = core_dfi_p0_act_n;
assign core_slave_p0_wrdata = core_dfi_p0_wrdata;
assign core_slave_p0_wrdata_en = core_dfi_p0_wrdata_en;
assign core_slave_p0_wrdata_mask = core_dfi_p0_wrdata_mask;
assign core_slave_p0_rddata_en = core_dfi_p0_rddata_en;
assign core_dfi_p0_rddata = core_slave_p0_rddata;
assign core_dfi_p0_rddata_valid = core_slave_p0_rddata_valid;
assign core_slave_p1_address = core_dfi_p1_address;
assign core_slave_p1_bank = core_dfi_p1_bank;
assign core_slave_p1_cas_n = core_dfi_p1_cas_n;
assign core_slave_p1_cs_n = core_dfi_p1_cs_n;
assign core_slave_p1_ras_n = core_dfi_p1_ras_n;
assign core_slave_p1_we_n = core_dfi_p1_we_n;
assign core_slave_p1_cke = core_dfi_p1_cke;
assign core_slave_p1_odt = core_dfi_p1_odt;
assign core_slave_p1_reset_n = core_dfi_p1_reset_n;
assign core_slave_p1_act_n = core_dfi_p1_act_n;
assign core_slave_p1_wrdata = core_dfi_p1_wrdata;
assign core_slave_p1_wrdata_en = core_dfi_p1_wrdata_en;
assign core_slave_p1_wrdata_mask = core_dfi_p1_wrdata_mask;
assign core_slave_p1_rddata_en = core_dfi_p1_rddata_en;
assign core_dfi_p1_rddata = core_slave_p1_rddata;
assign core_dfi_p1_rddata_valid = core_slave_p1_rddata_valid;
assign core_slave_p2_address = core_dfi_p2_address;
assign core_slave_p2_bank = core_dfi_p2_bank;
assign core_slave_p2_cas_n = core_dfi_p2_cas_n;
assign core_slave_p2_cs_n = core_dfi_p2_cs_n;
assign core_slave_p2_ras_n = core_dfi_p2_ras_n;
assign core_slave_p2_we_n = core_dfi_p2_we_n;
assign core_slave_p2_cke = core_dfi_p2_cke;
assign core_slave_p2_odt = core_dfi_p2_odt;
assign core_slave_p2_reset_n = core_dfi_p2_reset_n;
assign core_slave_p2_act_n = core_dfi_p2_act_n;
assign core_slave_p2_wrdata = core_dfi_p2_wrdata;
assign core_slave_p2_wrdata_en = core_dfi_p2_wrdata_en;
assign core_slave_p2_wrdata_mask = core_dfi_p2_wrdata_mask;
assign core_slave_p2_rddata_en = core_dfi_p2_rddata_en;
assign core_dfi_p2_rddata = core_slave_p2_rddata;
assign core_dfi_p2_rddata_valid = core_slave_p2_rddata_valid;
assign core_slave_p3_address = core_dfi_p3_address;
assign core_slave_p3_bank = core_dfi_p3_bank;
assign core_slave_p3_cas_n = core_dfi_p3_cas_n;
assign core_slave_p3_cs_n = core_dfi_p3_cs_n;
assign core_slave_p3_ras_n = core_dfi_p3_ras_n;
assign core_slave_p3_we_n = core_dfi_p3_we_n;
assign core_slave_p3_cke = core_dfi_p3_cke;
assign core_slave_p3_odt = core_dfi_p3_odt;
assign core_slave_p3_reset_n = core_dfi_p3_reset_n;
assign core_slave_p3_act_n = core_dfi_p3_act_n;
assign core_slave_p3_wrdata = core_dfi_p3_wrdata;
assign core_slave_p3_wrdata_en = core_dfi_p3_wrdata_en;
assign core_slave_p3_wrdata_mask = core_dfi_p3_wrdata_mask;
assign core_slave_p3_rddata_en = core_dfi_p3_rddata_en;
assign core_dfi_p3_rddata = core_slave_p3_rddata;
assign core_dfi_p3_rddata_valid = core_slave_p3_rddata_valid;

// synthesis translate_off
reg dummy_d;
// synthesis translate_on
always @(*) begin
	core_slave_p0_rddata <= 64'd0;
	core_slave_p0_rddata_valid <= 1'd0;
	core_slave_p1_rddata <= 64'd0;
	core_slave_p1_rddata_valid <= 1'd0;
	core_slave_p2_rddata <= 64'd0;
	core_slave_p2_rddata_valid <= 1'd0;
	core_slave_p3_rddata <= 64'd0;
	core_slave_p3_rddata_valid <= 1'd0;
	core_master_p0_address <= 15'd0;
	core_master_p0_bank <= 3'd0;
	core_master_p0_cas_n <= 1'd1;
	core_master_p0_cs_n <= 1'd1;
	core_master_p0_ras_n <= 1'd1;
	core_master_p0_we_n <= 1'd1;
	core_master_p0_cke <= 1'd0;
	core_master_p0_odt <= 1'd0;
	core_master_p0_reset_n <= 1'd0;
	core_master_p0_act_n <= 1'd1;
	core_master_p0_wrdata <= 64'd0;
	core_master_p0_wrdata_en <= 1'd0;
	core_master_p0_wrdata_mask <= 8'd0;
	core_master_p0_rddata_en <= 1'd0;
	core_master_p1_address <= 15'd0;
	core_master_p1_bank <= 3'd0;
	core_master_p1_cas_n <= 1'd1;
	core_master_p1_cs_n <= 1'd1;
	core_master_p1_ras_n <= 1'd1;
	core_master_p1_we_n <= 1'd1;
	core_master_p1_cke <= 1'd0;
	core_master_p1_odt <= 1'd0;
	core_master_p1_reset_n <= 1'd0;
	core_master_p1_act_n <= 1'd1;
	core_master_p1_wrdata <= 64'd0;
	core_master_p1_wrdata_en <= 1'd0;
	core_master_p1_wrdata_mask <= 8'd0;
	core_master_p1_rddata_en <= 1'd0;
	core_master_p2_address <= 15'd0;
	core_master_p2_bank <= 3'd0;
	core_master_p2_cas_n <= 1'd1;
	core_master_p2_cs_n <= 1'd1;
	core_master_p2_ras_n <= 1'd1;
	core_master_p2_we_n <= 1'd1;
	core_master_p2_cke <= 1'd0;
	core_master_p2_odt <= 1'd0;
	core_master_p2_reset_n <= 1'd0;
	core_master_p2_act_n <= 1'd1;
	core_master_p2_wrdata <= 64'd0;
	core_master_p2_wrdata_en <= 1'd0;
	core_master_p2_wrdata_mask <= 8'd0;
	core_master_p2_rddata_en <= 1'd0;
	core_master_p3_address <= 15'd0;
	core_master_p3_bank <= 3'd0;
	core_master_p3_cas_n <= 1'd1;
	core_master_p3_cs_n <= 1'd1;
	core_master_p3_ras_n <= 1'd1;
	core_master_p3_we_n <= 1'd1;
	core_master_p3_cke <= 1'd0;
	core_master_p3_odt <= 1'd0;
	core_master_p3_reset_n <= 1'd0;
	core_master_p3_act_n <= 1'd1;
	core_master_p3_wrdata <= 64'd0;
	core_master_p3_wrdata_en <= 1'd0;
	core_master_p3_wrdata_mask <= 8'd0;
	core_master_p3_rddata_en <= 1'd0;
	core_csr_dfi_p0_rddata <= 64'd0;
	core_csr_dfi_p0_rddata_valid <= 1'd0;
	core_csr_dfi_p1_rddata <= 64'd0;
	core_csr_dfi_p1_rddata_valid <= 1'd0;
	core_csr_dfi_p2_rddata <= 64'd0;
	core_csr_dfi_p2_rddata_valid <= 1'd0;
	core_csr_dfi_p3_rddata <= 64'd0;
	core_csr_dfi_p3_rddata_valid <= 1'd0;
	core_ext_dfi_p0_rddata <= 64'd0;
	core_ext_dfi_p0_rddata_valid <= 1'd0;
	core_ext_dfi_p1_rddata <= 64'd0;
	core_ext_dfi_p1_rddata_valid <= 1'd0;
	core_ext_dfi_p2_rddata <= 64'd0;
	core_ext_dfi_p2_rddata_valid <= 1'd0;
	core_ext_dfi_p3_rddata <= 64'd0;
	core_ext_dfi_p3_rddata_valid <= 1'd0;
	if (core_sel) begin
		if (core_ext_dfi_sel) begin
			core_master_p0_address <= core_ext_dfi_p0_address;
			core_master_p0_bank <= core_ext_dfi_p0_bank;
			core_master_p0_cas_n <= core_ext_dfi_p0_cas_n;
			core_master_p0_cs_n <= core_ext_dfi_p0_cs_n;
			core_master_p0_ras_n <= core_ext_dfi_p0_ras_n;
			core_master_p0_we_n <= core_ext_dfi_p0_we_n;
			core_master_p0_cke <= core_ext_dfi_p0_cke;
			core_master_p0_odt <= core_ext_dfi_p0_odt;
			core_master_p0_reset_n <= core_ext_dfi_p0_reset_n;
			core_master_p0_act_n <= core_ext_dfi_p0_act_n;
			core_master_p0_wrdata <= core_ext_dfi_p0_wrdata;
			core_master_p0_wrdata_en <= core_ext_dfi_p0_wrdata_en;
			core_master_p0_wrdata_mask <= core_ext_dfi_p0_wrdata_mask;
			core_master_p0_rddata_en <= core_ext_dfi_p0_rddata_en;
			core_ext_dfi_p0_rddata <= core_master_p0_rddata;
			core_ext_dfi_p0_rddata_valid <= core_master_p0_rddata_valid;
			core_master_p1_address <= core_ext_dfi_p1_address;
			core_master_p1_bank <= core_ext_dfi_p1_bank;
			core_master_p1_cas_n <= core_ext_dfi_p1_cas_n;
			core_master_p1_cs_n <= core_ext_dfi_p1_cs_n;
			core_master_p1_ras_n <= core_ext_dfi_p1_ras_n;
			core_master_p1_we_n <= core_ext_dfi_p1_we_n;
			core_master_p1_cke <= core_ext_dfi_p1_cke;
			core_master_p1_odt <= core_ext_dfi_p1_odt;
			core_master_p1_reset_n <= core_ext_dfi_p1_reset_n;
			core_master_p1_act_n <= core_ext_dfi_p1_act_n;
			core_master_p1_wrdata <= core_ext_dfi_p1_wrdata;
			core_master_p1_wrdata_en <= core_ext_dfi_p1_wrdata_en;
			core_master_p1_wrdata_mask <= core_ext_dfi_p1_wrdata_mask;
			core_master_p1_rddata_en <= core_ext_dfi_p1_rddata_en;
			core_ext_dfi_p1_rddata <= core_master_p1_rddata;
			core_ext_dfi_p1_rddata_valid <= core_master_p1_rddata_valid;
			core_master_p2_address <= core_ext_dfi_p2_address;
			core_master_p2_bank <= core_ext_dfi_p2_bank;
			core_master_p2_cas_n <= core_ext_dfi_p2_cas_n;
			core_master_p2_cs_n <= core_ext_dfi_p2_cs_n;
			core_master_p2_ras_n <= core_ext_dfi_p2_ras_n;
			core_master_p2_we_n <= core_ext_dfi_p2_we_n;
			core_master_p2_cke <= core_ext_dfi_p2_cke;
			core_master_p2_odt <= core_ext_dfi_p2_odt;
			core_master_p2_reset_n <= core_ext_dfi_p2_reset_n;
			core_master_p2_act_n <= core_ext_dfi_p2_act_n;
			core_master_p2_wrdata <= core_ext_dfi_p2_wrdata;
			core_master_p2_wrdata_en <= core_ext_dfi_p2_wrdata_en;
			core_master_p2_wrdata_mask <= core_ext_dfi_p2_wrdata_mask;
			core_master_p2_rddata_en <= core_ext_dfi_p2_rddata_en;
			core_ext_dfi_p2_rddata <= core_master_p2_rddata;
			core_ext_dfi_p2_rddata_valid <= core_master_p2_rddata_valid;
			core_master_p3_address <= core_ext_dfi_p3_address;
			core_master_p3_bank <= core_ext_dfi_p3_bank;
			core_master_p3_cas_n <= core_ext_dfi_p3_cas_n;
			core_master_p3_cs_n <= core_ext_dfi_p3_cs_n;
			core_master_p3_ras_n <= core_ext_dfi_p3_ras_n;
			core_master_p3_we_n <= core_ext_dfi_p3_we_n;
			core_master_p3_cke <= core_ext_dfi_p3_cke;
			core_master_p3_odt <= core_ext_dfi_p3_odt;
			core_master_p3_reset_n <= core_ext_dfi_p3_reset_n;
			core_master_p3_act_n <= core_ext_dfi_p3_act_n;
			core_master_p3_wrdata <= core_ext_dfi_p3_wrdata;
			core_master_p3_wrdata_en <= core_ext_dfi_p3_wrdata_en;
			core_master_p3_wrdata_mask <= core_ext_dfi_p3_wrdata_mask;
			core_master_p3_rddata_en <= core_ext_dfi_p3_rddata_en;
			core_ext_dfi_p3_rddata <= core_master_p3_rddata;
			core_ext_dfi_p3_rddata_valid <= core_master_p3_rddata_valid;
		end else begin
			core_master_p0_address <= core_slave_p0_address;
			core_master_p0_bank <= core_slave_p0_bank;
			core_master_p0_cas_n <= core_slave_p0_cas_n;
			core_master_p0_cs_n <= core_slave_p0_cs_n;
			core_master_p0_ras_n <= core_slave_p0_ras_n;
			core_master_p0_we_n <= core_slave_p0_we_n;
			core_master_p0_cke <= core_slave_p0_cke;
			core_master_p0_odt <= core_slave_p0_odt;
			core_master_p0_reset_n <= core_slave_p0_reset_n;
			core_master_p0_act_n <= core_slave_p0_act_n;
			core_master_p0_wrdata <= core_slave_p0_wrdata;
			core_master_p0_wrdata_en <= core_slave_p0_wrdata_en;
			core_master_p0_wrdata_mask <= core_slave_p0_wrdata_mask;
			core_master_p0_rddata_en <= core_slave_p0_rddata_en;
			core_slave_p0_rddata <= core_master_p0_rddata;
			core_slave_p0_rddata_valid <= core_master_p0_rddata_valid;
			core_master_p1_address <= core_slave_p1_address;
			core_master_p1_bank <= core_slave_p1_bank;
			core_master_p1_cas_n <= core_slave_p1_cas_n;
			core_master_p1_cs_n <= core_slave_p1_cs_n;
			core_master_p1_ras_n <= core_slave_p1_ras_n;
			core_master_p1_we_n <= core_slave_p1_we_n;
			core_master_p1_cke <= core_slave_p1_cke;
			core_master_p1_odt <= core_slave_p1_odt;
			core_master_p1_reset_n <= core_slave_p1_reset_n;
			core_master_p1_act_n <= core_slave_p1_act_n;
			core_master_p1_wrdata <= core_slave_p1_wrdata;
			core_master_p1_wrdata_en <= core_slave_p1_wrdata_en;
			core_master_p1_wrdata_mask <= core_slave_p1_wrdata_mask;
			core_master_p1_rddata_en <= core_slave_p1_rddata_en;
			core_slave_p1_rddata <= core_master_p1_rddata;
			core_slave_p1_rddata_valid <= core_master_p1_rddata_valid;
			core_master_p2_address <= core_slave_p2_address;
			core_master_p2_bank <= core_slave_p2_bank;
			core_master_p2_cas_n <= core_slave_p2_cas_n;
			core_master_p2_cs_n <= core_slave_p2_cs_n;
			core_master_p2_ras_n <= core_slave_p2_ras_n;
			core_master_p2_we_n <= core_slave_p2_we_n;
			core_master_p2_cke <= core_slave_p2_cke;
			core_master_p2_odt <= core_slave_p2_odt;
			core_master_p2_reset_n <= core_slave_p2_reset_n;
			core_master_p2_act_n <= core_slave_p2_act_n;
			core_master_p2_wrdata <= core_slave_p2_wrdata;
			core_master_p2_wrdata_en <= core_slave_p2_wrdata_en;
			core_master_p2_wrdata_mask <= core_slave_p2_wrdata_mask;
			core_master_p2_rddata_en <= core_slave_p2_rddata_en;
			core_slave_p2_rddata <= core_master_p2_rddata;
			core_slave_p2_rddata_valid <= core_master_p2_rddata_valid;
			core_master_p3_address <= core_slave_p3_address;
			core_master_p3_bank <= core_slave_p3_bank;
			core_master_p3_cas_n <= core_slave_p3_cas_n;
			core_master_p3_cs_n <= core_slave_p3_cs_n;
			core_master_p3_ras_n <= core_slave_p3_ras_n;
			core_master_p3_we_n <= core_slave_p3_we_n;
			core_master_p3_cke <= core_slave_p3_cke;
			core_master_p3_odt <= core_slave_p3_odt;
			core_master_p3_reset_n <= core_slave_p3_reset_n;
			core_master_p3_act_n <= core_slave_p3_act_n;
			core_master_p3_wrdata <= core_slave_p3_wrdata;
			core_master_p3_wrdata_en <= core_slave_p3_wrdata_en;
			core_master_p3_wrdata_mask <= core_slave_p3_wrdata_mask;
			core_master_p3_rddata_en <= core_slave_p3_rddata_en;
			core_slave_p3_rddata <= core_master_p3_rddata;
			core_slave_p3_rddata_valid <= core_master_p3_rddata_valid;
			if (1'd0) begin
				core_master_p0_cs_n <= {2{core_slave_p0_cs_n}};
				core_master_p1_cs_n <= {2{core_slave_p1_cs_n}};
				core_master_p2_cs_n <= {2{core_slave_p2_cs_n}};
				core_master_p3_cs_n <= {2{core_slave_p3_cs_n}};
			end
		end
	end else begin
		core_master_p0_address <= core_csr_dfi_p0_address;
		core_master_p0_bank <= core_csr_dfi_p0_bank;
		core_master_p0_cas_n <= core_csr_dfi_p0_cas_n;
		core_master_p0_cs_n <= core_csr_dfi_p0_cs_n;
		core_master_p0_ras_n <= core_csr_dfi_p0_ras_n;
		core_master_p0_we_n <= core_csr_dfi_p0_we_n;
		core_master_p0_cke <= core_csr_dfi_p0_cke;
		core_master_p0_odt <= core_csr_dfi_p0_odt;
		core_master_p0_reset_n <= core_csr_dfi_p0_reset_n;
		core_master_p0_act_n <= core_csr_dfi_p0_act_n;
		core_master_p0_wrdata <= core_csr_dfi_p0_wrdata;
		core_master_p0_wrdata_en <= core_csr_dfi_p0_wrdata_en;
		core_master_p0_wrdata_mask <= core_csr_dfi_p0_wrdata_mask;
		core_master_p0_rddata_en <= core_csr_dfi_p0_rddata_en;
		core_csr_dfi_p0_rddata <= core_master_p0_rddata;
		core_csr_dfi_p0_rddata_valid <= core_master_p0_rddata_valid;
		core_master_p1_address <= core_csr_dfi_p1_address;
		core_master_p1_bank <= core_csr_dfi_p1_bank;
		core_master_p1_cas_n <= core_csr_dfi_p1_cas_n;
		core_master_p1_cs_n <= core_csr_dfi_p1_cs_n;
		core_master_p1_ras_n <= core_csr_dfi_p1_ras_n;
		core_master_p1_we_n <= core_csr_dfi_p1_we_n;
		core_master_p1_cke <= core_csr_dfi_p1_cke;
		core_master_p1_odt <= core_csr_dfi_p1_odt;
		core_master_p1_reset_n <= core_csr_dfi_p1_reset_n;
		core_master_p1_act_n <= core_csr_dfi_p1_act_n;
		core_master_p1_wrdata <= core_csr_dfi_p1_wrdata;
		core_master_p1_wrdata_en <= core_csr_dfi_p1_wrdata_en;
		core_master_p1_wrdata_mask <= core_csr_dfi_p1_wrdata_mask;
		core_master_p1_rddata_en <= core_csr_dfi_p1_rddata_en;
		core_csr_dfi_p1_rddata <= core_master_p1_rddata;
		core_csr_dfi_p1_rddata_valid <= core_master_p1_rddata_valid;
		core_master_p2_address <= core_csr_dfi_p2_address;
		core_master_p2_bank <= core_csr_dfi_p2_bank;
		core_master_p2_cas_n <= core_csr_dfi_p2_cas_n;
		core_master_p2_cs_n <= core_csr_dfi_p2_cs_n;
		core_master_p2_ras_n <= core_csr_dfi_p2_ras_n;
		core_master_p2_we_n <= core_csr_dfi_p2_we_n;
		core_master_p2_cke <= core_csr_dfi_p2_cke;
		core_master_p2_odt <= core_csr_dfi_p2_odt;
		core_master_p2_reset_n <= core_csr_dfi_p2_reset_n;
		core_master_p2_act_n <= core_csr_dfi_p2_act_n;
		core_master_p2_wrdata <= core_csr_dfi_p2_wrdata;
		core_master_p2_wrdata_en <= core_csr_dfi_p2_wrdata_en;
		core_master_p2_wrdata_mask <= core_csr_dfi_p2_wrdata_mask;
		core_master_p2_rddata_en <= core_csr_dfi_p2_rddata_en;
		core_csr_dfi_p2_rddata <= core_master_p2_rddata;
		core_csr_dfi_p2_rddata_valid <= core_master_p2_rddata_valid;
		core_master_p3_address <= core_csr_dfi_p3_address;
		core_master_p3_bank <= core_csr_dfi_p3_bank;
		core_master_p3_cas_n <= core_csr_dfi_p3_cas_n;
		core_master_p3_cs_n <= core_csr_dfi_p3_cs_n;
		core_master_p3_ras_n <= core_csr_dfi_p3_ras_n;
		core_master_p3_we_n <= core_csr_dfi_p3_we_n;
		core_master_p3_cke <= core_csr_dfi_p3_cke;
		core_master_p3_odt <= core_csr_dfi_p3_odt;
		core_master_p3_reset_n <= core_csr_dfi_p3_reset_n;
		core_master_p3_act_n <= core_csr_dfi_p3_act_n;
		core_master_p3_wrdata <= core_csr_dfi_p3_wrdata;
		core_master_p3_wrdata_en <= core_csr_dfi_p3_wrdata_en;
		core_master_p3_wrdata_mask <= core_csr_dfi_p3_wrdata_mask;
		core_master_p3_rddata_en <= core_csr_dfi_p3_rddata_en;
		core_csr_dfi_p3_rddata <= core_master_p3_rddata;
		core_csr_dfi_p3_rddata_valid <= core_master_p3_rddata_valid;
	end
// synthesis translate_off
	dummy_d <= dummy_s;
// synthesis translate_on
end
assign core_csr_dfi_p0_cke = core_cke;
assign core_csr_dfi_p1_cke = core_cke;
assign core_csr_dfi_p2_cke = core_cke;
assign core_csr_dfi_p3_cke = core_cke;
assign core_csr_dfi_p0_odt = core_odt;
assign core_csr_dfi_p1_odt = core_odt;
assign core_csr_dfi_p2_odt = core_odt;
assign core_csr_dfi_p3_odt = core_odt;
assign core_csr_dfi_p0_reset_n = core_reset_n;
assign core_csr_dfi_p1_reset_n = core_reset_n;
assign core_csr_dfi_p2_reset_n = core_reset_n;
assign core_csr_dfi_p3_reset_n = core_reset_n;

// synthesis translate_off
reg dummy_d_1;
// synthesis translate_on
always @(*) begin
	core_csr_dfi_p0_cas_n <= 1'd1;
	core_csr_dfi_p0_cs_n <= 1'd1;
	core_csr_dfi_p0_ras_n <= 1'd1;
	core_csr_dfi_p0_we_n <= 1'd1;
	if (core_phaseinjector0_command_issue_re) begin
		if (core_phaseinjector0_cs_top) begin
			core_csr_dfi_p0_cs_n <= 2'd2;
		end else begin
			if (core_phaseinjector0_cs_bottom) begin
				core_csr_dfi_p0_cs_n <= 1'd1;
			end else begin
				core_csr_dfi_p0_cs_n <= {1{(~core_phaseinjector0_cs)}};
			end
		end
		core_csr_dfi_p0_we_n <= (~core_phaseinjector0_we);
		core_csr_dfi_p0_cas_n <= (~core_phaseinjector0_cas);
		core_csr_dfi_p0_ras_n <= (~core_phaseinjector0_ras);
	end else begin
		core_csr_dfi_p0_cs_n <= {1{1'd1}};
		core_csr_dfi_p0_we_n <= 1'd1;
		core_csr_dfi_p0_cas_n <= 1'd1;
		core_csr_dfi_p0_ras_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_1 <= dummy_s;
// synthesis translate_on
end
assign core_csr_dfi_p0_address = core_phaseinjector0_address_storage;
assign core_csr_dfi_p0_bank = core_phaseinjector0_baddress_storage;
assign core_csr_dfi_p0_wrdata_en = (core_phaseinjector0_command_issue_re & core_phaseinjector0_wren);
assign core_csr_dfi_p0_rddata_en = (core_phaseinjector0_command_issue_re & core_phaseinjector0_rden);
assign core_csr_dfi_p0_wrdata = core_phaseinjector0_wrdata_storage;
assign core_csr_dfi_p0_wrdata_mask = 1'd0;

// synthesis translate_off
reg dummy_d_2;
// synthesis translate_on
always @(*) begin
	core_csr_dfi_p1_cas_n <= 1'd1;
	core_csr_dfi_p1_cs_n <= 1'd1;
	core_csr_dfi_p1_ras_n <= 1'd1;
	core_csr_dfi_p1_we_n <= 1'd1;
	if (core_phaseinjector1_command_issue_re) begin
		if (core_phaseinjector1_cs_top) begin
			core_csr_dfi_p1_cs_n <= 2'd2;
		end else begin
			if (core_phaseinjector1_cs_bottom) begin
				core_csr_dfi_p1_cs_n <= 1'd1;
			end else begin
				core_csr_dfi_p1_cs_n <= {1{(~core_phaseinjector1_cs)}};
			end
		end
		core_csr_dfi_p1_we_n <= (~core_phaseinjector1_we);
		core_csr_dfi_p1_cas_n <= (~core_phaseinjector1_cas);
		core_csr_dfi_p1_ras_n <= (~core_phaseinjector1_ras);
	end else begin
		core_csr_dfi_p1_cs_n <= {1{1'd1}};
		core_csr_dfi_p1_we_n <= 1'd1;
		core_csr_dfi_p1_cas_n <= 1'd1;
		core_csr_dfi_p1_ras_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_2 <= dummy_s;
// synthesis translate_on
end
assign core_csr_dfi_p1_address = core_phaseinjector1_address_storage;
assign core_csr_dfi_p1_bank = core_phaseinjector1_baddress_storage;
assign core_csr_dfi_p1_wrdata_en = (core_phaseinjector1_command_issue_re & core_phaseinjector1_wren);
assign core_csr_dfi_p1_rddata_en = (core_phaseinjector1_command_issue_re & core_phaseinjector1_rden);
assign core_csr_dfi_p1_wrdata = core_phaseinjector1_wrdata_storage;
assign core_csr_dfi_p1_wrdata_mask = 1'd0;

// synthesis translate_off
reg dummy_d_3;
// synthesis translate_on
always @(*) begin
	core_csr_dfi_p2_cas_n <= 1'd1;
	core_csr_dfi_p2_cs_n <= 1'd1;
	core_csr_dfi_p2_ras_n <= 1'd1;
	core_csr_dfi_p2_we_n <= 1'd1;
	if (core_phaseinjector2_command_issue_re) begin
		if (core_phaseinjector2_cs_top) begin
			core_csr_dfi_p2_cs_n <= 2'd2;
		end else begin
			if (core_phaseinjector2_cs_bottom) begin
				core_csr_dfi_p2_cs_n <= 1'd1;
			end else begin
				core_csr_dfi_p2_cs_n <= {1{(~core_phaseinjector2_cs)}};
			end
		end
		core_csr_dfi_p2_we_n <= (~core_phaseinjector2_we);
		core_csr_dfi_p2_cas_n <= (~core_phaseinjector2_cas);
		core_csr_dfi_p2_ras_n <= (~core_phaseinjector2_ras);
	end else begin
		core_csr_dfi_p2_cs_n <= {1{1'd1}};
		core_csr_dfi_p2_we_n <= 1'd1;
		core_csr_dfi_p2_cas_n <= 1'd1;
		core_csr_dfi_p2_ras_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_3 <= dummy_s;
// synthesis translate_on
end
assign core_csr_dfi_p2_address = core_phaseinjector2_address_storage;
assign core_csr_dfi_p2_bank = core_phaseinjector2_baddress_storage;
assign core_csr_dfi_p2_wrdata_en = (core_phaseinjector2_command_issue_re & core_phaseinjector2_wren);
assign core_csr_dfi_p2_rddata_en = (core_phaseinjector2_command_issue_re & core_phaseinjector2_rden);
assign core_csr_dfi_p2_wrdata = core_phaseinjector2_wrdata_storage;
assign core_csr_dfi_p2_wrdata_mask = 1'd0;

// synthesis translate_off
reg dummy_d_4;
// synthesis translate_on
always @(*) begin
	core_csr_dfi_p3_cas_n <= 1'd1;
	core_csr_dfi_p3_cs_n <= 1'd1;
	core_csr_dfi_p3_ras_n <= 1'd1;
	core_csr_dfi_p3_we_n <= 1'd1;
	if (core_phaseinjector3_command_issue_re) begin
		if (core_phaseinjector3_cs_top) begin
			core_csr_dfi_p3_cs_n <= 2'd2;
		end else begin
			if (core_phaseinjector3_cs_bottom) begin
				core_csr_dfi_p3_cs_n <= 1'd1;
			end else begin
				core_csr_dfi_p3_cs_n <= {1{(~core_phaseinjector3_cs)}};
			end
		end
		core_csr_dfi_p3_we_n <= (~core_phaseinjector3_we);
		core_csr_dfi_p3_cas_n <= (~core_phaseinjector3_cas);
		core_csr_dfi_p3_ras_n <= (~core_phaseinjector3_ras);
	end else begin
		core_csr_dfi_p3_cs_n <= {1{1'd1}};
		core_csr_dfi_p3_we_n <= 1'd1;
		core_csr_dfi_p3_cas_n <= 1'd1;
		core_csr_dfi_p3_ras_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_4 <= dummy_s;
// synthesis translate_on
end
assign core_csr_dfi_p3_address = core_phaseinjector3_address_storage;
assign core_csr_dfi_p3_bank = core_phaseinjector3_baddress_storage;
assign core_csr_dfi_p3_wrdata_en = (core_phaseinjector3_command_issue_re & core_phaseinjector3_wren);
assign core_csr_dfi_p3_rddata_en = (core_phaseinjector3_command_issue_re & core_phaseinjector3_rden);
assign core_csr_dfi_p3_wrdata = core_phaseinjector3_wrdata_storage;
assign core_csr_dfi_p3_wrdata_mask = 1'd0;
assign core_bankmachine0_req_valid = core_interface_bank0_valid;
assign core_interface_bank0_ready = core_bankmachine0_req_ready;
assign core_bankmachine0_req_we = core_interface_bank0_we;
assign core_bankmachine0_req_addr = core_interface_bank0_addr;
assign core_interface_bank0_lock = core_bankmachine0_req_lock;
assign core_interface_bank0_wdata_ready = core_bankmachine0_req_wdata_ready;
assign core_interface_bank0_rdata_valid = core_bankmachine0_req_rdata_valid;
assign core_bankmachine1_req_valid = core_interface_bank1_valid;
assign core_interface_bank1_ready = core_bankmachine1_req_ready;
assign core_bankmachine1_req_we = core_interface_bank1_we;
assign core_bankmachine1_req_addr = core_interface_bank1_addr;
assign core_interface_bank1_lock = core_bankmachine1_req_lock;
assign core_interface_bank1_wdata_ready = core_bankmachine1_req_wdata_ready;
assign core_interface_bank1_rdata_valid = core_bankmachine1_req_rdata_valid;
assign core_bankmachine2_req_valid = core_interface_bank2_valid;
assign core_interface_bank2_ready = core_bankmachine2_req_ready;
assign core_bankmachine2_req_we = core_interface_bank2_we;
assign core_bankmachine2_req_addr = core_interface_bank2_addr;
assign core_interface_bank2_lock = core_bankmachine2_req_lock;
assign core_interface_bank2_wdata_ready = core_bankmachine2_req_wdata_ready;
assign core_interface_bank2_rdata_valid = core_bankmachine2_req_rdata_valid;
assign core_bankmachine3_req_valid = core_interface_bank3_valid;
assign core_interface_bank3_ready = core_bankmachine3_req_ready;
assign core_bankmachine3_req_we = core_interface_bank3_we;
assign core_bankmachine3_req_addr = core_interface_bank3_addr;
assign core_interface_bank3_lock = core_bankmachine3_req_lock;
assign core_interface_bank3_wdata_ready = core_bankmachine3_req_wdata_ready;
assign core_interface_bank3_rdata_valid = core_bankmachine3_req_rdata_valid;
assign core_bankmachine4_req_valid = core_interface_bank4_valid;
assign core_interface_bank4_ready = core_bankmachine4_req_ready;
assign core_bankmachine4_req_we = core_interface_bank4_we;
assign core_bankmachine4_req_addr = core_interface_bank4_addr;
assign core_interface_bank4_lock = core_bankmachine4_req_lock;
assign core_interface_bank4_wdata_ready = core_bankmachine4_req_wdata_ready;
assign core_interface_bank4_rdata_valid = core_bankmachine4_req_rdata_valid;
assign core_bankmachine5_req_valid = core_interface_bank5_valid;
assign core_interface_bank5_ready = core_bankmachine5_req_ready;
assign core_bankmachine5_req_we = core_interface_bank5_we;
assign core_bankmachine5_req_addr = core_interface_bank5_addr;
assign core_interface_bank5_lock = core_bankmachine5_req_lock;
assign core_interface_bank5_wdata_ready = core_bankmachine5_req_wdata_ready;
assign core_interface_bank5_rdata_valid = core_bankmachine5_req_rdata_valid;
assign core_bankmachine6_req_valid = core_interface_bank6_valid;
assign core_interface_bank6_ready = core_bankmachine6_req_ready;
assign core_bankmachine6_req_we = core_interface_bank6_we;
assign core_bankmachine6_req_addr = core_interface_bank6_addr;
assign core_interface_bank6_lock = core_bankmachine6_req_lock;
assign core_interface_bank6_wdata_ready = core_bankmachine6_req_wdata_ready;
assign core_interface_bank6_rdata_valid = core_bankmachine6_req_rdata_valid;
assign core_bankmachine7_req_valid = core_interface_bank7_valid;
assign core_interface_bank7_ready = core_bankmachine7_req_ready;
assign core_bankmachine7_req_we = core_interface_bank7_we;
assign core_bankmachine7_req_addr = core_interface_bank7_addr;
assign core_interface_bank7_lock = core_bankmachine7_req_lock;
assign core_interface_bank7_wdata_ready = core_bankmachine7_req_wdata_ready;
assign core_interface_bank7_rdata_valid = core_bankmachine7_req_rdata_valid;
assign core_timer_wait = (~core_timer_done0);
assign core_postponer_req_i = core_timer_done0;
assign core_wants_refresh = core_postponer_req_o;
assign core_wants_zqcs = core_zqcs_timer_done0;
assign core_zqcs_timer_wait = (~core_zqcs_executer_done);
assign core_timer_done1 = (core_timer_count1 == 1'd0);
assign core_timer_done0 = core_timer_done1;
assign core_timer_count0 = core_timer_count1;
assign core_sequencer_start1 = (core_sequencer_start0 | (core_sequencer_count != 1'd0));
assign core_sequencer_done0 = (core_sequencer_done1 & (core_sequencer_count == 1'd0));
assign core_zqcs_timer_done1 = (core_zqcs_timer_count1 == 1'd0);
assign core_zqcs_timer_done0 = core_zqcs_timer_done1;
assign core_zqcs_timer_count0 = core_zqcs_timer_count1;

// synthesis translate_off
reg dummy_d_5;
// synthesis translate_on
always @(*) begin
	core_cmd_valid <= 1'd0;
	core_cmd_last <= 1'd0;
	core_sequencer_start0 <= 1'd0;
	core_zqcs_executer_start <= 1'd0;
	refresher_next_state <= 2'd0;
	refresher_next_state <= refresher_state;
	case (refresher_state)
		1'd1: begin
			core_cmd_valid <= 1'd1;
			if (core_cmd_ready) begin
				core_sequencer_start0 <= 1'd1;
				refresher_next_state <= 2'd2;
			end
		end
		2'd2: begin
			core_cmd_valid <= 1'd1;
			if (core_sequencer_done0) begin
				if (core_wants_zqcs) begin
					core_zqcs_executer_start <= 1'd1;
					refresher_next_state <= 2'd3;
				end else begin
					core_cmd_valid <= 1'd0;
					core_cmd_last <= 1'd1;
					refresher_next_state <= 1'd0;
				end
			end
		end
		2'd3: begin
			core_cmd_valid <= 1'd1;
			if (core_zqcs_executer_done) begin
				core_cmd_valid <= 1'd0;
				core_cmd_last <= 1'd1;
				refresher_next_state <= 1'd0;
			end
		end
		default: begin
			if (1'd1) begin
				if (core_wants_refresh) begin
					refresher_next_state <= 1'd1;
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_5 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine0_sink_valid = core_bankmachine0_req_valid;
assign core_bankmachine0_req_ready = core_bankmachine0_sink_ready;
assign core_bankmachine0_sink_payload_we = core_bankmachine0_req_we;
assign core_bankmachine0_sink_payload_addr = core_bankmachine0_req_addr;
assign core_bankmachine0_sink_sink_valid = core_bankmachine0_source_valid;
assign core_bankmachine0_source_ready = core_bankmachine0_sink_sink_ready;
assign core_bankmachine0_sink_sink_first = core_bankmachine0_source_first;
assign core_bankmachine0_sink_sink_last = core_bankmachine0_source_last;
assign core_bankmachine0_sink_sink_payload_we = core_bankmachine0_source_payload_we;
assign core_bankmachine0_sink_sink_payload_addr = core_bankmachine0_source_payload_addr;
assign core_bankmachine0_source_source_ready = (core_bankmachine0_req_wdata_ready | core_bankmachine0_req_rdata_valid);
assign core_bankmachine0_req_lock = (core_bankmachine0_source_valid | core_bankmachine0_source_source_valid);
assign core_bankmachine0_row_hit = (core_bankmachine0_row == core_bankmachine0_source_source_payload_addr[21:7]);
assign core_bankmachine0_cmd_payload_ba = 1'd0;

// synthesis translate_off
reg dummy_d_6;
// synthesis translate_on
always @(*) begin
	core_bankmachine0_cmd_payload_a <= 15'd0;
	if (core_bankmachine0_row_col_n_addr_sel) begin
		core_bankmachine0_cmd_payload_a <= core_bankmachine0_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine0_cmd_payload_a <= ((core_bankmachine0_auto_precharge <<< 4'd10) | {core_bankmachine0_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_6 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine0_twtpcon_valid = ((core_bankmachine0_cmd_valid & core_bankmachine0_cmd_ready) & core_bankmachine0_cmd_payload_is_write);
assign core_bankmachine0_trccon_valid = ((core_bankmachine0_cmd_valid & core_bankmachine0_cmd_ready) & core_bankmachine0_row_open);
assign core_bankmachine0_trascon_valid = ((core_bankmachine0_cmd_valid & core_bankmachine0_cmd_ready) & core_bankmachine0_row_open);

// synthesis translate_off
reg dummy_d_7;
// synthesis translate_on
always @(*) begin
	core_bankmachine0_auto_precharge <= 1'd0;
	if ((core_bankmachine0_source_valid & core_bankmachine0_source_source_valid)) begin
		if ((core_bankmachine0_source_payload_addr[21:7] != core_bankmachine0_source_source_payload_addr[21:7])) begin
			core_bankmachine0_auto_precharge <= (core_bankmachine0_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_7 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine0_syncfifo0_din = {core_bankmachine0_fifo_in_last, core_bankmachine0_fifo_in_first, core_bankmachine0_fifo_in_payload_addr, core_bankmachine0_fifo_in_payload_we};
assign {core_bankmachine0_fifo_out_last, core_bankmachine0_fifo_out_first, core_bankmachine0_fifo_out_payload_addr, core_bankmachine0_fifo_out_payload_we} = core_bankmachine0_syncfifo0_dout;
assign core_bankmachine0_sink_ready = core_bankmachine0_syncfifo0_writable;
assign core_bankmachine0_syncfifo0_we = core_bankmachine0_sink_valid;
assign core_bankmachine0_fifo_in_first = core_bankmachine0_sink_first;
assign core_bankmachine0_fifo_in_last = core_bankmachine0_sink_last;
assign core_bankmachine0_fifo_in_payload_we = core_bankmachine0_sink_payload_we;
assign core_bankmachine0_fifo_in_payload_addr = core_bankmachine0_sink_payload_addr;
assign core_bankmachine0_source_valid = core_bankmachine0_syncfifo0_readable;
assign core_bankmachine0_source_first = core_bankmachine0_fifo_out_first;
assign core_bankmachine0_source_last = core_bankmachine0_fifo_out_last;
assign core_bankmachine0_source_payload_we = core_bankmachine0_fifo_out_payload_we;
assign core_bankmachine0_source_payload_addr = core_bankmachine0_fifo_out_payload_addr;
assign core_bankmachine0_syncfifo0_re = core_bankmachine0_source_ready;

// synthesis translate_off
reg dummy_d_8;
// synthesis translate_on
always @(*) begin
	core_bankmachine0_wrport_adr <= 3'd0;
	if (core_bankmachine0_replace) begin
		core_bankmachine0_wrport_adr <= (core_bankmachine0_produce - 1'd1);
	end else begin
		core_bankmachine0_wrport_adr <= core_bankmachine0_produce;
	end
// synthesis translate_off
	dummy_d_8 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine0_wrport_dat_w = core_bankmachine0_syncfifo0_din;
assign core_bankmachine0_wrport_we = (core_bankmachine0_syncfifo0_we & (core_bankmachine0_syncfifo0_writable | core_bankmachine0_replace));
assign core_bankmachine0_do_read = (core_bankmachine0_syncfifo0_readable & core_bankmachine0_syncfifo0_re);
assign core_bankmachine0_rdport_adr = core_bankmachine0_consume;
assign core_bankmachine0_syncfifo0_dout = core_bankmachine0_rdport_dat_r;
assign core_bankmachine0_syncfifo0_writable = (core_bankmachine0_level != 4'd8);
assign core_bankmachine0_syncfifo0_readable = (core_bankmachine0_level != 1'd0);
assign core_bankmachine0_pipe_valid_sink_ready = ((~core_bankmachine0_pipe_valid_source_valid) | core_bankmachine0_pipe_valid_source_ready);
assign core_bankmachine0_pipe_valid_sink_valid = core_bankmachine0_sink_sink_valid;
assign core_bankmachine0_sink_sink_ready = core_bankmachine0_pipe_valid_sink_ready;
assign core_bankmachine0_pipe_valid_sink_first = core_bankmachine0_sink_sink_first;
assign core_bankmachine0_pipe_valid_sink_last = core_bankmachine0_sink_sink_last;
assign core_bankmachine0_pipe_valid_sink_payload_we = core_bankmachine0_sink_sink_payload_we;
assign core_bankmachine0_pipe_valid_sink_payload_addr = core_bankmachine0_sink_sink_payload_addr;
assign core_bankmachine0_source_source_valid = core_bankmachine0_pipe_valid_source_valid;
assign core_bankmachine0_pipe_valid_source_ready = core_bankmachine0_source_source_ready;
assign core_bankmachine0_source_source_first = core_bankmachine0_pipe_valid_source_first;
assign core_bankmachine0_source_source_last = core_bankmachine0_pipe_valid_source_last;
assign core_bankmachine0_source_source_payload_we = core_bankmachine0_pipe_valid_source_payload_we;
assign core_bankmachine0_source_source_payload_addr = core_bankmachine0_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_9;
// synthesis translate_on
always @(*) begin
	core_bankmachine0_req_wdata_ready <= 1'd0;
	core_bankmachine0_req_rdata_valid <= 1'd0;
	core_bankmachine0_refresh_gnt <= 1'd0;
	core_bankmachine0_cmd_valid <= 1'd0;
	core_bankmachine0_cmd_payload_cas <= 1'd0;
	core_bankmachine0_cmd_payload_ras <= 1'd0;
	core_bankmachine0_cmd_payload_we <= 1'd0;
	core_bankmachine0_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine0_cmd_payload_is_read <= 1'd0;
	core_bankmachine0_cmd_payload_is_write <= 1'd0;
	core_bankmachine0_row_open <= 1'd0;
	core_bankmachine0_row_close <= 1'd0;
	core_bankmachine0_row_col_n_addr_sel <= 1'd0;
	bankmachine0_next_state <= 3'd0;
	bankmachine0_next_state <= bankmachine0_state;
	case (bankmachine0_state)
		1'd1: begin
			if ((core_bankmachine0_twtpcon_ready & core_bankmachine0_trascon_ready)) begin
				core_bankmachine0_cmd_valid <= 1'd1;
				if (core_bankmachine0_cmd_ready) begin
					bankmachine0_next_state <= 3'd5;
				end
				core_bankmachine0_cmd_payload_ras <= 1'd1;
				core_bankmachine0_cmd_payload_we <= 1'd1;
				core_bankmachine0_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine0_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine0_twtpcon_ready & core_bankmachine0_trascon_ready)) begin
				bankmachine0_next_state <= 3'd5;
			end
			core_bankmachine0_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine0_trccon_ready) begin
				core_bankmachine0_row_col_n_addr_sel <= 1'd1;
				core_bankmachine0_row_open <= 1'd1;
				core_bankmachine0_cmd_valid <= 1'd1;
				core_bankmachine0_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine0_cmd_ready) begin
					bankmachine0_next_state <= 3'd6;
				end
				core_bankmachine0_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine0_twtpcon_ready) begin
				core_bankmachine0_refresh_gnt <= 1'd1;
			end
			core_bankmachine0_row_close <= 1'd1;
			core_bankmachine0_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine0_refresh_req)) begin
				bankmachine0_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine0_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine0_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine0_refresh_req) begin
				bankmachine0_next_state <= 3'd4;
			end else begin
				if (core_bankmachine0_source_source_valid) begin
					if (core_bankmachine0_row_opened) begin
						if (core_bankmachine0_row_hit) begin
							core_bankmachine0_cmd_valid <= 1'd1;
							if (core_bankmachine0_source_source_payload_we) begin
								core_bankmachine0_req_wdata_ready <= core_bankmachine0_cmd_ready;
								core_bankmachine0_cmd_payload_is_write <= 1'd1;
								core_bankmachine0_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine0_req_rdata_valid <= core_bankmachine0_cmd_ready;
								core_bankmachine0_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine0_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine0_cmd_ready & core_bankmachine0_auto_precharge)) begin
								bankmachine0_next_state <= 2'd2;
							end
						end else begin
							bankmachine0_next_state <= 1'd1;
						end
					end else begin
						bankmachine0_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_9 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine1_sink_valid = core_bankmachine1_req_valid;
assign core_bankmachine1_req_ready = core_bankmachine1_sink_ready;
assign core_bankmachine1_sink_payload_we = core_bankmachine1_req_we;
assign core_bankmachine1_sink_payload_addr = core_bankmachine1_req_addr;
assign core_bankmachine1_sink_sink_valid = core_bankmachine1_source_valid;
assign core_bankmachine1_source_ready = core_bankmachine1_sink_sink_ready;
assign core_bankmachine1_sink_sink_first = core_bankmachine1_source_first;
assign core_bankmachine1_sink_sink_last = core_bankmachine1_source_last;
assign core_bankmachine1_sink_sink_payload_we = core_bankmachine1_source_payload_we;
assign core_bankmachine1_sink_sink_payload_addr = core_bankmachine1_source_payload_addr;
assign core_bankmachine1_source_source_ready = (core_bankmachine1_req_wdata_ready | core_bankmachine1_req_rdata_valid);
assign core_bankmachine1_req_lock = (core_bankmachine1_source_valid | core_bankmachine1_source_source_valid);
assign core_bankmachine1_row_hit = (core_bankmachine1_row == core_bankmachine1_source_source_payload_addr[21:7]);
assign core_bankmachine1_cmd_payload_ba = 1'd1;

// synthesis translate_off
reg dummy_d_10;
// synthesis translate_on
always @(*) begin
	core_bankmachine1_cmd_payload_a <= 15'd0;
	if (core_bankmachine1_row_col_n_addr_sel) begin
		core_bankmachine1_cmd_payload_a <= core_bankmachine1_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine1_cmd_payload_a <= ((core_bankmachine1_auto_precharge <<< 4'd10) | {core_bankmachine1_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_10 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine1_twtpcon_valid = ((core_bankmachine1_cmd_valid & core_bankmachine1_cmd_ready) & core_bankmachine1_cmd_payload_is_write);
assign core_bankmachine1_trccon_valid = ((core_bankmachine1_cmd_valid & core_bankmachine1_cmd_ready) & core_bankmachine1_row_open);
assign core_bankmachine1_trascon_valid = ((core_bankmachine1_cmd_valid & core_bankmachine1_cmd_ready) & core_bankmachine1_row_open);

// synthesis translate_off
reg dummy_d_11;
// synthesis translate_on
always @(*) begin
	core_bankmachine1_auto_precharge <= 1'd0;
	if ((core_bankmachine1_source_valid & core_bankmachine1_source_source_valid)) begin
		if ((core_bankmachine1_source_payload_addr[21:7] != core_bankmachine1_source_source_payload_addr[21:7])) begin
			core_bankmachine1_auto_precharge <= (core_bankmachine1_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_11 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine1_syncfifo1_din = {core_bankmachine1_fifo_in_last, core_bankmachine1_fifo_in_first, core_bankmachine1_fifo_in_payload_addr, core_bankmachine1_fifo_in_payload_we};
assign {core_bankmachine1_fifo_out_last, core_bankmachine1_fifo_out_first, core_bankmachine1_fifo_out_payload_addr, core_bankmachine1_fifo_out_payload_we} = core_bankmachine1_syncfifo1_dout;
assign core_bankmachine1_sink_ready = core_bankmachine1_syncfifo1_writable;
assign core_bankmachine1_syncfifo1_we = core_bankmachine1_sink_valid;
assign core_bankmachine1_fifo_in_first = core_bankmachine1_sink_first;
assign core_bankmachine1_fifo_in_last = core_bankmachine1_sink_last;
assign core_bankmachine1_fifo_in_payload_we = core_bankmachine1_sink_payload_we;
assign core_bankmachine1_fifo_in_payload_addr = core_bankmachine1_sink_payload_addr;
assign core_bankmachine1_source_valid = core_bankmachine1_syncfifo1_readable;
assign core_bankmachine1_source_first = core_bankmachine1_fifo_out_first;
assign core_bankmachine1_source_last = core_bankmachine1_fifo_out_last;
assign core_bankmachine1_source_payload_we = core_bankmachine1_fifo_out_payload_we;
assign core_bankmachine1_source_payload_addr = core_bankmachine1_fifo_out_payload_addr;
assign core_bankmachine1_syncfifo1_re = core_bankmachine1_source_ready;

// synthesis translate_off
reg dummy_d_12;
// synthesis translate_on
always @(*) begin
	core_bankmachine1_wrport_adr <= 3'd0;
	if (core_bankmachine1_replace) begin
		core_bankmachine1_wrport_adr <= (core_bankmachine1_produce - 1'd1);
	end else begin
		core_bankmachine1_wrport_adr <= core_bankmachine1_produce;
	end
// synthesis translate_off
	dummy_d_12 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine1_wrport_dat_w = core_bankmachine1_syncfifo1_din;
assign core_bankmachine1_wrport_we = (core_bankmachine1_syncfifo1_we & (core_bankmachine1_syncfifo1_writable | core_bankmachine1_replace));
assign core_bankmachine1_do_read = (core_bankmachine1_syncfifo1_readable & core_bankmachine1_syncfifo1_re);
assign core_bankmachine1_rdport_adr = core_bankmachine1_consume;
assign core_bankmachine1_syncfifo1_dout = core_bankmachine1_rdport_dat_r;
assign core_bankmachine1_syncfifo1_writable = (core_bankmachine1_level != 4'd8);
assign core_bankmachine1_syncfifo1_readable = (core_bankmachine1_level != 1'd0);
assign core_bankmachine1_pipe_valid_sink_ready = ((~core_bankmachine1_pipe_valid_source_valid) | core_bankmachine1_pipe_valid_source_ready);
assign core_bankmachine1_pipe_valid_sink_valid = core_bankmachine1_sink_sink_valid;
assign core_bankmachine1_sink_sink_ready = core_bankmachine1_pipe_valid_sink_ready;
assign core_bankmachine1_pipe_valid_sink_first = core_bankmachine1_sink_sink_first;
assign core_bankmachine1_pipe_valid_sink_last = core_bankmachine1_sink_sink_last;
assign core_bankmachine1_pipe_valid_sink_payload_we = core_bankmachine1_sink_sink_payload_we;
assign core_bankmachine1_pipe_valid_sink_payload_addr = core_bankmachine1_sink_sink_payload_addr;
assign core_bankmachine1_source_source_valid = core_bankmachine1_pipe_valid_source_valid;
assign core_bankmachine1_pipe_valid_source_ready = core_bankmachine1_source_source_ready;
assign core_bankmachine1_source_source_first = core_bankmachine1_pipe_valid_source_first;
assign core_bankmachine1_source_source_last = core_bankmachine1_pipe_valid_source_last;
assign core_bankmachine1_source_source_payload_we = core_bankmachine1_pipe_valid_source_payload_we;
assign core_bankmachine1_source_source_payload_addr = core_bankmachine1_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_13;
// synthesis translate_on
always @(*) begin
	core_bankmachine1_req_wdata_ready <= 1'd0;
	core_bankmachine1_req_rdata_valid <= 1'd0;
	core_bankmachine1_refresh_gnt <= 1'd0;
	core_bankmachine1_cmd_valid <= 1'd0;
	core_bankmachine1_cmd_payload_cas <= 1'd0;
	core_bankmachine1_cmd_payload_ras <= 1'd0;
	core_bankmachine1_cmd_payload_we <= 1'd0;
	core_bankmachine1_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine1_cmd_payload_is_read <= 1'd0;
	core_bankmachine1_cmd_payload_is_write <= 1'd0;
	core_bankmachine1_row_open <= 1'd0;
	core_bankmachine1_row_close <= 1'd0;
	core_bankmachine1_row_col_n_addr_sel <= 1'd0;
	bankmachine1_next_state <= 3'd0;
	bankmachine1_next_state <= bankmachine1_state;
	case (bankmachine1_state)
		1'd1: begin
			if ((core_bankmachine1_twtpcon_ready & core_bankmachine1_trascon_ready)) begin
				core_bankmachine1_cmd_valid <= 1'd1;
				if (core_bankmachine1_cmd_ready) begin
					bankmachine1_next_state <= 3'd5;
				end
				core_bankmachine1_cmd_payload_ras <= 1'd1;
				core_bankmachine1_cmd_payload_we <= 1'd1;
				core_bankmachine1_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine1_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine1_twtpcon_ready & core_bankmachine1_trascon_ready)) begin
				bankmachine1_next_state <= 3'd5;
			end
			core_bankmachine1_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine1_trccon_ready) begin
				core_bankmachine1_row_col_n_addr_sel <= 1'd1;
				core_bankmachine1_row_open <= 1'd1;
				core_bankmachine1_cmd_valid <= 1'd1;
				core_bankmachine1_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine1_cmd_ready) begin
					bankmachine1_next_state <= 3'd6;
				end
				core_bankmachine1_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine1_twtpcon_ready) begin
				core_bankmachine1_refresh_gnt <= 1'd1;
			end
			core_bankmachine1_row_close <= 1'd1;
			core_bankmachine1_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine1_refresh_req)) begin
				bankmachine1_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine1_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine1_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine1_refresh_req) begin
				bankmachine1_next_state <= 3'd4;
			end else begin
				if (core_bankmachine1_source_source_valid) begin
					if (core_bankmachine1_row_opened) begin
						if (core_bankmachine1_row_hit) begin
							core_bankmachine1_cmd_valid <= 1'd1;
							if (core_bankmachine1_source_source_payload_we) begin
								core_bankmachine1_req_wdata_ready <= core_bankmachine1_cmd_ready;
								core_bankmachine1_cmd_payload_is_write <= 1'd1;
								core_bankmachine1_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine1_req_rdata_valid <= core_bankmachine1_cmd_ready;
								core_bankmachine1_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine1_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine1_cmd_ready & core_bankmachine1_auto_precharge)) begin
								bankmachine1_next_state <= 2'd2;
							end
						end else begin
							bankmachine1_next_state <= 1'd1;
						end
					end else begin
						bankmachine1_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_13 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine2_sink_valid = core_bankmachine2_req_valid;
assign core_bankmachine2_req_ready = core_bankmachine2_sink_ready;
assign core_bankmachine2_sink_payload_we = core_bankmachine2_req_we;
assign core_bankmachine2_sink_payload_addr = core_bankmachine2_req_addr;
assign core_bankmachine2_sink_sink_valid = core_bankmachine2_source_valid;
assign core_bankmachine2_source_ready = core_bankmachine2_sink_sink_ready;
assign core_bankmachine2_sink_sink_first = core_bankmachine2_source_first;
assign core_bankmachine2_sink_sink_last = core_bankmachine2_source_last;
assign core_bankmachine2_sink_sink_payload_we = core_bankmachine2_source_payload_we;
assign core_bankmachine2_sink_sink_payload_addr = core_bankmachine2_source_payload_addr;
assign core_bankmachine2_source_source_ready = (core_bankmachine2_req_wdata_ready | core_bankmachine2_req_rdata_valid);
assign core_bankmachine2_req_lock = (core_bankmachine2_source_valid | core_bankmachine2_source_source_valid);
assign core_bankmachine2_row_hit = (core_bankmachine2_row == core_bankmachine2_source_source_payload_addr[21:7]);
assign core_bankmachine2_cmd_payload_ba = 2'd2;

// synthesis translate_off
reg dummy_d_14;
// synthesis translate_on
always @(*) begin
	core_bankmachine2_cmd_payload_a <= 15'd0;
	if (core_bankmachine2_row_col_n_addr_sel) begin
		core_bankmachine2_cmd_payload_a <= core_bankmachine2_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine2_cmd_payload_a <= ((core_bankmachine2_auto_precharge <<< 4'd10) | {core_bankmachine2_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_14 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine2_twtpcon_valid = ((core_bankmachine2_cmd_valid & core_bankmachine2_cmd_ready) & core_bankmachine2_cmd_payload_is_write);
assign core_bankmachine2_trccon_valid = ((core_bankmachine2_cmd_valid & core_bankmachine2_cmd_ready) & core_bankmachine2_row_open);
assign core_bankmachine2_trascon_valid = ((core_bankmachine2_cmd_valid & core_bankmachine2_cmd_ready) & core_bankmachine2_row_open);

// synthesis translate_off
reg dummy_d_15;
// synthesis translate_on
always @(*) begin
	core_bankmachine2_auto_precharge <= 1'd0;
	if ((core_bankmachine2_source_valid & core_bankmachine2_source_source_valid)) begin
		if ((core_bankmachine2_source_payload_addr[21:7] != core_bankmachine2_source_source_payload_addr[21:7])) begin
			core_bankmachine2_auto_precharge <= (core_bankmachine2_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_15 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine2_syncfifo2_din = {core_bankmachine2_fifo_in_last, core_bankmachine2_fifo_in_first, core_bankmachine2_fifo_in_payload_addr, core_bankmachine2_fifo_in_payload_we};
assign {core_bankmachine2_fifo_out_last, core_bankmachine2_fifo_out_first, core_bankmachine2_fifo_out_payload_addr, core_bankmachine2_fifo_out_payload_we} = core_bankmachine2_syncfifo2_dout;
assign core_bankmachine2_sink_ready = core_bankmachine2_syncfifo2_writable;
assign core_bankmachine2_syncfifo2_we = core_bankmachine2_sink_valid;
assign core_bankmachine2_fifo_in_first = core_bankmachine2_sink_first;
assign core_bankmachine2_fifo_in_last = core_bankmachine2_sink_last;
assign core_bankmachine2_fifo_in_payload_we = core_bankmachine2_sink_payload_we;
assign core_bankmachine2_fifo_in_payload_addr = core_bankmachine2_sink_payload_addr;
assign core_bankmachine2_source_valid = core_bankmachine2_syncfifo2_readable;
assign core_bankmachine2_source_first = core_bankmachine2_fifo_out_first;
assign core_bankmachine2_source_last = core_bankmachine2_fifo_out_last;
assign core_bankmachine2_source_payload_we = core_bankmachine2_fifo_out_payload_we;
assign core_bankmachine2_source_payload_addr = core_bankmachine2_fifo_out_payload_addr;
assign core_bankmachine2_syncfifo2_re = core_bankmachine2_source_ready;

// synthesis translate_off
reg dummy_d_16;
// synthesis translate_on
always @(*) begin
	core_bankmachine2_wrport_adr <= 3'd0;
	if (core_bankmachine2_replace) begin
		core_bankmachine2_wrport_adr <= (core_bankmachine2_produce - 1'd1);
	end else begin
		core_bankmachine2_wrport_adr <= core_bankmachine2_produce;
	end
// synthesis translate_off
	dummy_d_16 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine2_wrport_dat_w = core_bankmachine2_syncfifo2_din;
assign core_bankmachine2_wrport_we = (core_bankmachine2_syncfifo2_we & (core_bankmachine2_syncfifo2_writable | core_bankmachine2_replace));
assign core_bankmachine2_do_read = (core_bankmachine2_syncfifo2_readable & core_bankmachine2_syncfifo2_re);
assign core_bankmachine2_rdport_adr = core_bankmachine2_consume;
assign core_bankmachine2_syncfifo2_dout = core_bankmachine2_rdport_dat_r;
assign core_bankmachine2_syncfifo2_writable = (core_bankmachine2_level != 4'd8);
assign core_bankmachine2_syncfifo2_readable = (core_bankmachine2_level != 1'd0);
assign core_bankmachine2_pipe_valid_sink_ready = ((~core_bankmachine2_pipe_valid_source_valid) | core_bankmachine2_pipe_valid_source_ready);
assign core_bankmachine2_pipe_valid_sink_valid = core_bankmachine2_sink_sink_valid;
assign core_bankmachine2_sink_sink_ready = core_bankmachine2_pipe_valid_sink_ready;
assign core_bankmachine2_pipe_valid_sink_first = core_bankmachine2_sink_sink_first;
assign core_bankmachine2_pipe_valid_sink_last = core_bankmachine2_sink_sink_last;
assign core_bankmachine2_pipe_valid_sink_payload_we = core_bankmachine2_sink_sink_payload_we;
assign core_bankmachine2_pipe_valid_sink_payload_addr = core_bankmachine2_sink_sink_payload_addr;
assign core_bankmachine2_source_source_valid = core_bankmachine2_pipe_valid_source_valid;
assign core_bankmachine2_pipe_valid_source_ready = core_bankmachine2_source_source_ready;
assign core_bankmachine2_source_source_first = core_bankmachine2_pipe_valid_source_first;
assign core_bankmachine2_source_source_last = core_bankmachine2_pipe_valid_source_last;
assign core_bankmachine2_source_source_payload_we = core_bankmachine2_pipe_valid_source_payload_we;
assign core_bankmachine2_source_source_payload_addr = core_bankmachine2_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_17;
// synthesis translate_on
always @(*) begin
	core_bankmachine2_req_wdata_ready <= 1'd0;
	core_bankmachine2_req_rdata_valid <= 1'd0;
	core_bankmachine2_refresh_gnt <= 1'd0;
	core_bankmachine2_cmd_valid <= 1'd0;
	core_bankmachine2_cmd_payload_cas <= 1'd0;
	core_bankmachine2_cmd_payload_ras <= 1'd0;
	core_bankmachine2_cmd_payload_we <= 1'd0;
	core_bankmachine2_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine2_cmd_payload_is_read <= 1'd0;
	core_bankmachine2_cmd_payload_is_write <= 1'd0;
	core_bankmachine2_row_open <= 1'd0;
	core_bankmachine2_row_close <= 1'd0;
	core_bankmachine2_row_col_n_addr_sel <= 1'd0;
	bankmachine2_next_state <= 3'd0;
	bankmachine2_next_state <= bankmachine2_state;
	case (bankmachine2_state)
		1'd1: begin
			if ((core_bankmachine2_twtpcon_ready & core_bankmachine2_trascon_ready)) begin
				core_bankmachine2_cmd_valid <= 1'd1;
				if (core_bankmachine2_cmd_ready) begin
					bankmachine2_next_state <= 3'd5;
				end
				core_bankmachine2_cmd_payload_ras <= 1'd1;
				core_bankmachine2_cmd_payload_we <= 1'd1;
				core_bankmachine2_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine2_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine2_twtpcon_ready & core_bankmachine2_trascon_ready)) begin
				bankmachine2_next_state <= 3'd5;
			end
			core_bankmachine2_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine2_trccon_ready) begin
				core_bankmachine2_row_col_n_addr_sel <= 1'd1;
				core_bankmachine2_row_open <= 1'd1;
				core_bankmachine2_cmd_valid <= 1'd1;
				core_bankmachine2_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine2_cmd_ready) begin
					bankmachine2_next_state <= 3'd6;
				end
				core_bankmachine2_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine2_twtpcon_ready) begin
				core_bankmachine2_refresh_gnt <= 1'd1;
			end
			core_bankmachine2_row_close <= 1'd1;
			core_bankmachine2_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine2_refresh_req)) begin
				bankmachine2_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine2_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine2_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine2_refresh_req) begin
				bankmachine2_next_state <= 3'd4;
			end else begin
				if (core_bankmachine2_source_source_valid) begin
					if (core_bankmachine2_row_opened) begin
						if (core_bankmachine2_row_hit) begin
							core_bankmachine2_cmd_valid <= 1'd1;
							if (core_bankmachine2_source_source_payload_we) begin
								core_bankmachine2_req_wdata_ready <= core_bankmachine2_cmd_ready;
								core_bankmachine2_cmd_payload_is_write <= 1'd1;
								core_bankmachine2_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine2_req_rdata_valid <= core_bankmachine2_cmd_ready;
								core_bankmachine2_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine2_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine2_cmd_ready & core_bankmachine2_auto_precharge)) begin
								bankmachine2_next_state <= 2'd2;
							end
						end else begin
							bankmachine2_next_state <= 1'd1;
						end
					end else begin
						bankmachine2_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_17 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine3_sink_valid = core_bankmachine3_req_valid;
assign core_bankmachine3_req_ready = core_bankmachine3_sink_ready;
assign core_bankmachine3_sink_payload_we = core_bankmachine3_req_we;
assign core_bankmachine3_sink_payload_addr = core_bankmachine3_req_addr;
assign core_bankmachine3_sink_sink_valid = core_bankmachine3_source_valid;
assign core_bankmachine3_source_ready = core_bankmachine3_sink_sink_ready;
assign core_bankmachine3_sink_sink_first = core_bankmachine3_source_first;
assign core_bankmachine3_sink_sink_last = core_bankmachine3_source_last;
assign core_bankmachine3_sink_sink_payload_we = core_bankmachine3_source_payload_we;
assign core_bankmachine3_sink_sink_payload_addr = core_bankmachine3_source_payload_addr;
assign core_bankmachine3_source_source_ready = (core_bankmachine3_req_wdata_ready | core_bankmachine3_req_rdata_valid);
assign core_bankmachine3_req_lock = (core_bankmachine3_source_valid | core_bankmachine3_source_source_valid);
assign core_bankmachine3_row_hit = (core_bankmachine3_row == core_bankmachine3_source_source_payload_addr[21:7]);
assign core_bankmachine3_cmd_payload_ba = 2'd3;

// synthesis translate_off
reg dummy_d_18;
// synthesis translate_on
always @(*) begin
	core_bankmachine3_cmd_payload_a <= 15'd0;
	if (core_bankmachine3_row_col_n_addr_sel) begin
		core_bankmachine3_cmd_payload_a <= core_bankmachine3_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine3_cmd_payload_a <= ((core_bankmachine3_auto_precharge <<< 4'd10) | {core_bankmachine3_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_18 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine3_twtpcon_valid = ((core_bankmachine3_cmd_valid & core_bankmachine3_cmd_ready) & core_bankmachine3_cmd_payload_is_write);
assign core_bankmachine3_trccon_valid = ((core_bankmachine3_cmd_valid & core_bankmachine3_cmd_ready) & core_bankmachine3_row_open);
assign core_bankmachine3_trascon_valid = ((core_bankmachine3_cmd_valid & core_bankmachine3_cmd_ready) & core_bankmachine3_row_open);

// synthesis translate_off
reg dummy_d_19;
// synthesis translate_on
always @(*) begin
	core_bankmachine3_auto_precharge <= 1'd0;
	if ((core_bankmachine3_source_valid & core_bankmachine3_source_source_valid)) begin
		if ((core_bankmachine3_source_payload_addr[21:7] != core_bankmachine3_source_source_payload_addr[21:7])) begin
			core_bankmachine3_auto_precharge <= (core_bankmachine3_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_19 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine3_syncfifo3_din = {core_bankmachine3_fifo_in_last, core_bankmachine3_fifo_in_first, core_bankmachine3_fifo_in_payload_addr, core_bankmachine3_fifo_in_payload_we};
assign {core_bankmachine3_fifo_out_last, core_bankmachine3_fifo_out_first, core_bankmachine3_fifo_out_payload_addr, core_bankmachine3_fifo_out_payload_we} = core_bankmachine3_syncfifo3_dout;
assign core_bankmachine3_sink_ready = core_bankmachine3_syncfifo3_writable;
assign core_bankmachine3_syncfifo3_we = core_bankmachine3_sink_valid;
assign core_bankmachine3_fifo_in_first = core_bankmachine3_sink_first;
assign core_bankmachine3_fifo_in_last = core_bankmachine3_sink_last;
assign core_bankmachine3_fifo_in_payload_we = core_bankmachine3_sink_payload_we;
assign core_bankmachine3_fifo_in_payload_addr = core_bankmachine3_sink_payload_addr;
assign core_bankmachine3_source_valid = core_bankmachine3_syncfifo3_readable;
assign core_bankmachine3_source_first = core_bankmachine3_fifo_out_first;
assign core_bankmachine3_source_last = core_bankmachine3_fifo_out_last;
assign core_bankmachine3_source_payload_we = core_bankmachine3_fifo_out_payload_we;
assign core_bankmachine3_source_payload_addr = core_bankmachine3_fifo_out_payload_addr;
assign core_bankmachine3_syncfifo3_re = core_bankmachine3_source_ready;

// synthesis translate_off
reg dummy_d_20;
// synthesis translate_on
always @(*) begin
	core_bankmachine3_wrport_adr <= 3'd0;
	if (core_bankmachine3_replace) begin
		core_bankmachine3_wrport_adr <= (core_bankmachine3_produce - 1'd1);
	end else begin
		core_bankmachine3_wrport_adr <= core_bankmachine3_produce;
	end
// synthesis translate_off
	dummy_d_20 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine3_wrport_dat_w = core_bankmachine3_syncfifo3_din;
assign core_bankmachine3_wrport_we = (core_bankmachine3_syncfifo3_we & (core_bankmachine3_syncfifo3_writable | core_bankmachine3_replace));
assign core_bankmachine3_do_read = (core_bankmachine3_syncfifo3_readable & core_bankmachine3_syncfifo3_re);
assign core_bankmachine3_rdport_adr = core_bankmachine3_consume;
assign core_bankmachine3_syncfifo3_dout = core_bankmachine3_rdport_dat_r;
assign core_bankmachine3_syncfifo3_writable = (core_bankmachine3_level != 4'd8);
assign core_bankmachine3_syncfifo3_readable = (core_bankmachine3_level != 1'd0);
assign core_bankmachine3_pipe_valid_sink_ready = ((~core_bankmachine3_pipe_valid_source_valid) | core_bankmachine3_pipe_valid_source_ready);
assign core_bankmachine3_pipe_valid_sink_valid = core_bankmachine3_sink_sink_valid;
assign core_bankmachine3_sink_sink_ready = core_bankmachine3_pipe_valid_sink_ready;
assign core_bankmachine3_pipe_valid_sink_first = core_bankmachine3_sink_sink_first;
assign core_bankmachine3_pipe_valid_sink_last = core_bankmachine3_sink_sink_last;
assign core_bankmachine3_pipe_valid_sink_payload_we = core_bankmachine3_sink_sink_payload_we;
assign core_bankmachine3_pipe_valid_sink_payload_addr = core_bankmachine3_sink_sink_payload_addr;
assign core_bankmachine3_source_source_valid = core_bankmachine3_pipe_valid_source_valid;
assign core_bankmachine3_pipe_valid_source_ready = core_bankmachine3_source_source_ready;
assign core_bankmachine3_source_source_first = core_bankmachine3_pipe_valid_source_first;
assign core_bankmachine3_source_source_last = core_bankmachine3_pipe_valid_source_last;
assign core_bankmachine3_source_source_payload_we = core_bankmachine3_pipe_valid_source_payload_we;
assign core_bankmachine3_source_source_payload_addr = core_bankmachine3_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_21;
// synthesis translate_on
always @(*) begin
	core_bankmachine3_req_wdata_ready <= 1'd0;
	core_bankmachine3_req_rdata_valid <= 1'd0;
	core_bankmachine3_refresh_gnt <= 1'd0;
	core_bankmachine3_cmd_valid <= 1'd0;
	core_bankmachine3_cmd_payload_cas <= 1'd0;
	core_bankmachine3_cmd_payload_ras <= 1'd0;
	core_bankmachine3_cmd_payload_we <= 1'd0;
	core_bankmachine3_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine3_cmd_payload_is_read <= 1'd0;
	core_bankmachine3_cmd_payload_is_write <= 1'd0;
	core_bankmachine3_row_open <= 1'd0;
	core_bankmachine3_row_close <= 1'd0;
	core_bankmachine3_row_col_n_addr_sel <= 1'd0;
	bankmachine3_next_state <= 3'd0;
	bankmachine3_next_state <= bankmachine3_state;
	case (bankmachine3_state)
		1'd1: begin
			if ((core_bankmachine3_twtpcon_ready & core_bankmachine3_trascon_ready)) begin
				core_bankmachine3_cmd_valid <= 1'd1;
				if (core_bankmachine3_cmd_ready) begin
					bankmachine3_next_state <= 3'd5;
				end
				core_bankmachine3_cmd_payload_ras <= 1'd1;
				core_bankmachine3_cmd_payload_we <= 1'd1;
				core_bankmachine3_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine3_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine3_twtpcon_ready & core_bankmachine3_trascon_ready)) begin
				bankmachine3_next_state <= 3'd5;
			end
			core_bankmachine3_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine3_trccon_ready) begin
				core_bankmachine3_row_col_n_addr_sel <= 1'd1;
				core_bankmachine3_row_open <= 1'd1;
				core_bankmachine3_cmd_valid <= 1'd1;
				core_bankmachine3_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine3_cmd_ready) begin
					bankmachine3_next_state <= 3'd6;
				end
				core_bankmachine3_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine3_twtpcon_ready) begin
				core_bankmachine3_refresh_gnt <= 1'd1;
			end
			core_bankmachine3_row_close <= 1'd1;
			core_bankmachine3_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine3_refresh_req)) begin
				bankmachine3_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine3_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine3_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine3_refresh_req) begin
				bankmachine3_next_state <= 3'd4;
			end else begin
				if (core_bankmachine3_source_source_valid) begin
					if (core_bankmachine3_row_opened) begin
						if (core_bankmachine3_row_hit) begin
							core_bankmachine3_cmd_valid <= 1'd1;
							if (core_bankmachine3_source_source_payload_we) begin
								core_bankmachine3_req_wdata_ready <= core_bankmachine3_cmd_ready;
								core_bankmachine3_cmd_payload_is_write <= 1'd1;
								core_bankmachine3_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine3_req_rdata_valid <= core_bankmachine3_cmd_ready;
								core_bankmachine3_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine3_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine3_cmd_ready & core_bankmachine3_auto_precharge)) begin
								bankmachine3_next_state <= 2'd2;
							end
						end else begin
							bankmachine3_next_state <= 1'd1;
						end
					end else begin
						bankmachine3_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_21 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine4_sink_valid = core_bankmachine4_req_valid;
assign core_bankmachine4_req_ready = core_bankmachine4_sink_ready;
assign core_bankmachine4_sink_payload_we = core_bankmachine4_req_we;
assign core_bankmachine4_sink_payload_addr = core_bankmachine4_req_addr;
assign core_bankmachine4_sink_sink_valid = core_bankmachine4_source_valid;
assign core_bankmachine4_source_ready = core_bankmachine4_sink_sink_ready;
assign core_bankmachine4_sink_sink_first = core_bankmachine4_source_first;
assign core_bankmachine4_sink_sink_last = core_bankmachine4_source_last;
assign core_bankmachine4_sink_sink_payload_we = core_bankmachine4_source_payload_we;
assign core_bankmachine4_sink_sink_payload_addr = core_bankmachine4_source_payload_addr;
assign core_bankmachine4_source_source_ready = (core_bankmachine4_req_wdata_ready | core_bankmachine4_req_rdata_valid);
assign core_bankmachine4_req_lock = (core_bankmachine4_source_valid | core_bankmachine4_source_source_valid);
assign core_bankmachine4_row_hit = (core_bankmachine4_row == core_bankmachine4_source_source_payload_addr[21:7]);
assign core_bankmachine4_cmd_payload_ba = 3'd4;

// synthesis translate_off
reg dummy_d_22;
// synthesis translate_on
always @(*) begin
	core_bankmachine4_cmd_payload_a <= 15'd0;
	if (core_bankmachine4_row_col_n_addr_sel) begin
		core_bankmachine4_cmd_payload_a <= core_bankmachine4_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine4_cmd_payload_a <= ((core_bankmachine4_auto_precharge <<< 4'd10) | {core_bankmachine4_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_22 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine4_twtpcon_valid = ((core_bankmachine4_cmd_valid & core_bankmachine4_cmd_ready) & core_bankmachine4_cmd_payload_is_write);
assign core_bankmachine4_trccon_valid = ((core_bankmachine4_cmd_valid & core_bankmachine4_cmd_ready) & core_bankmachine4_row_open);
assign core_bankmachine4_trascon_valid = ((core_bankmachine4_cmd_valid & core_bankmachine4_cmd_ready) & core_bankmachine4_row_open);

// synthesis translate_off
reg dummy_d_23;
// synthesis translate_on
always @(*) begin
	core_bankmachine4_auto_precharge <= 1'd0;
	if ((core_bankmachine4_source_valid & core_bankmachine4_source_source_valid)) begin
		if ((core_bankmachine4_source_payload_addr[21:7] != core_bankmachine4_source_source_payload_addr[21:7])) begin
			core_bankmachine4_auto_precharge <= (core_bankmachine4_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_23 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine4_syncfifo4_din = {core_bankmachine4_fifo_in_last, core_bankmachine4_fifo_in_first, core_bankmachine4_fifo_in_payload_addr, core_bankmachine4_fifo_in_payload_we};
assign {core_bankmachine4_fifo_out_last, core_bankmachine4_fifo_out_first, core_bankmachine4_fifo_out_payload_addr, core_bankmachine4_fifo_out_payload_we} = core_bankmachine4_syncfifo4_dout;
assign core_bankmachine4_sink_ready = core_bankmachine4_syncfifo4_writable;
assign core_bankmachine4_syncfifo4_we = core_bankmachine4_sink_valid;
assign core_bankmachine4_fifo_in_first = core_bankmachine4_sink_first;
assign core_bankmachine4_fifo_in_last = core_bankmachine4_sink_last;
assign core_bankmachine4_fifo_in_payload_we = core_bankmachine4_sink_payload_we;
assign core_bankmachine4_fifo_in_payload_addr = core_bankmachine4_sink_payload_addr;
assign core_bankmachine4_source_valid = core_bankmachine4_syncfifo4_readable;
assign core_bankmachine4_source_first = core_bankmachine4_fifo_out_first;
assign core_bankmachine4_source_last = core_bankmachine4_fifo_out_last;
assign core_bankmachine4_source_payload_we = core_bankmachine4_fifo_out_payload_we;
assign core_bankmachine4_source_payload_addr = core_bankmachine4_fifo_out_payload_addr;
assign core_bankmachine4_syncfifo4_re = core_bankmachine4_source_ready;

// synthesis translate_off
reg dummy_d_24;
// synthesis translate_on
always @(*) begin
	core_bankmachine4_wrport_adr <= 3'd0;
	if (core_bankmachine4_replace) begin
		core_bankmachine4_wrport_adr <= (core_bankmachine4_produce - 1'd1);
	end else begin
		core_bankmachine4_wrport_adr <= core_bankmachine4_produce;
	end
// synthesis translate_off
	dummy_d_24 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine4_wrport_dat_w = core_bankmachine4_syncfifo4_din;
assign core_bankmachine4_wrport_we = (core_bankmachine4_syncfifo4_we & (core_bankmachine4_syncfifo4_writable | core_bankmachine4_replace));
assign core_bankmachine4_do_read = (core_bankmachine4_syncfifo4_readable & core_bankmachine4_syncfifo4_re);
assign core_bankmachine4_rdport_adr = core_bankmachine4_consume;
assign core_bankmachine4_syncfifo4_dout = core_bankmachine4_rdport_dat_r;
assign core_bankmachine4_syncfifo4_writable = (core_bankmachine4_level != 4'd8);
assign core_bankmachine4_syncfifo4_readable = (core_bankmachine4_level != 1'd0);
assign core_bankmachine4_pipe_valid_sink_ready = ((~core_bankmachine4_pipe_valid_source_valid) | core_bankmachine4_pipe_valid_source_ready);
assign core_bankmachine4_pipe_valid_sink_valid = core_bankmachine4_sink_sink_valid;
assign core_bankmachine4_sink_sink_ready = core_bankmachine4_pipe_valid_sink_ready;
assign core_bankmachine4_pipe_valid_sink_first = core_bankmachine4_sink_sink_first;
assign core_bankmachine4_pipe_valid_sink_last = core_bankmachine4_sink_sink_last;
assign core_bankmachine4_pipe_valid_sink_payload_we = core_bankmachine4_sink_sink_payload_we;
assign core_bankmachine4_pipe_valid_sink_payload_addr = core_bankmachine4_sink_sink_payload_addr;
assign core_bankmachine4_source_source_valid = core_bankmachine4_pipe_valid_source_valid;
assign core_bankmachine4_pipe_valid_source_ready = core_bankmachine4_source_source_ready;
assign core_bankmachine4_source_source_first = core_bankmachine4_pipe_valid_source_first;
assign core_bankmachine4_source_source_last = core_bankmachine4_pipe_valid_source_last;
assign core_bankmachine4_source_source_payload_we = core_bankmachine4_pipe_valid_source_payload_we;
assign core_bankmachine4_source_source_payload_addr = core_bankmachine4_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_25;
// synthesis translate_on
always @(*) begin
	core_bankmachine4_req_wdata_ready <= 1'd0;
	core_bankmachine4_req_rdata_valid <= 1'd0;
	core_bankmachine4_refresh_gnt <= 1'd0;
	core_bankmachine4_cmd_valid <= 1'd0;
	core_bankmachine4_cmd_payload_cas <= 1'd0;
	core_bankmachine4_cmd_payload_ras <= 1'd0;
	core_bankmachine4_cmd_payload_we <= 1'd0;
	core_bankmachine4_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine4_cmd_payload_is_read <= 1'd0;
	core_bankmachine4_cmd_payload_is_write <= 1'd0;
	core_bankmachine4_row_open <= 1'd0;
	core_bankmachine4_row_close <= 1'd0;
	core_bankmachine4_row_col_n_addr_sel <= 1'd0;
	bankmachine4_next_state <= 3'd0;
	bankmachine4_next_state <= bankmachine4_state;
	case (bankmachine4_state)
		1'd1: begin
			if ((core_bankmachine4_twtpcon_ready & core_bankmachine4_trascon_ready)) begin
				core_bankmachine4_cmd_valid <= 1'd1;
				if (core_bankmachine4_cmd_ready) begin
					bankmachine4_next_state <= 3'd5;
				end
				core_bankmachine4_cmd_payload_ras <= 1'd1;
				core_bankmachine4_cmd_payload_we <= 1'd1;
				core_bankmachine4_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine4_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine4_twtpcon_ready & core_bankmachine4_trascon_ready)) begin
				bankmachine4_next_state <= 3'd5;
			end
			core_bankmachine4_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine4_trccon_ready) begin
				core_bankmachine4_row_col_n_addr_sel <= 1'd1;
				core_bankmachine4_row_open <= 1'd1;
				core_bankmachine4_cmd_valid <= 1'd1;
				core_bankmachine4_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine4_cmd_ready) begin
					bankmachine4_next_state <= 3'd6;
				end
				core_bankmachine4_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine4_twtpcon_ready) begin
				core_bankmachine4_refresh_gnt <= 1'd1;
			end
			core_bankmachine4_row_close <= 1'd1;
			core_bankmachine4_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine4_refresh_req)) begin
				bankmachine4_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine4_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine4_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine4_refresh_req) begin
				bankmachine4_next_state <= 3'd4;
			end else begin
				if (core_bankmachine4_source_source_valid) begin
					if (core_bankmachine4_row_opened) begin
						if (core_bankmachine4_row_hit) begin
							core_bankmachine4_cmd_valid <= 1'd1;
							if (core_bankmachine4_source_source_payload_we) begin
								core_bankmachine4_req_wdata_ready <= core_bankmachine4_cmd_ready;
								core_bankmachine4_cmd_payload_is_write <= 1'd1;
								core_bankmachine4_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine4_req_rdata_valid <= core_bankmachine4_cmd_ready;
								core_bankmachine4_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine4_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine4_cmd_ready & core_bankmachine4_auto_precharge)) begin
								bankmachine4_next_state <= 2'd2;
							end
						end else begin
							bankmachine4_next_state <= 1'd1;
						end
					end else begin
						bankmachine4_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_25 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine5_sink_valid = core_bankmachine5_req_valid;
assign core_bankmachine5_req_ready = core_bankmachine5_sink_ready;
assign core_bankmachine5_sink_payload_we = core_bankmachine5_req_we;
assign core_bankmachine5_sink_payload_addr = core_bankmachine5_req_addr;
assign core_bankmachine5_sink_sink_valid = core_bankmachine5_source_valid;
assign core_bankmachine5_source_ready = core_bankmachine5_sink_sink_ready;
assign core_bankmachine5_sink_sink_first = core_bankmachine5_source_first;
assign core_bankmachine5_sink_sink_last = core_bankmachine5_source_last;
assign core_bankmachine5_sink_sink_payload_we = core_bankmachine5_source_payload_we;
assign core_bankmachine5_sink_sink_payload_addr = core_bankmachine5_source_payload_addr;
assign core_bankmachine5_source_source_ready = (core_bankmachine5_req_wdata_ready | core_bankmachine5_req_rdata_valid);
assign core_bankmachine5_req_lock = (core_bankmachine5_source_valid | core_bankmachine5_source_source_valid);
assign core_bankmachine5_row_hit = (core_bankmachine5_row == core_bankmachine5_source_source_payload_addr[21:7]);
assign core_bankmachine5_cmd_payload_ba = 3'd5;

// synthesis translate_off
reg dummy_d_26;
// synthesis translate_on
always @(*) begin
	core_bankmachine5_cmd_payload_a <= 15'd0;
	if (core_bankmachine5_row_col_n_addr_sel) begin
		core_bankmachine5_cmd_payload_a <= core_bankmachine5_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine5_cmd_payload_a <= ((core_bankmachine5_auto_precharge <<< 4'd10) | {core_bankmachine5_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_26 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine5_twtpcon_valid = ((core_bankmachine5_cmd_valid & core_bankmachine5_cmd_ready) & core_bankmachine5_cmd_payload_is_write);
assign core_bankmachine5_trccon_valid = ((core_bankmachine5_cmd_valid & core_bankmachine5_cmd_ready) & core_bankmachine5_row_open);
assign core_bankmachine5_trascon_valid = ((core_bankmachine5_cmd_valid & core_bankmachine5_cmd_ready) & core_bankmachine5_row_open);

// synthesis translate_off
reg dummy_d_27;
// synthesis translate_on
always @(*) begin
	core_bankmachine5_auto_precharge <= 1'd0;
	if ((core_bankmachine5_source_valid & core_bankmachine5_source_source_valid)) begin
		if ((core_bankmachine5_source_payload_addr[21:7] != core_bankmachine5_source_source_payload_addr[21:7])) begin
			core_bankmachine5_auto_precharge <= (core_bankmachine5_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_27 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine5_syncfifo5_din = {core_bankmachine5_fifo_in_last, core_bankmachine5_fifo_in_first, core_bankmachine5_fifo_in_payload_addr, core_bankmachine5_fifo_in_payload_we};
assign {core_bankmachine5_fifo_out_last, core_bankmachine5_fifo_out_first, core_bankmachine5_fifo_out_payload_addr, core_bankmachine5_fifo_out_payload_we} = core_bankmachine5_syncfifo5_dout;
assign core_bankmachine5_sink_ready = core_bankmachine5_syncfifo5_writable;
assign core_bankmachine5_syncfifo5_we = core_bankmachine5_sink_valid;
assign core_bankmachine5_fifo_in_first = core_bankmachine5_sink_first;
assign core_bankmachine5_fifo_in_last = core_bankmachine5_sink_last;
assign core_bankmachine5_fifo_in_payload_we = core_bankmachine5_sink_payload_we;
assign core_bankmachine5_fifo_in_payload_addr = core_bankmachine5_sink_payload_addr;
assign core_bankmachine5_source_valid = core_bankmachine5_syncfifo5_readable;
assign core_bankmachine5_source_first = core_bankmachine5_fifo_out_first;
assign core_bankmachine5_source_last = core_bankmachine5_fifo_out_last;
assign core_bankmachine5_source_payload_we = core_bankmachine5_fifo_out_payload_we;
assign core_bankmachine5_source_payload_addr = core_bankmachine5_fifo_out_payload_addr;
assign core_bankmachine5_syncfifo5_re = core_bankmachine5_source_ready;

// synthesis translate_off
reg dummy_d_28;
// synthesis translate_on
always @(*) begin
	core_bankmachine5_wrport_adr <= 3'd0;
	if (core_bankmachine5_replace) begin
		core_bankmachine5_wrport_adr <= (core_bankmachine5_produce - 1'd1);
	end else begin
		core_bankmachine5_wrport_adr <= core_bankmachine5_produce;
	end
// synthesis translate_off
	dummy_d_28 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine5_wrport_dat_w = core_bankmachine5_syncfifo5_din;
assign core_bankmachine5_wrport_we = (core_bankmachine5_syncfifo5_we & (core_bankmachine5_syncfifo5_writable | core_bankmachine5_replace));
assign core_bankmachine5_do_read = (core_bankmachine5_syncfifo5_readable & core_bankmachine5_syncfifo5_re);
assign core_bankmachine5_rdport_adr = core_bankmachine5_consume;
assign core_bankmachine5_syncfifo5_dout = core_bankmachine5_rdport_dat_r;
assign core_bankmachine5_syncfifo5_writable = (core_bankmachine5_level != 4'd8);
assign core_bankmachine5_syncfifo5_readable = (core_bankmachine5_level != 1'd0);
assign core_bankmachine5_pipe_valid_sink_ready = ((~core_bankmachine5_pipe_valid_source_valid) | core_bankmachine5_pipe_valid_source_ready);
assign core_bankmachine5_pipe_valid_sink_valid = core_bankmachine5_sink_sink_valid;
assign core_bankmachine5_sink_sink_ready = core_bankmachine5_pipe_valid_sink_ready;
assign core_bankmachine5_pipe_valid_sink_first = core_bankmachine5_sink_sink_first;
assign core_bankmachine5_pipe_valid_sink_last = core_bankmachine5_sink_sink_last;
assign core_bankmachine5_pipe_valid_sink_payload_we = core_bankmachine5_sink_sink_payload_we;
assign core_bankmachine5_pipe_valid_sink_payload_addr = core_bankmachine5_sink_sink_payload_addr;
assign core_bankmachine5_source_source_valid = core_bankmachine5_pipe_valid_source_valid;
assign core_bankmachine5_pipe_valid_source_ready = core_bankmachine5_source_source_ready;
assign core_bankmachine5_source_source_first = core_bankmachine5_pipe_valid_source_first;
assign core_bankmachine5_source_source_last = core_bankmachine5_pipe_valid_source_last;
assign core_bankmachine5_source_source_payload_we = core_bankmachine5_pipe_valid_source_payload_we;
assign core_bankmachine5_source_source_payload_addr = core_bankmachine5_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_29;
// synthesis translate_on
always @(*) begin
	core_bankmachine5_req_wdata_ready <= 1'd0;
	core_bankmachine5_req_rdata_valid <= 1'd0;
	core_bankmachine5_refresh_gnt <= 1'd0;
	core_bankmachine5_cmd_valid <= 1'd0;
	core_bankmachine5_cmd_payload_cas <= 1'd0;
	core_bankmachine5_cmd_payload_ras <= 1'd0;
	core_bankmachine5_cmd_payload_we <= 1'd0;
	core_bankmachine5_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine5_cmd_payload_is_read <= 1'd0;
	core_bankmachine5_cmd_payload_is_write <= 1'd0;
	core_bankmachine5_row_open <= 1'd0;
	core_bankmachine5_row_close <= 1'd0;
	core_bankmachine5_row_col_n_addr_sel <= 1'd0;
	bankmachine5_next_state <= 3'd0;
	bankmachine5_next_state <= bankmachine5_state;
	case (bankmachine5_state)
		1'd1: begin
			if ((core_bankmachine5_twtpcon_ready & core_bankmachine5_trascon_ready)) begin
				core_bankmachine5_cmd_valid <= 1'd1;
				if (core_bankmachine5_cmd_ready) begin
					bankmachine5_next_state <= 3'd5;
				end
				core_bankmachine5_cmd_payload_ras <= 1'd1;
				core_bankmachine5_cmd_payload_we <= 1'd1;
				core_bankmachine5_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine5_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine5_twtpcon_ready & core_bankmachine5_trascon_ready)) begin
				bankmachine5_next_state <= 3'd5;
			end
			core_bankmachine5_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine5_trccon_ready) begin
				core_bankmachine5_row_col_n_addr_sel <= 1'd1;
				core_bankmachine5_row_open <= 1'd1;
				core_bankmachine5_cmd_valid <= 1'd1;
				core_bankmachine5_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine5_cmd_ready) begin
					bankmachine5_next_state <= 3'd6;
				end
				core_bankmachine5_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine5_twtpcon_ready) begin
				core_bankmachine5_refresh_gnt <= 1'd1;
			end
			core_bankmachine5_row_close <= 1'd1;
			core_bankmachine5_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine5_refresh_req)) begin
				bankmachine5_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine5_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine5_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine5_refresh_req) begin
				bankmachine5_next_state <= 3'd4;
			end else begin
				if (core_bankmachine5_source_source_valid) begin
					if (core_bankmachine5_row_opened) begin
						if (core_bankmachine5_row_hit) begin
							core_bankmachine5_cmd_valid <= 1'd1;
							if (core_bankmachine5_source_source_payload_we) begin
								core_bankmachine5_req_wdata_ready <= core_bankmachine5_cmd_ready;
								core_bankmachine5_cmd_payload_is_write <= 1'd1;
								core_bankmachine5_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine5_req_rdata_valid <= core_bankmachine5_cmd_ready;
								core_bankmachine5_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine5_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine5_cmd_ready & core_bankmachine5_auto_precharge)) begin
								bankmachine5_next_state <= 2'd2;
							end
						end else begin
							bankmachine5_next_state <= 1'd1;
						end
					end else begin
						bankmachine5_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_29 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine6_sink_valid = core_bankmachine6_req_valid;
assign core_bankmachine6_req_ready = core_bankmachine6_sink_ready;
assign core_bankmachine6_sink_payload_we = core_bankmachine6_req_we;
assign core_bankmachine6_sink_payload_addr = core_bankmachine6_req_addr;
assign core_bankmachine6_sink_sink_valid = core_bankmachine6_source_valid;
assign core_bankmachine6_source_ready = core_bankmachine6_sink_sink_ready;
assign core_bankmachine6_sink_sink_first = core_bankmachine6_source_first;
assign core_bankmachine6_sink_sink_last = core_bankmachine6_source_last;
assign core_bankmachine6_sink_sink_payload_we = core_bankmachine6_source_payload_we;
assign core_bankmachine6_sink_sink_payload_addr = core_bankmachine6_source_payload_addr;
assign core_bankmachine6_source_source_ready = (core_bankmachine6_req_wdata_ready | core_bankmachine6_req_rdata_valid);
assign core_bankmachine6_req_lock = (core_bankmachine6_source_valid | core_bankmachine6_source_source_valid);
assign core_bankmachine6_row_hit = (core_bankmachine6_row == core_bankmachine6_source_source_payload_addr[21:7]);
assign core_bankmachine6_cmd_payload_ba = 3'd6;

// synthesis translate_off
reg dummy_d_30;
// synthesis translate_on
always @(*) begin
	core_bankmachine6_cmd_payload_a <= 15'd0;
	if (core_bankmachine6_row_col_n_addr_sel) begin
		core_bankmachine6_cmd_payload_a <= core_bankmachine6_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine6_cmd_payload_a <= ((core_bankmachine6_auto_precharge <<< 4'd10) | {core_bankmachine6_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_30 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine6_twtpcon_valid = ((core_bankmachine6_cmd_valid & core_bankmachine6_cmd_ready) & core_bankmachine6_cmd_payload_is_write);
assign core_bankmachine6_trccon_valid = ((core_bankmachine6_cmd_valid & core_bankmachine6_cmd_ready) & core_bankmachine6_row_open);
assign core_bankmachine6_trascon_valid = ((core_bankmachine6_cmd_valid & core_bankmachine6_cmd_ready) & core_bankmachine6_row_open);

// synthesis translate_off
reg dummy_d_31;
// synthesis translate_on
always @(*) begin
	core_bankmachine6_auto_precharge <= 1'd0;
	if ((core_bankmachine6_source_valid & core_bankmachine6_source_source_valid)) begin
		if ((core_bankmachine6_source_payload_addr[21:7] != core_bankmachine6_source_source_payload_addr[21:7])) begin
			core_bankmachine6_auto_precharge <= (core_bankmachine6_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_31 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine6_syncfifo6_din = {core_bankmachine6_fifo_in_last, core_bankmachine6_fifo_in_first, core_bankmachine6_fifo_in_payload_addr, core_bankmachine6_fifo_in_payload_we};
assign {core_bankmachine6_fifo_out_last, core_bankmachine6_fifo_out_first, core_bankmachine6_fifo_out_payload_addr, core_bankmachine6_fifo_out_payload_we} = core_bankmachine6_syncfifo6_dout;
assign core_bankmachine6_sink_ready = core_bankmachine6_syncfifo6_writable;
assign core_bankmachine6_syncfifo6_we = core_bankmachine6_sink_valid;
assign core_bankmachine6_fifo_in_first = core_bankmachine6_sink_first;
assign core_bankmachine6_fifo_in_last = core_bankmachine6_sink_last;
assign core_bankmachine6_fifo_in_payload_we = core_bankmachine6_sink_payload_we;
assign core_bankmachine6_fifo_in_payload_addr = core_bankmachine6_sink_payload_addr;
assign core_bankmachine6_source_valid = core_bankmachine6_syncfifo6_readable;
assign core_bankmachine6_source_first = core_bankmachine6_fifo_out_first;
assign core_bankmachine6_source_last = core_bankmachine6_fifo_out_last;
assign core_bankmachine6_source_payload_we = core_bankmachine6_fifo_out_payload_we;
assign core_bankmachine6_source_payload_addr = core_bankmachine6_fifo_out_payload_addr;
assign core_bankmachine6_syncfifo6_re = core_bankmachine6_source_ready;

// synthesis translate_off
reg dummy_d_32;
// synthesis translate_on
always @(*) begin
	core_bankmachine6_wrport_adr <= 3'd0;
	if (core_bankmachine6_replace) begin
		core_bankmachine6_wrport_adr <= (core_bankmachine6_produce - 1'd1);
	end else begin
		core_bankmachine6_wrport_adr <= core_bankmachine6_produce;
	end
// synthesis translate_off
	dummy_d_32 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine6_wrport_dat_w = core_bankmachine6_syncfifo6_din;
assign core_bankmachine6_wrport_we = (core_bankmachine6_syncfifo6_we & (core_bankmachine6_syncfifo6_writable | core_bankmachine6_replace));
assign core_bankmachine6_do_read = (core_bankmachine6_syncfifo6_readable & core_bankmachine6_syncfifo6_re);
assign core_bankmachine6_rdport_adr = core_bankmachine6_consume;
assign core_bankmachine6_syncfifo6_dout = core_bankmachine6_rdport_dat_r;
assign core_bankmachine6_syncfifo6_writable = (core_bankmachine6_level != 4'd8);
assign core_bankmachine6_syncfifo6_readable = (core_bankmachine6_level != 1'd0);
assign core_bankmachine6_pipe_valid_sink_ready = ((~core_bankmachine6_pipe_valid_source_valid) | core_bankmachine6_pipe_valid_source_ready);
assign core_bankmachine6_pipe_valid_sink_valid = core_bankmachine6_sink_sink_valid;
assign core_bankmachine6_sink_sink_ready = core_bankmachine6_pipe_valid_sink_ready;
assign core_bankmachine6_pipe_valid_sink_first = core_bankmachine6_sink_sink_first;
assign core_bankmachine6_pipe_valid_sink_last = core_bankmachine6_sink_sink_last;
assign core_bankmachine6_pipe_valid_sink_payload_we = core_bankmachine6_sink_sink_payload_we;
assign core_bankmachine6_pipe_valid_sink_payload_addr = core_bankmachine6_sink_sink_payload_addr;
assign core_bankmachine6_source_source_valid = core_bankmachine6_pipe_valid_source_valid;
assign core_bankmachine6_pipe_valid_source_ready = core_bankmachine6_source_source_ready;
assign core_bankmachine6_source_source_first = core_bankmachine6_pipe_valid_source_first;
assign core_bankmachine6_source_source_last = core_bankmachine6_pipe_valid_source_last;
assign core_bankmachine6_source_source_payload_we = core_bankmachine6_pipe_valid_source_payload_we;
assign core_bankmachine6_source_source_payload_addr = core_bankmachine6_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_33;
// synthesis translate_on
always @(*) begin
	core_bankmachine6_req_wdata_ready <= 1'd0;
	core_bankmachine6_req_rdata_valid <= 1'd0;
	core_bankmachine6_refresh_gnt <= 1'd0;
	core_bankmachine6_cmd_valid <= 1'd0;
	core_bankmachine6_cmd_payload_cas <= 1'd0;
	core_bankmachine6_cmd_payload_ras <= 1'd0;
	core_bankmachine6_cmd_payload_we <= 1'd0;
	core_bankmachine6_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine6_cmd_payload_is_read <= 1'd0;
	core_bankmachine6_cmd_payload_is_write <= 1'd0;
	core_bankmachine6_row_open <= 1'd0;
	core_bankmachine6_row_close <= 1'd0;
	core_bankmachine6_row_col_n_addr_sel <= 1'd0;
	bankmachine6_next_state <= 3'd0;
	bankmachine6_next_state <= bankmachine6_state;
	case (bankmachine6_state)
		1'd1: begin
			if ((core_bankmachine6_twtpcon_ready & core_bankmachine6_trascon_ready)) begin
				core_bankmachine6_cmd_valid <= 1'd1;
				if (core_bankmachine6_cmd_ready) begin
					bankmachine6_next_state <= 3'd5;
				end
				core_bankmachine6_cmd_payload_ras <= 1'd1;
				core_bankmachine6_cmd_payload_we <= 1'd1;
				core_bankmachine6_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine6_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine6_twtpcon_ready & core_bankmachine6_trascon_ready)) begin
				bankmachine6_next_state <= 3'd5;
			end
			core_bankmachine6_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine6_trccon_ready) begin
				core_bankmachine6_row_col_n_addr_sel <= 1'd1;
				core_bankmachine6_row_open <= 1'd1;
				core_bankmachine6_cmd_valid <= 1'd1;
				core_bankmachine6_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine6_cmd_ready) begin
					bankmachine6_next_state <= 3'd6;
				end
				core_bankmachine6_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine6_twtpcon_ready) begin
				core_bankmachine6_refresh_gnt <= 1'd1;
			end
			core_bankmachine6_row_close <= 1'd1;
			core_bankmachine6_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine6_refresh_req)) begin
				bankmachine6_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine6_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine6_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine6_refresh_req) begin
				bankmachine6_next_state <= 3'd4;
			end else begin
				if (core_bankmachine6_source_source_valid) begin
					if (core_bankmachine6_row_opened) begin
						if (core_bankmachine6_row_hit) begin
							core_bankmachine6_cmd_valid <= 1'd1;
							if (core_bankmachine6_source_source_payload_we) begin
								core_bankmachine6_req_wdata_ready <= core_bankmachine6_cmd_ready;
								core_bankmachine6_cmd_payload_is_write <= 1'd1;
								core_bankmachine6_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine6_req_rdata_valid <= core_bankmachine6_cmd_ready;
								core_bankmachine6_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine6_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine6_cmd_ready & core_bankmachine6_auto_precharge)) begin
								bankmachine6_next_state <= 2'd2;
							end
						end else begin
							bankmachine6_next_state <= 1'd1;
						end
					end else begin
						bankmachine6_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_33 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine7_sink_valid = core_bankmachine7_req_valid;
assign core_bankmachine7_req_ready = core_bankmachine7_sink_ready;
assign core_bankmachine7_sink_payload_we = core_bankmachine7_req_we;
assign core_bankmachine7_sink_payload_addr = core_bankmachine7_req_addr;
assign core_bankmachine7_sink_sink_valid = core_bankmachine7_source_valid;
assign core_bankmachine7_source_ready = core_bankmachine7_sink_sink_ready;
assign core_bankmachine7_sink_sink_first = core_bankmachine7_source_first;
assign core_bankmachine7_sink_sink_last = core_bankmachine7_source_last;
assign core_bankmachine7_sink_sink_payload_we = core_bankmachine7_source_payload_we;
assign core_bankmachine7_sink_sink_payload_addr = core_bankmachine7_source_payload_addr;
assign core_bankmachine7_source_source_ready = (core_bankmachine7_req_wdata_ready | core_bankmachine7_req_rdata_valid);
assign core_bankmachine7_req_lock = (core_bankmachine7_source_valid | core_bankmachine7_source_source_valid);
assign core_bankmachine7_row_hit = (core_bankmachine7_row == core_bankmachine7_source_source_payload_addr[21:7]);
assign core_bankmachine7_cmd_payload_ba = 3'd7;

// synthesis translate_off
reg dummy_d_34;
// synthesis translate_on
always @(*) begin
	core_bankmachine7_cmd_payload_a <= 15'd0;
	if (core_bankmachine7_row_col_n_addr_sel) begin
		core_bankmachine7_cmd_payload_a <= core_bankmachine7_source_source_payload_addr[21:7];
	end else begin
		core_bankmachine7_cmd_payload_a <= ((core_bankmachine7_auto_precharge <<< 4'd10) | {core_bankmachine7_source_source_payload_addr[6:0], {3{1'd0}}});
	end
// synthesis translate_off
	dummy_d_34 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine7_twtpcon_valid = ((core_bankmachine7_cmd_valid & core_bankmachine7_cmd_ready) & core_bankmachine7_cmd_payload_is_write);
assign core_bankmachine7_trccon_valid = ((core_bankmachine7_cmd_valid & core_bankmachine7_cmd_ready) & core_bankmachine7_row_open);
assign core_bankmachine7_trascon_valid = ((core_bankmachine7_cmd_valid & core_bankmachine7_cmd_ready) & core_bankmachine7_row_open);

// synthesis translate_off
reg dummy_d_35;
// synthesis translate_on
always @(*) begin
	core_bankmachine7_auto_precharge <= 1'd0;
	if ((core_bankmachine7_source_valid & core_bankmachine7_source_source_valid)) begin
		if ((core_bankmachine7_source_payload_addr[21:7] != core_bankmachine7_source_source_payload_addr[21:7])) begin
			core_bankmachine7_auto_precharge <= (core_bankmachine7_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_35 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine7_syncfifo7_din = {core_bankmachine7_fifo_in_last, core_bankmachine7_fifo_in_first, core_bankmachine7_fifo_in_payload_addr, core_bankmachine7_fifo_in_payload_we};
assign {core_bankmachine7_fifo_out_last, core_bankmachine7_fifo_out_first, core_bankmachine7_fifo_out_payload_addr, core_bankmachine7_fifo_out_payload_we} = core_bankmachine7_syncfifo7_dout;
assign core_bankmachine7_sink_ready = core_bankmachine7_syncfifo7_writable;
assign core_bankmachine7_syncfifo7_we = core_bankmachine7_sink_valid;
assign core_bankmachine7_fifo_in_first = core_bankmachine7_sink_first;
assign core_bankmachine7_fifo_in_last = core_bankmachine7_sink_last;
assign core_bankmachine7_fifo_in_payload_we = core_bankmachine7_sink_payload_we;
assign core_bankmachine7_fifo_in_payload_addr = core_bankmachine7_sink_payload_addr;
assign core_bankmachine7_source_valid = core_bankmachine7_syncfifo7_readable;
assign core_bankmachine7_source_first = core_bankmachine7_fifo_out_first;
assign core_bankmachine7_source_last = core_bankmachine7_fifo_out_last;
assign core_bankmachine7_source_payload_we = core_bankmachine7_fifo_out_payload_we;
assign core_bankmachine7_source_payload_addr = core_bankmachine7_fifo_out_payload_addr;
assign core_bankmachine7_syncfifo7_re = core_bankmachine7_source_ready;

// synthesis translate_off
reg dummy_d_36;
// synthesis translate_on
always @(*) begin
	core_bankmachine7_wrport_adr <= 3'd0;
	if (core_bankmachine7_replace) begin
		core_bankmachine7_wrport_adr <= (core_bankmachine7_produce - 1'd1);
	end else begin
		core_bankmachine7_wrport_adr <= core_bankmachine7_produce;
	end
// synthesis translate_off
	dummy_d_36 <= dummy_s;
// synthesis translate_on
end
assign core_bankmachine7_wrport_dat_w = core_bankmachine7_syncfifo7_din;
assign core_bankmachine7_wrport_we = (core_bankmachine7_syncfifo7_we & (core_bankmachine7_syncfifo7_writable | core_bankmachine7_replace));
assign core_bankmachine7_do_read = (core_bankmachine7_syncfifo7_readable & core_bankmachine7_syncfifo7_re);
assign core_bankmachine7_rdport_adr = core_bankmachine7_consume;
assign core_bankmachine7_syncfifo7_dout = core_bankmachine7_rdport_dat_r;
assign core_bankmachine7_syncfifo7_writable = (core_bankmachine7_level != 4'd8);
assign core_bankmachine7_syncfifo7_readable = (core_bankmachine7_level != 1'd0);
assign core_bankmachine7_pipe_valid_sink_ready = ((~core_bankmachine7_pipe_valid_source_valid) | core_bankmachine7_pipe_valid_source_ready);
assign core_bankmachine7_pipe_valid_sink_valid = core_bankmachine7_sink_sink_valid;
assign core_bankmachine7_sink_sink_ready = core_bankmachine7_pipe_valid_sink_ready;
assign core_bankmachine7_pipe_valid_sink_first = core_bankmachine7_sink_sink_first;
assign core_bankmachine7_pipe_valid_sink_last = core_bankmachine7_sink_sink_last;
assign core_bankmachine7_pipe_valid_sink_payload_we = core_bankmachine7_sink_sink_payload_we;
assign core_bankmachine7_pipe_valid_sink_payload_addr = core_bankmachine7_sink_sink_payload_addr;
assign core_bankmachine7_source_source_valid = core_bankmachine7_pipe_valid_source_valid;
assign core_bankmachine7_pipe_valid_source_ready = core_bankmachine7_source_source_ready;
assign core_bankmachine7_source_source_first = core_bankmachine7_pipe_valid_source_first;
assign core_bankmachine7_source_source_last = core_bankmachine7_pipe_valid_source_last;
assign core_bankmachine7_source_source_payload_we = core_bankmachine7_pipe_valid_source_payload_we;
assign core_bankmachine7_source_source_payload_addr = core_bankmachine7_pipe_valid_source_payload_addr;

// synthesis translate_off
reg dummy_d_37;
// synthesis translate_on
always @(*) begin
	core_bankmachine7_req_wdata_ready <= 1'd0;
	core_bankmachine7_req_rdata_valid <= 1'd0;
	core_bankmachine7_refresh_gnt <= 1'd0;
	core_bankmachine7_cmd_valid <= 1'd0;
	core_bankmachine7_cmd_payload_cas <= 1'd0;
	core_bankmachine7_cmd_payload_ras <= 1'd0;
	core_bankmachine7_cmd_payload_we <= 1'd0;
	core_bankmachine7_cmd_payload_is_cmd <= 1'd0;
	core_bankmachine7_cmd_payload_is_read <= 1'd0;
	core_bankmachine7_cmd_payload_is_write <= 1'd0;
	core_bankmachine7_row_open <= 1'd0;
	core_bankmachine7_row_close <= 1'd0;
	core_bankmachine7_row_col_n_addr_sel <= 1'd0;
	bankmachine7_next_state <= 3'd0;
	bankmachine7_next_state <= bankmachine7_state;
	case (bankmachine7_state)
		1'd1: begin
			if ((core_bankmachine7_twtpcon_ready & core_bankmachine7_trascon_ready)) begin
				core_bankmachine7_cmd_valid <= 1'd1;
				if (core_bankmachine7_cmd_ready) begin
					bankmachine7_next_state <= 3'd5;
				end
				core_bankmachine7_cmd_payload_ras <= 1'd1;
				core_bankmachine7_cmd_payload_we <= 1'd1;
				core_bankmachine7_cmd_payload_is_cmd <= 1'd1;
			end
			core_bankmachine7_row_close <= 1'd1;
		end
		2'd2: begin
			if ((core_bankmachine7_twtpcon_ready & core_bankmachine7_trascon_ready)) begin
				bankmachine7_next_state <= 3'd5;
			end
			core_bankmachine7_row_close <= 1'd1;
		end
		2'd3: begin
			if (core_bankmachine7_trccon_ready) begin
				core_bankmachine7_row_col_n_addr_sel <= 1'd1;
				core_bankmachine7_row_open <= 1'd1;
				core_bankmachine7_cmd_valid <= 1'd1;
				core_bankmachine7_cmd_payload_is_cmd <= 1'd1;
				if (core_bankmachine7_cmd_ready) begin
					bankmachine7_next_state <= 3'd6;
				end
				core_bankmachine7_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
			if (core_bankmachine7_twtpcon_ready) begin
				core_bankmachine7_refresh_gnt <= 1'd1;
			end
			core_bankmachine7_row_close <= 1'd1;
			core_bankmachine7_cmd_payload_is_cmd <= 1'd1;
			if ((~core_bankmachine7_refresh_req)) begin
				bankmachine7_next_state <= 1'd0;
			end
		end
		3'd5: begin
			bankmachine7_next_state <= 2'd3;
		end
		3'd6: begin
			bankmachine7_next_state <= 1'd0;
		end
		default: begin
			if (core_bankmachine7_refresh_req) begin
				bankmachine7_next_state <= 3'd4;
			end else begin
				if (core_bankmachine7_source_source_valid) begin
					if (core_bankmachine7_row_opened) begin
						if (core_bankmachine7_row_hit) begin
							core_bankmachine7_cmd_valid <= 1'd1;
							if (core_bankmachine7_source_source_payload_we) begin
								core_bankmachine7_req_wdata_ready <= core_bankmachine7_cmd_ready;
								core_bankmachine7_cmd_payload_is_write <= 1'd1;
								core_bankmachine7_cmd_payload_we <= 1'd1;
							end else begin
								core_bankmachine7_req_rdata_valid <= core_bankmachine7_cmd_ready;
								core_bankmachine7_cmd_payload_is_read <= 1'd1;
							end
							core_bankmachine7_cmd_payload_cas <= 1'd1;
							if ((core_bankmachine7_cmd_ready & core_bankmachine7_auto_precharge)) begin
								bankmachine7_next_state <= 2'd2;
							end
						end else begin
							bankmachine7_next_state <= 1'd1;
						end
					end else begin
						bankmachine7_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_37 <= dummy_s;
// synthesis translate_on
end
assign core_nphases = (rdphase - 1'd1);
assign core_rdphase = (wrphase - 1'd1);
assign core_trrdcon_valid = ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & ((core_choose_cmd_cmd_payload_ras & (~core_choose_cmd_cmd_payload_cas)) & (~core_choose_cmd_cmd_payload_we)));
assign core_tfawcon_valid = ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & ((core_choose_cmd_cmd_payload_ras & (~core_choose_cmd_cmd_payload_cas)) & (~core_choose_cmd_cmd_payload_we)));
assign core_ras_allowed = (core_trrdcon_ready & core_tfawcon_ready);
assign core_tccdcon_valid = ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_cmd_payload_is_write | core_choose_req_cmd_payload_is_read));
assign core_cas_allowed = core_tccdcon_ready;
assign core_twtrcon_valid = ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_write);
assign core_read_available = ((((((((core_bankmachine0_cmd_valid & core_bankmachine0_cmd_payload_is_read) | (core_bankmachine1_cmd_valid & core_bankmachine1_cmd_payload_is_read)) | (core_bankmachine2_cmd_valid & core_bankmachine2_cmd_payload_is_read)) | (core_bankmachine3_cmd_valid & core_bankmachine3_cmd_payload_is_read)) | (core_bankmachine4_cmd_valid & core_bankmachine4_cmd_payload_is_read)) | (core_bankmachine5_cmd_valid & core_bankmachine5_cmd_payload_is_read)) | (core_bankmachine6_cmd_valid & core_bankmachine6_cmd_payload_is_read)) | (core_bankmachine7_cmd_valid & core_bankmachine7_cmd_payload_is_read));
assign core_write_available = ((((((((core_bankmachine0_cmd_valid & core_bankmachine0_cmd_payload_is_write) | (core_bankmachine1_cmd_valid & core_bankmachine1_cmd_payload_is_write)) | (core_bankmachine2_cmd_valid & core_bankmachine2_cmd_payload_is_write)) | (core_bankmachine3_cmd_valid & core_bankmachine3_cmd_payload_is_write)) | (core_bankmachine4_cmd_valid & core_bankmachine4_cmd_payload_is_write)) | (core_bankmachine5_cmd_valid & core_bankmachine5_cmd_payload_is_write)) | (core_bankmachine6_cmd_valid & core_bankmachine6_cmd_payload_is_write)) | (core_bankmachine7_cmd_valid & core_bankmachine7_cmd_payload_is_write));
assign core_max_time0 = (core_time0 == 1'd0);
assign core_max_time1 = (core_time1 == 1'd0);
assign core_bankmachine0_refresh_req = core_cmd_valid;
assign core_bankmachine1_refresh_req = core_cmd_valid;
assign core_bankmachine2_refresh_req = core_cmd_valid;
assign core_bankmachine3_refresh_req = core_cmd_valid;
assign core_bankmachine4_refresh_req = core_cmd_valid;
assign core_bankmachine5_refresh_req = core_cmd_valid;
assign core_bankmachine6_refresh_req = core_cmd_valid;
assign core_bankmachine7_refresh_req = core_cmd_valid;
assign core_go_to_refresh = (((((((core_bankmachine0_refresh_gnt & core_bankmachine1_refresh_gnt) & core_bankmachine2_refresh_gnt) & core_bankmachine3_refresh_gnt) & core_bankmachine4_refresh_gnt) & core_bankmachine5_refresh_gnt) & core_bankmachine6_refresh_gnt) & core_bankmachine7_refresh_gnt);
assign core_interface_rdata = {core_dfi_p3_rddata, core_dfi_p2_rddata, core_dfi_p1_rddata, core_dfi_p0_rddata};
assign {core_dfi_p3_wrdata, core_dfi_p2_wrdata, core_dfi_p1_wrdata, core_dfi_p0_wrdata} = core_interface_wdata;
assign {core_dfi_p3_wrdata_mask, core_dfi_p2_wrdata_mask, core_dfi_p1_wrdata_mask, core_dfi_p0_wrdata_mask} = (~core_interface_wdata_we);

// synthesis translate_off
reg dummy_d_38;
// synthesis translate_on
always @(*) begin
	core_choose_cmd_valids <= 8'd0;
	core_choose_cmd_valids[0] <= (core_bankmachine0_cmd_valid & (((core_bankmachine0_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine0_cmd_payload_ras & (~core_bankmachine0_cmd_payload_cas)) & (~core_bankmachine0_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine0_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine0_cmd_payload_is_write == core_choose_cmd_want_writes))));
	core_choose_cmd_valids[1] <= (core_bankmachine1_cmd_valid & (((core_bankmachine1_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine1_cmd_payload_ras & (~core_bankmachine1_cmd_payload_cas)) & (~core_bankmachine1_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine1_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine1_cmd_payload_is_write == core_choose_cmd_want_writes))));
	core_choose_cmd_valids[2] <= (core_bankmachine2_cmd_valid & (((core_bankmachine2_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine2_cmd_payload_ras & (~core_bankmachine2_cmd_payload_cas)) & (~core_bankmachine2_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine2_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine2_cmd_payload_is_write == core_choose_cmd_want_writes))));
	core_choose_cmd_valids[3] <= (core_bankmachine3_cmd_valid & (((core_bankmachine3_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine3_cmd_payload_ras & (~core_bankmachine3_cmd_payload_cas)) & (~core_bankmachine3_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine3_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine3_cmd_payload_is_write == core_choose_cmd_want_writes))));
	core_choose_cmd_valids[4] <= (core_bankmachine4_cmd_valid & (((core_bankmachine4_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine4_cmd_payload_ras & (~core_bankmachine4_cmd_payload_cas)) & (~core_bankmachine4_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine4_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine4_cmd_payload_is_write == core_choose_cmd_want_writes))));
	core_choose_cmd_valids[5] <= (core_bankmachine5_cmd_valid & (((core_bankmachine5_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine5_cmd_payload_ras & (~core_bankmachine5_cmd_payload_cas)) & (~core_bankmachine5_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine5_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine5_cmd_payload_is_write == core_choose_cmd_want_writes))));
	core_choose_cmd_valids[6] <= (core_bankmachine6_cmd_valid & (((core_bankmachine6_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine6_cmd_payload_ras & (~core_bankmachine6_cmd_payload_cas)) & (~core_bankmachine6_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine6_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine6_cmd_payload_is_write == core_choose_cmd_want_writes))));
	core_choose_cmd_valids[7] <= (core_bankmachine7_cmd_valid & (((core_bankmachine7_cmd_payload_is_cmd & core_choose_cmd_want_cmds) & ((~((core_bankmachine7_cmd_payload_ras & (~core_bankmachine7_cmd_payload_cas)) & (~core_bankmachine7_cmd_payload_we))) | core_choose_cmd_want_activates)) | ((core_bankmachine7_cmd_payload_is_read == core_choose_cmd_want_reads) & (core_bankmachine7_cmd_payload_is_write == core_choose_cmd_want_writes))));
// synthesis translate_off
	dummy_d_38 <= dummy_s;
// synthesis translate_on
end
assign core_choose_cmd_request = core_choose_cmd_valids;
assign core_choose_cmd_cmd_valid = rhs_self0;
assign core_choose_cmd_cmd_payload_a = rhs_self1;
assign core_choose_cmd_cmd_payload_ba = rhs_self2;
assign core_choose_cmd_cmd_payload_is_read = rhs_self3;
assign core_choose_cmd_cmd_payload_is_write = rhs_self4;
assign core_choose_cmd_cmd_payload_is_cmd = rhs_self5;

// synthesis translate_off
reg dummy_d_39;
// synthesis translate_on
always @(*) begin
	core_choose_cmd_cmd_payload_cas <= 1'd0;
	if (core_choose_cmd_cmd_valid) begin
		core_choose_cmd_cmd_payload_cas <= t_self0;
	end
// synthesis translate_off
	dummy_d_39 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_40;
// synthesis translate_on
always @(*) begin
	core_choose_cmd_cmd_payload_ras <= 1'd0;
	if (core_choose_cmd_cmd_valid) begin
		core_choose_cmd_cmd_payload_ras <= t_self1;
	end
// synthesis translate_off
	dummy_d_40 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_41;
// synthesis translate_on
always @(*) begin
	core_choose_cmd_cmd_payload_we <= 1'd0;
	if (core_choose_cmd_cmd_valid) begin
		core_choose_cmd_cmd_payload_we <= t_self2;
	end
// synthesis translate_off
	dummy_d_41 <= dummy_s;
// synthesis translate_on
end
assign core_choose_cmd_ce = (core_choose_cmd_cmd_ready | (~core_choose_cmd_cmd_valid));

// synthesis translate_off
reg dummy_d_42;
// synthesis translate_on
always @(*) begin
	core_choose_req_valids <= 8'd0;
	core_choose_req_valids[0] <= (core_bankmachine0_cmd_valid & (((core_bankmachine0_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine0_cmd_payload_ras & (~core_bankmachine0_cmd_payload_cas)) & (~core_bankmachine0_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine0_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine0_cmd_payload_is_write == core_choose_req_want_writes))));
	core_choose_req_valids[1] <= (core_bankmachine1_cmd_valid & (((core_bankmachine1_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine1_cmd_payload_ras & (~core_bankmachine1_cmd_payload_cas)) & (~core_bankmachine1_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine1_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine1_cmd_payload_is_write == core_choose_req_want_writes))));
	core_choose_req_valids[2] <= (core_bankmachine2_cmd_valid & (((core_bankmachine2_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine2_cmd_payload_ras & (~core_bankmachine2_cmd_payload_cas)) & (~core_bankmachine2_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine2_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine2_cmd_payload_is_write == core_choose_req_want_writes))));
	core_choose_req_valids[3] <= (core_bankmachine3_cmd_valid & (((core_bankmachine3_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine3_cmd_payload_ras & (~core_bankmachine3_cmd_payload_cas)) & (~core_bankmachine3_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine3_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine3_cmd_payload_is_write == core_choose_req_want_writes))));
	core_choose_req_valids[4] <= (core_bankmachine4_cmd_valid & (((core_bankmachine4_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine4_cmd_payload_ras & (~core_bankmachine4_cmd_payload_cas)) & (~core_bankmachine4_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine4_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine4_cmd_payload_is_write == core_choose_req_want_writes))));
	core_choose_req_valids[5] <= (core_bankmachine5_cmd_valid & (((core_bankmachine5_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine5_cmd_payload_ras & (~core_bankmachine5_cmd_payload_cas)) & (~core_bankmachine5_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine5_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine5_cmd_payload_is_write == core_choose_req_want_writes))));
	core_choose_req_valids[6] <= (core_bankmachine6_cmd_valid & (((core_bankmachine6_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine6_cmd_payload_ras & (~core_bankmachine6_cmd_payload_cas)) & (~core_bankmachine6_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine6_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine6_cmd_payload_is_write == core_choose_req_want_writes))));
	core_choose_req_valids[7] <= (core_bankmachine7_cmd_valid & (((core_bankmachine7_cmd_payload_is_cmd & core_choose_req_want_cmds) & ((~((core_bankmachine7_cmd_payload_ras & (~core_bankmachine7_cmd_payload_cas)) & (~core_bankmachine7_cmd_payload_we))) | core_choose_req_want_activates)) | ((core_bankmachine7_cmd_payload_is_read == core_choose_req_want_reads) & (core_bankmachine7_cmd_payload_is_write == core_choose_req_want_writes))));
// synthesis translate_off
	dummy_d_42 <= dummy_s;
// synthesis translate_on
end
assign core_choose_req_request = core_choose_req_valids;
assign core_choose_req_cmd_valid = rhs_self6;
assign core_choose_req_cmd_payload_a = rhs_self7;
assign core_choose_req_cmd_payload_ba = rhs_self8;
assign core_choose_req_cmd_payload_is_read = rhs_self9;
assign core_choose_req_cmd_payload_is_write = rhs_self10;
assign core_choose_req_cmd_payload_is_cmd = rhs_self11;

// synthesis translate_off
reg dummy_d_43;
// synthesis translate_on
always @(*) begin
	core_choose_req_cmd_payload_cas <= 1'd0;
	if (core_choose_req_cmd_valid) begin
		core_choose_req_cmd_payload_cas <= t_self3;
	end
// synthesis translate_off
	dummy_d_43 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_44;
// synthesis translate_on
always @(*) begin
	core_choose_req_cmd_payload_ras <= 1'd0;
	if (core_choose_req_cmd_valid) begin
		core_choose_req_cmd_payload_ras <= t_self4;
	end
// synthesis translate_off
	dummy_d_44 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_45;
// synthesis translate_on
always @(*) begin
	core_choose_req_cmd_payload_we <= 1'd0;
	if (core_choose_req_cmd_valid) begin
		core_choose_req_cmd_payload_we <= t_self5;
	end
// synthesis translate_off
	dummy_d_45 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_46;
// synthesis translate_on
always @(*) begin
	core_bankmachine0_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 1'd0))) begin
		core_bankmachine0_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 1'd0))) begin
		core_bankmachine0_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_46 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_47;
// synthesis translate_on
always @(*) begin
	core_bankmachine1_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 1'd1))) begin
		core_bankmachine1_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 1'd1))) begin
		core_bankmachine1_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_47 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_48;
// synthesis translate_on
always @(*) begin
	core_bankmachine2_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 2'd2))) begin
		core_bankmachine2_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 2'd2))) begin
		core_bankmachine2_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_48 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_49;
// synthesis translate_on
always @(*) begin
	core_bankmachine3_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 2'd3))) begin
		core_bankmachine3_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 2'd3))) begin
		core_bankmachine3_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_49 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_50;
// synthesis translate_on
always @(*) begin
	core_bankmachine4_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 3'd4))) begin
		core_bankmachine4_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 3'd4))) begin
		core_bankmachine4_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_50 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_51;
// synthesis translate_on
always @(*) begin
	core_bankmachine5_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 3'd5))) begin
		core_bankmachine5_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 3'd5))) begin
		core_bankmachine5_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_51 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_52;
// synthesis translate_on
always @(*) begin
	core_bankmachine6_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 3'd6))) begin
		core_bankmachine6_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 3'd6))) begin
		core_bankmachine6_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_52 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_53;
// synthesis translate_on
always @(*) begin
	core_bankmachine7_cmd_ready <= 1'd0;
	if (((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & (core_choose_cmd_grant == 3'd7))) begin
		core_bankmachine7_cmd_ready <= 1'd1;
	end
	if (((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & (core_choose_req_grant == 3'd7))) begin
		core_bankmachine7_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_53 <= dummy_s;
// synthesis translate_on
end
assign core_choose_req_ce = (core_choose_req_cmd_ready | (~core_choose_req_cmd_valid));
assign core_dfi_p0_reset_n = 1'd1;
assign core_dfi_p0_cke = {1{core_steerer4}};
assign core_dfi_p0_odt = {1{core_steerer5}};
assign core_dfi_p1_reset_n = 1'd1;
assign core_dfi_p1_cke = {1{core_steerer6}};
assign core_dfi_p1_odt = {1{core_steerer7}};
assign core_dfi_p2_reset_n = 1'd1;
assign core_dfi_p2_cke = {1{core_steerer8}};
assign core_dfi_p2_odt = {1{core_steerer9}};
assign core_dfi_p3_reset_n = 1'd1;
assign core_dfi_p3_cke = {1{core_steerer10}};
assign core_dfi_p3_odt = {1{core_steerer11}};
assign core_tfawcon_count = (((core_tfawcon_window[0] + core_tfawcon_window[1]) + core_tfawcon_window[2]) + core_tfawcon_window[3]);

// synthesis translate_off
reg dummy_d_54;
// synthesis translate_on
always @(*) begin
	core_cmd_ready <= 1'd0;
	core_choose_cmd_want_activates <= 1'd0;
	core_choose_cmd_cmd_ready <= 1'd0;
	core_choose_req_want_reads <= 1'd0;
	core_choose_req_want_writes <= 1'd0;
	core_choose_req_cmd_ready <= 1'd0;
	core_steerer0 <= 2'd0;
	core_steerer1 <= 2'd0;
	core_steerer2 <= 2'd0;
	core_steerer3 <= 2'd0;
	core_en0 <= 1'd0;
	core_en1 <= 1'd0;
	multiplexer_next_state <= 4'd0;
	multiplexer_next_state <= multiplexer_state;
	case (multiplexer_state)
		1'd1: begin
			core_en1 <= 1'd1;
			core_choose_req_want_writes <= 1'd1;
			if (1'd0) begin
				core_choose_req_cmd_ready <= (core_cas_allowed & ((~((core_choose_req_cmd_payload_ras & (~core_choose_req_cmd_payload_cas)) & (~core_choose_req_cmd_payload_we))) | core_ras_allowed));
			end else begin
				core_choose_cmd_want_activates <= core_ras_allowed;
				core_choose_cmd_cmd_ready <= ((~((core_choose_cmd_cmd_payload_ras & (~core_choose_cmd_cmd_payload_cas)) & (~core_choose_cmd_cmd_payload_we))) | core_ras_allowed);
				core_choose_req_cmd_ready <= core_cas_allowed;
			end
			core_steerer0 <= 1'd0;
			if ((wrphase == 1'd0)) begin
				core_steerer0 <= 2'd2;
			end
			if ((core_rdphase == 1'd0)) begin
				core_steerer0 <= 1'd1;
			end
			core_steerer1 <= 1'd0;
			if ((wrphase == 1'd1)) begin
				core_steerer1 <= 2'd2;
			end
			if ((core_rdphase == 1'd1)) begin
				core_steerer1 <= 1'd1;
			end
			core_steerer2 <= 1'd0;
			if ((wrphase == 2'd2)) begin
				core_steerer2 <= 2'd2;
			end
			if ((core_rdphase == 2'd2)) begin
				core_steerer2 <= 1'd1;
			end
			core_steerer3 <= 1'd0;
			if ((wrphase == 2'd3)) begin
				core_steerer3 <= 2'd2;
			end
			if ((core_rdphase == 2'd3)) begin
				core_steerer3 <= 1'd1;
			end
			if (core_read_available) begin
				if (((~core_write_available) | core_max_time1)) begin
					multiplexer_next_state <= 2'd3;
				end
			end
			if (core_go_to_refresh) begin
				multiplexer_next_state <= 2'd2;
			end
		end
		2'd2: begin
			core_steerer0 <= 2'd3;
			core_cmd_ready <= 1'd1;
			if (core_cmd_last) begin
				multiplexer_next_state <= 1'd0;
			end
		end
		2'd3: begin
			if (core_twtrcon_ready) begin
				multiplexer_next_state <= 1'd0;
			end
		end
		3'd4: begin
			multiplexer_next_state <= 3'd5;
		end
		3'd5: begin
			multiplexer_next_state <= 3'd6;
		end
		3'd6: begin
			multiplexer_next_state <= 3'd7;
		end
		3'd7: begin
			multiplexer_next_state <= 4'd8;
		end
		4'd8: begin
			multiplexer_next_state <= 4'd9;
		end
		4'd9: begin
			multiplexer_next_state <= 4'd10;
		end
		4'd10: begin
			multiplexer_next_state <= 1'd1;
		end
		default: begin
			core_en0 <= 1'd1;
			core_choose_req_want_reads <= 1'd1;
			if (1'd0) begin
				core_choose_req_cmd_ready <= (core_cas_allowed & ((~((core_choose_req_cmd_payload_ras & (~core_choose_req_cmd_payload_cas)) & (~core_choose_req_cmd_payload_we))) | core_ras_allowed));
			end else begin
				core_choose_cmd_want_activates <= core_ras_allowed;
				core_choose_cmd_cmd_ready <= ((~((core_choose_cmd_cmd_payload_ras & (~core_choose_cmd_cmd_payload_cas)) & (~core_choose_cmd_cmd_payload_we))) | core_ras_allowed);
				core_choose_req_cmd_ready <= core_cas_allowed;
			end
			core_steerer0 <= 1'd0;
			if ((rdphase == 1'd0)) begin
				core_steerer0 <= 2'd2;
			end
			if ((core_nphases == 1'd0)) begin
				core_steerer0 <= 1'd1;
			end
			core_steerer1 <= 1'd0;
			if ((rdphase == 1'd1)) begin
				core_steerer1 <= 2'd2;
			end
			if ((core_nphases == 1'd1)) begin
				core_steerer1 <= 1'd1;
			end
			core_steerer2 <= 1'd0;
			if ((rdphase == 2'd2)) begin
				core_steerer2 <= 2'd2;
			end
			if ((core_nphases == 2'd2)) begin
				core_steerer2 <= 1'd1;
			end
			core_steerer3 <= 1'd0;
			if ((rdphase == 2'd3)) begin
				core_steerer3 <= 2'd2;
			end
			if ((core_nphases == 2'd3)) begin
				core_steerer3 <= 1'd1;
			end
			if (core_write_available) begin
				if (((~core_read_available) | core_max_time0)) begin
					multiplexer_next_state <= 3'd4;
				end
			end
			if (core_go_to_refresh) begin
				multiplexer_next_state <= 2'd2;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_54 <= dummy_s;
// synthesis translate_on
end
assign roundrobin0_request = {(((cmd_payload_addr[9:7] == 1'd0) & (~(((((((locked0 | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid)};
assign roundrobin0_ce = ((~core_interface_bank0_valid) & (~core_interface_bank0_lock));
assign core_interface_bank0_addr = rhs_self12;
assign core_interface_bank0_we = rhs_self13;
assign core_interface_bank0_valid = rhs_self14;
assign roundrobin1_request = {(((cmd_payload_addr[9:7] == 1'd1) & (~(((((((locked1 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid)};
assign roundrobin1_ce = ((~core_interface_bank1_valid) & (~core_interface_bank1_lock));
assign core_interface_bank1_addr = rhs_self15;
assign core_interface_bank1_we = rhs_self16;
assign core_interface_bank1_valid = rhs_self17;
assign roundrobin2_request = {(((cmd_payload_addr[9:7] == 2'd2) & (~(((((((locked2 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid)};
assign roundrobin2_ce = ((~core_interface_bank2_valid) & (~core_interface_bank2_lock));
assign core_interface_bank2_addr = rhs_self18;
assign core_interface_bank2_we = rhs_self19;
assign core_interface_bank2_valid = rhs_self20;
assign roundrobin3_request = {(((cmd_payload_addr[9:7] == 2'd3) & (~(((((((locked3 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid)};
assign roundrobin3_ce = ((~core_interface_bank3_valid) & (~core_interface_bank3_lock));
assign core_interface_bank3_addr = rhs_self21;
assign core_interface_bank3_we = rhs_self22;
assign core_interface_bank3_valid = rhs_self23;
assign roundrobin4_request = {(((cmd_payload_addr[9:7] == 3'd4) & (~(((((((locked4 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid)};
assign roundrobin4_ce = ((~core_interface_bank4_valid) & (~core_interface_bank4_lock));
assign core_interface_bank4_addr = rhs_self24;
assign core_interface_bank4_we = rhs_self25;
assign core_interface_bank4_valid = rhs_self26;
assign roundrobin5_request = {(((cmd_payload_addr[9:7] == 3'd5) & (~(((((((locked5 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid)};
assign roundrobin5_ce = ((~core_interface_bank5_valid) & (~core_interface_bank5_lock));
assign core_interface_bank5_addr = rhs_self27;
assign core_interface_bank5_we = rhs_self28;
assign core_interface_bank5_valid = rhs_self29;
assign roundrobin6_request = {(((cmd_payload_addr[9:7] == 3'd6) & (~(((((((locked6 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid)};
assign roundrobin6_ce = ((~core_interface_bank6_valid) & (~core_interface_bank6_lock));
assign core_interface_bank6_addr = rhs_self30;
assign core_interface_bank6_we = rhs_self31;
assign core_interface_bank6_valid = rhs_self32;
assign roundrobin7_request = {(((cmd_payload_addr[9:7] == 3'd7) & (~(((((((locked7 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))))) & cmd_valid)};
assign roundrobin7_ce = ((~core_interface_bank7_valid) & (~core_interface_bank7_lock));
assign core_interface_bank7_addr = rhs_self33;
assign core_interface_bank7_we = rhs_self34;
assign core_interface_bank7_valid = rhs_self35;
assign cmd_ready = ((((((((1'd0 | (((roundrobin0_grant == 1'd0) & ((cmd_payload_addr[9:7] == 1'd0) & (~(((((((locked0 | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0)))))) & core_interface_bank0_ready)) | (((roundrobin1_grant == 1'd0) & ((cmd_payload_addr[9:7] == 1'd1) & (~(((((((locked1 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0)))))) & core_interface_bank1_ready)) | (((roundrobin2_grant == 1'd0) & ((cmd_payload_addr[9:7] == 2'd2) & (~(((((((locked2 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0)))))) & core_interface_bank2_ready)) | (((roundrobin3_grant == 1'd0) & ((cmd_payload_addr[9:7] == 2'd3) & (~(((((((locked3 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0)))))) & core_interface_bank3_ready)) | (((roundrobin4_grant == 1'd0) & ((cmd_payload_addr[9:7] == 3'd4) & (~(((((((locked4 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0)))))) & core_interface_bank4_ready)) | (((roundrobin5_grant == 1'd0) & ((cmd_payload_addr[9:7] == 3'd5) & (~(((((((locked5 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0)))))) & core_interface_bank5_ready)) | (((roundrobin6_grant == 1'd0) & ((cmd_payload_addr[9:7] == 3'd6) & (~(((((((locked6 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0)))))) & core_interface_bank6_ready)) | (((roundrobin7_grant == 1'd0) & ((cmd_payload_addr[9:7] == 3'd7) & (~(((((((locked7 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0)))))) & core_interface_bank7_ready));
assign wdata_ready = new_master_wdata_ready1;
assign rdata_valid = new_master_rdata_valid8;

// synthesis translate_off
reg dummy_d_55;
// synthesis translate_on
always @(*) begin
	core_interface_wdata <= 256'd0;
	core_interface_wdata_we <= 32'd0;
	case ({new_master_wdata_ready1})
		1'd1: begin
			core_interface_wdata <= wdata_payload_data;
			core_interface_wdata_we <= wdata_payload_we;
		end
		default: begin
			core_interface_wdata <= 1'd0;
			core_interface_wdata_we <= 1'd0;
		end
	endcase
// synthesis translate_off
	dummy_d_55 <= dummy_s;
// synthesis translate_on
end
assign rdata_payload_data = core_interface_rdata;
assign roundrobin0_grant = 1'd0;
assign roundrobin1_grant = 1'd0;
assign roundrobin2_grant = 1'd0;
assign roundrobin3_grant = 1'd0;
assign roundrobin4_grant = 1'd0;
assign roundrobin5_grant = 1'd0;
assign roundrobin6_grant = 1'd0;
assign roundrobin7_grant = 1'd0;

// synthesis translate_off
reg dummy_d_56;
// synthesis translate_on
always @(*) begin
	rhs_self0 <= 1'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			rhs_self0 <= core_choose_cmd_valids[0];
		end
		1'd1: begin
			rhs_self0 <= core_choose_cmd_valids[1];
		end
		2'd2: begin
			rhs_self0 <= core_choose_cmd_valids[2];
		end
		2'd3: begin
			rhs_self0 <= core_choose_cmd_valids[3];
		end
		3'd4: begin
			rhs_self0 <= core_choose_cmd_valids[4];
		end
		3'd5: begin
			rhs_self0 <= core_choose_cmd_valids[5];
		end
		3'd6: begin
			rhs_self0 <= core_choose_cmd_valids[6];
		end
		default: begin
			rhs_self0 <= core_choose_cmd_valids[7];
		end
	endcase
// synthesis translate_off
	dummy_d_56 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_57;
// synthesis translate_on
always @(*) begin
	rhs_self1 <= 15'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			rhs_self1 <= core_bankmachine0_cmd_payload_a;
		end
		1'd1: begin
			rhs_self1 <= core_bankmachine1_cmd_payload_a;
		end
		2'd2: begin
			rhs_self1 <= core_bankmachine2_cmd_payload_a;
		end
		2'd3: begin
			rhs_self1 <= core_bankmachine3_cmd_payload_a;
		end
		3'd4: begin
			rhs_self1 <= core_bankmachine4_cmd_payload_a;
		end
		3'd5: begin
			rhs_self1 <= core_bankmachine5_cmd_payload_a;
		end
		3'd6: begin
			rhs_self1 <= core_bankmachine6_cmd_payload_a;
		end
		default: begin
			rhs_self1 <= core_bankmachine7_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_57 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_58;
// synthesis translate_on
always @(*) begin
	rhs_self2 <= 3'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			rhs_self2 <= core_bankmachine0_cmd_payload_ba;
		end
		1'd1: begin
			rhs_self2 <= core_bankmachine1_cmd_payload_ba;
		end
		2'd2: begin
			rhs_self2 <= core_bankmachine2_cmd_payload_ba;
		end
		2'd3: begin
			rhs_self2 <= core_bankmachine3_cmd_payload_ba;
		end
		3'd4: begin
			rhs_self2 <= core_bankmachine4_cmd_payload_ba;
		end
		3'd5: begin
			rhs_self2 <= core_bankmachine5_cmd_payload_ba;
		end
		3'd6: begin
			rhs_self2 <= core_bankmachine6_cmd_payload_ba;
		end
		default: begin
			rhs_self2 <= core_bankmachine7_cmd_payload_ba;
		end
	endcase
// synthesis translate_off
	dummy_d_58 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_59;
// synthesis translate_on
always @(*) begin
	rhs_self3 <= 1'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			rhs_self3 <= core_bankmachine0_cmd_payload_is_read;
		end
		1'd1: begin
			rhs_self3 <= core_bankmachine1_cmd_payload_is_read;
		end
		2'd2: begin
			rhs_self3 <= core_bankmachine2_cmd_payload_is_read;
		end
		2'd3: begin
			rhs_self3 <= core_bankmachine3_cmd_payload_is_read;
		end
		3'd4: begin
			rhs_self3 <= core_bankmachine4_cmd_payload_is_read;
		end
		3'd5: begin
			rhs_self3 <= core_bankmachine5_cmd_payload_is_read;
		end
		3'd6: begin
			rhs_self3 <= core_bankmachine6_cmd_payload_is_read;
		end
		default: begin
			rhs_self3 <= core_bankmachine7_cmd_payload_is_read;
		end
	endcase
// synthesis translate_off
	dummy_d_59 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_60;
// synthesis translate_on
always @(*) begin
	rhs_self4 <= 1'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			rhs_self4 <= core_bankmachine0_cmd_payload_is_write;
		end
		1'd1: begin
			rhs_self4 <= core_bankmachine1_cmd_payload_is_write;
		end
		2'd2: begin
			rhs_self4 <= core_bankmachine2_cmd_payload_is_write;
		end
		2'd3: begin
			rhs_self4 <= core_bankmachine3_cmd_payload_is_write;
		end
		3'd4: begin
			rhs_self4 <= core_bankmachine4_cmd_payload_is_write;
		end
		3'd5: begin
			rhs_self4 <= core_bankmachine5_cmd_payload_is_write;
		end
		3'd6: begin
			rhs_self4 <= core_bankmachine6_cmd_payload_is_write;
		end
		default: begin
			rhs_self4 <= core_bankmachine7_cmd_payload_is_write;
		end
	endcase
// synthesis translate_off
	dummy_d_60 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_61;
// synthesis translate_on
always @(*) begin
	rhs_self5 <= 1'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			rhs_self5 <= core_bankmachine0_cmd_payload_is_cmd;
		end
		1'd1: begin
			rhs_self5 <= core_bankmachine1_cmd_payload_is_cmd;
		end
		2'd2: begin
			rhs_self5 <= core_bankmachine2_cmd_payload_is_cmd;
		end
		2'd3: begin
			rhs_self5 <= core_bankmachine3_cmd_payload_is_cmd;
		end
		3'd4: begin
			rhs_self5 <= core_bankmachine4_cmd_payload_is_cmd;
		end
		3'd5: begin
			rhs_self5 <= core_bankmachine5_cmd_payload_is_cmd;
		end
		3'd6: begin
			rhs_self5 <= core_bankmachine6_cmd_payload_is_cmd;
		end
		default: begin
			rhs_self5 <= core_bankmachine7_cmd_payload_is_cmd;
		end
	endcase
// synthesis translate_off
	dummy_d_61 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_62;
// synthesis translate_on
always @(*) begin
	t_self0 <= 1'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			t_self0 <= core_bankmachine0_cmd_payload_cas;
		end
		1'd1: begin
			t_self0 <= core_bankmachine1_cmd_payload_cas;
		end
		2'd2: begin
			t_self0 <= core_bankmachine2_cmd_payload_cas;
		end
		2'd3: begin
			t_self0 <= core_bankmachine3_cmd_payload_cas;
		end
		3'd4: begin
			t_self0 <= core_bankmachine4_cmd_payload_cas;
		end
		3'd5: begin
			t_self0 <= core_bankmachine5_cmd_payload_cas;
		end
		3'd6: begin
			t_self0 <= core_bankmachine6_cmd_payload_cas;
		end
		default: begin
			t_self0 <= core_bankmachine7_cmd_payload_cas;
		end
	endcase
// synthesis translate_off
	dummy_d_62 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_63;
// synthesis translate_on
always @(*) begin
	t_self1 <= 1'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			t_self1 <= core_bankmachine0_cmd_payload_ras;
		end
		1'd1: begin
			t_self1 <= core_bankmachine1_cmd_payload_ras;
		end
		2'd2: begin
			t_self1 <= core_bankmachine2_cmd_payload_ras;
		end
		2'd3: begin
			t_self1 <= core_bankmachine3_cmd_payload_ras;
		end
		3'd4: begin
			t_self1 <= core_bankmachine4_cmd_payload_ras;
		end
		3'd5: begin
			t_self1 <= core_bankmachine5_cmd_payload_ras;
		end
		3'd6: begin
			t_self1 <= core_bankmachine6_cmd_payload_ras;
		end
		default: begin
			t_self1 <= core_bankmachine7_cmd_payload_ras;
		end
	endcase
// synthesis translate_off
	dummy_d_63 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_64;
// synthesis translate_on
always @(*) begin
	t_self2 <= 1'd0;
	case (core_choose_cmd_grant)
		1'd0: begin
			t_self2 <= core_bankmachine0_cmd_payload_we;
		end
		1'd1: begin
			t_self2 <= core_bankmachine1_cmd_payload_we;
		end
		2'd2: begin
			t_self2 <= core_bankmachine2_cmd_payload_we;
		end
		2'd3: begin
			t_self2 <= core_bankmachine3_cmd_payload_we;
		end
		3'd4: begin
			t_self2 <= core_bankmachine4_cmd_payload_we;
		end
		3'd5: begin
			t_self2 <= core_bankmachine5_cmd_payload_we;
		end
		3'd6: begin
			t_self2 <= core_bankmachine6_cmd_payload_we;
		end
		default: begin
			t_self2 <= core_bankmachine7_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_64 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_65;
// synthesis translate_on
always @(*) begin
	rhs_self6 <= 1'd0;
	case (core_choose_req_grant)
		1'd0: begin
			rhs_self6 <= core_choose_req_valids[0];
		end
		1'd1: begin
			rhs_self6 <= core_choose_req_valids[1];
		end
		2'd2: begin
			rhs_self6 <= core_choose_req_valids[2];
		end
		2'd3: begin
			rhs_self6 <= core_choose_req_valids[3];
		end
		3'd4: begin
			rhs_self6 <= core_choose_req_valids[4];
		end
		3'd5: begin
			rhs_self6 <= core_choose_req_valids[5];
		end
		3'd6: begin
			rhs_self6 <= core_choose_req_valids[6];
		end
		default: begin
			rhs_self6 <= core_choose_req_valids[7];
		end
	endcase
// synthesis translate_off
	dummy_d_65 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_66;
// synthesis translate_on
always @(*) begin
	rhs_self7 <= 15'd0;
	case (core_choose_req_grant)
		1'd0: begin
			rhs_self7 <= core_bankmachine0_cmd_payload_a;
		end
		1'd1: begin
			rhs_self7 <= core_bankmachine1_cmd_payload_a;
		end
		2'd2: begin
			rhs_self7 <= core_bankmachine2_cmd_payload_a;
		end
		2'd3: begin
			rhs_self7 <= core_bankmachine3_cmd_payload_a;
		end
		3'd4: begin
			rhs_self7 <= core_bankmachine4_cmd_payload_a;
		end
		3'd5: begin
			rhs_self7 <= core_bankmachine5_cmd_payload_a;
		end
		3'd6: begin
			rhs_self7 <= core_bankmachine6_cmd_payload_a;
		end
		default: begin
			rhs_self7 <= core_bankmachine7_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_66 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_67;
// synthesis translate_on
always @(*) begin
	rhs_self8 <= 3'd0;
	case (core_choose_req_grant)
		1'd0: begin
			rhs_self8 <= core_bankmachine0_cmd_payload_ba;
		end
		1'd1: begin
			rhs_self8 <= core_bankmachine1_cmd_payload_ba;
		end
		2'd2: begin
			rhs_self8 <= core_bankmachine2_cmd_payload_ba;
		end
		2'd3: begin
			rhs_self8 <= core_bankmachine3_cmd_payload_ba;
		end
		3'd4: begin
			rhs_self8 <= core_bankmachine4_cmd_payload_ba;
		end
		3'd5: begin
			rhs_self8 <= core_bankmachine5_cmd_payload_ba;
		end
		3'd6: begin
			rhs_self8 <= core_bankmachine6_cmd_payload_ba;
		end
		default: begin
			rhs_self8 <= core_bankmachine7_cmd_payload_ba;
		end
	endcase
// synthesis translate_off
	dummy_d_67 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_68;
// synthesis translate_on
always @(*) begin
	rhs_self9 <= 1'd0;
	case (core_choose_req_grant)
		1'd0: begin
			rhs_self9 <= core_bankmachine0_cmd_payload_is_read;
		end
		1'd1: begin
			rhs_self9 <= core_bankmachine1_cmd_payload_is_read;
		end
		2'd2: begin
			rhs_self9 <= core_bankmachine2_cmd_payload_is_read;
		end
		2'd3: begin
			rhs_self9 <= core_bankmachine3_cmd_payload_is_read;
		end
		3'd4: begin
			rhs_self9 <= core_bankmachine4_cmd_payload_is_read;
		end
		3'd5: begin
			rhs_self9 <= core_bankmachine5_cmd_payload_is_read;
		end
		3'd6: begin
			rhs_self9 <= core_bankmachine6_cmd_payload_is_read;
		end
		default: begin
			rhs_self9 <= core_bankmachine7_cmd_payload_is_read;
		end
	endcase
// synthesis translate_off
	dummy_d_68 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_69;
// synthesis translate_on
always @(*) begin
	rhs_self10 <= 1'd0;
	case (core_choose_req_grant)
		1'd0: begin
			rhs_self10 <= core_bankmachine0_cmd_payload_is_write;
		end
		1'd1: begin
			rhs_self10 <= core_bankmachine1_cmd_payload_is_write;
		end
		2'd2: begin
			rhs_self10 <= core_bankmachine2_cmd_payload_is_write;
		end
		2'd3: begin
			rhs_self10 <= core_bankmachine3_cmd_payload_is_write;
		end
		3'd4: begin
			rhs_self10 <= core_bankmachine4_cmd_payload_is_write;
		end
		3'd5: begin
			rhs_self10 <= core_bankmachine5_cmd_payload_is_write;
		end
		3'd6: begin
			rhs_self10 <= core_bankmachine6_cmd_payload_is_write;
		end
		default: begin
			rhs_self10 <= core_bankmachine7_cmd_payload_is_write;
		end
	endcase
// synthesis translate_off
	dummy_d_69 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_70;
// synthesis translate_on
always @(*) begin
	rhs_self11 <= 1'd0;
	case (core_choose_req_grant)
		1'd0: begin
			rhs_self11 <= core_bankmachine0_cmd_payload_is_cmd;
		end
		1'd1: begin
			rhs_self11 <= core_bankmachine1_cmd_payload_is_cmd;
		end
		2'd2: begin
			rhs_self11 <= core_bankmachine2_cmd_payload_is_cmd;
		end
		2'd3: begin
			rhs_self11 <= core_bankmachine3_cmd_payload_is_cmd;
		end
		3'd4: begin
			rhs_self11 <= core_bankmachine4_cmd_payload_is_cmd;
		end
		3'd5: begin
			rhs_self11 <= core_bankmachine5_cmd_payload_is_cmd;
		end
		3'd6: begin
			rhs_self11 <= core_bankmachine6_cmd_payload_is_cmd;
		end
		default: begin
			rhs_self11 <= core_bankmachine7_cmd_payload_is_cmd;
		end
	endcase
// synthesis translate_off
	dummy_d_70 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_71;
// synthesis translate_on
always @(*) begin
	t_self3 <= 1'd0;
	case (core_choose_req_grant)
		1'd0: begin
			t_self3 <= core_bankmachine0_cmd_payload_cas;
		end
		1'd1: begin
			t_self3 <= core_bankmachine1_cmd_payload_cas;
		end
		2'd2: begin
			t_self3 <= core_bankmachine2_cmd_payload_cas;
		end
		2'd3: begin
			t_self3 <= core_bankmachine3_cmd_payload_cas;
		end
		3'd4: begin
			t_self3 <= core_bankmachine4_cmd_payload_cas;
		end
		3'd5: begin
			t_self3 <= core_bankmachine5_cmd_payload_cas;
		end
		3'd6: begin
			t_self3 <= core_bankmachine6_cmd_payload_cas;
		end
		default: begin
			t_self3 <= core_bankmachine7_cmd_payload_cas;
		end
	endcase
// synthesis translate_off
	dummy_d_71 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_72;
// synthesis translate_on
always @(*) begin
	t_self4 <= 1'd0;
	case (core_choose_req_grant)
		1'd0: begin
			t_self4 <= core_bankmachine0_cmd_payload_ras;
		end
		1'd1: begin
			t_self4 <= core_bankmachine1_cmd_payload_ras;
		end
		2'd2: begin
			t_self4 <= core_bankmachine2_cmd_payload_ras;
		end
		2'd3: begin
			t_self4 <= core_bankmachine3_cmd_payload_ras;
		end
		3'd4: begin
			t_self4 <= core_bankmachine4_cmd_payload_ras;
		end
		3'd5: begin
			t_self4 <= core_bankmachine5_cmd_payload_ras;
		end
		3'd6: begin
			t_self4 <= core_bankmachine6_cmd_payload_ras;
		end
		default: begin
			t_self4 <= core_bankmachine7_cmd_payload_ras;
		end
	endcase
// synthesis translate_off
	dummy_d_72 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_73;
// synthesis translate_on
always @(*) begin
	t_self5 <= 1'd0;
	case (core_choose_req_grant)
		1'd0: begin
			t_self5 <= core_bankmachine0_cmd_payload_we;
		end
		1'd1: begin
			t_self5 <= core_bankmachine1_cmd_payload_we;
		end
		2'd2: begin
			t_self5 <= core_bankmachine2_cmd_payload_we;
		end
		2'd3: begin
			t_self5 <= core_bankmachine3_cmd_payload_we;
		end
		3'd4: begin
			t_self5 <= core_bankmachine4_cmd_payload_we;
		end
		3'd5: begin
			t_self5 <= core_bankmachine5_cmd_payload_we;
		end
		3'd6: begin
			t_self5 <= core_bankmachine6_cmd_payload_we;
		end
		default: begin
			t_self5 <= core_bankmachine7_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_73 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_74;
// synthesis translate_on
always @(*) begin
	rhs_self12 <= 22'd0;
	case (roundrobin0_grant)
		default: begin
			rhs_self12 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_74 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_75;
// synthesis translate_on
always @(*) begin
	rhs_self13 <= 1'd0;
	case (roundrobin0_grant)
		default: begin
			rhs_self13 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_75 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_76;
// synthesis translate_on
always @(*) begin
	rhs_self14 <= 1'd0;
	case (roundrobin0_grant)
		default: begin
			rhs_self14 <= (((cmd_payload_addr[9:7] == 1'd0) & (~(((((((locked0 | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_76 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_77;
// synthesis translate_on
always @(*) begin
	rhs_self15 <= 22'd0;
	case (roundrobin1_grant)
		default: begin
			rhs_self15 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_77 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_78;
// synthesis translate_on
always @(*) begin
	rhs_self16 <= 1'd0;
	case (roundrobin1_grant)
		default: begin
			rhs_self16 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_78 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_79;
// synthesis translate_on
always @(*) begin
	rhs_self17 <= 1'd0;
	case (roundrobin1_grant)
		default: begin
			rhs_self17 <= (((cmd_payload_addr[9:7] == 1'd1) & (~(((((((locked1 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_79 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_80;
// synthesis translate_on
always @(*) begin
	rhs_self18 <= 22'd0;
	case (roundrobin2_grant)
		default: begin
			rhs_self18 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_80 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_81;
// synthesis translate_on
always @(*) begin
	rhs_self19 <= 1'd0;
	case (roundrobin2_grant)
		default: begin
			rhs_self19 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_81 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_82;
// synthesis translate_on
always @(*) begin
	rhs_self20 <= 1'd0;
	case (roundrobin2_grant)
		default: begin
			rhs_self20 <= (((cmd_payload_addr[9:7] == 2'd2) & (~(((((((locked2 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_82 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_83;
// synthesis translate_on
always @(*) begin
	rhs_self21 <= 22'd0;
	case (roundrobin3_grant)
		default: begin
			rhs_self21 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_83 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_84;
// synthesis translate_on
always @(*) begin
	rhs_self22 <= 1'd0;
	case (roundrobin3_grant)
		default: begin
			rhs_self22 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_84 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_85;
// synthesis translate_on
always @(*) begin
	rhs_self23 <= 1'd0;
	case (roundrobin3_grant)
		default: begin
			rhs_self23 <= (((cmd_payload_addr[9:7] == 2'd3) & (~(((((((locked3 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_85 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_86;
// synthesis translate_on
always @(*) begin
	rhs_self24 <= 22'd0;
	case (roundrobin4_grant)
		default: begin
			rhs_self24 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_86 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_87;
// synthesis translate_on
always @(*) begin
	rhs_self25 <= 1'd0;
	case (roundrobin4_grant)
		default: begin
			rhs_self25 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_87 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_88;
// synthesis translate_on
always @(*) begin
	rhs_self26 <= 1'd0;
	case (roundrobin4_grant)
		default: begin
			rhs_self26 <= (((cmd_payload_addr[9:7] == 3'd4) & (~(((((((locked4 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_88 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_89;
// synthesis translate_on
always @(*) begin
	rhs_self27 <= 22'd0;
	case (roundrobin5_grant)
		default: begin
			rhs_self27 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_89 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_90;
// synthesis translate_on
always @(*) begin
	rhs_self28 <= 1'd0;
	case (roundrobin5_grant)
		default: begin
			rhs_self28 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_90 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_91;
// synthesis translate_on
always @(*) begin
	rhs_self29 <= 1'd0;
	case (roundrobin5_grant)
		default: begin
			rhs_self29 <= (((cmd_payload_addr[9:7] == 3'd5) & (~(((((((locked5 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_91 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_92;
// synthesis translate_on
always @(*) begin
	rhs_self30 <= 22'd0;
	case (roundrobin6_grant)
		default: begin
			rhs_self30 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_92 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_93;
// synthesis translate_on
always @(*) begin
	rhs_self31 <= 1'd0;
	case (roundrobin6_grant)
		default: begin
			rhs_self31 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_93 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_94;
// synthesis translate_on
always @(*) begin
	rhs_self32 <= 1'd0;
	case (roundrobin6_grant)
		default: begin
			rhs_self32 <= (((cmd_payload_addr[9:7] == 3'd6) & (~(((((((locked6 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank7_lock & (roundrobin7_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_94 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_95;
// synthesis translate_on
always @(*) begin
	rhs_self33 <= 22'd0;
	case (roundrobin7_grant)
		default: begin
			rhs_self33 <= {cmd_payload_addr[24:10], cmd_payload_addr[6:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_95 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_96;
// synthesis translate_on
always @(*) begin
	rhs_self34 <= 1'd0;
	case (roundrobin7_grant)
		default: begin
			rhs_self34 <= cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_96 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_97;
// synthesis translate_on
always @(*) begin
	rhs_self35 <= 1'd0;
	case (roundrobin7_grant)
		default: begin
			rhs_self35 <= (((cmd_payload_addr[9:7] == 3'd7) & (~(((((((locked7 | (core_interface_bank0_lock & (roundrobin0_grant == 1'd0))) | (core_interface_bank1_lock & (roundrobin1_grant == 1'd0))) | (core_interface_bank2_lock & (roundrobin2_grant == 1'd0))) | (core_interface_bank3_lock & (roundrobin3_grant == 1'd0))) | (core_interface_bank4_lock & (roundrobin4_grant == 1'd0))) | (core_interface_bank5_lock & (roundrobin5_grant == 1'd0))) | (core_interface_bank6_lock & (roundrobin6_grant == 1'd0))))) & cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_97 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_98;
// synthesis translate_on
always @(*) begin
	self0 <= 3'd0;
	case (core_steerer0)
		1'd0: begin
			self0 <= core_nop_ba[2:0];
		end
		1'd1: begin
			self0 <= core_choose_cmd_cmd_payload_ba[2:0];
		end
		2'd2: begin
			self0 <= core_choose_req_cmd_payload_ba[2:0];
		end
		default: begin
			self0 <= core_cmd_payload_ba[2:0];
		end
	endcase
// synthesis translate_off
	dummy_d_98 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_99;
// synthesis translate_on
always @(*) begin
	self1 <= 15'd0;
	case (core_steerer0)
		1'd0: begin
			self1 <= core_nop_a;
		end
		1'd1: begin
			self1 <= core_choose_cmd_cmd_payload_a;
		end
		2'd2: begin
			self1 <= core_choose_req_cmd_payload_a;
		end
		default: begin
			self1 <= core_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_99 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_100;
// synthesis translate_on
always @(*) begin
	self2 <= 1'd0;
	case (core_steerer0)
		1'd0: begin
			self2 <= 1'd0;
		end
		1'd1: begin
			self2 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_cas);
		end
		2'd2: begin
			self2 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_cas);
		end
		default: begin
			self2 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_cas);
		end
	endcase
// synthesis translate_off
	dummy_d_100 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_101;
// synthesis translate_on
always @(*) begin
	self3 <= 1'd0;
	case (core_steerer0)
		1'd0: begin
			self3 <= 1'd0;
		end
		1'd1: begin
			self3 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_ras);
		end
		2'd2: begin
			self3 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_ras);
		end
		default: begin
			self3 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_ras);
		end
	endcase
// synthesis translate_off
	dummy_d_101 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_102;
// synthesis translate_on
always @(*) begin
	self4 <= 1'd0;
	case (core_steerer0)
		1'd0: begin
			self4 <= 1'd0;
		end
		1'd1: begin
			self4 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_we);
		end
		2'd2: begin
			self4 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_we);
		end
		default: begin
			self4 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_we);
		end
	endcase
// synthesis translate_off
	dummy_d_102 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_103;
// synthesis translate_on
always @(*) begin
	self5 <= 1'd0;
	case (core_steerer0)
		1'd0: begin
			self5 <= 1'd0;
		end
		1'd1: begin
			self5 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_read);
		end
		2'd2: begin
			self5 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_read);
		end
		default: begin
			self5 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_read);
		end
	endcase
// synthesis translate_off
	dummy_d_103 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_104;
// synthesis translate_on
always @(*) begin
	self6 <= 1'd0;
	case (core_steerer0)
		1'd0: begin
			self6 <= 1'd0;
		end
		1'd1: begin
			self6 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_write);
		end
		2'd2: begin
			self6 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_write);
		end
		default: begin
			self6 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_write);
		end
	endcase
// synthesis translate_off
	dummy_d_104 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_105;
// synthesis translate_on
always @(*) begin
	self7 <= 3'd0;
	case (core_steerer1)
		1'd0: begin
			self7 <= core_nop_ba[2:0];
		end
		1'd1: begin
			self7 <= core_choose_cmd_cmd_payload_ba[2:0];
		end
		2'd2: begin
			self7 <= core_choose_req_cmd_payload_ba[2:0];
		end
		default: begin
			self7 <= core_cmd_payload_ba[2:0];
		end
	endcase
// synthesis translate_off
	dummy_d_105 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_106;
// synthesis translate_on
always @(*) begin
	self8 <= 15'd0;
	case (core_steerer1)
		1'd0: begin
			self8 <= core_nop_a;
		end
		1'd1: begin
			self8 <= core_choose_cmd_cmd_payload_a;
		end
		2'd2: begin
			self8 <= core_choose_req_cmd_payload_a;
		end
		default: begin
			self8 <= core_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_106 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_107;
// synthesis translate_on
always @(*) begin
	self9 <= 1'd0;
	case (core_steerer1)
		1'd0: begin
			self9 <= 1'd0;
		end
		1'd1: begin
			self9 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_cas);
		end
		2'd2: begin
			self9 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_cas);
		end
		default: begin
			self9 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_cas);
		end
	endcase
// synthesis translate_off
	dummy_d_107 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_108;
// synthesis translate_on
always @(*) begin
	self10 <= 1'd0;
	case (core_steerer1)
		1'd0: begin
			self10 <= 1'd0;
		end
		1'd1: begin
			self10 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_ras);
		end
		2'd2: begin
			self10 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_ras);
		end
		default: begin
			self10 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_ras);
		end
	endcase
// synthesis translate_off
	dummy_d_108 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_109;
// synthesis translate_on
always @(*) begin
	self11 <= 1'd0;
	case (core_steerer1)
		1'd0: begin
			self11 <= 1'd0;
		end
		1'd1: begin
			self11 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_we);
		end
		2'd2: begin
			self11 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_we);
		end
		default: begin
			self11 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_we);
		end
	endcase
// synthesis translate_off
	dummy_d_109 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_110;
// synthesis translate_on
always @(*) begin
	self12 <= 1'd0;
	case (core_steerer1)
		1'd0: begin
			self12 <= 1'd0;
		end
		1'd1: begin
			self12 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_read);
		end
		2'd2: begin
			self12 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_read);
		end
		default: begin
			self12 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_read);
		end
	endcase
// synthesis translate_off
	dummy_d_110 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_111;
// synthesis translate_on
always @(*) begin
	self13 <= 1'd0;
	case (core_steerer1)
		1'd0: begin
			self13 <= 1'd0;
		end
		1'd1: begin
			self13 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_write);
		end
		2'd2: begin
			self13 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_write);
		end
		default: begin
			self13 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_write);
		end
	endcase
// synthesis translate_off
	dummy_d_111 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_112;
// synthesis translate_on
always @(*) begin
	self14 <= 3'd0;
	case (core_steerer2)
		1'd0: begin
			self14 <= core_nop_ba[2:0];
		end
		1'd1: begin
			self14 <= core_choose_cmd_cmd_payload_ba[2:0];
		end
		2'd2: begin
			self14 <= core_choose_req_cmd_payload_ba[2:0];
		end
		default: begin
			self14 <= core_cmd_payload_ba[2:0];
		end
	endcase
// synthesis translate_off
	dummy_d_112 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_113;
// synthesis translate_on
always @(*) begin
	self15 <= 15'd0;
	case (core_steerer2)
		1'd0: begin
			self15 <= core_nop_a;
		end
		1'd1: begin
			self15 <= core_choose_cmd_cmd_payload_a;
		end
		2'd2: begin
			self15 <= core_choose_req_cmd_payload_a;
		end
		default: begin
			self15 <= core_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_113 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_114;
// synthesis translate_on
always @(*) begin
	self16 <= 1'd0;
	case (core_steerer2)
		1'd0: begin
			self16 <= 1'd0;
		end
		1'd1: begin
			self16 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_cas);
		end
		2'd2: begin
			self16 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_cas);
		end
		default: begin
			self16 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_cas);
		end
	endcase
// synthesis translate_off
	dummy_d_114 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_115;
// synthesis translate_on
always @(*) begin
	self17 <= 1'd0;
	case (core_steerer2)
		1'd0: begin
			self17 <= 1'd0;
		end
		1'd1: begin
			self17 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_ras);
		end
		2'd2: begin
			self17 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_ras);
		end
		default: begin
			self17 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_ras);
		end
	endcase
// synthesis translate_off
	dummy_d_115 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_116;
// synthesis translate_on
always @(*) begin
	self18 <= 1'd0;
	case (core_steerer2)
		1'd0: begin
			self18 <= 1'd0;
		end
		1'd1: begin
			self18 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_we);
		end
		2'd2: begin
			self18 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_we);
		end
		default: begin
			self18 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_we);
		end
	endcase
// synthesis translate_off
	dummy_d_116 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_117;
// synthesis translate_on
always @(*) begin
	self19 <= 1'd0;
	case (core_steerer2)
		1'd0: begin
			self19 <= 1'd0;
		end
		1'd1: begin
			self19 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_read);
		end
		2'd2: begin
			self19 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_read);
		end
		default: begin
			self19 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_read);
		end
	endcase
// synthesis translate_off
	dummy_d_117 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_118;
// synthesis translate_on
always @(*) begin
	self20 <= 1'd0;
	case (core_steerer2)
		1'd0: begin
			self20 <= 1'd0;
		end
		1'd1: begin
			self20 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_write);
		end
		2'd2: begin
			self20 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_write);
		end
		default: begin
			self20 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_write);
		end
	endcase
// synthesis translate_off
	dummy_d_118 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_119;
// synthesis translate_on
always @(*) begin
	self21 <= 3'd0;
	case (core_steerer3)
		1'd0: begin
			self21 <= core_nop_ba[2:0];
		end
		1'd1: begin
			self21 <= core_choose_cmd_cmd_payload_ba[2:0];
		end
		2'd2: begin
			self21 <= core_choose_req_cmd_payload_ba[2:0];
		end
		default: begin
			self21 <= core_cmd_payload_ba[2:0];
		end
	endcase
// synthesis translate_off
	dummy_d_119 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_120;
// synthesis translate_on
always @(*) begin
	self22 <= 15'd0;
	case (core_steerer3)
		1'd0: begin
			self22 <= core_nop_a;
		end
		1'd1: begin
			self22 <= core_choose_cmd_cmd_payload_a;
		end
		2'd2: begin
			self22 <= core_choose_req_cmd_payload_a;
		end
		default: begin
			self22 <= core_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_120 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_121;
// synthesis translate_on
always @(*) begin
	self23 <= 1'd0;
	case (core_steerer3)
		1'd0: begin
			self23 <= 1'd0;
		end
		1'd1: begin
			self23 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_cas);
		end
		2'd2: begin
			self23 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_cas);
		end
		default: begin
			self23 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_cas);
		end
	endcase
// synthesis translate_off
	dummy_d_121 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_122;
// synthesis translate_on
always @(*) begin
	self24 <= 1'd0;
	case (core_steerer3)
		1'd0: begin
			self24 <= 1'd0;
		end
		1'd1: begin
			self24 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_ras);
		end
		2'd2: begin
			self24 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_ras);
		end
		default: begin
			self24 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_ras);
		end
	endcase
// synthesis translate_off
	dummy_d_122 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_123;
// synthesis translate_on
always @(*) begin
	self25 <= 1'd0;
	case (core_steerer3)
		1'd0: begin
			self25 <= 1'd0;
		end
		1'd1: begin
			self25 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_we);
		end
		2'd2: begin
			self25 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_we);
		end
		default: begin
			self25 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_we);
		end
	endcase
// synthesis translate_off
	dummy_d_123 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_124;
// synthesis translate_on
always @(*) begin
	self26 <= 1'd0;
	case (core_steerer3)
		1'd0: begin
			self26 <= 1'd0;
		end
		1'd1: begin
			self26 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_read);
		end
		2'd2: begin
			self26 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_read);
		end
		default: begin
			self26 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_read);
		end
	endcase
// synthesis translate_off
	dummy_d_124 <= dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_125;
// synthesis translate_on
always @(*) begin
	self27 <= 1'd0;
	case (core_steerer3)
		1'd0: begin
			self27 <= 1'd0;
		end
		1'd1: begin
			self27 <= ((core_choose_cmd_cmd_valid & core_choose_cmd_cmd_ready) & core_choose_cmd_cmd_payload_is_write);
		end
		2'd2: begin
			self27 <= ((core_choose_req_cmd_valid & core_choose_req_cmd_ready) & core_choose_req_cmd_payload_is_write);
		end
		default: begin
			self27 <= ((core_cmd_valid & core_cmd_ready) & core_cmd_payload_is_write);
		end
	endcase
// synthesis translate_off
	dummy_d_125 <= dummy_s;
// synthesis translate_on
end

always @(posedge sys_clk) begin
	if (core_csr_dfi_p0_rddata_valid) begin
		core_phaseinjector0_status <= core_csr_dfi_p0_rddata;
	end
	if (core_csr_dfi_p1_rddata_valid) begin
		core_phaseinjector1_status <= core_csr_dfi_p1_rddata;
	end
	if (core_csr_dfi_p2_rddata_valid) begin
		core_phaseinjector2_status <= core_csr_dfi_p2_rddata;
	end
	if (core_csr_dfi_p3_rddata_valid) begin
		core_phaseinjector3_status <= core_csr_dfi_p3_rddata;
	end
	if ((core_timer_wait & (~core_timer_done0))) begin
		core_timer_count1 <= (core_timer_count1 - 1'd1);
	end else begin
		core_timer_count1 <= 10'd585;
	end
	core_postponer_req_o <= 1'd0;
	if (core_postponer_req_i) begin
		core_postponer_count <= (core_postponer_count - 1'd1);
		if ((core_postponer_count == 1'd0)) begin
			core_postponer_count <= 1'd0;
			core_postponer_req_o <= 1'd1;
		end
	end
	if (core_sequencer_start0) begin
		core_sequencer_count <= 1'd0;
	end else begin
		if (core_sequencer_done1) begin
			if ((core_sequencer_count != 1'd0)) begin
				core_sequencer_count <= (core_sequencer_count - 1'd1);
			end
		end
	end
	core_cmd_payload_a <= 1'd0;
	core_cmd_payload_ba <= 1'd0;
	core_cmd_payload_cas <= 1'd0;
	core_cmd_payload_ras <= 1'd0;
	core_cmd_payload_we <= 1'd0;
	core_sequencer_done1 <= 1'd0;
	if ((core_sequencer_start1 & (core_sequencer_trigger == 1'd0))) begin
		core_cmd_payload_a <= 11'd1024;
		core_cmd_payload_ba <= 1'd0;
		core_cmd_payload_cas <= 1'd0;
		core_cmd_payload_ras <= 1'd1;
		core_cmd_payload_we <= 1'd1;
	end
	if ((core_sequencer_trigger == 2'd2)) begin
		core_cmd_payload_a <= 11'd1024;
		core_cmd_payload_ba <= 1'd0;
		core_cmd_payload_cas <= 1'd1;
		core_cmd_payload_ras <= 1'd1;
		core_cmd_payload_we <= 1'd0;
	end
	if ((core_sequencer_trigger == 6'd54)) begin
		core_cmd_payload_a <= 1'd0;
		core_cmd_payload_ba <= 1'd0;
		core_cmd_payload_cas <= 1'd0;
		core_cmd_payload_ras <= 1'd0;
		core_cmd_payload_we <= 1'd0;
		core_sequencer_done1 <= 1'd1;
	end
	if ((core_sequencer_trigger == 6'd54)) begin
		core_sequencer_trigger <= 1'd0;
	end else begin
		if ((core_sequencer_trigger != 1'd0)) begin
			core_sequencer_trigger <= (core_sequencer_trigger + 1'd1);
		end else begin
			if (core_sequencer_start1) begin
				core_sequencer_trigger <= 1'd1;
			end
		end
	end
	if ((core_zqcs_timer_wait & (~core_zqcs_timer_done0))) begin
		core_zqcs_timer_count1 <= (core_zqcs_timer_count1 - 1'd1);
	end else begin
		core_zqcs_timer_count1 <= 27'd74999999;
	end
	core_zqcs_executer_done <= 1'd0;
	if ((core_zqcs_executer_start & (core_zqcs_executer_trigger == 1'd0))) begin
		core_cmd_payload_a <= 11'd1024;
		core_cmd_payload_ba <= 1'd0;
		core_cmd_payload_cas <= 1'd0;
		core_cmd_payload_ras <= 1'd1;
		core_cmd_payload_we <= 1'd1;
	end
	if ((core_zqcs_executer_trigger == 2'd2)) begin
		core_cmd_payload_a <= 1'd0;
		core_cmd_payload_ba <= 1'd0;
		core_cmd_payload_cas <= 1'd0;
		core_cmd_payload_ras <= 1'd0;
		core_cmd_payload_we <= 1'd1;
	end
	if ((core_zqcs_executer_trigger == 5'd18)) begin
		core_cmd_payload_a <= 1'd0;
		core_cmd_payload_ba <= 1'd0;
		core_cmd_payload_cas <= 1'd0;
		core_cmd_payload_ras <= 1'd0;
		core_cmd_payload_we <= 1'd0;
		core_zqcs_executer_done <= 1'd1;
	end
	if ((core_zqcs_executer_trigger == 5'd18)) begin
		core_zqcs_executer_trigger <= 1'd0;
	end else begin
		if ((core_zqcs_executer_trigger != 1'd0)) begin
			core_zqcs_executer_trigger <= (core_zqcs_executer_trigger + 1'd1);
		end else begin
			if (core_zqcs_executer_start) begin
				core_zqcs_executer_trigger <= 1'd1;
			end
		end
	end
	refresher_state <= refresher_next_state;
	if (core_bankmachine0_row_close) begin
		core_bankmachine0_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine0_row_open) begin
			core_bankmachine0_row_opened <= 1'd1;
			core_bankmachine0_row <= core_bankmachine0_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine0_syncfifo0_we & core_bankmachine0_syncfifo0_writable) & (~core_bankmachine0_replace))) begin
		core_bankmachine0_produce <= (core_bankmachine0_produce + 1'd1);
	end
	if (core_bankmachine0_do_read) begin
		core_bankmachine0_consume <= (core_bankmachine0_consume + 1'd1);
	end
	if (((core_bankmachine0_syncfifo0_we & core_bankmachine0_syncfifo0_writable) & (~core_bankmachine0_replace))) begin
		if ((~core_bankmachine0_do_read)) begin
			core_bankmachine0_level <= (core_bankmachine0_level + 1'd1);
		end
	end else begin
		if (core_bankmachine0_do_read) begin
			core_bankmachine0_level <= (core_bankmachine0_level - 1'd1);
		end
	end
	if (((~core_bankmachine0_pipe_valid_source_valid) | core_bankmachine0_pipe_valid_source_ready)) begin
		core_bankmachine0_pipe_valid_source_valid <= core_bankmachine0_pipe_valid_sink_valid;
		core_bankmachine0_pipe_valid_source_first <= core_bankmachine0_pipe_valid_sink_first;
		core_bankmachine0_pipe_valid_source_last <= core_bankmachine0_pipe_valid_sink_last;
		core_bankmachine0_pipe_valid_source_payload_we <= core_bankmachine0_pipe_valid_sink_payload_we;
		core_bankmachine0_pipe_valid_source_payload_addr <= core_bankmachine0_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine0_twtpcon_valid) begin
		core_bankmachine0_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine0_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine0_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine0_twtpcon_ready)) begin
			core_bankmachine0_twtpcon_count <= (core_bankmachine0_twtpcon_count - 1'd1);
			if ((core_bankmachine0_twtpcon_count == 1'd1)) begin
				core_bankmachine0_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine0_trccon_valid) begin
		core_bankmachine0_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine0_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine0_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine0_trccon_ready)) begin
			core_bankmachine0_trccon_count <= (core_bankmachine0_trccon_count - 1'd1);
			if ((core_bankmachine0_trccon_count == 1'd1)) begin
				core_bankmachine0_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine0_trascon_valid) begin
		core_bankmachine0_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine0_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine0_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine0_trascon_ready)) begin
			core_bankmachine0_trascon_count <= (core_bankmachine0_trascon_count - 1'd1);
			if ((core_bankmachine0_trascon_count == 1'd1)) begin
				core_bankmachine0_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine0_state <= bankmachine0_next_state;
	if (core_bankmachine1_row_close) begin
		core_bankmachine1_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine1_row_open) begin
			core_bankmachine1_row_opened <= 1'd1;
			core_bankmachine1_row <= core_bankmachine1_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine1_syncfifo1_we & core_bankmachine1_syncfifo1_writable) & (~core_bankmachine1_replace))) begin
		core_bankmachine1_produce <= (core_bankmachine1_produce + 1'd1);
	end
	if (core_bankmachine1_do_read) begin
		core_bankmachine1_consume <= (core_bankmachine1_consume + 1'd1);
	end
	if (((core_bankmachine1_syncfifo1_we & core_bankmachine1_syncfifo1_writable) & (~core_bankmachine1_replace))) begin
		if ((~core_bankmachine1_do_read)) begin
			core_bankmachine1_level <= (core_bankmachine1_level + 1'd1);
		end
	end else begin
		if (core_bankmachine1_do_read) begin
			core_bankmachine1_level <= (core_bankmachine1_level - 1'd1);
		end
	end
	if (((~core_bankmachine1_pipe_valid_source_valid) | core_bankmachine1_pipe_valid_source_ready)) begin
		core_bankmachine1_pipe_valid_source_valid <= core_bankmachine1_pipe_valid_sink_valid;
		core_bankmachine1_pipe_valid_source_first <= core_bankmachine1_pipe_valid_sink_first;
		core_bankmachine1_pipe_valid_source_last <= core_bankmachine1_pipe_valid_sink_last;
		core_bankmachine1_pipe_valid_source_payload_we <= core_bankmachine1_pipe_valid_sink_payload_we;
		core_bankmachine1_pipe_valid_source_payload_addr <= core_bankmachine1_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine1_twtpcon_valid) begin
		core_bankmachine1_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine1_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine1_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine1_twtpcon_ready)) begin
			core_bankmachine1_twtpcon_count <= (core_bankmachine1_twtpcon_count - 1'd1);
			if ((core_bankmachine1_twtpcon_count == 1'd1)) begin
				core_bankmachine1_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine1_trccon_valid) begin
		core_bankmachine1_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine1_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine1_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine1_trccon_ready)) begin
			core_bankmachine1_trccon_count <= (core_bankmachine1_trccon_count - 1'd1);
			if ((core_bankmachine1_trccon_count == 1'd1)) begin
				core_bankmachine1_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine1_trascon_valid) begin
		core_bankmachine1_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine1_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine1_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine1_trascon_ready)) begin
			core_bankmachine1_trascon_count <= (core_bankmachine1_trascon_count - 1'd1);
			if ((core_bankmachine1_trascon_count == 1'd1)) begin
				core_bankmachine1_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine1_state <= bankmachine1_next_state;
	if (core_bankmachine2_row_close) begin
		core_bankmachine2_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine2_row_open) begin
			core_bankmachine2_row_opened <= 1'd1;
			core_bankmachine2_row <= core_bankmachine2_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine2_syncfifo2_we & core_bankmachine2_syncfifo2_writable) & (~core_bankmachine2_replace))) begin
		core_bankmachine2_produce <= (core_bankmachine2_produce + 1'd1);
	end
	if (core_bankmachine2_do_read) begin
		core_bankmachine2_consume <= (core_bankmachine2_consume + 1'd1);
	end
	if (((core_bankmachine2_syncfifo2_we & core_bankmachine2_syncfifo2_writable) & (~core_bankmachine2_replace))) begin
		if ((~core_bankmachine2_do_read)) begin
			core_bankmachine2_level <= (core_bankmachine2_level + 1'd1);
		end
	end else begin
		if (core_bankmachine2_do_read) begin
			core_bankmachine2_level <= (core_bankmachine2_level - 1'd1);
		end
	end
	if (((~core_bankmachine2_pipe_valid_source_valid) | core_bankmachine2_pipe_valid_source_ready)) begin
		core_bankmachine2_pipe_valid_source_valid <= core_bankmachine2_pipe_valid_sink_valid;
		core_bankmachine2_pipe_valid_source_first <= core_bankmachine2_pipe_valid_sink_first;
		core_bankmachine2_pipe_valid_source_last <= core_bankmachine2_pipe_valid_sink_last;
		core_bankmachine2_pipe_valid_source_payload_we <= core_bankmachine2_pipe_valid_sink_payload_we;
		core_bankmachine2_pipe_valid_source_payload_addr <= core_bankmachine2_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine2_twtpcon_valid) begin
		core_bankmachine2_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine2_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine2_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine2_twtpcon_ready)) begin
			core_bankmachine2_twtpcon_count <= (core_bankmachine2_twtpcon_count - 1'd1);
			if ((core_bankmachine2_twtpcon_count == 1'd1)) begin
				core_bankmachine2_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine2_trccon_valid) begin
		core_bankmachine2_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine2_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine2_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine2_trccon_ready)) begin
			core_bankmachine2_trccon_count <= (core_bankmachine2_trccon_count - 1'd1);
			if ((core_bankmachine2_trccon_count == 1'd1)) begin
				core_bankmachine2_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine2_trascon_valid) begin
		core_bankmachine2_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine2_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine2_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine2_trascon_ready)) begin
			core_bankmachine2_trascon_count <= (core_bankmachine2_trascon_count - 1'd1);
			if ((core_bankmachine2_trascon_count == 1'd1)) begin
				core_bankmachine2_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine2_state <= bankmachine2_next_state;
	if (core_bankmachine3_row_close) begin
		core_bankmachine3_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine3_row_open) begin
			core_bankmachine3_row_opened <= 1'd1;
			core_bankmachine3_row <= core_bankmachine3_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine3_syncfifo3_we & core_bankmachine3_syncfifo3_writable) & (~core_bankmachine3_replace))) begin
		core_bankmachine3_produce <= (core_bankmachine3_produce + 1'd1);
	end
	if (core_bankmachine3_do_read) begin
		core_bankmachine3_consume <= (core_bankmachine3_consume + 1'd1);
	end
	if (((core_bankmachine3_syncfifo3_we & core_bankmachine3_syncfifo3_writable) & (~core_bankmachine3_replace))) begin
		if ((~core_bankmachine3_do_read)) begin
			core_bankmachine3_level <= (core_bankmachine3_level + 1'd1);
		end
	end else begin
		if (core_bankmachine3_do_read) begin
			core_bankmachine3_level <= (core_bankmachine3_level - 1'd1);
		end
	end
	if (((~core_bankmachine3_pipe_valid_source_valid) | core_bankmachine3_pipe_valid_source_ready)) begin
		core_bankmachine3_pipe_valid_source_valid <= core_bankmachine3_pipe_valid_sink_valid;
		core_bankmachine3_pipe_valid_source_first <= core_bankmachine3_pipe_valid_sink_first;
		core_bankmachine3_pipe_valid_source_last <= core_bankmachine3_pipe_valid_sink_last;
		core_bankmachine3_pipe_valid_source_payload_we <= core_bankmachine3_pipe_valid_sink_payload_we;
		core_bankmachine3_pipe_valid_source_payload_addr <= core_bankmachine3_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine3_twtpcon_valid) begin
		core_bankmachine3_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine3_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine3_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine3_twtpcon_ready)) begin
			core_bankmachine3_twtpcon_count <= (core_bankmachine3_twtpcon_count - 1'd1);
			if ((core_bankmachine3_twtpcon_count == 1'd1)) begin
				core_bankmachine3_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine3_trccon_valid) begin
		core_bankmachine3_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine3_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine3_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine3_trccon_ready)) begin
			core_bankmachine3_trccon_count <= (core_bankmachine3_trccon_count - 1'd1);
			if ((core_bankmachine3_trccon_count == 1'd1)) begin
				core_bankmachine3_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine3_trascon_valid) begin
		core_bankmachine3_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine3_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine3_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine3_trascon_ready)) begin
			core_bankmachine3_trascon_count <= (core_bankmachine3_trascon_count - 1'd1);
			if ((core_bankmachine3_trascon_count == 1'd1)) begin
				core_bankmachine3_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine3_state <= bankmachine3_next_state;
	if (core_bankmachine4_row_close) begin
		core_bankmachine4_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine4_row_open) begin
			core_bankmachine4_row_opened <= 1'd1;
			core_bankmachine4_row <= core_bankmachine4_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine4_syncfifo4_we & core_bankmachine4_syncfifo4_writable) & (~core_bankmachine4_replace))) begin
		core_bankmachine4_produce <= (core_bankmachine4_produce + 1'd1);
	end
	if (core_bankmachine4_do_read) begin
		core_bankmachine4_consume <= (core_bankmachine4_consume + 1'd1);
	end
	if (((core_bankmachine4_syncfifo4_we & core_bankmachine4_syncfifo4_writable) & (~core_bankmachine4_replace))) begin
		if ((~core_bankmachine4_do_read)) begin
			core_bankmachine4_level <= (core_bankmachine4_level + 1'd1);
		end
	end else begin
		if (core_bankmachine4_do_read) begin
			core_bankmachine4_level <= (core_bankmachine4_level - 1'd1);
		end
	end
	if (((~core_bankmachine4_pipe_valid_source_valid) | core_bankmachine4_pipe_valid_source_ready)) begin
		core_bankmachine4_pipe_valid_source_valid <= core_bankmachine4_pipe_valid_sink_valid;
		core_bankmachine4_pipe_valid_source_first <= core_bankmachine4_pipe_valid_sink_first;
		core_bankmachine4_pipe_valid_source_last <= core_bankmachine4_pipe_valid_sink_last;
		core_bankmachine4_pipe_valid_source_payload_we <= core_bankmachine4_pipe_valid_sink_payload_we;
		core_bankmachine4_pipe_valid_source_payload_addr <= core_bankmachine4_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine4_twtpcon_valid) begin
		core_bankmachine4_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine4_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine4_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine4_twtpcon_ready)) begin
			core_bankmachine4_twtpcon_count <= (core_bankmachine4_twtpcon_count - 1'd1);
			if ((core_bankmachine4_twtpcon_count == 1'd1)) begin
				core_bankmachine4_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine4_trccon_valid) begin
		core_bankmachine4_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine4_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine4_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine4_trccon_ready)) begin
			core_bankmachine4_trccon_count <= (core_bankmachine4_trccon_count - 1'd1);
			if ((core_bankmachine4_trccon_count == 1'd1)) begin
				core_bankmachine4_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine4_trascon_valid) begin
		core_bankmachine4_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine4_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine4_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine4_trascon_ready)) begin
			core_bankmachine4_trascon_count <= (core_bankmachine4_trascon_count - 1'd1);
			if ((core_bankmachine4_trascon_count == 1'd1)) begin
				core_bankmachine4_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine4_state <= bankmachine4_next_state;
	if (core_bankmachine5_row_close) begin
		core_bankmachine5_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine5_row_open) begin
			core_bankmachine5_row_opened <= 1'd1;
			core_bankmachine5_row <= core_bankmachine5_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine5_syncfifo5_we & core_bankmachine5_syncfifo5_writable) & (~core_bankmachine5_replace))) begin
		core_bankmachine5_produce <= (core_bankmachine5_produce + 1'd1);
	end
	if (core_bankmachine5_do_read) begin
		core_bankmachine5_consume <= (core_bankmachine5_consume + 1'd1);
	end
	if (((core_bankmachine5_syncfifo5_we & core_bankmachine5_syncfifo5_writable) & (~core_bankmachine5_replace))) begin
		if ((~core_bankmachine5_do_read)) begin
			core_bankmachine5_level <= (core_bankmachine5_level + 1'd1);
		end
	end else begin
		if (core_bankmachine5_do_read) begin
			core_bankmachine5_level <= (core_bankmachine5_level - 1'd1);
		end
	end
	if (((~core_bankmachine5_pipe_valid_source_valid) | core_bankmachine5_pipe_valid_source_ready)) begin
		core_bankmachine5_pipe_valid_source_valid <= core_bankmachine5_pipe_valid_sink_valid;
		core_bankmachine5_pipe_valid_source_first <= core_bankmachine5_pipe_valid_sink_first;
		core_bankmachine5_pipe_valid_source_last <= core_bankmachine5_pipe_valid_sink_last;
		core_bankmachine5_pipe_valid_source_payload_we <= core_bankmachine5_pipe_valid_sink_payload_we;
		core_bankmachine5_pipe_valid_source_payload_addr <= core_bankmachine5_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine5_twtpcon_valid) begin
		core_bankmachine5_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine5_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine5_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine5_twtpcon_ready)) begin
			core_bankmachine5_twtpcon_count <= (core_bankmachine5_twtpcon_count - 1'd1);
			if ((core_bankmachine5_twtpcon_count == 1'd1)) begin
				core_bankmachine5_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine5_trccon_valid) begin
		core_bankmachine5_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine5_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine5_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine5_trccon_ready)) begin
			core_bankmachine5_trccon_count <= (core_bankmachine5_trccon_count - 1'd1);
			if ((core_bankmachine5_trccon_count == 1'd1)) begin
				core_bankmachine5_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine5_trascon_valid) begin
		core_bankmachine5_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine5_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine5_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine5_trascon_ready)) begin
			core_bankmachine5_trascon_count <= (core_bankmachine5_trascon_count - 1'd1);
			if ((core_bankmachine5_trascon_count == 1'd1)) begin
				core_bankmachine5_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine5_state <= bankmachine5_next_state;
	if (core_bankmachine6_row_close) begin
		core_bankmachine6_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine6_row_open) begin
			core_bankmachine6_row_opened <= 1'd1;
			core_bankmachine6_row <= core_bankmachine6_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine6_syncfifo6_we & core_bankmachine6_syncfifo6_writable) & (~core_bankmachine6_replace))) begin
		core_bankmachine6_produce <= (core_bankmachine6_produce + 1'd1);
	end
	if (core_bankmachine6_do_read) begin
		core_bankmachine6_consume <= (core_bankmachine6_consume + 1'd1);
	end
	if (((core_bankmachine6_syncfifo6_we & core_bankmachine6_syncfifo6_writable) & (~core_bankmachine6_replace))) begin
		if ((~core_bankmachine6_do_read)) begin
			core_bankmachine6_level <= (core_bankmachine6_level + 1'd1);
		end
	end else begin
		if (core_bankmachine6_do_read) begin
			core_bankmachine6_level <= (core_bankmachine6_level - 1'd1);
		end
	end
	if (((~core_bankmachine6_pipe_valid_source_valid) | core_bankmachine6_pipe_valid_source_ready)) begin
		core_bankmachine6_pipe_valid_source_valid <= core_bankmachine6_pipe_valid_sink_valid;
		core_bankmachine6_pipe_valid_source_first <= core_bankmachine6_pipe_valid_sink_first;
		core_bankmachine6_pipe_valid_source_last <= core_bankmachine6_pipe_valid_sink_last;
		core_bankmachine6_pipe_valid_source_payload_we <= core_bankmachine6_pipe_valid_sink_payload_we;
		core_bankmachine6_pipe_valid_source_payload_addr <= core_bankmachine6_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine6_twtpcon_valid) begin
		core_bankmachine6_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine6_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine6_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine6_twtpcon_ready)) begin
			core_bankmachine6_twtpcon_count <= (core_bankmachine6_twtpcon_count - 1'd1);
			if ((core_bankmachine6_twtpcon_count == 1'd1)) begin
				core_bankmachine6_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine6_trccon_valid) begin
		core_bankmachine6_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine6_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine6_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine6_trccon_ready)) begin
			core_bankmachine6_trccon_count <= (core_bankmachine6_trccon_count - 1'd1);
			if ((core_bankmachine6_trccon_count == 1'd1)) begin
				core_bankmachine6_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine6_trascon_valid) begin
		core_bankmachine6_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine6_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine6_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine6_trascon_ready)) begin
			core_bankmachine6_trascon_count <= (core_bankmachine6_trascon_count - 1'd1);
			if ((core_bankmachine6_trascon_count == 1'd1)) begin
				core_bankmachine6_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine6_state <= bankmachine6_next_state;
	if (core_bankmachine7_row_close) begin
		core_bankmachine7_row_opened <= 1'd0;
	end else begin
		if (core_bankmachine7_row_open) begin
			core_bankmachine7_row_opened <= 1'd1;
			core_bankmachine7_row <= core_bankmachine7_source_source_payload_addr[21:7];
		end
	end
	if (((core_bankmachine7_syncfifo7_we & core_bankmachine7_syncfifo7_writable) & (~core_bankmachine7_replace))) begin
		core_bankmachine7_produce <= (core_bankmachine7_produce + 1'd1);
	end
	if (core_bankmachine7_do_read) begin
		core_bankmachine7_consume <= (core_bankmachine7_consume + 1'd1);
	end
	if (((core_bankmachine7_syncfifo7_we & core_bankmachine7_syncfifo7_writable) & (~core_bankmachine7_replace))) begin
		if ((~core_bankmachine7_do_read)) begin
			core_bankmachine7_level <= (core_bankmachine7_level + 1'd1);
		end
	end else begin
		if (core_bankmachine7_do_read) begin
			core_bankmachine7_level <= (core_bankmachine7_level - 1'd1);
		end
	end
	if (((~core_bankmachine7_pipe_valid_source_valid) | core_bankmachine7_pipe_valid_source_ready)) begin
		core_bankmachine7_pipe_valid_source_valid <= core_bankmachine7_pipe_valid_sink_valid;
		core_bankmachine7_pipe_valid_source_first <= core_bankmachine7_pipe_valid_sink_first;
		core_bankmachine7_pipe_valid_source_last <= core_bankmachine7_pipe_valid_sink_last;
		core_bankmachine7_pipe_valid_source_payload_we <= core_bankmachine7_pipe_valid_sink_payload_we;
		core_bankmachine7_pipe_valid_source_payload_addr <= core_bankmachine7_pipe_valid_sink_payload_addr;
	end
	if (core_bankmachine7_twtpcon_valid) begin
		core_bankmachine7_twtpcon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine7_twtpcon_ready <= 1'd1;
		end else begin
			core_bankmachine7_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine7_twtpcon_ready)) begin
			core_bankmachine7_twtpcon_count <= (core_bankmachine7_twtpcon_count - 1'd1);
			if ((core_bankmachine7_twtpcon_count == 1'd1)) begin
				core_bankmachine7_twtpcon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine7_trccon_valid) begin
		core_bankmachine7_trccon_count <= 3'd4;
		if (1'd0) begin
			core_bankmachine7_trccon_ready <= 1'd1;
		end else begin
			core_bankmachine7_trccon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine7_trccon_ready)) begin
			core_bankmachine7_trccon_count <= (core_bankmachine7_trccon_count - 1'd1);
			if ((core_bankmachine7_trccon_count == 1'd1)) begin
				core_bankmachine7_trccon_ready <= 1'd1;
			end
		end
	end
	if (core_bankmachine7_trascon_valid) begin
		core_bankmachine7_trascon_count <= 2'd3;
		if (1'd0) begin
			core_bankmachine7_trascon_ready <= 1'd1;
		end else begin
			core_bankmachine7_trascon_ready <= 1'd0;
		end
	end else begin
		if ((~core_bankmachine7_trascon_ready)) begin
			core_bankmachine7_trascon_count <= (core_bankmachine7_trascon_count - 1'd1);
			if ((core_bankmachine7_trascon_count == 1'd1)) begin
				core_bankmachine7_trascon_ready <= 1'd1;
			end
		end
	end
	bankmachine7_state <= bankmachine7_next_state;
	if ((~core_en0)) begin
		core_time0 <= 5'd31;
	end else begin
		if ((~core_max_time0)) begin
			core_time0 <= (core_time0 - 1'd1);
		end
	end
	if ((~core_en1)) begin
		core_time1 <= 4'd15;
	end else begin
		if ((~core_max_time1)) begin
			core_time1 <= (core_time1 - 1'd1);
		end
	end
	if (core_choose_cmd_ce) begin
		case (core_choose_cmd_grant)
			1'd0: begin
				if (core_choose_cmd_request[1]) begin
					core_choose_cmd_grant <= 1'd1;
				end else begin
					if (core_choose_cmd_request[2]) begin
						core_choose_cmd_grant <= 2'd2;
					end else begin
						if (core_choose_cmd_request[3]) begin
							core_choose_cmd_grant <= 2'd3;
						end else begin
							if (core_choose_cmd_request[4]) begin
								core_choose_cmd_grant <= 3'd4;
							end else begin
								if (core_choose_cmd_request[5]) begin
									core_choose_cmd_grant <= 3'd5;
								end else begin
									if (core_choose_cmd_request[6]) begin
										core_choose_cmd_grant <= 3'd6;
									end else begin
										if (core_choose_cmd_request[7]) begin
											core_choose_cmd_grant <= 3'd7;
										end
									end
								end
							end
						end
					end
				end
			end
			1'd1: begin
				if (core_choose_cmd_request[2]) begin
					core_choose_cmd_grant <= 2'd2;
				end else begin
					if (core_choose_cmd_request[3]) begin
						core_choose_cmd_grant <= 2'd3;
					end else begin
						if (core_choose_cmd_request[4]) begin
							core_choose_cmd_grant <= 3'd4;
						end else begin
							if (core_choose_cmd_request[5]) begin
								core_choose_cmd_grant <= 3'd5;
							end else begin
								if (core_choose_cmd_request[6]) begin
									core_choose_cmd_grant <= 3'd6;
								end else begin
									if (core_choose_cmd_request[7]) begin
										core_choose_cmd_grant <= 3'd7;
									end else begin
										if (core_choose_cmd_request[0]) begin
											core_choose_cmd_grant <= 1'd0;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd2: begin
				if (core_choose_cmd_request[3]) begin
					core_choose_cmd_grant <= 2'd3;
				end else begin
					if (core_choose_cmd_request[4]) begin
						core_choose_cmd_grant <= 3'd4;
					end else begin
						if (core_choose_cmd_request[5]) begin
							core_choose_cmd_grant <= 3'd5;
						end else begin
							if (core_choose_cmd_request[6]) begin
								core_choose_cmd_grant <= 3'd6;
							end else begin
								if (core_choose_cmd_request[7]) begin
									core_choose_cmd_grant <= 3'd7;
								end else begin
									if (core_choose_cmd_request[0]) begin
										core_choose_cmd_grant <= 1'd0;
									end else begin
										if (core_choose_cmd_request[1]) begin
											core_choose_cmd_grant <= 1'd1;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd3: begin
				if (core_choose_cmd_request[4]) begin
					core_choose_cmd_grant <= 3'd4;
				end else begin
					if (core_choose_cmd_request[5]) begin
						core_choose_cmd_grant <= 3'd5;
					end else begin
						if (core_choose_cmd_request[6]) begin
							core_choose_cmd_grant <= 3'd6;
						end else begin
							if (core_choose_cmd_request[7]) begin
								core_choose_cmd_grant <= 3'd7;
							end else begin
								if (core_choose_cmd_request[0]) begin
									core_choose_cmd_grant <= 1'd0;
								end else begin
									if (core_choose_cmd_request[1]) begin
										core_choose_cmd_grant <= 1'd1;
									end else begin
										if (core_choose_cmd_request[2]) begin
											core_choose_cmd_grant <= 2'd2;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd4: begin
				if (core_choose_cmd_request[5]) begin
					core_choose_cmd_grant <= 3'd5;
				end else begin
					if (core_choose_cmd_request[6]) begin
						core_choose_cmd_grant <= 3'd6;
					end else begin
						if (core_choose_cmd_request[7]) begin
							core_choose_cmd_grant <= 3'd7;
						end else begin
							if (core_choose_cmd_request[0]) begin
								core_choose_cmd_grant <= 1'd0;
							end else begin
								if (core_choose_cmd_request[1]) begin
									core_choose_cmd_grant <= 1'd1;
								end else begin
									if (core_choose_cmd_request[2]) begin
										core_choose_cmd_grant <= 2'd2;
									end else begin
										if (core_choose_cmd_request[3]) begin
											core_choose_cmd_grant <= 2'd3;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd5: begin
				if (core_choose_cmd_request[6]) begin
					core_choose_cmd_grant <= 3'd6;
				end else begin
					if (core_choose_cmd_request[7]) begin
						core_choose_cmd_grant <= 3'd7;
					end else begin
						if (core_choose_cmd_request[0]) begin
							core_choose_cmd_grant <= 1'd0;
						end else begin
							if (core_choose_cmd_request[1]) begin
								core_choose_cmd_grant <= 1'd1;
							end else begin
								if (core_choose_cmd_request[2]) begin
									core_choose_cmd_grant <= 2'd2;
								end else begin
									if (core_choose_cmd_request[3]) begin
										core_choose_cmd_grant <= 2'd3;
									end else begin
										if (core_choose_cmd_request[4]) begin
											core_choose_cmd_grant <= 3'd4;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd6: begin
				if (core_choose_cmd_request[7]) begin
					core_choose_cmd_grant <= 3'd7;
				end else begin
					if (core_choose_cmd_request[0]) begin
						core_choose_cmd_grant <= 1'd0;
					end else begin
						if (core_choose_cmd_request[1]) begin
							core_choose_cmd_grant <= 1'd1;
						end else begin
							if (core_choose_cmd_request[2]) begin
								core_choose_cmd_grant <= 2'd2;
							end else begin
								if (core_choose_cmd_request[3]) begin
									core_choose_cmd_grant <= 2'd3;
								end else begin
									if (core_choose_cmd_request[4]) begin
										core_choose_cmd_grant <= 3'd4;
									end else begin
										if (core_choose_cmd_request[5]) begin
											core_choose_cmd_grant <= 3'd5;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd7: begin
				if (core_choose_cmd_request[0]) begin
					core_choose_cmd_grant <= 1'd0;
				end else begin
					if (core_choose_cmd_request[1]) begin
						core_choose_cmd_grant <= 1'd1;
					end else begin
						if (core_choose_cmd_request[2]) begin
							core_choose_cmd_grant <= 2'd2;
						end else begin
							if (core_choose_cmd_request[3]) begin
								core_choose_cmd_grant <= 2'd3;
							end else begin
								if (core_choose_cmd_request[4]) begin
									core_choose_cmd_grant <= 3'd4;
								end else begin
									if (core_choose_cmd_request[5]) begin
										core_choose_cmd_grant <= 3'd5;
									end else begin
										if (core_choose_cmd_request[6]) begin
											core_choose_cmd_grant <= 3'd6;
										end
									end
								end
							end
						end
					end
				end
			end
		endcase
	end
	if (core_choose_req_ce) begin
		case (core_choose_req_grant)
			1'd0: begin
				if (core_choose_req_request[1]) begin
					core_choose_req_grant <= 1'd1;
				end else begin
					if (core_choose_req_request[2]) begin
						core_choose_req_grant <= 2'd2;
					end else begin
						if (core_choose_req_request[3]) begin
							core_choose_req_grant <= 2'd3;
						end else begin
							if (core_choose_req_request[4]) begin
								core_choose_req_grant <= 3'd4;
							end else begin
								if (core_choose_req_request[5]) begin
									core_choose_req_grant <= 3'd5;
								end else begin
									if (core_choose_req_request[6]) begin
										core_choose_req_grant <= 3'd6;
									end else begin
										if (core_choose_req_request[7]) begin
											core_choose_req_grant <= 3'd7;
										end
									end
								end
							end
						end
					end
				end
			end
			1'd1: begin
				if (core_choose_req_request[2]) begin
					core_choose_req_grant <= 2'd2;
				end else begin
					if (core_choose_req_request[3]) begin
						core_choose_req_grant <= 2'd3;
					end else begin
						if (core_choose_req_request[4]) begin
							core_choose_req_grant <= 3'd4;
						end else begin
							if (core_choose_req_request[5]) begin
								core_choose_req_grant <= 3'd5;
							end else begin
								if (core_choose_req_request[6]) begin
									core_choose_req_grant <= 3'd6;
								end else begin
									if (core_choose_req_request[7]) begin
										core_choose_req_grant <= 3'd7;
									end else begin
										if (core_choose_req_request[0]) begin
											core_choose_req_grant <= 1'd0;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd2: begin
				if (core_choose_req_request[3]) begin
					core_choose_req_grant <= 2'd3;
				end else begin
					if (core_choose_req_request[4]) begin
						core_choose_req_grant <= 3'd4;
					end else begin
						if (core_choose_req_request[5]) begin
							core_choose_req_grant <= 3'd5;
						end else begin
							if (core_choose_req_request[6]) begin
								core_choose_req_grant <= 3'd6;
							end else begin
								if (core_choose_req_request[7]) begin
									core_choose_req_grant <= 3'd7;
								end else begin
									if (core_choose_req_request[0]) begin
										core_choose_req_grant <= 1'd0;
									end else begin
										if (core_choose_req_request[1]) begin
											core_choose_req_grant <= 1'd1;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd3: begin
				if (core_choose_req_request[4]) begin
					core_choose_req_grant <= 3'd4;
				end else begin
					if (core_choose_req_request[5]) begin
						core_choose_req_grant <= 3'd5;
					end else begin
						if (core_choose_req_request[6]) begin
							core_choose_req_grant <= 3'd6;
						end else begin
							if (core_choose_req_request[7]) begin
								core_choose_req_grant <= 3'd7;
							end else begin
								if (core_choose_req_request[0]) begin
									core_choose_req_grant <= 1'd0;
								end else begin
									if (core_choose_req_request[1]) begin
										core_choose_req_grant <= 1'd1;
									end else begin
										if (core_choose_req_request[2]) begin
											core_choose_req_grant <= 2'd2;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd4: begin
				if (core_choose_req_request[5]) begin
					core_choose_req_grant <= 3'd5;
				end else begin
					if (core_choose_req_request[6]) begin
						core_choose_req_grant <= 3'd6;
					end else begin
						if (core_choose_req_request[7]) begin
							core_choose_req_grant <= 3'd7;
						end else begin
							if (core_choose_req_request[0]) begin
								core_choose_req_grant <= 1'd0;
							end else begin
								if (core_choose_req_request[1]) begin
									core_choose_req_grant <= 1'd1;
								end else begin
									if (core_choose_req_request[2]) begin
										core_choose_req_grant <= 2'd2;
									end else begin
										if (core_choose_req_request[3]) begin
											core_choose_req_grant <= 2'd3;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd5: begin
				if (core_choose_req_request[6]) begin
					core_choose_req_grant <= 3'd6;
				end else begin
					if (core_choose_req_request[7]) begin
						core_choose_req_grant <= 3'd7;
					end else begin
						if (core_choose_req_request[0]) begin
							core_choose_req_grant <= 1'd0;
						end else begin
							if (core_choose_req_request[1]) begin
								core_choose_req_grant <= 1'd1;
							end else begin
								if (core_choose_req_request[2]) begin
									core_choose_req_grant <= 2'd2;
								end else begin
									if (core_choose_req_request[3]) begin
										core_choose_req_grant <= 2'd3;
									end else begin
										if (core_choose_req_request[4]) begin
											core_choose_req_grant <= 3'd4;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd6: begin
				if (core_choose_req_request[7]) begin
					core_choose_req_grant <= 3'd7;
				end else begin
					if (core_choose_req_request[0]) begin
						core_choose_req_grant <= 1'd0;
					end else begin
						if (core_choose_req_request[1]) begin
							core_choose_req_grant <= 1'd1;
						end else begin
							if (core_choose_req_request[2]) begin
								core_choose_req_grant <= 2'd2;
							end else begin
								if (core_choose_req_request[3]) begin
									core_choose_req_grant <= 2'd3;
								end else begin
									if (core_choose_req_request[4]) begin
										core_choose_req_grant <= 3'd4;
									end else begin
										if (core_choose_req_request[5]) begin
											core_choose_req_grant <= 3'd5;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd7: begin
				if (core_choose_req_request[0]) begin
					core_choose_req_grant <= 1'd0;
				end else begin
					if (core_choose_req_request[1]) begin
						core_choose_req_grant <= 1'd1;
					end else begin
						if (core_choose_req_request[2]) begin
							core_choose_req_grant <= 2'd2;
						end else begin
							if (core_choose_req_request[3]) begin
								core_choose_req_grant <= 2'd3;
							end else begin
								if (core_choose_req_request[4]) begin
									core_choose_req_grant <= 3'd4;
								end else begin
									if (core_choose_req_request[5]) begin
										core_choose_req_grant <= 3'd5;
									end else begin
										if (core_choose_req_request[6]) begin
											core_choose_req_grant <= 3'd6;
										end
									end
								end
							end
						end
					end
				end
			end
		endcase
	end
	core_dfi_p0_cs_n <= 1'd0;
	core_dfi_p0_bank <= self0;
	core_dfi_p0_address <= self1;
	core_dfi_p0_cas_n <= (~self2);
	core_dfi_p0_ras_n <= (~self3);
	core_dfi_p0_we_n <= (~self4);
	core_dfi_p0_rddata_en <= self5;
	core_dfi_p0_wrdata_en <= self6;
	core_dfi_p1_cs_n <= 1'd0;
	core_dfi_p1_bank <= self7;
	core_dfi_p1_address <= self8;
	core_dfi_p1_cas_n <= (~self9);
	core_dfi_p1_ras_n <= (~self10);
	core_dfi_p1_we_n <= (~self11);
	core_dfi_p1_rddata_en <= self12;
	core_dfi_p1_wrdata_en <= self13;
	core_dfi_p2_cs_n <= 1'd0;
	core_dfi_p2_bank <= self14;
	core_dfi_p2_address <= self15;
	core_dfi_p2_cas_n <= (~self16);
	core_dfi_p2_ras_n <= (~self17);
	core_dfi_p2_we_n <= (~self18);
	core_dfi_p2_rddata_en <= self19;
	core_dfi_p2_wrdata_en <= self20;
	core_dfi_p3_cs_n <= 1'd0;
	core_dfi_p3_bank <= self21;
	core_dfi_p3_address <= self22;
	core_dfi_p3_cas_n <= (~self23);
	core_dfi_p3_ras_n <= (~self24);
	core_dfi_p3_we_n <= (~self25);
	core_dfi_p3_rddata_en <= self26;
	core_dfi_p3_wrdata_en <= self27;
	if (core_trrdcon_valid) begin
		core_trrdcon_count <= 1'd1;
		if (1'd0) begin
			core_trrdcon_ready <= 1'd1;
		end else begin
			core_trrdcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_trrdcon_ready)) begin
			core_trrdcon_count <= (core_trrdcon_count - 1'd1);
			if ((core_trrdcon_count == 1'd1)) begin
				core_trrdcon_ready <= 1'd1;
			end
		end
	end
	core_tfawcon_window <= {core_tfawcon_window, core_tfawcon_valid};
	if ((core_tfawcon_count < 3'd4)) begin
		if ((core_tfawcon_count == 2'd3)) begin
			core_tfawcon_ready <= (~core_tfawcon_valid);
		end else begin
			core_tfawcon_ready <= 1'd1;
		end
	end
	if (core_tccdcon_valid) begin
		core_tccdcon_count <= 1'd0;
		if (1'd1) begin
			core_tccdcon_ready <= 1'd1;
		end else begin
			core_tccdcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_tccdcon_ready)) begin
			core_tccdcon_count <= (core_tccdcon_count - 1'd1);
			if ((core_tccdcon_count == 1'd1)) begin
				core_tccdcon_ready <= 1'd1;
			end
		end
	end
	if (core_twtrcon_valid) begin
		core_twtrcon_count <= 3'd4;
		if (1'd0) begin
			core_twtrcon_ready <= 1'd1;
		end else begin
			core_twtrcon_ready <= 1'd0;
		end
	end else begin
		if ((~core_twtrcon_ready)) begin
			core_twtrcon_count <= (core_twtrcon_count - 1'd1);
			if ((core_twtrcon_count == 1'd1)) begin
				core_twtrcon_ready <= 1'd1;
			end
		end
	end
	multiplexer_state <= multiplexer_next_state;
	new_master_wdata_ready0 <= ((((((((1'd0 | ((roundrobin0_grant == 1'd0) & core_interface_bank0_wdata_ready)) | ((roundrobin1_grant == 1'd0) & core_interface_bank1_wdata_ready)) | ((roundrobin2_grant == 1'd0) & core_interface_bank2_wdata_ready)) | ((roundrobin3_grant == 1'd0) & core_interface_bank3_wdata_ready)) | ((roundrobin4_grant == 1'd0) & core_interface_bank4_wdata_ready)) | ((roundrobin5_grant == 1'd0) & core_interface_bank5_wdata_ready)) | ((roundrobin6_grant == 1'd0) & core_interface_bank6_wdata_ready)) | ((roundrobin7_grant == 1'd0) & core_interface_bank7_wdata_ready));
	new_master_wdata_ready1 <= new_master_wdata_ready0;
	new_master_rdata_valid0 <= ((((((((1'd0 | ((roundrobin0_grant == 1'd0) & core_interface_bank0_rdata_valid)) | ((roundrobin1_grant == 1'd0) & core_interface_bank1_rdata_valid)) | ((roundrobin2_grant == 1'd0) & core_interface_bank2_rdata_valid)) | ((roundrobin3_grant == 1'd0) & core_interface_bank3_rdata_valid)) | ((roundrobin4_grant == 1'd0) & core_interface_bank4_rdata_valid)) | ((roundrobin5_grant == 1'd0) & core_interface_bank5_rdata_valid)) | ((roundrobin6_grant == 1'd0) & core_interface_bank6_rdata_valid)) | ((roundrobin7_grant == 1'd0) & core_interface_bank7_rdata_valid));
	new_master_rdata_valid1 <= new_master_rdata_valid0;
	new_master_rdata_valid2 <= new_master_rdata_valid1;
	new_master_rdata_valid3 <= new_master_rdata_valid2;
	new_master_rdata_valid4 <= new_master_rdata_valid3;
	new_master_rdata_valid5 <= new_master_rdata_valid4;
	new_master_rdata_valid6 <= new_master_rdata_valid5;
	new_master_rdata_valid7 <= new_master_rdata_valid6;
	new_master_rdata_valid8 <= new_master_rdata_valid7;
	if (sys_rst) begin
		core_phaseinjector0_status <= 64'd0;
		core_phaseinjector1_status <= 64'd0;
		core_phaseinjector2_status <= 64'd0;
		core_phaseinjector3_status <= 64'd0;
		core_dfi_p0_address <= 15'd0;
		core_dfi_p0_bank <= 3'd0;
		core_dfi_p0_cas_n <= 1'd1;
		core_dfi_p0_cs_n <= 1'd1;
		core_dfi_p0_ras_n <= 1'd1;
		core_dfi_p0_we_n <= 1'd1;
		core_dfi_p0_wrdata_en <= 1'd0;
		core_dfi_p0_rddata_en <= 1'd0;
		core_dfi_p1_address <= 15'd0;
		core_dfi_p1_bank <= 3'd0;
		core_dfi_p1_cas_n <= 1'd1;
		core_dfi_p1_cs_n <= 1'd1;
		core_dfi_p1_ras_n <= 1'd1;
		core_dfi_p1_we_n <= 1'd1;
		core_dfi_p1_wrdata_en <= 1'd0;
		core_dfi_p1_rddata_en <= 1'd0;
		core_dfi_p2_address <= 15'd0;
		core_dfi_p2_bank <= 3'd0;
		core_dfi_p2_cas_n <= 1'd1;
		core_dfi_p2_cs_n <= 1'd1;
		core_dfi_p2_ras_n <= 1'd1;
		core_dfi_p2_we_n <= 1'd1;
		core_dfi_p2_wrdata_en <= 1'd0;
		core_dfi_p2_rddata_en <= 1'd0;
		core_dfi_p3_address <= 15'd0;
		core_dfi_p3_bank <= 3'd0;
		core_dfi_p3_cas_n <= 1'd1;
		core_dfi_p3_cs_n <= 1'd1;
		core_dfi_p3_ras_n <= 1'd1;
		core_dfi_p3_we_n <= 1'd1;
		core_dfi_p3_wrdata_en <= 1'd0;
		core_dfi_p3_rddata_en <= 1'd0;
		core_timer_count1 <= 10'd585;
		core_postponer_req_o <= 1'd0;
		core_postponer_count <= 1'd0;
		core_sequencer_done1 <= 1'd0;
		core_sequencer_trigger <= 6'd0;
		core_sequencer_count <= 1'd0;
		core_zqcs_timer_count1 <= 27'd74999999;
		core_zqcs_executer_done <= 1'd0;
		core_zqcs_executer_trigger <= 5'd0;
		core_bankmachine0_level <= 4'd0;
		core_bankmachine0_produce <= 3'd0;
		core_bankmachine0_consume <= 3'd0;
		core_bankmachine0_pipe_valid_source_valid <= 1'd0;
		core_bankmachine0_row <= 15'd0;
		core_bankmachine0_row_opened <= 1'd0;
		core_bankmachine0_twtpcon_ready <= 1'd0;
		core_bankmachine0_twtpcon_count <= 3'd0;
		core_bankmachine0_trccon_ready <= 1'd0;
		core_bankmachine0_trccon_count <= 3'd0;
		core_bankmachine0_trascon_ready <= 1'd0;
		core_bankmachine0_trascon_count <= 2'd0;
		core_bankmachine1_level <= 4'd0;
		core_bankmachine1_produce <= 3'd0;
		core_bankmachine1_consume <= 3'd0;
		core_bankmachine1_pipe_valid_source_valid <= 1'd0;
		core_bankmachine1_row <= 15'd0;
		core_bankmachine1_row_opened <= 1'd0;
		core_bankmachine1_twtpcon_ready <= 1'd0;
		core_bankmachine1_twtpcon_count <= 3'd0;
		core_bankmachine1_trccon_ready <= 1'd0;
		core_bankmachine1_trccon_count <= 3'd0;
		core_bankmachine1_trascon_ready <= 1'd0;
		core_bankmachine1_trascon_count <= 2'd0;
		core_bankmachine2_level <= 4'd0;
		core_bankmachine2_produce <= 3'd0;
		core_bankmachine2_consume <= 3'd0;
		core_bankmachine2_pipe_valid_source_valid <= 1'd0;
		core_bankmachine2_row <= 15'd0;
		core_bankmachine2_row_opened <= 1'd0;
		core_bankmachine2_twtpcon_ready <= 1'd0;
		core_bankmachine2_twtpcon_count <= 3'd0;
		core_bankmachine2_trccon_ready <= 1'd0;
		core_bankmachine2_trccon_count <= 3'd0;
		core_bankmachine2_trascon_ready <= 1'd0;
		core_bankmachine2_trascon_count <= 2'd0;
		core_bankmachine3_level <= 4'd0;
		core_bankmachine3_produce <= 3'd0;
		core_bankmachine3_consume <= 3'd0;
		core_bankmachine3_pipe_valid_source_valid <= 1'd0;
		core_bankmachine3_row <= 15'd0;
		core_bankmachine3_row_opened <= 1'd0;
		core_bankmachine3_twtpcon_ready <= 1'd0;
		core_bankmachine3_twtpcon_count <= 3'd0;
		core_bankmachine3_trccon_ready <= 1'd0;
		core_bankmachine3_trccon_count <= 3'd0;
		core_bankmachine3_trascon_ready <= 1'd0;
		core_bankmachine3_trascon_count <= 2'd0;
		core_bankmachine4_level <= 4'd0;
		core_bankmachine4_produce <= 3'd0;
		core_bankmachine4_consume <= 3'd0;
		core_bankmachine4_pipe_valid_source_valid <= 1'd0;
		core_bankmachine4_row <= 15'd0;
		core_bankmachine4_row_opened <= 1'd0;
		core_bankmachine4_twtpcon_ready <= 1'd0;
		core_bankmachine4_twtpcon_count <= 3'd0;
		core_bankmachine4_trccon_ready <= 1'd0;
		core_bankmachine4_trccon_count <= 3'd0;
		core_bankmachine4_trascon_ready <= 1'd0;
		core_bankmachine4_trascon_count <= 2'd0;
		core_bankmachine5_level <= 4'd0;
		core_bankmachine5_produce <= 3'd0;
		core_bankmachine5_consume <= 3'd0;
		core_bankmachine5_pipe_valid_source_valid <= 1'd0;
		core_bankmachine5_row <= 15'd0;
		core_bankmachine5_row_opened <= 1'd0;
		core_bankmachine5_twtpcon_ready <= 1'd0;
		core_bankmachine5_twtpcon_count <= 3'd0;
		core_bankmachine5_trccon_ready <= 1'd0;
		core_bankmachine5_trccon_count <= 3'd0;
		core_bankmachine5_trascon_ready <= 1'd0;
		core_bankmachine5_trascon_count <= 2'd0;
		core_bankmachine6_level <= 4'd0;
		core_bankmachine6_produce <= 3'd0;
		core_bankmachine6_consume <= 3'd0;
		core_bankmachine6_pipe_valid_source_valid <= 1'd0;
		core_bankmachine6_row <= 15'd0;
		core_bankmachine6_row_opened <= 1'd0;
		core_bankmachine6_twtpcon_ready <= 1'd0;
		core_bankmachine6_twtpcon_count <= 3'd0;
		core_bankmachine6_trccon_ready <= 1'd0;
		core_bankmachine6_trccon_count <= 3'd0;
		core_bankmachine6_trascon_ready <= 1'd0;
		core_bankmachine6_trascon_count <= 2'd0;
		core_bankmachine7_level <= 4'd0;
		core_bankmachine7_produce <= 3'd0;
		core_bankmachine7_consume <= 3'd0;
		core_bankmachine7_pipe_valid_source_valid <= 1'd0;
		core_bankmachine7_row <= 15'd0;
		core_bankmachine7_row_opened <= 1'd0;
		core_bankmachine7_twtpcon_ready <= 1'd0;
		core_bankmachine7_twtpcon_count <= 3'd0;
		core_bankmachine7_trccon_ready <= 1'd0;
		core_bankmachine7_trccon_count <= 3'd0;
		core_bankmachine7_trascon_ready <= 1'd0;
		core_bankmachine7_trascon_count <= 2'd0;
		core_choose_cmd_grant <= 3'd0;
		core_choose_req_grant <= 3'd0;
		core_trrdcon_ready <= 1'd0;
		core_trrdcon_count <= 1'd0;
		core_tfawcon_ready <= 1'd1;
		core_tfawcon_window <= 4'd0;
		core_tccdcon_ready <= 1'd0;
		core_tccdcon_count <= 1'd0;
		core_twtrcon_ready <= 1'd0;
		core_twtrcon_count <= 3'd0;
		core_time0 <= 5'd0;
		core_time1 <= 4'd0;
		refresher_state <= 2'd0;
		bankmachine0_state <= 3'd0;
		bankmachine1_state <= 3'd0;
		bankmachine2_state <= 3'd0;
		bankmachine3_state <= 3'd0;
		bankmachine4_state <= 3'd0;
		bankmachine5_state <= 3'd0;
		bankmachine6_state <= 3'd0;
		bankmachine7_state <= 3'd0;
		multiplexer_state <= 4'd0;
		new_master_wdata_ready0 <= 1'd0;
		new_master_wdata_ready1 <= 1'd0;
		new_master_rdata_valid0 <= 1'd0;
		new_master_rdata_valid1 <= 1'd0;
		new_master_rdata_valid2 <= 1'd0;
		new_master_rdata_valid3 <= 1'd0;
		new_master_rdata_valid4 <= 1'd0;
		new_master_rdata_valid5 <= 1'd0;
		new_master_rdata_valid6 <= 1'd0;
		new_master_rdata_valid7 <= 1'd0;
		new_master_rdata_valid8 <= 1'd0;
	end
end

reg [24:0] storage[0:7];
reg [24:0] memdat;
always @(posedge sys_clk) begin
	if (core_bankmachine0_wrport_we)
		storage[core_bankmachine0_wrport_adr] <= core_bankmachine0_wrport_dat_w;
	memdat <= storage[core_bankmachine0_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine0_wrport_dat_r = memdat;
assign core_bankmachine0_rdport_dat_r = storage[core_bankmachine0_rdport_adr];

reg [24:0] storage_1[0:7];
reg [24:0] memdat_1;
always @(posedge sys_clk) begin
	if (core_bankmachine1_wrport_we)
		storage_1[core_bankmachine1_wrport_adr] <= core_bankmachine1_wrport_dat_w;
	memdat_1 <= storage_1[core_bankmachine1_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine1_wrport_dat_r = memdat_1;
assign core_bankmachine1_rdport_dat_r = storage_1[core_bankmachine1_rdport_adr];

reg [24:0] storage_2[0:7];
reg [24:0] memdat_2;
always @(posedge sys_clk) begin
	if (core_bankmachine2_wrport_we)
		storage_2[core_bankmachine2_wrport_adr] <= core_bankmachine2_wrport_dat_w;
	memdat_2 <= storage_2[core_bankmachine2_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine2_wrport_dat_r = memdat_2;
assign core_bankmachine2_rdport_dat_r = storage_2[core_bankmachine2_rdport_adr];

reg [24:0] storage_3[0:7];
reg [24:0] memdat_3;
always @(posedge sys_clk) begin
	if (core_bankmachine3_wrport_we)
		storage_3[core_bankmachine3_wrport_adr] <= core_bankmachine3_wrport_dat_w;
	memdat_3 <= storage_3[core_bankmachine3_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine3_wrport_dat_r = memdat_3;
assign core_bankmachine3_rdport_dat_r = storage_3[core_bankmachine3_rdport_adr];

reg [24:0] storage_4[0:7];
reg [24:0] memdat_4;
always @(posedge sys_clk) begin
	if (core_bankmachine4_wrport_we)
		storage_4[core_bankmachine4_wrport_adr] <= core_bankmachine4_wrport_dat_w;
	memdat_4 <= storage_4[core_bankmachine4_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine4_wrport_dat_r = memdat_4;
assign core_bankmachine4_rdport_dat_r = storage_4[core_bankmachine4_rdport_adr];

reg [24:0] storage_5[0:7];
reg [24:0] memdat_5;
always @(posedge sys_clk) begin
	if (core_bankmachine5_wrport_we)
		storage_5[core_bankmachine5_wrport_adr] <= core_bankmachine5_wrport_dat_w;
	memdat_5 <= storage_5[core_bankmachine5_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine5_wrport_dat_r = memdat_5;
assign core_bankmachine5_rdport_dat_r = storage_5[core_bankmachine5_rdport_adr];

reg [24:0] storage_6[0:7];
reg [24:0] memdat_6;
always @(posedge sys_clk) begin
	if (core_bankmachine6_wrport_we)
		storage_6[core_bankmachine6_wrport_adr] <= core_bankmachine6_wrport_dat_w;
	memdat_6 <= storage_6[core_bankmachine6_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine6_wrport_dat_r = memdat_6;
assign core_bankmachine6_rdport_dat_r = storage_6[core_bankmachine6_rdport_adr];

reg [24:0] storage_7[0:7];
reg [24:0] memdat_7;
always @(posedge sys_clk) begin
	if (core_bankmachine7_wrport_we)
		storage_7[core_bankmachine7_wrport_adr] <= core_bankmachine7_wrport_dat_w;
	memdat_7 <= storage_7[core_bankmachine7_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign core_bankmachine7_wrport_dat_r = memdat_7;
assign core_bankmachine7_rdport_dat_r = storage_7[core_bankmachine7_rdport_adr];

endmodule
