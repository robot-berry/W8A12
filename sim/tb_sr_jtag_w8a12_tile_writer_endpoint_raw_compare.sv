`timescale 1ns/1ps

module tb_sr_jtag_w8a12_tile_writer_endpoint_raw_compare;
`ifndef TB_IMAGE_W
`define TB_IMAGE_W 2
`endif
`ifndef TB_TILE_W
`define TB_TILE_W `TB_IMAGE_W
`endif
`ifndef TB_TILE_H
`define TB_TILE_H `TB_TILE_W
`endif
`ifndef TB_HALO
`define TB_HALO 21
`endif
`ifndef TB_OUT_LANES
`define TB_OUT_LANES 1
`endif
`ifndef TB_TAP_LANES
`define TB_TAP_LANES 4
`endif
`ifndef TB_SCALE_LANES
`define TB_SCALE_LANES 1
`endif
`ifndef TB_DEBUG_EXPORT_LEVEL
`define TB_DEBUG_EXPORT_LEVEL 2
`endif
`ifndef TB_MAX_CYCLES
`define TB_MAX_CYCLES 22000000
`endif

    localparam int C_S_AXI_DATA_WIDTH = 32;
    localparam int C_S_AXI_ADDR_WIDTH = 6;
    localparam int DATA_W = 24;
    localparam int IMG_W = `TB_IMAGE_W;
    localparam int TILE_W = `TB_TILE_W;
    localparam int TILE_H = `TB_TILE_H;
    localparam int HALO = `TB_HALO;
    localparam int SCALE = 4;
    localparam int OUT_LANES = `TB_OUT_LANES;
    localparam int TAP_LANES = `TB_TAP_LANES;
    localparam int SCALE_LANES = `TB_SCALE_LANES;
    localparam int DEBUG_EXPORT_LEVEL = `TB_DEBUG_EXPORT_LEVEL;
    localparam int IN_PIXELS = IMG_W * IMG_W;
    localparam int OUT_PIXELS = IMG_W * IMG_W * SCALE * SCALE;
    localparam int IN_IDX_W = (IN_PIXELS <= 2) ? 1 : $clog2(IN_PIXELS);
    localparam int OUT_IDX_W = (OUT_PIXELS <= 2) ? 1 : $clog2(OUT_PIXELS);
    localparam int MAX_CYCLES = `TB_MAX_CYCLES;
    localparam int AXIL_TIMEOUT_CYCLES = 1000;

    localparam logic [5:0] REG_STATUS = 6'h00;
    localparam logic [5:0] REG_INPUT_FLAGS = 6'h04;
    localparam logic [5:0] REG_INPUT_PIXEL = 6'h08;
    localparam logic [5:0] REG_OUTPUT_PIXEL = 6'h0c;
    localparam logic [5:0] REG_OUTPUT_FLAGS = 6'h10;
    localparam logic [5:0] REG_COUNTER_IN = 6'h14;
    localparam logic [5:0] REG_COUNTER_OUT = 6'h18;
    localparam logic [5:0] REG_ERROR = 6'h1c;
    localparam logic [5:0] REG_FRAME_CYCLES = 6'h20;
    localparam logic [5:0] REG_FRAME_DONE = 6'h24;
    localparam logic [5:0] REG_PERF_CTRL = 6'h28;
    localparam logic [5:0] REG_E2E_CYCLES = 6'h2c;
    localparam logic [5:0] REG_DEBUG_WRITEBACK_HASH = 6'h30;
    localparam logic [5:0] REG_DEBUG_WRITEBACK_RANGE = 6'h34;
    localparam logic [5:0] REG_DEBUG_WRITEBACK_FIRST = 6'h38;
    localparam logic [5:0] REG_DEBUG_WRITEBACK_LAST = 6'h3c;

    logic clk = 1'b0;
    logic rstn = 1'b0;
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr = '0;
    logic [2:0] awprot = '0;
    logic awvalid = 1'b0;
    wire awready;
    logic [C_S_AXI_DATA_WIDTH-1:0] wdata = '0;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb = 4'hf;
    logic wvalid = 1'b0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    logic bready = 1'b0;
    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr = '0;
    logic [2:0] arprot = '0;
    logic arvalid = 1'b0;
    wire arready;
    wire [C_S_AXI_DATA_WIDTH-1:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    logic rready = 1'b0;
    wire irq;

    int input_raw_fd;
    int input_raw_count;
    bit input_raw_enabled;
    string input_raw_file;
    int output_rgb_dump_fd;
    string output_rgb_dump_file;
    logic [7:0] input_raw_bytes [0:IN_PIXELS*3-1];
    logic [DATA_W-1:0] output_words [0:OUT_PIXELS-1];
    int out_count;
    int cyc;

    always #5 clk = ~clk;

`ifdef TB_USE_SYNTH_DUT
    sr_jtag_w8a12_tile_writer_endpoint_raw_compare_synth_dut dut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rstn),
        .s_axi_awaddr(awaddr),
        .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),
        .irq(irq)
    );
