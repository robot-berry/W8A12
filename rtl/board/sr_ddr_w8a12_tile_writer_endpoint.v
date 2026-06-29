`timescale 1ns/1ps

// DDR-backed W8A12 tile-writer endpoint.
//
// Control is AXI-Lite from PS. Image data stays in DDR as XRGB888 words:
// - input_base points to LR frame, one 32-bit word per RGB pixel.
// - output_base points to HR frame, one 32-bit word per RGB pixel.
// PL performs hardware tile scheduling, halo reads, W8A12 compute and writes
// the super-resolved frame back to DDR.
module sr_ddr_w8a12_tile_writer_endpoint #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 10,
    parameter integer M_AXI_DATA_WIDTH = 32,
    parameter integer DATA_W = 24,
    parameter integer DEFAULT_IMG_W = 320,
    parameter integer DEFAULT_IMG_H = 180,
    parameter integer DEFAULT_INPUT_BASE = 32'h1000_0000,
    parameter integer DEFAULT_OUTPUT_BASE = 32'h1100_0000,
    parameter integer TILE_W = 20,
    parameter integer TILE_H = 20,
    parameter integer HALO = 21,
    parameter integer SCALE = 4,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 24,
    parameter integer TAP_LANES = 64,
    parameter integer SCALE_LANES = 2,
    parameter integer DEBUG_SRC_HASH = 0,
    parameter integer DEBUG_TAIL_HANDSHAKE = 0,
    parameter integer USE_FULL_STREAMED_WRITER = 0,
    parameter integer MIRROR_FIFO_DEPTH = 1024
) (
    input  wire                                  s_axi_aclk,
    input  wire                                  s_axi_aresetn,
    input  wire                                  m_axi_aclk,
    input  wire                                  m_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         s_axi_awaddr,
    input  wire [2:0]                            s_axi_awprot,
    input  wire                                  s_axi_awvalid,
    output wire                                  s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]         s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb,
    input  wire                                  s_axi_wvalid,
    output wire                                  s_axi_wready,

    output reg  [1:0]                            s_axi_bresp,
    output reg                                   s_axi_bvalid,
    input  wire                                  s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         s_axi_araddr,
    input  wire [2:0]                            s_axi_arprot,
    input  wire                                  s_axi_arvalid,
    output reg                                   s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]         s_axi_rdata,
    output reg  [1:0]                            s_axi_rresp,
    output reg                                   s_axi_rvalid,
    input  wire                                  s_axi_rready,

    output wire [ADDR_W-1:0]                     m_axi_awaddr,
    output wire [7:0]                            m_axi_awlen,
    output wire [2:0]                            m_axi_awsize,
    output wire [1:0]                            m_axi_awburst,
    output wire [3:0]                            m_axi_awcache,
    output wire [2:0]                            m_axi_awprot,
    output wire                                  m_axi_awvalid,
    input  wire                                  m_axi_awready,

    output wire [M_AXI_DATA_WIDTH-1:0]           m_axi_wdata,
    output wire [(M_AXI_DATA_WIDTH/8)-1:0]       m_axi_wstrb,
    output wire                                  m_axi_wlast,
    output wire                                  m_axi_wvalid,
    input  wire                                  m_axi_wready,

    input  wire [1:0]                            m_axi_bresp,
    input  wire                                  m_axi_bvalid,
    output wire                                  m_axi_bready,

    output wire [ADDR_W-1:0]                     m_axi_araddr,
    output wire [7:0]                            m_axi_arlen,
    output wire [2:0]                            m_axi_arsize,
    output wire [1:0]                            m_axi_arburst,
    output wire [3:0]                            m_axi_arcache,
    output wire [2:0]                            m_axi_arprot,
    output wire                                  m_axi_arvalid,
    input  wire                                  m_axi_arready,

    input  wire [M_AXI_DATA_WIDTH-1:0]           m_axi_rdata,
    input  wire [1:0]                            m_axi_rresp,
    input  wire                                  m_axi_rlast,
    input  wire                                  m_axi_rvalid,
    output wire                                  m_axi_rready,

    output wire                                  irq
);
    localparam [9:0] REG_CONTROL        = 10'h000;
    localparam [9:0] REG_STATUS         = 10'h004;
    localparam [9:0] REG_IMG_W          = 10'h008;
    localparam [9:0] REG_IMG_H          = 10'h00c;
    localparam [9:0] REG_INPUT_BASE     = 10'h010;
    localparam [9:0] REG_OUTPUT_BASE    = 10'h014;
    localparam [9:0] REG_FRAME_CYCLES   = 10'h018;
    localparam [9:0] REG_TILES_DONE     = 10'h01c;
    localparam [9:0] REG_ERROR          = 10'h020;
    localparam [9:0] REG_BLOCK_STARTS   = 10'h024;
    localparam [9:0] REG_BLOCK_OUTPUTS  = 10'h028;
    localparam [9:0] REG_REPLAY_FEATURE = 10'h02c;
    localparam [9:0] REG_CONFIG         = 10'h030;
    localparam [9:0] REG_DEBUG_STATE    = 10'h034;
    localparam [9:0] REG_DEBUG_C1       = 10'h038;
    localparam [9:0] REG_DEBUG_C2       = 10'h03c;
    localparam [9:0] REG_DEBUG_C3       = 10'h040;
    localparam [9:0] REG_DEBUG_ATT      = 10'h044;
    localparam [9:0] REG_DEBUG_C1_LANE  = 10'h048;
    localparam [9:0] REG_DEBUG_C2_LANE  = 10'h04c;
    localparam [9:0] REG_DEBUG_C3_LANE  = 10'h050;
    localparam [9:0] REG_DEBUG_ATT_LANE = 10'h054;
    localparam [9:0] REG_DEBUG_C1_DETAIL = 10'h058;
    localparam [9:0] REG_DEBUG_C2_DETAIL = 10'h05c;
    localparam [9:0] REG_DEBUG_C3_DETAIL = 10'h060;
    localparam [9:0] REG_DEBUG_C2_CORE_DETAIL = 10'h064;
    localparam [9:0] REG_DEBUG_C2_LANE_DETAIL = 10'h068;
    localparam [9:0] REG_DEBUG_C3_CORE_DETAIL = 10'h06c;
    localparam [9:0] REG_DEBUG_C3_LANE_DETAIL = 10'h070;
    localparam [9:0] REG_DEBUG_C3_IO_DETAIL = 10'h074;
    localparam [9:0] REG_DEBUG_TAIL_FEAT0_HASH = 10'h078;
    localparam [9:0] REG_DEBUG_TAIL_BLOCK6_HASH = 10'h07c;
    localparam [9:0] REG_DEBUG_TAIL_B1_HASH = 10'h080;
    localparam [9:0] REG_DEBUG_TAIL_B6_ACT1_HASH = 10'h084;
    localparam [9:0] REG_DEBUG_TAIL_RGB_Q_HASH = 10'h088;
    localparam [9:0] REG_DEBUG_SRC_FEAT0_HASH = 10'h08c;
    localparam [9:0] REG_DEBUG_SRC_BLOCK6_HASH = 10'h090;
    localparam [9:0] REG_DEBUG_SRC_B1_HASH = 10'h094;
    localparam [9:0] REG_DEBUG_SRC_B6_ACT1_HASH = 10'h098;
    localparam [9:0] REG_DEBUG_SPAB_FLAGS = 10'h09c;
    localparam [9:0] REG_DEBUG_ATT_DETAIL = 10'h0a0;
    localparam [9:0] REG_DEBUG_C1_CORE_DETAIL = 10'h0a4;
    localparam [9:0] REG_DEBUG_C1_LANE_DETAIL = 10'h0a8;
    localparam [9:0] REG_DEBUG_C1_IO_DETAIL = 10'h0ac;
    localparam [9:0] REG_DEBUG_SPAB_B1_C1_SAMPLE0 = 10'h0b0;
    localparam [9:0] REG_DEBUG_SPAB_B1_C1_SAMPLE1 = 10'h0b4;
    localparam [9:0] REG_DEBUG_SPAB_B1_C1_SAMPLE2 = 10'h0b8;
    localparam [9:0] REG_DEBUG_SPAB_B1_C1_SAMPLE3 = 10'h0bc;
    localparam [9:0] REG_DEBUG_SPAB_HASH_RESIDUAL = 10'h0c0;
    localparam [9:0] REG_DEBUG_SPAB_HASH_ATT = 10'h0c4;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_INPUT = 10'h0c8;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_C1 = 10'h0cc;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_C2 = 10'h0d0;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_C3 = 10'h0d4;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_RESIDUAL = 10'h0d8;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_ATT = 10'h0dc;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_C2_REPLAY = 10'h0e0;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_C2_WINDOW = 10'h0e4;
    localparam [9:0] REG_DEBUG_SPAB_B1_HASH_C1_RAW = 10'h0e8;
    localparam [9:0] REG_DEBUG_RGB_OUTPUT_COUNT = 10'h0ec;
    localparam [9:0] REG_DEBUG_WRITEBACK_HASH = 10'h0f0;
    localparam [9:0] REG_DEBUG_WRITEBACK_RANGE = 10'h0f4;
    localparam [9:0] REG_DEBUG_WRITEBACK_FIRST = 10'h0f8;
    localparam [9:0] REG_DEBUG_WRITEBACK_LAST = 10'h0fc;
    localparam [9:0] REG_MIRROR_OUTPUT_PIXEL = 10'h100;
    localparam [9:0] REG_MIRROR_OUTPUT_COUNT = 10'h104;
    localparam [9:0] REG_MIRROR_OUTPUT_READ_COUNT = 10'h108;
    localparam [9:0] REG_MIRROR_STATUS = 10'h10c;
    localparam [9:0] REG_MIRROR_OUTPUT_INDEX = 10'h110;
    localparam [9:0] REG_DEBUG_WR_HANDSHAKE = 10'h114;
    localparam [9:0] REG_DEBUG_WR_FIRE_COUNT = 10'h118;
    localparam [9:0] REG_DEBUG_WR_LAST_ADDR = 10'h11c;
    localparam [9:0] REG_DEBUG_WR_LAST_DATA = 10'h120;
    localparam [9:0] REG_DEBUG_AXI_WRITE_COUNTS = 10'h124;
    localparam [9:0] REG_DEBUG_AXI_RESP_COUNTS = 10'h128;
    localparam [9:0] REG_DEBUG_AXI_STATE = 10'h12c;
    localparam [9:0] REG_DEBUG_SPAB_B2_HASH_ATT = 10'h130;
    localparam [9:0] REG_DEBUG_SPAB_B3_HASH_ATT = 10'h134;
    localparam [9:0] REG_DEBUG_SPAB_B4_HASH_ATT = 10'h138;
    localparam [9:0] REG_DEBUG_SPAB_B5_HASH_ATT = 10'h13c;
    localparam [7:0] TILE_W_U8 = TILE_W;
    localparam [7:0] TILE_H_U8 = TILE_H;
    localparam [7:0] SCALE_U8 = SCALE;
    localparam integer OUT_PIXELS = TILE_W * TILE_H * SCALE * SCALE;
    localparam integer OUT_PIX_W = (OUT_PIXELS <= 2) ? 1 : $clog2(OUT_PIXELS + 1);
    localparam [31:0] OUT_PIXELS_U32 = OUT_PIXELS;
    localparam [31:0] OUT_PIXELS_LAST_U32 = OUT_PIXELS - 1;

    wire rst = !s_axi_aresetn;

    reg aw_hold_valid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] aw_hold_addr;
    reg w_hold_valid;
    reg [C_S_AXI_DATA_WIDTH-1:0] w_hold_data;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] w_hold_strb;
    wire write_fire = aw_hold_valid && w_hold_valid && !s_axi_bvalid;

    reg [COORD_W-1:0] image_w_q;
    reg [COORD_W-1:0] image_h_q;
    reg [ADDR_W-1:0] input_base_q;
    reg [ADDR_W-1:0] output_base_q;
    reg core_start;
    reg frame_active;
    reg frame_done;
    reg [31:0] frame_cycles_q;
    reg [31:0] frame_cycles_latched;
    reg sw_error;

    wire core_busy;
    wire core_done;
    wire core_error;
    wire [31:0] tiles_done;
    wire [15:0] block_start_count;
    wire [31:0] replay_feature_count;
    wire [31:0] block_output_count;
    wire [OUT_PIX_W-1:0] rgb_output_count;
    wire [31:0] rgb_output_count_dbg =
        {{(32-OUT_PIX_W){1'b0}}, rgb_output_count};
    wire [31:0] front_debug_state;
    wire [31:0] front_debug_c1_counts;
    wire [31:0] front_debug_c2_counts;
    wire [31:0] front_debug_c3_counts;
    wire [31:0] front_debug_att_counts;
    wire [31:0] front_debug_c1_lane_outputs;
    wire [31:0] front_debug_c2_lane_outputs;
    wire [31:0] front_debug_c3_lane_outputs;
    wire [31:0] front_debug_att_lane_outputs;
    wire [31:0] front_debug_c1_detail;
    wire [31:0] front_debug_c1_core_detail;
    wire [31:0] front_debug_c1_lane_detail;
    wire [31:0] front_debug_c1_io_detail;
    wire [31:0] front_debug_c2_detail;
    wire [31:0] front_debug_c3_detail;
    wire [31:0] front_debug_c2_core_detail;
    wire [31:0] front_debug_c2_lane_detail;
    wire [31:0] front_debug_c3_core_detail;
    wire [31:0] front_debug_c3_lane_detail;
    wire [31:0] front_debug_c3_io_detail;
    wire [31:0] front_debug_spab_flags;
    wire [31:0] front_debug_att_detail;
    wire [31:0] front_debug_tail_feat0_hash;
    wire [31:0] front_debug_tail_block6_hash;
    wire [31:0] front_debug_tail_b1_hash;
    wire [31:0] front_debug_tail_b6_act1_hash;
    wire [31:0] front_debug_tail_rgb_q_hash;
    wire [31:0] front_debug_src_feat0_hash;
    wire [31:0] front_debug_src_block6_hash;
    wire [31:0] front_debug_src_b1_hash;
    wire [31:0] front_debug_src_b6_act1_hash;
    wire [31:0] front_debug_spab_hash_input;
    wire [31:0] front_debug_spab_hash_c1;
    wire [31:0] front_debug_spab_hash_c2;
    wire [31:0] front_debug_spab_hash_c3;
    wire [31:0] front_debug_spab_hash_residual;
    wire [31:0] front_debug_spab_hash_att;
    wire [31:0] front_debug_spab_b1_hash_input;
    wire [31:0] front_debug_spab_b1_hash_c1;
    wire [31:0] front_debug_spab_b1_hash_c1_raw;
    wire [31:0] front_debug_spab_b1_c1_sample0;
    wire [31:0] front_debug_spab_b1_c1_sample1;
    wire [31:0] front_debug_spab_b1_c1_sample2;
    wire [31:0] front_debug_spab_b1_c1_sample3;
    wire [31:0] front_debug_spab_b2_hash_att;
    wire [31:0] front_debug_spab_b3_hash_att;
    wire [31:0] front_debug_spab_b4_hash_att;
    wire [31:0] front_debug_spab_b5_hash_att;
    wire [31:0] front_debug_writer_rgb_hash;
    wire [31:0] front_debug_writer_rgb_range;
    wire [31:0] front_debug_writer_rgb_first;
    wire [31:0] front_debug_writer_rgb_last;
    wire [31:0] front_debug_writeback_hash;
    wire [31:0] front_debug_writeback_range;
    wire [31:0] front_debug_writeback_first;
    wire [31:0] front_debug_writeback_last;
    wire [31:0] front_debug_spab_b1_hash_c2;
    wire [31:0] front_debug_spab_b1_hash_c2_replay;
    wire [31:0] front_debug_spab_b1_hash_c2_window;
    wire [31:0] front_debug_spab_b1_hash_c2_raw;
    wire [31:0] front_debug_spab_b1_c2_sample0;
    wire [31:0] front_debug_spab_b1_c2_sample1;
    wire [31:0] front_debug_spab_b1_c2_sample2;
    wire [31:0] front_debug_spab_b1_c2_sample3;
    wire [31:0] front_debug_spab_b1_hash_c3;
    wire [31:0] front_debug_spab_b1_hash_residual;
    wire [31:0] front_debug_spab_b1_hash_att;
    wire ddr_busy;
    wire ddr_error;

    wire core_rd_req_valid;
    wire core_rd_req_ready;
    wire [ADDR_W-1:0] core_rd_req_addr;
    wire core_rd_resp_valid;
    wire [DATA_W-1:0] core_rd_resp_data;
    wire ddr_rd_req_valid;
    wire ddr_rd_req_ready;
    wire [ADDR_W-1:0] ddr_rd_req_addr;
    wire ddr_rd_resp_valid;
    wire [DATA_W-1:0] ddr_rd_resp_data;
    wire wr_valid;
    wire wr_ready;
    wire [ADDR_W-1:0] wr_addr;
    wire [DATA_W-1:0] wr_data;
    wire wr_data_fire = wr_valid && wr_ready;
    wire axi_aw_fire = m_axi_awvalid && m_axi_awready;
    wire axi_w_fire = m_axi_wvalid && m_axi_wready;
    wire axi_b_fire = m_axi_bvalid && m_axi_bready;
    wire axi_ar_fire = m_axi_arvalid && m_axi_arready;
    wire axi_r_fire = m_axi_rvalid && m_axi_rready;
    wire debug_counter_clear =
        write_fire &&
        (aw_hold_addr[9:0] == REG_CONTROL) &&
        (w_hold_data[0] || w_hold_data[1]);
    reg [15:0] debug_wr_valid_cycles;
    reg [15:0] debug_wr_ready_cycles;
    reg [15:0] debug_wr_fire_count;
    reg [15:0] debug_axi_aw_count;
    reg [15:0] debug_axi_w_count;
    reg [15:0] debug_axi_b_count;
    reg [15:0] debug_axi_ar_count;
    reg [15:0] debug_axi_r_count;
    reg [ADDR_W-1:0] debug_wr_last_addr;
    reg [DATA_W-1:0] debug_wr_last_data;
    reg [31:0] output_read_count;
    reg [31:0] output_read_index;
    reg [DATA_W-1:0] output_read_data;
    reg output_read_valid;
    reg output_read_busy;
    reg output_read_req_valid;
    reg output_read_wait_resp;
    reg output_read_error;
    wire output_read_last =
        output_read_valid && (output_read_index == OUT_PIXELS_LAST_U32);
    wire [31:0] output_read_total_count_dbg = rgb_output_count_dbg;
    wire [31:0] output_read_count_dbg = output_read_count;
    wire [31:0] output_read_index_dbg = output_read_index;
    wire output_read_pixel_read =
        !s_axi_rvalid && s_axi_arvalid &&
        (s_axi_araddr[9:0] == REG_MIRROR_OUTPUT_PIXEL);
    wire [ADDR_W-1:0] output_read_offset =
        output_read_index[ADDR_W-1:0] * BYTES_PER_PIXEL;
    wire [ADDR_W-1:0] output_read_addr = output_base_q + output_read_offset;
    wire output_read_debug_req_valid =
        output_read_req_valid && !core_rd_req_valid && !core_busy && !frame_active;
    wire output_read_fire = output_read_debug_req_valid && ddr_rd_req_ready;

    wire start_allowed = !core_busy && !frame_active;
    wire any_error = sw_error || core_error || ddr_error || output_read_error;

    assign ddr_rd_req_valid = core_rd_req_valid || output_read_debug_req_valid;
    assign ddr_rd_req_addr = core_rd_req_valid ? core_rd_req_addr : output_read_addr;
    assign core_rd_req_ready = ddr_rd_req_ready && core_rd_req_valid;
    assign core_rd_resp_valid = ddr_rd_resp_valid && !output_read_wait_resp;
    assign core_rd_resp_data = ddr_rd_resp_data;

    assign s_axi_awready = !aw_hold_valid && !s_axi_bvalid;
    assign s_axi_wready = !w_hold_valid && !s_axi_bvalid;
    assign irq = frame_done || any_error;

    generate
        if (USE_FULL_STREAMED_WRITER != 0) begin : gen_full_streamed_writer
            sr_tile_halo_w8a12_writer_shell #(
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
                .SCALE_LANES(SCALE_LANES)
            ) u_tile_writer (
                .clk(s_axi_aclk),
                .rst(rst),
                .start(core_start),
                .image_w(image_w_q),
                .image_h(image_h_q),
                .input_base(input_base_q),
                .output_base(output_base_q),
                .rd_req_valid(core_rd_req_valid),
                .rd_req_ready(core_rd_req_ready),
                .rd_req_addr(core_rd_req_addr),
                .rd_resp_valid(core_rd_resp_valid),
                .rd_resp_data(core_rd_resp_data),
                .wr_valid(wr_valid),
                .wr_ready(wr_ready),
                .wr_addr(wr_addr),
                .wr_data(wr_data),
                .busy(core_busy),
                .done(core_done),
                .error(core_error),
                .tiles_done(tiles_done)
            );

            assign block_start_count = 16'd0;
            assign replay_feature_count = 32'd0;
            assign block_output_count = 32'd0;
            assign rgb_output_count = {OUT_PIX_W{1'b0}};
            assign front_debug_state = 32'd0;
            assign front_debug_c1_counts = 32'd0;
            assign front_debug_c2_counts = 32'd0;
            assign front_debug_c3_counts = 32'd0;
            assign front_debug_att_counts = 32'd0;
            assign front_debug_c1_lane_outputs = 32'd0;
            assign front_debug_c2_lane_outputs = 32'd0;
            assign front_debug_c3_lane_outputs = 32'd0;
            assign front_debug_att_lane_outputs = 32'd0;
            assign front_debug_c1_detail = 32'd0;
            assign front_debug_c1_core_detail = 32'd0;
            assign front_debug_c1_lane_detail = 32'd0;
            assign front_debug_c1_io_detail = 32'd0;
            assign front_debug_c2_detail = 32'd0;
            assign front_debug_c3_detail = 32'd0;
            assign front_debug_c2_core_detail = 32'd0;
            assign front_debug_c2_lane_detail = 32'd0;
            assign front_debug_c3_core_detail = 32'd0;
            assign front_debug_c3_lane_detail = 32'd0;
            assign front_debug_c3_io_detail = 32'd0;
            assign front_debug_spab_flags = 32'd0;
            assign front_debug_att_detail = 32'd0;
            assign front_debug_tail_feat0_hash = 32'd0;
            assign front_debug_tail_block6_hash = 32'd0;
            assign front_debug_tail_b1_hash = 32'd0;
            assign front_debug_tail_b6_act1_hash = 32'd0;
            assign front_debug_tail_rgb_q_hash = 32'd0;
            assign front_debug_src_feat0_hash = 32'd0;
            assign front_debug_src_block6_hash = 32'd0;
            assign front_debug_src_b1_hash = 32'd0;
            assign front_debug_src_b6_act1_hash = 32'd0;
            assign front_debug_spab_hash_input = 32'd0;
            assign front_debug_spab_hash_c1 = 32'd0;
            assign front_debug_spab_hash_c2 = 32'd0;
            assign front_debug_spab_hash_c3 = 32'd0;
            assign front_debug_spab_hash_residual = 32'd0;
            assign front_debug_spab_hash_att = 32'd0;
            assign front_debug_spab_b1_hash_input = 32'd0;
            assign front_debug_spab_b1_hash_c1 = 32'd0;
            assign front_debug_spab_b1_hash_c1_raw = 32'd0;
            assign front_debug_spab_b1_c1_sample0 = 32'd0;
            assign front_debug_spab_b1_c1_sample1 = 32'd0;
            assign front_debug_spab_b1_c1_sample2 = 32'd0;
            assign front_debug_spab_b1_c1_sample3 = 32'd0;
            assign front_debug_spab_b2_hash_att = 32'd0;
            assign front_debug_spab_b3_hash_att = 32'd0;
            assign front_debug_spab_b4_hash_att = 32'd0;
            assign front_debug_spab_b5_hash_att = 32'd0;
            assign front_debug_writer_rgb_hash = 32'd0;
            assign front_debug_writer_rgb_range = 32'd0;
            assign front_debug_writer_rgb_first = 32'd0;
            assign front_debug_writer_rgb_last = 32'd0;
            assign front_debug_writeback_hash = 32'd0;
            assign front_debug_writeback_range = 32'd0;
            assign front_debug_writeback_first = 32'd0;
            assign front_debug_writeback_last = 32'd0;
            assign front_debug_spab_b1_hash_c2 = 32'd0;
            assign front_debug_spab_b1_hash_c2_replay = 32'd0;
            assign front_debug_spab_b1_hash_c2_window = 32'd0;
            assign front_debug_spab_b1_hash_c2_raw = 32'd0;
            assign front_debug_spab_b1_c2_sample0 = 32'd0;
            assign front_debug_spab_b1_c2_sample1 = 32'd0;
            assign front_debug_spab_b1_c2_sample2 = 32'd0;
            assign front_debug_spab_b1_c2_sample3 = 32'd0;
            assign front_debug_spab_b1_hash_c3 = 32'd0;
            assign front_debug_spab_b1_hash_residual = 32'd0;
            assign front_debug_spab_b1_hash_att = 32'd0;
        end else begin : gen_runtime_writer
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
                .DEBUG_SRC_HASH(DEBUG_SRC_HASH),
                .DEBUG_TAIL_HANDSHAKE(DEBUG_TAIL_HANDSHAKE)
            ) u_tile_writer (
                .clk(s_axi_aclk),
                .rst(rst),
                .start(core_start),
                .image_w(image_w_q),
                .image_h(image_h_q),
                .input_base(input_base_q),
                .output_base(output_base_q),
                .rd_req_valid(core_rd_req_valid),
                .rd_req_ready(core_rd_req_ready),
                .rd_req_addr(core_rd_req_addr),
                .rd_resp_valid(core_rd_resp_valid),
                .rd_resp_data(core_rd_resp_data),
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
                .rgb_output_count(rgb_output_count),
                .front_debug_state(front_debug_state),
                .front_debug_c1_counts(front_debug_c1_counts),
                .front_debug_c2_counts(front_debug_c2_counts),
                .front_debug_c3_counts(front_debug_c3_counts),
                .front_debug_att_counts(front_debug_att_counts),
                .front_debug_c1_lane_outputs(front_debug_c1_lane_outputs),
                .front_debug_c2_lane_outputs(front_debug_c2_lane_outputs),
                .front_debug_c3_lane_outputs(front_debug_c3_lane_outputs),
                .front_debug_att_lane_outputs(front_debug_att_lane_outputs),
                .front_debug_c1_detail(front_debug_c1_detail),
                .front_debug_c1_core_detail(front_debug_c1_core_detail),
                .front_debug_c1_lane_detail(front_debug_c1_lane_detail),
                .front_debug_c1_io_detail(front_debug_c1_io_detail),
                .front_debug_c2_detail(front_debug_c2_detail),
                .front_debug_c3_detail(front_debug_c3_detail),
                .front_debug_c2_core_detail(front_debug_c2_core_detail),
                .front_debug_c2_lane_detail(front_debug_c2_lane_detail),
                .front_debug_c3_core_detail(front_debug_c3_core_detail),
                .front_debug_c3_lane_detail(front_debug_c3_lane_detail),
                .front_debug_c3_io_detail(front_debug_c3_io_detail),
                .front_debug_spab_flags(front_debug_spab_flags),
                .front_debug_att_detail(front_debug_att_detail),
                .front_debug_tail_feat0_hash(front_debug_tail_feat0_hash),
                .front_debug_tail_block6_hash(front_debug_tail_block6_hash),
                .front_debug_tail_b1_hash(front_debug_tail_b1_hash),
                .front_debug_tail_b6_act1_hash(front_debug_tail_b6_act1_hash),
                .front_debug_tail_rgb_q_hash(front_debug_tail_rgb_q_hash),
                .front_debug_src_feat0_hash(front_debug_src_feat0_hash),
                .front_debug_src_block6_hash(front_debug_src_block6_hash),
                .front_debug_src_b1_hash(front_debug_src_b1_hash),
                .front_debug_src_b6_act1_hash(front_debug_src_b6_act1_hash),
                .front_debug_spab_hash_input(front_debug_spab_hash_input),
                .front_debug_spab_hash_c1(front_debug_spab_hash_c1),
                .front_debug_spab_hash_c2(front_debug_spab_hash_c2),
                .front_debug_spab_hash_c3(front_debug_spab_hash_c3),
                .front_debug_spab_hash_residual(front_debug_spab_hash_residual),
                .front_debug_spab_hash_att(front_debug_spab_hash_att),
                .front_debug_spab_b1_hash_input(front_debug_spab_b1_hash_input),
                .front_debug_spab_b1_hash_c1(front_debug_spab_b1_hash_c1),
                .front_debug_spab_b1_hash_c1_raw(front_debug_spab_b1_hash_c1_raw),
                .front_debug_spab_b1_c1_sample0(front_debug_spab_b1_c1_sample0),
                .front_debug_spab_b1_c1_sample1(front_debug_spab_b1_c1_sample1),
                .front_debug_spab_b1_c1_sample2(front_debug_spab_b1_c1_sample2),
                .front_debug_spab_b1_c1_sample3(front_debug_spab_b1_c1_sample3),
                .front_debug_spab_b2_hash_att(front_debug_spab_b2_hash_att),
                .front_debug_spab_b3_hash_att(front_debug_spab_b3_hash_att),
                .front_debug_spab_b4_hash_att(front_debug_spab_b4_hash_att),
                .front_debug_spab_b5_hash_att(front_debug_spab_b5_hash_att),
                .front_debug_writer_rgb_hash(front_debug_writer_rgb_hash),
                .front_debug_writer_rgb_range(front_debug_writer_rgb_range),
                .front_debug_writer_rgb_first(front_debug_writer_rgb_first),
                .front_debug_writer_rgb_last(front_debug_writer_rgb_last),
                .front_debug_writeback_hash(front_debug_writeback_hash),
                .front_debug_writeback_range(front_debug_writeback_range),
                .front_debug_writeback_first(front_debug_writeback_first),
                .front_debug_writeback_last(front_debug_writeback_last),
                .front_debug_spab_b1_hash_c2(front_debug_spab_b1_hash_c2),
                .front_debug_spab_b1_hash_c2_replay(front_debug_spab_b1_hash_c2_replay),
                .front_debug_spab_b1_hash_c2_window(front_debug_spab_b1_hash_c2_window),
                .front_debug_spab_b1_hash_c2_raw(front_debug_spab_b1_hash_c2_raw),
                .front_debug_spab_b1_c2_sample0(front_debug_spab_b1_c2_sample0),
                .front_debug_spab_b1_c2_sample1(front_debug_spab_b1_c2_sample1),
                .front_debug_spab_b1_c2_sample2(front_debug_spab_b1_c2_sample2),
                .front_debug_spab_b1_c2_sample3(front_debug_spab_b1_c2_sample3),
                .front_debug_spab_b1_hash_c3(front_debug_spab_b1_hash_c3),
                .front_debug_spab_b1_hash_residual(front_debug_spab_b1_hash_residual),
                .front_debug_spab_b1_hash_att(front_debug_spab_b1_hash_att)
            );
        end
    endgenerate

    sr_ddr_pixel_axi_master #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .AXI_DATA_W(M_AXI_DATA_WIDTH)
    ) u_ddr_master (
        .clk(s_axi_aclk),
        .rst(rst),
        .rd_req_valid(ddr_rd_req_valid),
        .rd_req_ready(ddr_rd_req_ready),
        .rd_req_addr(ddr_rd_req_addr),
        .rd_resp_valid(ddr_rd_resp_valid),
        .rd_resp_data(ddr_rd_resp_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(ddr_busy),
        .error(ddr_error),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            aw_hold_valid <= 1'b0;
            aw_hold_addr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            w_hold_valid <= 1'b0;
            w_hold_data <= {C_S_AXI_DATA_WIDTH{1'b0}};
            w_hold_strb <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
        end else begin
            if (s_axi_awready && s_axi_awvalid) begin
                aw_hold_valid <= 1'b1;
                aw_hold_addr <= s_axi_awaddr;
            end
            if (s_axi_wready && s_axi_wvalid) begin
                w_hold_valid <= 1'b1;
                w_hold_data <= s_axi_wdata;
                w_hold_strb <= s_axi_wstrb;
            end
            if (write_fire) begin
                aw_hold_valid <= 1'b0;
                w_hold_valid <= 1'b0;
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
            if (!s_axi_rvalid && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;
                case (s_axi_araddr[9:0])
                    REG_CONTROL:
                        s_axi_rdata <= 32'd0;
                    REG_STATUS:
                        s_axi_rdata <= {
                            24'd0,
                            ddr_busy,
                            ddr_error,
                            core_error,
                            any_error,
                            frame_done,
                            frame_active,
                            core_busy,
                            start_allowed
                        };
                    REG_IMG_W:
                        s_axi_rdata <= image_w_q;
                    REG_IMG_H:
                        s_axi_rdata <= image_h_q;
                    REG_INPUT_BASE:
                        s_axi_rdata <= input_base_q;
                    REG_OUTPUT_BASE:
                        s_axi_rdata <= output_base_q;
                    REG_FRAME_CYCLES:
                        s_axi_rdata <= frame_cycles_latched;
                    REG_TILES_DONE:
                        s_axi_rdata <= tiles_done;
                    REG_ERROR:
                        s_axi_rdata <= {28'd0, ddr_error, core_error, sw_error, any_error};
                    REG_BLOCK_STARTS:
                        s_axi_rdata <= {16'd0, block_start_count};
                    REG_BLOCK_OUTPUTS:
                        s_axi_rdata <= block_output_count;
                    REG_REPLAY_FEATURE:
                        s_axi_rdata <= replay_feature_count;
                    REG_CONFIG:
                        s_axi_rdata <= {8'd0, SCALE_U8, TILE_H_U8, TILE_W_U8};
                    REG_DEBUG_STATE:
                        s_axi_rdata <= front_debug_state;
                    REG_DEBUG_C1:
                        s_axi_rdata <= front_debug_c1_counts;
                    REG_DEBUG_C2:
                        s_axi_rdata <= front_debug_c2_counts;
                    REG_DEBUG_C3:
                        s_axi_rdata <= front_debug_c3_counts;
                    REG_DEBUG_ATT:
                        s_axi_rdata <= front_debug_att_counts;
                    REG_DEBUG_C1_LANE:
                        s_axi_rdata <= front_debug_c1_lane_outputs;
                    REG_DEBUG_C2_LANE:
                        s_axi_rdata <= front_debug_c2_lane_outputs;
                    REG_DEBUG_C3_LANE:
                        s_axi_rdata <= front_debug_c3_lane_outputs;
                    REG_DEBUG_ATT_LANE:
                        s_axi_rdata <= front_debug_att_lane_outputs;
                    REG_DEBUG_C1_DETAIL:
                        s_axi_rdata <= front_debug_c1_detail;
                    REG_DEBUG_C2_DETAIL:
                        s_axi_rdata <= front_debug_c2_detail;
                    REG_DEBUG_C3_DETAIL:
                        s_axi_rdata <= front_debug_c3_detail;
                    REG_DEBUG_C2_CORE_DETAIL:
                        s_axi_rdata <= front_debug_c2_core_detail;
                    REG_DEBUG_C2_LANE_DETAIL:
                        s_axi_rdata <= front_debug_c2_lane_detail;
                    REG_DEBUG_C3_CORE_DETAIL:
                        s_axi_rdata <= front_debug_c3_core_detail;
                    REG_DEBUG_C3_LANE_DETAIL:
                        s_axi_rdata <= front_debug_c3_lane_detail;
                    REG_DEBUG_C3_IO_DETAIL:
                        s_axi_rdata <= front_debug_c3_io_detail;
                    REG_DEBUG_TAIL_FEAT0_HASH:
                        s_axi_rdata <= front_debug_tail_feat0_hash;
                    REG_DEBUG_TAIL_BLOCK6_HASH:
                        s_axi_rdata <= front_debug_tail_block6_hash;
                    REG_DEBUG_TAIL_B1_HASH:
                        s_axi_rdata <= front_debug_tail_b1_hash;
                    REG_DEBUG_TAIL_B6_ACT1_HASH:
                        s_axi_rdata <= front_debug_tail_b6_act1_hash;
                    REG_DEBUG_TAIL_RGB_Q_HASH:
                        s_axi_rdata <= front_debug_tail_rgb_q_hash;
                    REG_DEBUG_SRC_FEAT0_HASH:
                        s_axi_rdata <= front_debug_src_feat0_hash;
                    REG_DEBUG_SRC_BLOCK6_HASH:
                        s_axi_rdata <= front_debug_src_block6_hash;
                    REG_DEBUG_SRC_B1_HASH:
                        s_axi_rdata <= front_debug_src_b1_hash;
                    REG_DEBUG_SRC_B6_ACT1_HASH:
                        s_axi_rdata <= front_debug_src_b6_act1_hash;
                    REG_DEBUG_SPAB_FLAGS:
                        s_axi_rdata <= (core_error && (tiles_done == 32'd0) &&
                                        (block_start_count == 16'd0)) ?
                                       front_debug_spab_b5_hash_att :
                                       front_debug_spab_flags;
                    REG_DEBUG_ATT_DETAIL:
                        s_axi_rdata <= front_debug_att_detail;
                    REG_DEBUG_C1_CORE_DETAIL:
                        s_axi_rdata <= front_debug_c1_core_detail;
                    REG_DEBUG_C1_LANE_DETAIL:
                        s_axi_rdata <= front_debug_c1_lane_detail;
                    REG_DEBUG_C1_IO_DETAIL:
                        s_axi_rdata <= front_debug_c1_io_detail;
                    REG_DEBUG_SPAB_B1_C1_SAMPLE0:
                        s_axi_rdata <= front_debug_spab_b1_c1_sample0;
                    REG_DEBUG_SPAB_B1_C1_SAMPLE1:
                        s_axi_rdata <= front_debug_spab_b1_c1_sample1;
                    REG_DEBUG_SPAB_B1_C1_SAMPLE2:
                        s_axi_rdata <= front_debug_spab_b1_c1_sample2;
                    REG_DEBUG_SPAB_B1_C1_SAMPLE3:
                        s_axi_rdata <= front_debug_spab_b1_c1_sample3;
                    REG_DEBUG_SPAB_HASH_RESIDUAL:
                        s_axi_rdata <= front_debug_spab_hash_residual;
                    REG_DEBUG_SPAB_HASH_ATT:
                        s_axi_rdata <= front_debug_spab_hash_att;
                    REG_DEBUG_SPAB_B1_HASH_INPUT:
                        s_axi_rdata <= front_debug_spab_b1_hash_input;
                    REG_DEBUG_SPAB_B1_HASH_C1:
                        s_axi_rdata <= front_debug_spab_b1_hash_c1;
                    REG_DEBUG_SPAB_B1_HASH_C2:
                        s_axi_rdata <= front_debug_spab_b1_hash_c2;
                    REG_DEBUG_SPAB_B1_HASH_C2_REPLAY:
                        s_axi_rdata <= front_debug_spab_b1_hash_c2_replay;
                    REG_DEBUG_SPAB_B1_HASH_C2_WINDOW:
                        s_axi_rdata <= front_debug_spab_b1_hash_c2_window;
                    REG_DEBUG_SPAB_B1_HASH_C1_RAW:
                        s_axi_rdata <= front_debug_spab_b1_hash_c1_raw;
                    REG_DEBUG_SPAB_B1_HASH_C3:
                        s_axi_rdata <= front_debug_spab_b1_hash_c3;
                    REG_DEBUG_SPAB_B1_HASH_RESIDUAL:
                        s_axi_rdata <= front_debug_spab_b1_hash_residual;
                    REG_DEBUG_SPAB_B1_HASH_ATT:
                        s_axi_rdata <= front_debug_spab_b1_hash_att;
                    REG_DEBUG_RGB_OUTPUT_COUNT:
                        s_axi_rdata <= rgb_output_count_dbg;
                    REG_DEBUG_WRITEBACK_HASH:
                        s_axi_rdata <= front_debug_writeback_hash;
                    REG_DEBUG_WRITEBACK_RANGE:
                        s_axi_rdata <= front_debug_writeback_range;
                    REG_DEBUG_WRITEBACK_FIRST:
                        s_axi_rdata <= front_debug_writeback_first;
                    REG_DEBUG_WRITEBACK_LAST:
                        s_axi_rdata <= front_debug_writeback_last;
                    REG_MIRROR_OUTPUT_PIXEL:
                        s_axi_rdata <= output_read_valid ?
                            {8'd0, output_read_data} :
                            32'd0;
                    REG_MIRROR_OUTPUT_COUNT:
                        s_axi_rdata <= output_read_total_count_dbg;
                    REG_MIRROR_OUTPUT_READ_COUNT:
                        s_axi_rdata <= output_read_count_dbg;
                    REG_MIRROR_STATUS:
                        s_axi_rdata <= {
                            28'd0,
                            output_read_error,
                            output_read_last,
                            frame_done,
                            output_read_valid
                        };
                    REG_MIRROR_OUTPUT_INDEX:
                        s_axi_rdata <= output_read_index_dbg;
                    REG_DEBUG_WR_HANDSHAKE:
                        s_axi_rdata <= {debug_wr_valid_cycles, debug_wr_ready_cycles};
                    REG_DEBUG_WR_FIRE_COUNT:
                        s_axi_rdata <= {16'd0, debug_wr_fire_count};
                    REG_DEBUG_WR_LAST_ADDR:
                        s_axi_rdata <= debug_wr_last_addr;
                    REG_DEBUG_WR_LAST_DATA:
                        s_axi_rdata <= {8'd0, debug_wr_last_data};
                    REG_DEBUG_AXI_WRITE_COUNTS:
                        s_axi_rdata <= {debug_axi_aw_count, debug_axi_w_count};
                    REG_DEBUG_AXI_RESP_COUNTS:
                        s_axi_rdata <= {debug_axi_b_count, debug_axi_ar_count[7:0], debug_axi_r_count[7:0]};
                    REG_DEBUG_AXI_STATE:
                        s_axi_rdata <= {
                            9'd0,
                            frame_active,
                            core_busy,
                            output_read_busy,
                            output_read_wait_resp,
                            ddr_busy,
                            ddr_error,
                            wr_valid,
                            wr_ready,
                            m_axi_awvalid,
                            m_axi_awready,
                            m_axi_wvalid,
                            m_axi_wready,
                            m_axi_bvalid,
                            m_axi_bready,
                            m_axi_arvalid,
                            m_axi_arready,
                            m_axi_rvalid,
                            m_axi_rready
                        };
                    REG_DEBUG_SPAB_B2_HASH_ATT:
                        s_axi_rdata <= front_debug_spab_b2_hash_att;
                    REG_DEBUG_SPAB_B3_HASH_ATT:
                        s_axi_rdata <= front_debug_spab_b3_hash_att;
                    REG_DEBUG_SPAB_B4_HASH_ATT:
                        s_axi_rdata <= front_debug_spab_b4_hash_att;
                    REG_DEBUG_SPAB_B5_HASH_ATT:
                        s_axi_rdata <= front_debug_spab_b5_hash_att;
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
            image_w_q <= DEFAULT_IMG_W;
            image_h_q <= DEFAULT_IMG_H;
            input_base_q <= DEFAULT_INPUT_BASE;
            output_base_q <= DEFAULT_OUTPUT_BASE;
            core_start <= 1'b0;
            frame_active <= 1'b0;
            frame_done <= 1'b0;
            frame_cycles_q <= 32'd0;
            frame_cycles_latched <= 32'd0;
            sw_error <= 1'b0;
            output_read_count <= 32'd0;
            output_read_index <= 32'd0;
            output_read_data <= {DATA_W{1'b0}};
            output_read_valid <= 1'b0;
            output_read_busy <= 1'b0;
            output_read_req_valid <= 1'b0;
            output_read_wait_resp <= 1'b0;
            output_read_error <= 1'b0;
            debug_wr_valid_cycles <= 16'd0;
            debug_wr_ready_cycles <= 16'd0;
            debug_wr_fire_count <= 16'd0;
            debug_axi_aw_count <= 16'd0;
            debug_axi_w_count <= 16'd0;
            debug_axi_b_count <= 16'd0;
            debug_axi_ar_count <= 16'd0;
            debug_axi_r_count <= 16'd0;
            debug_wr_last_addr <= {ADDR_W{1'b0}};
            debug_wr_last_data <= {DATA_W{1'b0}};
        end else begin
            core_start <= 1'b0;

            if (write_fire) begin
                case (aw_hold_addr[9:0])
                    REG_CONTROL: begin
                        if (w_hold_data[1]) begin
                            frame_active <= 1'b0;
                            frame_done <= 1'b0;
                            frame_cycles_q <= 32'd0;
                            frame_cycles_latched <= 32'd0;
                            sw_error <= 1'b0;
                            output_read_count <= 32'd0;
                            output_read_index <= 32'd0;
                            output_read_valid <= 1'b0;
                            output_read_busy <= 1'b0;
                            output_read_req_valid <= 1'b0;
                            output_read_wait_resp <= 1'b0;
                            output_read_error <= 1'b0;
                            debug_wr_valid_cycles <= 16'd0;
                            debug_wr_ready_cycles <= 16'd0;
                            debug_wr_fire_count <= 16'd0;
                            debug_axi_aw_count <= 16'd0;
                            debug_axi_w_count <= 16'd0;
                            debug_axi_b_count <= 16'd0;
                            debug_axi_ar_count <= 16'd0;
                            debug_axi_r_count <= 16'd0;
                            debug_wr_last_addr <= {ADDR_W{1'b0}};
                            debug_wr_last_data <= {DATA_W{1'b0}};
                        end
                        if (w_hold_data[0]) begin
                            if (start_allowed) begin
                                core_start <= 1'b1;
                                frame_active <= 1'b1;
                                frame_done <= 1'b0;
                                frame_cycles_q <= 32'd0;
                                frame_cycles_latched <= 32'd0;
                                sw_error <= 1'b0;
                                output_read_count <= 32'd0;
                                output_read_index <= 32'd0;
                                output_read_valid <= 1'b0;
                                output_read_busy <= 1'b0;
                                output_read_req_valid <= 1'b0;
                                output_read_wait_resp <= 1'b0;
                                output_read_error <= 1'b0;
                                debug_wr_valid_cycles <= 16'd0;
                                debug_wr_ready_cycles <= 16'd0;
                                debug_wr_fire_count <= 16'd0;
                                debug_axi_aw_count <= 16'd0;
                                debug_axi_w_count <= 16'd0;
                                debug_axi_b_count <= 16'd0;
                                debug_axi_ar_count <= 16'd0;
                                debug_axi_r_count <= 16'd0;
                                debug_wr_last_addr <= {ADDR_W{1'b0}};
                                debug_wr_last_data <= {DATA_W{1'b0}};
                            end else begin
                                sw_error <= 1'b1;
                            end
                        end
                    end
                    REG_IMG_W:
                        if (!frame_active && !core_busy)
                            image_w_q <= w_hold_data[COORD_W-1:0];
                    REG_IMG_H:
                        if (!frame_active && !core_busy)
                            image_h_q <= w_hold_data[COORD_W-1:0];
                    REG_INPUT_BASE:
                        if (!frame_active && !core_busy)
                            input_base_q <= {w_hold_data[ADDR_W-1:2], 2'b00};
                    REG_OUTPUT_BASE:
                        if (!frame_active && !core_busy)
                            output_base_q <= {w_hold_data[ADDR_W-1:2], 2'b00};
                    REG_MIRROR_OUTPUT_INDEX:
                        if (!frame_active && !core_busy && !output_read_busy) begin
                            output_read_valid <= 1'b0;
                            output_read_wait_resp <= 1'b0;
                            if (w_hold_data < OUT_PIXELS_U32) begin
                                output_read_index <= w_hold_data;
                                output_read_req_valid <= 1'b1;
                                output_read_busy <= 1'b1;
                            end else begin
                                output_read_index <= OUT_PIXELS_LAST_U32;
                                output_read_req_valid <= 1'b0;
                                output_read_error <= 1'b1;
                            end
                        end else begin
                            output_read_error <= 1'b1;
                        end
                    REG_ERROR: begin
                        if (w_hold_data[0])
                            sw_error <= 1'b0;
                    end
                    default: begin
                    end
                endcase
            end

            if (output_read_fire) begin
                output_read_req_valid <= 1'b0;
                output_read_wait_resp <= 1'b1;
            end

            if (ddr_rd_resp_valid && output_read_wait_resp) begin
                output_read_data <= ddr_rd_resp_data;
                output_read_valid <= 1'b1;
                output_read_busy <= 1'b0;
                output_read_wait_resp <= 1'b0;
            end

            if (output_read_pixel_read) begin
                output_read_count <= output_read_count + 1'b1;
            end

            if (!debug_counter_clear) begin
                if (wr_valid && debug_wr_valid_cycles != 16'hffff)
                    debug_wr_valid_cycles <= debug_wr_valid_cycles + 16'd1;
                if (wr_ready && debug_wr_ready_cycles != 16'hffff)
                    debug_wr_ready_cycles <= debug_wr_ready_cycles + 16'd1;
                if (wr_data_fire) begin
                    if (debug_wr_fire_count != 16'hffff)
                        debug_wr_fire_count <= debug_wr_fire_count + 16'd1;
                    debug_wr_last_addr <= wr_addr;
                    debug_wr_last_data <= wr_data;
                end
                if (axi_aw_fire && debug_axi_aw_count != 16'hffff)
                    debug_axi_aw_count <= debug_axi_aw_count + 16'd1;
                if (axi_w_fire && debug_axi_w_count != 16'hffff)
                    debug_axi_w_count <= debug_axi_w_count + 16'd1;
                if (axi_b_fire && debug_axi_b_count != 16'hffff)
                    debug_axi_b_count <= debug_axi_b_count + 16'd1;
                if (axi_ar_fire && debug_axi_ar_count != 16'hffff)
                    debug_axi_ar_count <= debug_axi_ar_count + 16'd1;
                if (axi_r_fire && debug_axi_r_count != 16'hffff)
                    debug_axi_r_count <= debug_axi_r_count + 16'd1;
            end

            if (frame_active)
                frame_cycles_q <= frame_cycles_q + 32'd1;

            if (core_done && frame_active) begin
                frame_active <= 1'b0;
                frame_done <= 1'b1;
                frame_cycles_latched <= frame_cycles_q + 32'd1;
            end
        end
    end

    wire unused_axi = |s_axi_awprot | |s_axi_arprot | |w_hold_strb |
                      m_axi_aclk | m_axi_aresetn;
endmodule
