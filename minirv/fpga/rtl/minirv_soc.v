// minirv SoC: the minirv CPU + 64 KiB RAM + console + LEDs + a debug port.
// The same RTL runs in the Verilator testbench and on the FPGA.
//
// CPU memory map:
//   0x3000_0000-0x3000_FFFF  RAM, 64 KiB, program and data (reset PC = 0x3000_0000)
//   0x1000_0000              console TX: store a byte (16550 THR position)
//   0x1000_0005              console status (16550 LSR): 0x60 = ready, 0x00 = buffer full
//   0x1000_1000              LEDs [2:0]
// Both buses answer one cycle after the request (block-RAM read latency). A console
// store waits while the 512-byte console buffer is full.
//
// Debug port (clk domain): dbg_valid pulses for one cycle; dbg_done pulses when
// dbg_result is valid.
//   1 WRITE  RAM[addr] <= wdata (ignored while the CPU runs)
//   2 READ   result <= RAM[addr]
//   3 CTRL   wdata[0]=1: run (release reset, clear counters); 0: hold the CPU in reset
//   4 POP    result = {23'b0, valid, byte} from the console buffer
module minirv_soc (
    input  wire        clk,
    input  wire        dbg_valid,
    input  wire [3:0]  dbg_cmd,
    input  wire [13:0] dbg_addr,
    input  wire [31:0] dbg_wdata,
    output reg         dbg_done   = 1'b0,
    output reg  [31:0] dbg_result = 32'd0,
    output reg  [2:0]  leds       = 3'd0,
    output reg         running    = 1'b0,
    output reg         halted     = 1'b0,
    output wire [31:0] pc,
    output reg  [31:0] cycles     = 32'd0,
    output reg  [31:0] instret    = 32'd0,
    output wire [31:0] a0
);
    localparam CMD_WRITE = 4'd1, CMD_READ = 4'd2, CMD_CTRL = 4'd3, CMD_POP = 4'd4;

    // ---- CPU ----
    wire [31:0] ifu_addr, lsu_addr, lsu_wdata;
    wire [3:0]  lsu_wmask;
    wire [1:0]  lsu_size;
    wire [6:0]  funct7;
    wire        ifu_req, lsu_req, lsu_wen, retired, ebreak;
    reg         ifu_resp = 1'b0, lsu_resp = 1'b0;
    reg  [31:0] ifu_rdata = 32'd0;
    wire [31:0] lsu_rdata;

    minirv_core cpu (
        .clock(clk), .reset(!running),
        .io_ifu_addr(ifu_addr), .io_ifu_rdata(ifu_rdata),
        .io_ifu_reqValid(ifu_req), .io_ifu_respValid(ifu_resp),
        .io_lsu_addr(lsu_addr), .io_lsu_wdata(lsu_wdata), .io_lsu_wmask(lsu_wmask),
        .io_lsu_wen(lsu_wen), .io_lsu_reqValid(lsu_req), .io_lsu_respValid(lsu_resp),
        .io_lsu_rdata(lsu_rdata), .io_lsu_size(lsu_size),
        .pc(pc), .inst_retired(retired), .funct7_out(funct7),
        .dbg_a0(a0), .dbg_ebreak(ebreak)
    );

    // ---- RAM: 16K x 32, port A = instruction fetch, port B = load/store or debug ----
    reg [31:0] ram [0:16383];

    wire ifu_fire = running && !halted && ifu_req && !ifu_resp;
    always @(posedge clk) begin
        ifu_resp <= ifu_fire;
        if (ifu_fire)
            ifu_rdata <= ram[ifu_addr[15:2]];
    end

    // ---- console buffer: 512 bytes ----
    reg  [7:0] con_mem [0:511];
    reg  [9:0] con_wp = 10'd0, con_rp = 10'd0;
    reg  [7:0] con_byte = 8'd0;
    wire       con_empty = (con_wp == con_rp);
    wire       con_full  = (con_wp[8:0] == con_rp[8:0]) && (con_wp[9] != con_rp[9]);

    // ---- load/store decode ----
    wire sel_ram  = (lsu_addr[31:16] == 16'h3000);
    wire sel_con  = (lsu_addr[31:12] == 20'h10000);
    wire sel_led  = (lsu_addr[31:12] == 20'h10001);
    wire con_push = sel_con && lsu_wen && (lsu_addr[11:2] == 10'd0) && lsu_wmask[0];
    wire lsu_fire = running && lsu_req && !lsu_resp && !(con_push && con_full);

    wire        dbg_mem = !running && dbg_valid && (dbg_cmd == CMD_WRITE || dbg_cmd == CMD_READ);
    wire        b_en    = running ? (lsu_fire && sel_ram) : dbg_mem;
    wire [13:0] b_addr  = running ? lsu_addr[15:2] : dbg_addr;
    wire [3:0]  b_we    = running ? ((lsu_fire && sel_ram && lsu_wen) ? lsu_wmask : 4'b0000)
                                  : ((dbg_mem && dbg_cmd == CMD_WRITE) ? 4'b1111 : 4'b0000);
    wire [31:0] b_wdata = running ? lsu_wdata : dbg_wdata;
    reg  [31:0] b_rdata = 32'd0;
    always @(posedge clk) begin
        if (b_en) begin
            if (b_we[0]) ram[b_addr][7:0]   <= b_wdata[7:0];
            if (b_we[1]) ram[b_addr][15:8]  <= b_wdata[15:8];
            if (b_we[2]) ram[b_addr][23:16] <= b_wdata[23:16];
            if (b_we[3]) ram[b_addr][31:24] <= b_wdata[31:24];
            b_rdata <= ram[b_addr];
        end
    end

    reg        lsu_was_ram = 1'b0;
    reg [31:0] mmio_rdata  = 32'd0;
    assign lsu_rdata = lsu_was_ram ? b_rdata : mmio_rdata;

    // ---- console, LEDs, debug commands, counters ----
    reg dbg_read_pending = 1'b0, dbg_pop_pending = 1'b0, popped = 1'b0;
    always @(posedge clk) begin
        lsu_resp    <= lsu_fire;
        lsu_was_ram <= sel_ram;
        dbg_done    <= 1'b0;

        if (lsu_fire) begin
            mmio_rdata <= 32'd0;
            if (sel_con && lsu_addr[11:2] == 10'd1)
                mmio_rdata <= {16'd0, con_full ? 8'h00 : 8'h60, 8'h00};   // LSR at byte 5
            if (sel_led)
                mmio_rdata <= {29'd0, leds};
            if (sel_led && lsu_wen && lsu_wmask[0])
                leds <= lsu_wdata[2:0];
        end

        if (lsu_fire && con_push) begin
            con_mem[con_wp[8:0]] <= lsu_wdata[7:0];
            con_wp <= con_wp + 10'd1;
        end

        if (running && !halted) begin
            cycles <= cycles + 32'd1;
            if (retired) instret <= instret + 32'd1;
            if (ebreak)  halted  <= 1'b1;
        end

        if (dbg_read_pending) begin
            dbg_result <= b_rdata;
            dbg_done <= 1'b1;
            dbg_read_pending <= 1'b0;
        end
        if (dbg_pop_pending) begin
            dbg_result <= {23'd0, popped, popped ? con_byte : 8'd0};
            dbg_done <= 1'b1;
            dbg_pop_pending <= 1'b0;
        end

        if (dbg_valid) begin
            case (dbg_cmd)
                CMD_WRITE: begin dbg_result <= {31'd0, running}; dbg_done <= 1'b1; end
                CMD_READ:  dbg_read_pending <= 1'b1;
                CMD_CTRL: begin
                    if (dbg_wdata[0] && !running) begin   // a fresh start: clear state the program can see
                        halted <= 1'b0; cycles <= 32'd0; instret <= 32'd0; leds <= 3'd0;
                    end
                    running <= dbg_wdata[0];
                    dbg_result <= 32'd0;
                    dbg_done <= 1'b1;
                end
                CMD_POP: begin
                    popped <= !con_empty;
                    if (!con_empty) begin
                        con_byte <= con_mem[con_rp[8:0]];
                        con_rp <= con_rp + 10'd1;
                    end
                    dbg_pop_pending <= 1'b1;
                end
                default: begin dbg_result <= 32'hFFFF_FFFF; dbg_done <= 1'b1; end
            endcase
        end
    end
endmodule
