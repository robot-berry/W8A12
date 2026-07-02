`timescale 1ns/1ps

// AXI-Lite endpoint for JTAG acceptance of the hardware-side W8A12 tile path.
//
// The host writes one complete LR frame into an on-chip input buffer through
// the same simple pixel registers used by the existing JTAG smoke flow. After
// the last input pixel is accepted, the endpoint starts the tile writer shell.
// The shell reads pixels back by address, so tile/halo fetch is still performed
// by hardware rather than by PC-side pre-cut tiles.
module sr_jtag_w8a12_tile_writer_endpoint #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 32,
    parameter integer TILE_W = 32,
    parameter integer TILE_H = 32,
    parameter integer HALO = 21,
    parameter integer SCALE = 4,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer SCALE_LANES = 2,
    parameter integer DEBUG_EXPORT_LEVEL = 2,
    parameter integer IN_PIXELS = IMG_W * IMG_W,
    parameter integer OUT_PIXELS = IMG_W * IMG_W * SCALE * SCALE,
    parameter integer IN_IDX_W = (IN_PIXELS <= 2) ? 1 : $clog2(IN_PIXELS),
    parameter integer OUT_IDX_W = (OUT_PIXELS <= 2) ? 1 : $clog2(OUT_PIXELS)
) (
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                        s_axi_arprot,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    output wire                              irq
);
    localparam [5:0] REG_STATUS       = 6'h00;
    localparam [5:0] REG_INPUT_FLAGS  = 6'h04;
    localparam [5:0] REG_INPUT_PIXEL  = 6'h08;
    localparam [5:0] REG_OUTPUT_PIXEL = 6'h0c;
    localparam [5:0] REG_OUTPUT_FLAGS = 6'h10;
    localparam [5:0] REG_COUNTER_IN   = 6'h14;
    localparam [5:0] REG_COUNTER_OUT  = 6'h18;
    localparam [5:0] REG_ERROR        = 6'h1c;
    localparam [5:0] REG_FRAME_CYCLES = 6'h20;
    localparam [5:0] REG_FRAME_DONE   = 6'h24;
    localparam [5:0] REG_PERF_CTRL    = 6'h28;
    localparam [5:0] REG_E2E_CYCLES   = 6'h2c;
    localparam [5:0] REG_DEBUG_WRITEBACK_HASH  = 6'h30;
    localparam [5:0] REG_DEBUG_WRITEBACK_RANGE = 6'h34;
    localparam [5:0] REG_DEBUG_WRITEBACK_FIRST = 6'h38;
    localparam [5:0] REG_DEBUG_WRITEBACK_LAST  = 6'h3c;

    localparam [ADDR_W-1:0] INPUT_BASE_ADDR = {ADDR_W{1'b0}};
    localparam [ADDR_W-1:0] OUTPUT_BASE_ADDR = {ADDR_W{1'b0}};
    localparam [COORD_W-1:0] IMG_W_C = IMG_W[COORD_W-1:0];

    reg [DATA_W-1:0] input_mem [0:IN_PIXELS-1];
    reg [DATA_W-1:0] output_mem [0:OUT_PIXELS-1];

    wire rst = !s_axi_aresetn;
    wire write_accept = !s_axi_bvalid && s_axi_awvalid && s_axi_wvalid;
    wire read_accept = !s_axi_rvalid && s_axi_arvalid;

    reg [31:0] input_count;
    reg [31:0] output_count;
    reg [31:0] output_read_count;
    reg [31:0] frame_cycle_count;
    reg [31:0] frame_cycle_latched;
    reg [31:0] e2e_cycle_count;
    reg [31:0] e2e_cycle_latched;
    reg frame_active;
    reg frame_done;
    reg perf_drain_enable;
    reg [7:0] debug_bank;
    reg input_drop_error;
    reg output_overrun_error;
    reg mem_addr_error;
    reg core_start;

    wire core_busy;
    wire core_done;
    wire core_error;
    wire [31:0] tiles_done;
    wire [15:0] block_start_count;
    wire [31:0] replay_feature_count;
    wire [31:0] block_output_count;
    wire rd_req_valid;
    wire rd_req_ready;
    wire [ADDR_W-1:0] rd_req_addr;
    wire [ADDR_W-1:0] rd_req_byte_offset = rd_req_addr - INPUT_BASE_ADDR;
    wire [31:0] rd_req_index = rd_req_byte_offset / BYTES_PER_PIXEL;
    wire rd_req_index_bad = (rd_req_index >= IN_PIXELS);
    reg rd_resp_valid;
    reg [DATA_W-1:0] rd_resp_data;
    reg rd_resp_pending;
    reg rd_resp_bad;
    reg [IN_IDX_W-1:0] rd_pending_index;
    wire wr_valid;
    wire wr_ready;
    wire [ADDR_W-1:0] wr_addr;
    wire [DATA_W-1:0] wr_data;
    wire [31:0] debug_writeback_hash;
    wire [31:0] debug_writeback_range;
    wire [31:0] debug_writeback_first;
    wire [31:0] debug_writeback_last;
    wire [31:0] debug_tail_feat0_hash;
    wire [31:0] debug_tail_block6_hash;
    wire [31:0] debug_tail_b1_hash;
    wire [31:0] debug_tail_b6_act1_hash;
    wire [31:0] debug_tail_rgb_q_hash;
    wire [31:0] debug_src_feat0_hash;
    wire [31:0] debug_src_block6_hash;
    wire [31:0] debug_src_b1_hash;
    wire [31:0] debug_src_b6_act1_hash;
    wire [31:0] debug_spab_b1_hash_input;
    wire [31:0] debug_spab_b1_hash_c1;
    wire [31:0] debug_spab_b1_hash_c1_raw;
    wire [31:0] debug_spab_b1_hash_c2;
    wire [31:0] debug_spab_b1_hash_c2_replay;
    wire [31:0] debug_spab_b1_hash_c2_window;
    wire [31:0] debug_spab_b1_hash_c3;
    wire [31:0] debug_spab_b1_hash_residual;
    wire [31:0] debug_spab_b1_hash_att;
    reg [31:0] debug_slot_04;
    reg [31:0] debug_slot_08;
    reg [31:0] debug_slot_10;
    reg [31:0] debug_slot_30;
    reg [31:0] debug_slot_34;
    reg [31:0] debug_slot_38;
    reg [31:0] debug_slot_3c;

    wire input_ready = !core_busy && !frame_active && (input_count < IN_PIXELS);
    wire output_valid = !perf_drain_enable && (output_read_count < output_count);
    wire output_last = (output_read_count == (OUT_PIXELS - 1));
    wire input_pixel_write = write_accept && (s_axi_awaddr[5:0] == REG_INPUT_PIXEL);
    wire last_input_write = input_pixel_write && input_ready &&
                            (input_count == (IN_PIXELS - 1));
    wire output_pixel_read = read_accept && (s_axi_araddr[5:0] == REG_OUTPUT_PIXEL) &&
                             output_valid;
    assign irq = output_valid || frame_done;
    assign rd_req_ready = !rd_resp_pending;
    assign wr_ready = 1'b1;

    sr_tile_halo_fetch_w8a12_front_tail_writer_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .HALO(HALO),
        .SCALE(SCALE),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .SCALE_LANES(SCALE_LANES),
        .DEBUG_SRC_HASH((DEBUG_EXPORT_LEVEL >= 2) ? 1 : 0),
        .DEBUG_SPAB_HASH((DEBUG_EXPORT_LEVEL >= 3) ? 1 : 0)
    ) u_tile_writer (
        .clk(s_axi_aclk),
        .rst(rst),
        .start(core_start),
        .image_w(IMG_W_C),
        .image_h(IMG_W_C),
        .input_base(INPUT_BASE_ADDR),
        .output_base(OUTPUT_BASE_ADDR),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(core_busy),
        .done(core_done),
        .error(core_error),
        .tiles_done(tiles_done),
        .block_start_count(block_start_count),
        .replay_feature_count(replay_feature_count),
        .block_output_count(block_output_count),
        .rgb_output_count(),
        .front_debug_tail_feat0_hash(debug_tail_feat0_hash),
        .front_debug_tail_block6_hash(debug_tail_block6_hash),
        .front_debug_tail_b1_hash(debug_tail_b1_hash),
        .front_debug_tail_b6_act1_hash(debug_tail_b6_act1_hash),
        .front_debug_tail_rgb_q_hash(debug_tail_rgb_q_hash),
        .front_debug_src_feat0_hash(debug_src_feat0_hash),
        .front_debug_src_block6_hash(debug_src_block6_hash),
        .front_debug_src_b1_hash(debug_src_b1_hash),
        .front_debug_src_b6_act1_hash(debug_src_b6_act1_hash),
        .front_debug_spab_b1_hash_input(debug_spab_b1_hash_input),
        .front_debug_spab_b1_hash_c1(debug_spab_b1_hash_c1),
        .front_debug_spab_b1_hash_c1_raw(debug_spab_b1_hash_c1_raw),
        .front_debug_spab_b1_hash_c2(debug_spab_b1_hash_c2),
        .front_debug_spab_b1_hash_c2_replay(debug_spab_b1_hash_c2_replay),
        .front_debug_spab_b1_hash_c2_window(debug_spab_b1_hash_c2_window),
        .front_debug_spab_b1_hash_c3(debug_spab_b1_hash_c3),
        .front_debug_spab_b1_hash_residual(debug_spab_b1_hash_residual),
        .front_debug_spab_b1_hash_att(debug_spab_b1_hash_att),
        .front_debug_writeback_hash(debug_writeback_hash),
        .front_debug_writeback_range(debug_writeback_range),
        .front_debug_writeback_first(debug_writeback_first),
        .front_debug_writeback_last(debug_writeback_last)
    );

    always @* begin
        debug_slot_04 = 32'd0;
        debug_slot_08 = 32'd0;
        debug_slot_10 = {30'd0, output_last, 1'b0};
        debug_slot_30 = 32'd0;
        debug_slot_34 = 32'd0;
        debug_slot_38 = 32'd0;
        debug_slot_3c = 32'd0;
        if (DEBUG_EXPORT_LEVEL >= 1) begin
            debug_slot_04 = debug_tail_b1_hash;
            debug_slot_08 = debug_tail_b6_act1_hash;
            debug_slot_10 = debug_tail_rgb_q_hash;
            debug_slot_30 = debug_writeback_hash;
            debug_slot_34 = debug_writeback_range;
            debug_slot_38 = debug_writeback_first;
            debug_slot_3c = debug_writeback_last;
            case (debug_bank)
                8'h01: begin
                    debug_slot_04 = debug_tail_feat0_hash;
                    debug_slot_08 = debug_src_feat0_hash;
                    debug_slot_10 = debug_src_b1_hash;
                    debug_slot_30 = debug_tail_b1_hash;
                    debug_slot_34 = debug_tail_b6_act1_hash;
                    debug_slot_38 = debug_tail_rgb_q_hash;
                    debug_slot_3c = debug_writeback_hash;
                end
                8'h02: begin
                    if (DEBUG_EXPORT_LEVEL >= 3) begin
                        debug_slot_04 = debug_spab_b1_hash_c1_raw;
                        debug_slot_08 = debug_spab_b1_hash_c2_replay;
                        debug_slot_10 = debug_spab_b1_hash_c2_window;
                        debug_slot_30 = debug_spab_b1_hash_residual;
                        debug_slot_34 = debug_spab_b1_hash_att;
                        debug_slot_38 = debug_tail_b1_hash;
                        debug_slot_3c = debug_tail_rgb_q_hash;
                    end
                end
                8'h03: begin
                    if (DEBUG_EXPORT_LEVEL >= 2) begin
                        debug_slot_04 = debug_src_feat0_hash;
                        debug_slot_08 = debug_src_block6_hash;
                        debug_slot_10 = debug_src_b1_hash;
                        debug_slot_30 = debug_src_b6_act1_hash;
                        debug_slot_34 = debug_tail_b1_hash;
                        debug_slot_38 = debug_tail_b6_act1_hash;
                        debug_slot_3c = debug_tail_rgb_q_hash;
                    end
                end
                default: begin
                end
            endcase
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
        end else begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            if (write_accept) begin
                s_axi_awready <= 1'b1;
                s_axi_wready <= 1'b1;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= 2'b00;
            s_axi_rdata <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else begin
            s_axi_arready <= 1'b0;
            if (read_accept) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;
                case (s_axi_araddr[5:0])
                    REG_STATUS:
                        s_axi_rdata <= {
                            17'd0,
                            core_busy,
                            frame_done,
                            output_overrun_error | mem_addr_error | core_error,
                            input_drop_error,
                            output_last,
                            1'b0,
                            output_valid,
                            input_ready,
                            6'd0
                        };
                    REG_OUTPUT_PIXEL:
                        s_axi_rdata <= output_valid ?
                            {8'd0, output_mem[output_read_count[OUT_IDX_W-1:0]]} :
                            32'd0;
                    REG_INPUT_FLAGS:
                        s_axi_rdata <= debug_slot_04;
                    REG_INPUT_PIXEL:
                        s_axi_rdata <= debug_slot_08;
                    REG_OUTPUT_FLAGS:
                        s_axi_rdata <= debug_slot_10;
                    REG_COUNTER_IN:
                        s_axi_rdata <= input_count;
                    REG_COUNTER_OUT:
                        s_axi_rdata <= output_count;
                    REG_ERROR:
                        s_axi_rdata <= {28'd0, core_error, mem_addr_error,
                                        output_overrun_error, input_drop_error};
                    REG_FRAME_CYCLES:
                        s_axi_rdata <= frame_cycle_latched;
                    REG_FRAME_DONE:
                        s_axi_rdata <= {31'd0, frame_done};
                    REG_PERF_CTRL:
                        s_axi_rdata <= {16'd0, debug_bank, 7'd0, perf_drain_enable};
                    REG_E2E_CYCLES:
                        s_axi_rdata <= e2e_cycle_latched;
                    REG_DEBUG_WRITEBACK_HASH:
                        s_axi_rdata <= debug_slot_30;
                    REG_DEBUG_WRITEBACK_RANGE:
                        s_axi_rdata <= debug_slot_34;
                    REG_DEBUG_WRITEBACK_FIRST:
                        s_axi_rdata <= debug_slot_38;
                    REG_DEBUG_WRITEBACK_LAST:
                        s_axi_rdata <= debug_slot_3c;
                    default:
                        s_axi_rdata <= 32'd0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            input_count <= 32'd0;
            output_count <= 32'd0;
            output_read_count <= 32'd0;
            frame_cycle_count <= 32'd0;
            frame_cycle_latched <= 32'd0;
            e2e_cycle_count <= 32'd0;
            e2e_cycle_latched <= 32'd0;
            frame_active <= 1'b0;
            frame_done <= 1'b0;
            perf_drain_enable <= 1'b0;
            debug_bank <= 8'd0;
            input_drop_error <= 1'b0;
            output_overrun_error <= 1'b0;
            mem_addr_error <= 1'b0;
            core_start <= 1'b0;
            output_mem[0] <= {DATA_W{1'b0}};
        end else begin
            core_start <= 1'b0;

            if (write_accept) begin
                case (s_axi_awaddr[5:0])
                    REG_INPUT_PIXEL: begin
                        if (input_ready) begin
                            input_mem[input_count[IN_IDX_W-1:0]] <= s_axi_wdata[DATA_W-1:0];
                            input_count <= input_count + 32'd1;
                            if (last_input_write) begin
                                core_start <= 1'b1;
                                frame_active <= 1'b1;
                                frame_done <= 1'b0;
                                frame_cycle_count <= 32'd0;
                                frame_cycle_latched <= 32'd0;
                                e2e_cycle_count <= 32'd0;
                                e2e_cycle_latched <= 32'd0;
                                output_count <= 32'd0;
                                output_read_count <= 32'd0;
                            end
                        end else begin
                            input_drop_error <= 1'b1;
                        end
                    end
                    REG_ERROR: begin
                        if (s_axi_wdata[0] || s_axi_wdata[1]) begin
                            input_count <= 32'd0;
                            output_count <= 32'd0;
                            output_read_count <= 32'd0;
                            frame_cycle_count <= 32'd0;
                            frame_cycle_latched <= 32'd0;
                            e2e_cycle_count <= 32'd0;
                            e2e_cycle_latched <= 32'd0;
                            frame_active <= 1'b0;
                            frame_done <= 1'b0;
                            input_drop_error <= 1'b0;
                            output_overrun_error <= 1'b0;
                            mem_addr_error <= 1'b0;
                        end
                    end
                    REG_PERF_CTRL: begin
                        perf_drain_enable <= s_axi_wdata[0];
                        debug_bank <= s_axi_wdata[15:8];
                    end
                    default: begin
                    end
                endcase
            end

            if (output_pixel_read)
                output_read_count <= output_read_count + 32'd1;

            if (frame_active) begin
                frame_cycle_count <= frame_cycle_count + 32'd1;
                e2e_cycle_count <= e2e_cycle_count + 32'd1;
            end
            if (core_done && frame_active) begin
                frame_active <= 1'b0;
                frame_done <= 1'b1;
                frame_cycle_latched <= frame_cycle_count + 32'd1;
                e2e_cycle_latched <= e2e_cycle_count + 32'd1;
            end
            if (core_error)
                mem_addr_error <= 1'b1;
            if (rd_resp_valid && rd_resp_bad)
                mem_addr_error <= 1'b1;

            if (wr_valid && wr_ready) begin
                if (output_count < OUT_PIXELS) begin
                    output_mem[output_count[OUT_IDX_W-1:0]] <= wr_data;
                    output_count <= output_count + 32'd1;
                end else begin
                    output_overrun_error <= 1'b1;
                end
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            rd_resp_valid <= 1'b0;
            rd_resp_data <= {DATA_W{1'b0}};
            rd_resp_pending <= 1'b0;
            rd_resp_bad <= 1'b0;
            rd_pending_index <= {IN_IDX_W{1'b0}};
        end else begin
            rd_resp_valid <= 1'b0;
            if (rd_resp_pending) begin
                rd_resp_valid <= 1'b1;
                rd_resp_data <= rd_resp_bad ? {DATA_W{1'b0}} : input_mem[rd_pending_index];
                rd_resp_pending <= 1'b0;
            end
            if (rd_req_valid && rd_req_ready) begin
                rd_resp_pending <= 1'b1;
                if (rd_req_index_bad) begin
                    rd_resp_bad <= 1'b1;
                    rd_pending_index <= {IN_IDX_W{1'b0}};
                end else begin
                    rd_resp_bad <= 1'b0;
                    rd_pending_index <= rd_req_index[IN_IDX_W-1:0];
                end
            end
        end
    end

    wire unused_axi = |s_axi_awprot | |s_axi_arprot | |s_axi_wstrb |
                      |block_start_count | |replay_feature_count |
                      |block_output_count | |tiles_done | |wr_addr;
endmodule