`else
    sr_jtag_w8a12_tile_writer_endpoint #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .HALO(HALO),
        .SCALE(SCALE),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .SCALE_LANES(SCALE_LANES),
        .DEBUG_EXPORT_LEVEL(DEBUG_EXPORT_LEVEL),
        .IN_PIXELS(IN_PIXELS),
        .OUT_PIXELS(OUT_PIXELS),
        .IN_IDX_W(IN_IDX_W),
        .OUT_IDX_W(OUT_IDX_W)
    ) dut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rstn),
        .s_axi_awaddr(awaddr),
        .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),
        .irq(irq)
    );
`endif

    function automatic [DATA_W-1:0] input_pix(input int i);
        int byte_idx;
        begin
            if (input_raw_enabled) begin
                byte_idx = i * 3;
                input_pix = {input_raw_bytes[byte_idx + 0],
                             input_raw_bytes[byte_idx + 1],
                             input_raw_bytes[byte_idx + 2]};
            end else begin
                input_pix = {8'(8'h20 + i), 8'(8'h40 + i), 8'(8'h60 + i)};
            end
        end
    endfunction

    task automatic load_input_raw;
        begin
            input_raw_enabled = 1'b0;
            input_raw_file = "";
`ifdef TB_INPUT_RAW_FILE
            input_raw_file = `TB_INPUT_RAW_FILE;
`endif
            if (input_raw_file != "") begin
                input_raw_fd = $fopen(input_raw_file, "rb");
                if (input_raw_fd == 0)
                    $fatal(1, "failed to open TB_INPUT_RAW_FILE=%s", input_raw_file);
                input_raw_count = $fread(input_raw_bytes, input_raw_fd);
                $fclose(input_raw_fd);
                if (input_raw_count != IN_PIXELS * 3)
                    $fatal(1, "raw input byte count mismatch in %s: got %0d expected %0d",
                           input_raw_file, input_raw_count, IN_PIXELS * 3);
                input_raw_enabled = 1'b1;
                $display("TB_INPUT_RAW_FILE=%s bytes=%0d", input_raw_file, input_raw_count);
            end
        end
    endtask

    task automatic dump_output_rgb_dump;
        begin
            output_rgb_dump_file = "";
`ifdef TB_OUTPUT_RGB_DUMP_FILE
            output_rgb_dump_file = `TB_OUTPUT_RGB_DUMP_FILE;
`endif
            if (output_rgb_dump_file != "") begin
                output_rgb_dump_fd = $fopen(output_rgb_dump_file, "w");
                if (output_rgb_dump_fd == 0)
                    $fatal(1, "failed to open TB_OUTPUT_RGB_DUMP_FILE=%s", output_rgb_dump_file);
                for (int i = 0; i < OUT_PIXELS; i++) begin
                    $fwrite(output_rgb_dump_fd, "%0d %0d %0d %0d\n",
                            i,
                            output_words[i][23:16],
                            output_words[i][15:8],
                            output_words[i][7:0]);
                end
                $fclose(output_rgb_dump_fd);
                $display("TB_OUTPUT_RGB_DUMP_FILE=%s pixels=%0d",
                         output_rgb_dump_file, OUT_PIXELS);
            end
        end
    endtask

    task automatic axi_write(input logic [5:0] addr, input logic [31:0] data);
        int wait_cycles;
        begin
            @(posedge clk);
            awaddr <= addr;
            wdata <= data;
            wstrb <= 4'hf;
            awvalid <= 1'b1;
            wvalid <= 1'b1;
            wait_cycles = 0;
            do begin
                @(posedge clk);
                #1;
                wait_cycles++;
                if (wait_cycles > AXIL_TIMEOUT_CYCLES)
                    $fatal(1, "AXI-Lite write timeout addr=%02x data=%08x awready=%0b wready=%0b bvalid=%0b",
                           addr, data, awready, wready, bvalid);
            end while (!(awready && wready && bvalid));
            if (bresp != 2'b00)
                $fatal(1, "AXI-Lite write response error addr=%02x resp=%0d", addr, bresp);
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            bready <= 1'b1;
            @(posedge clk);
            bready <= 1'b0;
        end
    endtask

    task automatic axi_read(input logic [5:0] addr, output logic [31:0] data);
        int wait_cycles;
        begin
            @(posedge clk);
            araddr <= addr;
            arvalid <= 1'b1;
            wait_cycles = 0;
            do begin
                @(posedge clk);
                #1;
                wait_cycles++;
                if (wait_cycles > AXIL_TIMEOUT_CYCLES)
                    $fatal(1, "AXI-Lite read timeout addr=%02x arready=%0b rvalid=%0b",
                           addr, arready, rvalid);
            end while (!(arready && rvalid));
            data = rdata;
            if (rresp != 2'b00)
                $fatal(1, "AXI-Lite read response error addr=%02x resp=%0d", addr, rresp);
            arvalid <= 1'b0;
            rready <= 1'b1;
            @(posedge clk);
            rready <= 1'b0;
        end
    endtask

    task automatic poll_status_bit(input logic [31:0] mask, output logic [31:0] status);
        int wait_cycles;
        begin
            wait_cycles = 0;
            do begin
                axi_read(REG_STATUS, status);
                if ((status & mask) == 0) begin
                    @(posedge clk);
                    wait_cycles++;
                    if (wait_cycles > MAX_CYCLES)
                        $fatal(1, "status poll timeout mask=0x%08x status=0x%08x out_count=%0d",
                               mask, status, out_count);
                end
            end while ((status & mask) == 0);
        end
    endtask

    initial begin
        logic [31:0] status;
        logic [31:0] data;
        load_input_raw();
        $display("TB_JTAG_RAW_COMPARE_CONFIG image=%0dx%0d tile=%0dx%0d halo=%0d lanes=%0d/%0d/%0d in_pixels=%0d out_pixels=%0d in_idx_w=%0d out_idx_w=%0d",
                 IMG_W, IMG_W, TILE_W, TILE_H, HALO, OUT_LANES, TAP_LANES,
                 SCALE_LANES, IN_PIXELS, OUT_PIXELS, IN_IDX_W, OUT_IDX_W);

        repeat (12) @(posedge clk);
        rstn <= 1'b1;
        repeat (8) @(posedge clk);

        axi_write(REG_ERROR, 32'h3);
        for (int i = 0; i < IN_PIXELS; i++) begin
            poll_status_bit(32'h40, status);
            axi_write(REG_INPUT_FLAGS, (i == 0) ? 32'h1 : 32'h0);
            axi_write(REG_INPUT_PIXEL, {8'h00, input_pix(i)});
        end

        out_count = 0;
        fork
            begin
                while (out_count < OUT_PIXELS) begin
                    axi_read(REG_STATUS, status);
                    if ((status & 32'h80) != 0) begin
                        axi_read(REG_OUTPUT_PIXEL, data);
                        output_words[out_count] = data[DATA_W-1:0];
                        out_count++;
                    end else begin
                        @(posedge clk);
                    end
                end
            end
            begin
                repeat (MAX_CYCLES) @(posedge clk);
                $fatal(1, "timeout waiting for JTAG endpoint output out_count=%0d status=0x%08x",
                       out_count, status);
            end
        join_any
        disable fork;

        axi_read(REG_COUNTER_IN, data);
        if (data != IN_PIXELS)
            $fatal(1, "expected counter_in=%0d got %0d", IN_PIXELS, data);
        axi_read(REG_COUNTER_OUT, data);
        if (data != OUT_PIXELS)
            $fatal(1, "expected counter_out=%0d got %0d", OUT_PIXELS, data);
        axi_read(REG_FRAME_DONE, data);
        if ((data & 32'h1) == 0)
            $fatal(1, "frame_done not set");
        axi_read(REG_ERROR, data);
        if (data != 32'd0)
            $fatal(1, "error flags set: 0x%08x", data);
        axi_read(REG_FRAME_CYCLES, data);
        $display("JTAG_FRAME_CYCLES=%0d", data);
        axi_read(REG_E2E_CYCLES, data);
        $display("JTAG_E2E_CYCLES=%0d", data);
        axi_read(REG_INPUT_FLAGS, data);
        $display("JTAG_DEBUG_TAIL_B1_HASH=0x%08x", data);
        axi_read(REG_INPUT_PIXEL, data);
        $display("JTAG_DEBUG_TAIL_B6_ACT1_HASH=0x%08x", data);
        axi_read(REG_OUTPUT_FLAGS, data);
        $display("JTAG_DEBUG_TAIL_RGB_Q_HASH=0x%08x", data);
        axi_read(REG_DEBUG_WRITEBACK_HASH, data);
        $display("JTAG_DEBUG_WRITEBACK_HASH=0x%08x", data);
        axi_read(REG_DEBUG_WRITEBACK_RANGE, data);
        $display("JTAG_DEBUG_WRITEBACK_RANGE=0x%08x", data);
        axi_read(REG_DEBUG_WRITEBACK_FIRST, data);
        $display("JTAG_DEBUG_WRITEBACK_FIRST=0x%08x", data);
        axi_read(REG_DEBUG_WRITEBACK_LAST, data);
        $display("JTAG_DEBUG_WRITEBACK_LAST=0x%08x", data);
        if (DEBUG_EXPORT_LEVEL >= 2) begin
            axi_write(REG_PERF_CTRL, 32'h0000_0100);
            axi_read(REG_INPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK1_TAIL_FEAT0_HASH=0x%08x", data);
            axi_read(REG_INPUT_PIXEL, data);
            $display("JTAG_DEBUG_BANK1_SRC_FEAT0_HASH=0x%08x", data);
            axi_read(REG_OUTPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK1_SRC_B1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_HASH, data);
            $display("JTAG_DEBUG_BANK1_TAIL_B1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_RANGE, data);
            $display("JTAG_DEBUG_BANK1_TAIL_B6_ACT1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_FIRST, data);
            $display("JTAG_DEBUG_BANK1_TAIL_RGB_Q_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_LAST, data);
            $display("JTAG_DEBUG_BANK1_WRITEBACK_HASH=0x%08x", data);
        end
        if (DEBUG_EXPORT_LEVEL >= 3) begin
            axi_write(REG_PERF_CTRL, 32'h0000_0200);
            axi_read(REG_INPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK2_SPAB_B1_C1_RAW_HASH=0x%08x", data);
            axi_read(REG_INPUT_PIXEL, data);
            $display("JTAG_DEBUG_BANK2_SPAB_B1_C2_REPLAY_HASH=0x%08x", data);
            axi_read(REG_OUTPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK2_SPAB_B1_C2_WINDOW_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_HASH, data);
            $display("JTAG_DEBUG_BANK2_SPAB_B1_RESIDUAL_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_RANGE, data);
            $display("JTAG_DEBUG_BANK2_SPAB_B1_ATT_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_FIRST, data);
            $display("JTAG_DEBUG_BANK2_TAIL_B1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_LAST, data);
            $display("JTAG_DEBUG_BANK2_TAIL_RGB_Q_HASH=0x%08x", data);
        end
        if (DEBUG_EXPORT_LEVEL >= 2) begin
            axi_write(REG_PERF_CTRL, 32'h0000_0300);
            axi_read(REG_INPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK3_SRC_FEAT0_HASH=0x%08x", data);
            axi_read(REG_INPUT_PIXEL, data);
            $display("JTAG_DEBUG_BANK3_SRC_BLOCK6_HASH=0x%08x", data);
            axi_read(REG_OUTPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK3_SRC_B1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_HASH, data);
            $display("JTAG_DEBUG_BANK3_SRC_B6_ACT1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_RANGE, data);
            $display("JTAG_DEBUG_BANK3_TAIL_B1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_FIRST, data);
            $display("JTAG_DEBUG_BANK3_TAIL_B6_ACT1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_LAST, data);
            $display("JTAG_DEBUG_BANK3_TAIL_RGB_Q_HASH=0x%08x", data);
        end
        if (DEBUG_EXPORT_LEVEL >= 3) begin
            axi_write(REG_PERF_CTRL, 32'h0000_0400);
            axi_read(REG_INPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK4_SCHED_FEAT0_HASH=0x%08x", data);
            axi_read(REG_INPUT_PIXEL, data);
            $display("JTAG_DEBUG_BANK4_SCHED_B1_HASH=0x%08x", data);
            axi_read(REG_OUTPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK4_SRC_B1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_HASH, data);
            $display("JTAG_DEBUG_BANK4_TAIL_B1_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_RANGE, data);
            $display("JTAG_DEBUG_BANK4_SPAB_B1_ATT_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_FIRST, data);
            $display("JTAG_DEBUG_BANK4_SPAB_B1_C3_HASH=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_LAST, data);
            $display("JTAG_DEBUG_BANK4_SPAB_B1_RESIDUAL_HASH=0x%08x", data);
            axi_write(REG_PERF_CTRL, 32'h0000_0500);
            axi_read(REG_INPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK5_FRONT_STATE=0x%08x", data);
            axi_read(REG_INPUT_PIXEL, data);
            $display("JTAG_DEBUG_BANK5_C1_COUNTS=0x%08x", data);
            axi_read(REG_OUTPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK5_C2_COUNTS=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_HASH, data);
            $display("JTAG_DEBUG_BANK5_C3_COUNTS=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_RANGE, data);
            $display("JTAG_DEBUG_BANK5_ATT_COUNTS=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_FIRST, data);
            $display("JTAG_DEBUG_BANK5_BLOCK_COUNTS=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_LAST, data);
            $display("JTAG_DEBUG_BANK5_REPLAY_COUNT=0x%08x", data);
            axi_write(REG_PERF_CTRL, 32'h0000_0600);
            axi_read(REG_INPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK6_C1_DETAIL=0x%08x", data);
            axi_read(REG_INPUT_PIXEL, data);
            $display("JTAG_DEBUG_BANK6_C1_CORE_DETAIL=0x%08x", data);
            axi_read(REG_OUTPUT_FLAGS, data);
            $display("JTAG_DEBUG_BANK6_C1_LANE_DETAIL=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_HASH, data);
            $display("JTAG_DEBUG_BANK6_C1_IO_DETAIL=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_RANGE, data);
            $display("JTAG_DEBUG_BANK6_C2_DETAIL=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_FIRST, data);
            $display("JTAG_DEBUG_BANK6_C2_CORE_DETAIL=0x%08x", data);
            axi_read(REG_DEBUG_WRITEBACK_LAST, data);
            $display("JTAG_DEBUG_BANK6_C2_LANE_DETAIL=0x%08x", data);
        end
        if (DEBUG_EXPORT_LEVEL >= 2)
            axi_write(REG_PERF_CTRL, 32'h0000_0000);

        dump_output_rgb_dump();
        $display("PASS sr_jtag_w8a12_tile_writer_endpoint_raw_compare inputs=%0d outputs=%0d",
                 IN_PIXELS, OUT_PIXELS);
        $finish;
    end

    initial begin
        repeat (MAX_CYCLES + 100000) @(posedge clk);
        $fatal(1, "global timeout JTAG raw compare out_count=%0d", out_count);
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            cyc <= 0;
        end else begin
            cyc <= cyc + 1;
        end
    end

    wire unused = irq ^ |awprot ^ |arprot ^ |wstrb ^ |cyc;
endmodule
