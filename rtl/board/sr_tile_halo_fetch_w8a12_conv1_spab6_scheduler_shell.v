`timescale 1ns/1ps

// Halo tile fetch -> W8A12 conv1 -> six runtime-selected SPAB blocks.
//
// Tile splitting remains on the hardware side: this shell fetches a tile plus
// halo from the SD/DDR image address stream, computes conv1 features, then
// ping-pongs two tile-local feature buffers through one reusable block-group
// SPAB backend with block_i = 0..5.
module sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer HALO = 1,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer BLOCKS = 6,
    parameter integer DEBUG_COUNTERS = 1,
    parameter integer DEBUG_HASHES = 0,
    parameter integer FEAT_W = OUT_CH * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1),
    parameter integer BLOCK_INDEX_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS)
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       cmd_valid,
    output wire                       cmd_ready,
    input  wire [COORD_W-1:0]         cmd_image_w,
    input  wire [COORD_W-1:0]         cmd_image_h,
    input  wire [COORD_W-1:0]         cmd_tile_x,
    input  wire [COORD_W-1:0]         cmd_tile_y,
    input  wire [ADDR_W-1:0]          cmd_input_base,

    output wire                       rd_req_valid,
    input  wire                       rd_req_ready,
    output wire [ADDR_W-1:0]          rd_req_addr,
    input  wire                       rd_resp_valid,
    input  wire [DATA_W-1:0]          rd_resp_data,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire [FEAT_W-1:0]          m_feat,
    output wire                       m_user,
    output wire                       m_last,

    output wire                       tap_feat0_valid,
    input  wire                       tap_feat0_ready,
    output wire [FEAT_W-1:0]          tap_feat0_feat,
    output wire                       tap_feat0_user,
    output wire                       tap_feat0_last,

    output wire                       tap_b1_valid,
    input  wire                       tap_b1_ready,
    output wire [FEAT_W-1:0]          tap_b1_feat,
    output wire                       tap_b1_user,
    output wire                       tap_b1_last,

    output wire                       tap_b6_act1_valid,
    input  wire                       tap_b6_act1_ready,
    output wire [FEAT_W-1:0]          tap_b6_act1_feat,
    output wire                       tap_b6_act1_user,
    output wire                       tap_b6_act1_last,

    output wire                       busy,
    output wire                       done,
    output wire                       error,
    output wire [BLOCK_INDEX_W-1:0]   block_index,
    output wire [15:0]                block_start_count,
    output wire [31:0]                replay_feature_count,
    output wire [31:0]                block_output_count,
    output wire [31:0]                debug_state,
    output wire [31:0]                debug_c1_counts,
    output wire [31:0]                debug_c2_counts,
    output wire [31:0]                debug_c3_counts,
    output wire [31:0]                debug_att_counts,
    output wire [31:0]                debug_c1_lane_outputs,
    output wire [31:0]                debug_c2_lane_outputs,
    output wire [31:0]                debug_c3_lane_outputs,
    output wire [31:0]                debug_att_lane_outputs,
    output wire [31:0]                debug_c1_detail,
    output wire [31:0]                debug_c1_core_detail,
    output wire [31:0]                debug_c1_lane_detail,
    output wire [31:0]                debug_c1_io_detail,
    output wire [31:0]                debug_c2_detail,
    output wire [31:0]                debug_c3_detail,
    output wire [31:0]                debug_c2_core_detail,
    output wire [31:0]                debug_c2_lane_detail,
    output wire [31:0]                debug_c3_core_detail,
    output wire [31:0]                debug_c3_lane_detail,
    output wire [31:0]                debug_c3_io_detail,
    output wire [31:0]                debug_spab_flags,
    output wire [31:0]                debug_att_detail,
    output reg  [31:0]                debug_hash_feat0,
    output reg  [31:0]                debug_hash_block6,
    output reg  [31:0]                debug_hash_b1,
    output reg  [31:0]                debug_hash_b6_act1,
    output wire [31:0]                debug_hash_spab_input,
    output wire [31:0]                debug_hash_spab_c1,
    output wire [31:0]                debug_hash_spab_c2,
    output wire [31:0]                debug_hash_spab_c2_replay,
    output wire [31:0]                debug_hash_spab_c2_window,
    output wire [31:0]                debug_hash_spab_c2_raw,
    output wire [31:0]                debug_spab_c2_sample0,
    output wire [31:0]                debug_spab_c2_sample1,
    output wire [31:0]                debug_spab_c2_sample2,
    output wire [31:0]                debug_spab_c2_sample3,
    output wire [31:0]                debug_hash_spab_c3,
    output wire [31:0]                debug_hash_spab_residual,
    output wire [31:0]                debug_hash_spab_att,
    output reg  [31:0]                debug_hash_spab_b1_input,
    output reg  [31:0]                debug_hash_spab_b1_c1,
    output reg  [31:0]                debug_hash_spab_b1_c1_raw,
    output reg  [31:0]                debug_spab_b1_c1_sample0,
    output reg  [31:0]                debug_spab_b1_c1_sample1,
    output reg  [31:0]                debug_spab_b1_c1_sample2,
    output reg  [31:0]                debug_spab_b1_c1_sample3,
    output reg  [31:0]                debug_hash_spab_b2_att,
    output reg  [31:0]                debug_hash_spab_b3_att,
    output reg  [31:0]                debug_hash_spab_b4_att,
    output reg  [31:0]                debug_hash_spab_b5_att,
    output reg  [31:0]                debug_hash_spab_b1_c2,
    output reg  [31:0]                debug_hash_spab_b1_c2_replay,
    output reg  [31:0]                debug_hash_spab_b1_c2_window,
    output reg  [31:0]                debug_hash_spab_b1_c2_raw,
    output reg  [31:0]                debug_spab_b1_c2_sample0,
    output reg  [31:0]                debug_spab_b1_c2_sample1,
    output reg  [31:0]                debug_spab_b1_c2_sample2,
    output reg  [31:0]                debug_spab_b1_c2_sample3,
    output reg  [31:0]                debug_hash_spab_b1_c3,
    output reg  [31:0]                debug_hash_spab_b1_residual,
    output reg  [31:0]                debug_hash_spab_b1_att
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_CONV_LOAD  = 3'd1;
    localparam [2:0] ST_BLOCK_START = 3'd2;
    localparam [2:0] ST_BLOCK_RUN  = 3'd3;
    localparam [2:0] ST_DONE       = 3'd4;

    reg [2:0] state;
    reg inner_cmd_valid;
    reg buf0_load_start;
    reg buf1_load_start;
    reg buf0_stream_start;
    reg buf1_stream_start;
    reg spab_start;
    reg done_r;
    reg error_r;
    reg current_sel;
    reg [BLOCK_INDEX_W-1:0] block_index_r;
    reg current_stream_done_seen;
    reg target_load_done_seen;
    reg spab_done_seen;
    reg [15:0] block_start_count_r;
    reg [31:0] replay_feature_count_r;
    reg [31:0] block_output_count_r;

    wire inner_cmd_ready;
    wire inner_cmd_take = inner_cmd_valid && inner_cmd_ready;
    wire fetch_busy;
    wire fetch_done;
    wire fetch_error;
    wire conv_valid;
    wire conv_ready;
    wire [FEAT_W-1:0] conv_feat;
    wire conv_user;
    wire conv_last;

    wire buf0_load_busy;
    wire buf0_load_done;
    wire buf0_load_error;
    wire buf0_stream_busy;
    wire buf0_stream_done;
    wire buf0_s_ready;
    wire buf0_m_valid;
    wire buf0_m_ready;
    wire [FEAT_W-1:0] buf0_m_feat;
    wire buf0_m_user;
    wire buf0_m_last;

    wire buf1_load_busy;
    wire buf1_load_done;
    wire buf1_load_error;
    wire buf1_stream_busy;
    wire buf1_stream_done;
    wire buf1_s_ready;
    wire buf1_m_valid;
    wire buf1_m_ready;
    wire [FEAT_W-1:0] buf1_m_feat;
    wire buf1_m_user;
    wire buf1_m_last;

    wire spab_ready;
    wire spab_busy;
    wire spab_done;
    wire spab_error;
    wire spab_s_valid;
    wire spab_s_ready;
    wire signed [FEAT_W-1:0] spab_s_feat;
    wire spab_s_user;
    wire spab_s_last;
    wire spab_m_valid;
    wire spab_m_ready;
    wire signed [FEAT_W-1:0] spab_m_feat;
    wire spab_m_user;
    wire spab_m_last;
    wire spab_tap_c1_valid;
    wire spab_tap_c1_ready;
    wire signed [FEAT_W-1:0] spab_tap_c1_feat;
    wire spab_tap_c1_user;
    wire spab_tap_c1_last;
    wire [31:0] spab_debug_hash_c1_raw;
    wire [31:0] spab_debug_c1_sample0;
    wire [31:0] spab_debug_c1_sample1;
    wire [31:0] spab_debug_c1_sample2;
    wire [31:0] spab_debug_c1_sample3;
    wire [PIX_W-1:0] spab_residual_load_count;
    wire [PIX_W-1:0] spab_c1_load_count;
    wire [PIX_W-1:0] spab_c1_output_count;
    wire [31:0] spab_c1_lane_output_count;
    wire [31:0] spab_c1_debug_state;
    wire [31:0] spab_c1_core_debug_state;
    wire [31:0] spab_c1_lane_debug_state;
    wire [31:0] spab_c1_core_io_debug_state;
    wire [PIX_W-1:0] spab_c2_load_count;
    wire [PIX_W-1:0] spab_c2_output_count;
    wire [31:0] spab_c2_lane_output_count;
    wire [31:0] spab_c2_debug_state;
    wire [31:0] spab_c2_core_debug_state;
    wire [31:0] spab_c2_lane_debug_state;
    wire [PIX_W-1:0] spab_c3_load_count;
    wire [PIX_W-1:0] spab_c3_output_count;
    wire [31:0] spab_c3_lane_output_count;
    wire [31:0] spab_c3_debug_state;
    wire [31:0] spab_c3_core_debug_state;
    wire [31:0] spab_c3_lane_debug_state;
    wire [31:0] spab_c3_core_io_debug_state;
    wire [PIX_W-1:0] spab_att_input_count;
    wire [PIX_W-1:0] spab_att_output_count;
    wire [31:0] spab_att_lane_output_count;

    wire conv_load_active = (state == ST_CONV_LOAD);
    wire last_block = (block_index_r == BLOCKS - 1);
    wire intermediate_block = (state == ST_BLOCK_RUN) && !last_block;
    wire target_sel = ~current_sel;
    wire spab_to_buf0 = intermediate_block && (target_sel == 1'b0);
    wire spab_to_buf1 = intermediate_block && (target_sel == 1'b1);
    wire tap_b1_active = intermediate_block && (block_index_r == {BLOCK_INDEX_W{1'b0}});
    wire target_s_ready = spab_to_buf0 ? buf0_s_ready :
                          (spab_to_buf1 ? buf1_s_ready : 1'b0);
    wire target_take_allowed = !tap_b1_active || tap_b1_ready;
    wire current_stream_done = (current_sel == 1'b0) ? buf0_stream_done : buf1_stream_done;
    wire target_load_done = (target_sel == 1'b0) ? buf0_load_done : buf1_load_done;
    wire current_stream_done_now = current_stream_done_seen || current_stream_done;
    wire target_load_done_now = last_block || target_load_done_seen || target_load_done;
    wire spab_done_now = spab_done_seen || spab_done;
    wire replay_take = spab_s_valid && spab_s_ready;
    wire block_output_take = spab_m_valid && spab_m_ready;
    wire first_block = (block_index_r == {BLOCK_INDEX_W{1'b0}});
    wire conv_output_take = conv_valid && conv_ready;
    wire final_block_take = m_valid && m_ready;
    wire b1_tap_take = tap_b1_valid && tap_b1_ready;
    wire b6_act1_tap_take = tap_b6_act1_valid && tap_b6_act1_ready;

    function [31:0] rotl5;
        input [31:0] value;
        begin
            rotl5 = {value[26:0], value[31:27]};
        end
    endfunction

    function [31:0] feature_signature;
        input [FEAT_W-1:0] feat;
        integer sig_ch;
        reg signed [ACT_W-1:0] sample;
        reg [31:0] acc;
        begin
            acc = 32'h9E37_79B9;
            for (sig_ch = 0; sig_ch < OUT_CH; sig_ch = sig_ch + 1) begin
                sample = $signed(feat[sig_ch*ACT_W +: ACT_W]);
                acc = rotl5(acc) ^
                      {{(32-ACT_W){sample[ACT_W-1]}}, sample} ^
                      (32'h7F4A_7C15 + sig_ch[31:0]);
            end
            feature_signature = acc;
        end
    endfunction

    assign cmd_ready = (state == ST_IDLE) && !inner_cmd_valid;
    assign busy = (state != ST_IDLE) || inner_cmd_valid;
    assign done = done_r;
    wire spab_error_active =
        ((state == ST_BLOCK_START) || (state == ST_BLOCK_RUN)) && spab_error;

    assign error = error_r || fetch_error || buf0_load_error ||
                   buf1_load_error || spab_error_active;
    assign block_index = block_index_r;
    assign block_start_count = block_start_count_r;
    assign replay_feature_count = replay_feature_count_r;
    assign block_output_count = block_output_count_r;

    wire [15:0] spab_c1_load_count_u16 = spab_c1_load_count;
    wire [15:0] spab_c1_output_count_u16 = spab_c1_output_count;
    wire [15:0] spab_c2_load_count_u16 = spab_c2_load_count;
    wire [15:0] spab_c2_output_count_u16 = spab_c2_output_count;
    wire [15:0] spab_c3_load_count_u16 = spab_c3_load_count;
    wire [15:0] spab_c3_output_count_u16 = spab_c3_output_count;
    wire [15:0] spab_att_input_count_u16 = spab_att_input_count;
    wire [15:0] spab_att_output_count_u16 = spab_att_output_count;

    assign debug_state = {
        8'd0,
        state,
        block_index_r,
        current_sel,
        last_block,
        spab_ready,
        spab_busy,
        spab_done,
        spab_s_valid,
        spab_s_ready,
        spab_m_valid,
        spab_m_ready,
        current_stream_done,
        target_load_done,
        target_s_ready,
        tap_b1_active,
        tap_b1_ready
    };
    assign debug_c1_counts = {spab_c1_output_count_u16, spab_c1_load_count_u16};
    assign debug_c2_counts = {spab_c2_output_count_u16, spab_c2_load_count_u16};
    assign debug_c3_counts = {spab_c3_output_count_u16, spab_c3_load_count_u16};
    assign debug_att_counts = {spab_att_output_count_u16, spab_att_input_count_u16};
    assign debug_c1_lane_outputs = spab_c1_lane_output_count;
    assign debug_c2_lane_outputs = spab_c2_lane_output_count;
    assign debug_c3_lane_outputs = spab_c3_lane_output_count;
    assign debug_att_lane_outputs = spab_att_lane_output_count;
    assign debug_c1_detail = spab_c1_debug_state;
    assign debug_c1_core_detail = spab_c1_core_debug_state;
    assign debug_c1_lane_detail = spab_c1_lane_debug_state;
    assign debug_c1_io_detail = spab_c1_core_io_debug_state;
    assign debug_c2_detail = spab_c2_debug_state;
    assign debug_c3_detail = spab_c3_debug_state;
    assign debug_c2_core_detail = spab_c2_core_debug_state;
    assign debug_c2_lane_detail = spab_c2_lane_debug_state;
    assign debug_c3_core_detail = spab_c3_core_debug_state;
    assign debug_c3_lane_detail = spab_c3_lane_debug_state;
    assign debug_c3_io_detail = spab_c3_core_io_debug_state;

    assign conv_ready = conv_load_active ? (buf0_s_ready && tap_feat0_ready) : 1'b0;
    assign tap_feat0_valid = conv_load_active && conv_valid && buf0_s_ready;
    assign tap_feat0_feat = conv_feat;
    assign tap_feat0_user = conv_user;
    assign tap_feat0_last = conv_last;

    wire buf0_s_valid = conv_load_active ? conv_valid :
                        (spab_to_buf0 ? (spab_m_valid && target_take_allowed) : 1'b0);
    wire [FEAT_W-1:0] buf0_s_feat = conv_load_active ? conv_feat : spab_m_feat;
    wire buf0_s_user = conv_load_active ? conv_user : spab_m_user;
    wire buf0_s_last = conv_load_active ? conv_last : spab_m_last;

    wire buf1_s_valid = spab_to_buf1 ? (spab_m_valid && target_take_allowed) : 1'b0;
    wire [FEAT_W-1:0] buf1_s_feat = spab_m_feat;
    wire buf1_s_user = spab_m_user;
    wire buf1_s_last = spab_m_last;

    assign buf0_m_ready = ((state == ST_BLOCK_RUN) && (current_sel == 1'b0)) ? spab_s_ready : 1'b0;
    assign buf1_m_ready = ((state == ST_BLOCK_RUN) && (current_sel == 1'b1)) ? spab_s_ready : 1'b0;
    assign spab_s_valid = (current_sel == 1'b0) ? buf0_m_valid : buf1_m_valid;
    assign spab_s_feat = (current_sel == 1'b0) ? buf0_m_feat : buf1_m_feat;
    assign spab_s_user = (current_sel == 1'b0) ? buf0_m_user : buf1_m_user;
    assign spab_s_last = (current_sel == 1'b0) ? buf0_m_last : buf1_m_last;

    assign spab_m_ready = last_block ? m_ready : (target_s_ready && target_take_allowed);
    assign m_valid = ((state == ST_BLOCK_RUN) && last_block) ? spab_m_valid : 1'b0;
    assign m_feat = spab_m_feat;
    assign m_user = spab_m_user;
    assign m_last = spab_m_last;
    assign tap_b1_valid = spab_m_valid && tap_b1_active && target_s_ready;
    assign tap_b1_feat = spab_m_feat;
    assign tap_b1_user = spab_m_user;
    assign tap_b1_last = spab_m_last;
    assign tap_b6_act1_valid = spab_tap_c1_valid && (state == ST_BLOCK_RUN) && last_block;
    assign spab_tap_c1_ready = ((state == ST_BLOCK_RUN) && last_block) ? tap_b6_act1_ready : 1'b1;
    assign tap_b6_act1_feat = spab_tap_c1_feat;
    assign tap_b6_act1_user = spab_tap_c1_user;
    assign tap_b6_act1_last = spab_tap_c1_last;

    sr_tile_halo_fetch_w8a12_conv1_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .HALO(HALO),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(OUT_CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_conv1_tile (
        .clk(clk),
        .rst(rst),
        .cmd_valid(inner_cmd_valid),
        .cmd_ready(inner_cmd_ready),
        .cmd_image_w(cmd_image_w),
        .cmd_image_h(cmd_image_h),
        .cmd_tile_x(cmd_tile_x),
        .cmd_tile_y(cmd_tile_y),
        .cmd_input_base(cmd_input_base),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .m_valid(conv_valid),
        .m_ready(conv_ready),
        .m_feat(conv_feat),
        .m_user(conv_user),
        .m_last(conv_last),
        .fetch_busy(fetch_busy),
        .fetch_done(fetch_done),
        .fetch_error(fetch_error)
    );

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H)
    ) u_buf0 (
        .clk(clk),
        .rst(rst),
        .load_start(buf0_load_start),
        .load_busy(buf0_load_busy),
        .load_done(buf0_load_done),
        .load_error(buf0_load_error),
        .s_valid(buf0_s_valid),
        .s_ready(buf0_s_ready),
        .s_feat(buf0_s_feat),
        .s_user(buf0_s_user),
        .s_last(buf0_s_last),
        .stream_start(buf0_stream_start),
        .stream_busy(buf0_stream_busy),
        .stream_done(buf0_stream_done),
        .m_valid(buf0_m_valid),
        .m_ready(buf0_m_ready),
        .m_feat(buf0_m_feat),
        .m_user(buf0_m_user),
        .m_last(buf0_m_last)
    );

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H)
    ) u_buf1 (
        .clk(clk),
        .rst(rst),
        .load_start(buf1_load_start),
        .load_busy(buf1_load_busy),
        .load_done(buf1_load_done),
        .load_error(buf1_load_error),
        .s_valid(buf1_s_valid),
        .s_ready(buf1_s_ready),
        .s_feat(buf1_s_feat),
        .s_user(buf1_s_user),
        .s_last(buf1_s_last),
        .stream_start(buf1_stream_start),
        .stream_busy(buf1_stream_busy),
        .stream_done(buf1_stream_done),
        .m_valid(buf1_m_valid),
        .m_ready(buf1_m_ready),
        .m_feat(buf1_m_feat),
        .m_user(buf1_m_user),
        .m_last(buf1_m_last)
    );

    sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(OUT_CH),
        .BLOCKS(BLOCKS),
        .BLOCK_W(BLOCK_INDEX_W),
        .DEBUG_HASHES(0),
        .DEBUG_SAMPLES(DEBUG_HASHES)
    ) u_spab (
        .clk(clk),
        .rst(rst),
        .start(spab_start),
        .ready(spab_ready),
        .busy(spab_busy),
        .done(spab_done),
        .error(spab_error),
        .block_i(block_index_r),
        .s_valid(spab_s_valid),
        .s_ready(spab_s_ready),
        .s_feat(spab_s_feat),
        .s_user(spab_s_user),
        .s_last(spab_s_last),
        .m_valid(spab_m_valid),
        .m_ready(spab_m_ready),
        .m_feat(spab_m_feat),
        .m_user(spab_m_user),
        .m_last(spab_m_last),
        .tap_c1_valid(spab_tap_c1_valid),
        .tap_c1_ready(spab_tap_c1_ready),
        .tap_c1_feat(spab_tap_c1_feat),
        .tap_c1_user(spab_tap_c1_user),
        .tap_c1_last(spab_tap_c1_last),
        .residual_load_count(spab_residual_load_count),
        .c1_load_count(spab_c1_load_count),
        .c1_output_count(spab_c1_output_count),
        .c1_lane_output_count(spab_c1_lane_output_count),
        .c1_debug_state(spab_c1_debug_state),
        .c1_core_debug_state(spab_c1_core_debug_state),
        .c1_lane_debug_state(spab_c1_lane_debug_state),
        .c1_core_io_debug_state(spab_c1_core_io_debug_state),
        .c2_load_count(spab_c2_load_count),
        .c2_output_count(spab_c2_output_count),
        .c2_lane_output_count(spab_c2_lane_output_count),
        .c2_debug_state(spab_c2_debug_state),
        .c2_core_debug_state(spab_c2_core_debug_state),
        .c2_lane_debug_state(spab_c2_lane_debug_state),
        .c3_load_count(spab_c3_load_count),
        .c3_output_count(spab_c3_output_count),
        .c3_lane_output_count(spab_c3_lane_output_count),
        .c3_debug_state(spab_c3_debug_state),
        .c3_core_debug_state(spab_c3_core_debug_state),
        .c3_lane_debug_state(spab_c3_lane_debug_state),
        .c3_core_io_debug_state(spab_c3_core_io_debug_state),
        .att_input_count(spab_att_input_count),
        .att_output_count(spab_att_output_count),
        .att_lane_output_count(spab_att_lane_output_count),
        .debug_error_flags(debug_spab_flags),
        .att_debug_state(debug_att_detail),
        .debug_hash_input(debug_hash_spab_input),
        .debug_hash_c1(debug_hash_spab_c1),
        .debug_hash_c1_raw(spab_debug_hash_c1_raw),
        .debug_c1_sample0(spab_debug_c1_sample0),
        .debug_c1_sample1(spab_debug_c1_sample1),
        .debug_c1_sample2(spab_debug_c1_sample2),
        .debug_c1_sample3(spab_debug_c1_sample3),
        .debug_hash_c2(debug_hash_spab_c2),
        .debug_hash_c2_replay(debug_hash_spab_c2_replay),
        .debug_hash_c2_window(debug_hash_spab_c2_window),
        .debug_hash_c2_raw(debug_hash_spab_c2_raw),
        .debug_c2_sample0(debug_spab_c2_sample0),
        .debug_c2_sample1(debug_spab_c2_sample1),
        .debug_c2_sample2(debug_spab_c2_sample2),
        .debug_c2_sample3(debug_spab_c2_sample3),
        .debug_hash_c3(debug_hash_spab_c3),
        .debug_hash_residual(debug_hash_spab_residual),
        .debug_hash_att(debug_hash_spab_att)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            inner_cmd_valid <= 1'b0;
            buf0_load_start <= 1'b0;
            buf1_load_start <= 1'b0;
            buf0_stream_start <= 1'b0;
            buf1_stream_start <= 1'b0;
            spab_start <= 1'b0;
            done_r <= 1'b0;
            error_r <= 1'b0;
            current_sel <= 1'b0;
            block_index_r <= {BLOCK_INDEX_W{1'b0}};
            current_stream_done_seen <= 1'b0;
            target_load_done_seen <= 1'b0;
            spab_done_seen <= 1'b0;
            block_start_count_r <= 16'd0;
            replay_feature_count_r <= 32'd0;
            block_output_count_r <= 32'd0;
            debug_hash_feat0 <= 32'h811C_9DC5;
            debug_hash_block6 <= 32'h811C_9DC5;
            debug_hash_b1 <= 32'h811C_9DC5;
            debug_hash_b6_act1 <= 32'h811C_9DC5;
            debug_hash_spab_b1_input <= 32'h811C_9DC5;
            debug_hash_spab_b1_c1 <= 32'h811C_9DC5;
            debug_hash_spab_b1_c1_raw <= 32'h811C_9DC5;
            debug_spab_b1_c1_sample0 <= 32'd0;
            debug_spab_b1_c1_sample1 <= 32'd0;
            debug_spab_b1_c1_sample2 <= 32'd0;
            debug_spab_b1_c1_sample3 <= 32'd0;
            debug_hash_spab_b2_att <= 32'h811C_9DC5;
            debug_hash_spab_b3_att <= 32'h811C_9DC5;
            debug_hash_spab_b4_att <= 32'h811C_9DC5;
            debug_hash_spab_b5_att <= 32'h811C_9DC5;
            debug_hash_spab_b1_c2 <= 32'h811C_9DC5;
            debug_hash_spab_b1_c2_replay <= 32'h811C_9DC5;
            debug_hash_spab_b1_c2_window <= 32'h811C_9DC5;
            debug_hash_spab_b1_c2_raw <= 32'h811C_9DC5;
            debug_spab_b1_c2_sample0 <= 32'd0;
            debug_spab_b1_c2_sample1 <= 32'd0;
            debug_spab_b1_c2_sample2 <= 32'd0;
            debug_spab_b1_c2_sample3 <= 32'd0;
            debug_hash_spab_b1_c3 <= 32'h811C_9DC5;
            debug_hash_spab_b1_residual <= 32'h811C_9DC5;
            debug_hash_spab_b1_att <= 32'h811C_9DC5;
        end else begin
            buf0_load_start <= 1'b0;
            buf1_load_start <= 1'b0;
            buf0_stream_start <= 1'b0;
            buf1_stream_start <= 1'b0;
            spab_start <= 1'b0;
            done_r <= 1'b0;

            if (inner_cmd_take)
                inner_cmd_valid <= 1'b0;
            if (current_stream_done)
                current_stream_done_seen <= 1'b1;
            if (target_load_done)
                target_load_done_seen <= 1'b1;
            if (spab_done)
                spab_done_seen <= 1'b1;
            if (DEBUG_COUNTERS != 0 && replay_take)
                replay_feature_count_r <= replay_feature_count_r + 1'b1;
            if (DEBUG_COUNTERS != 0 && block_output_take)
                block_output_count_r <= block_output_count_r + 1'b1;
            if (DEBUG_HASHES != 0 && conv_output_take)
                debug_hash_feat0 <= rotl5(debug_hash_feat0) ^
                                    feature_signature(conv_feat);
            if (DEBUG_HASHES != 0 && replay_take && first_block)
                debug_hash_spab_b1_input <= rotl5(debug_hash_spab_b1_input) ^
                                            feature_signature(spab_s_feat);
            if (DEBUG_HASHES != 0 && final_block_take)
                debug_hash_block6 <= rotl5(debug_hash_block6) ^
                                     feature_signature(m_feat);
            if (DEBUG_HASHES != 0 && b1_tap_take)
                debug_hash_b1 <= rotl5(debug_hash_b1) ^
                                 feature_signature(tap_b1_feat);
            if (DEBUG_HASHES != 0 && b6_act1_tap_take)
                debug_hash_b6_act1 <= rotl5(debug_hash_b6_act1) ^
                                      feature_signature(tap_b6_act1_feat);
            if (DEBUG_HASHES != 0 && block_output_take) begin
                if (block_index_r == 0)
                    debug_hash_spab_b1_att <= rotl5(debug_hash_spab_b1_att) ^
                                              feature_signature(spab_m_feat);
                if (block_index_r == 1)
                    debug_hash_spab_b2_att <= rotl5(debug_hash_spab_b2_att) ^
                                              feature_signature(spab_m_feat);
                if (block_index_r == 2)
                    debug_hash_spab_b3_att <= rotl5(debug_hash_spab_b3_att) ^
                                              feature_signature(spab_m_feat);
                if (block_index_r == 3)
                    debug_hash_spab_b4_att <= rotl5(debug_hash_spab_b4_att) ^
                                              feature_signature(spab_m_feat);
                if (block_index_r == 4)
                    debug_hash_spab_b5_att <= rotl5(debug_hash_spab_b5_att) ^
                                              feature_signature(spab_m_feat);
            end
            if (first_block) begin
                debug_hash_spab_b1_c1 <= debug_hash_spab_c1;
                debug_hash_spab_b1_c1_raw <= spab_debug_hash_c1_raw;
                debug_spab_b1_c1_sample0 <= spab_debug_c1_sample0;
                debug_spab_b1_c1_sample1 <= spab_debug_c1_sample1;
                debug_spab_b1_c1_sample2 <= spab_debug_c1_sample2;
                debug_spab_b1_c1_sample3 <= spab_debug_c1_sample3;
                debug_hash_spab_b1_c2 <= debug_hash_spab_c2;
                debug_hash_spab_b1_c2_replay <= debug_hash_spab_c2_replay;
                debug_hash_spab_b1_c2_window <= debug_hash_spab_c2_window;
                debug_hash_spab_b1_c2_raw <= debug_hash_spab_c2_raw;
                debug_spab_b1_c2_sample0 <= debug_spab_c2_sample0;
                debug_spab_b1_c2_sample1 <= debug_spab_c2_sample1;
                debug_spab_b1_c2_sample2 <= debug_spab_c2_sample2;
                debug_spab_b1_c2_sample3 <= debug_spab_c2_sample3;
                debug_hash_spab_b1_c3 <= debug_hash_spab_c3;
                debug_hash_spab_b1_residual <= debug_hash_spab_residual;
            end
            if (fetch_error || buf0_load_error || buf1_load_error ||
                spab_error_active)
                error_r <= 1'b1;

            case (state)
                ST_IDLE: begin
                    if (cmd_valid && cmd_ready) begin
                        inner_cmd_valid <= 1'b1;
                        buf0_load_start <= 1'b1;
                        current_sel <= 1'b0;
                        block_index_r <= {BLOCK_INDEX_W{1'b0}};
                        current_stream_done_seen <= 1'b0;
                        target_load_done_seen <= 1'b0;
                        spab_done_seen <= 1'b0;
                        block_start_count_r <= 16'd0;
                        replay_feature_count_r <= 32'd0;
                        block_output_count_r <= 32'd0;
                        debug_hash_feat0 <= 32'h811C_9DC5;
                        debug_hash_block6 <= 32'h811C_9DC5;
                        debug_hash_b1 <= 32'h811C_9DC5;
                        debug_hash_b6_act1 <= 32'h811C_9DC5;
                        debug_hash_spab_b1_input <= 32'h811C_9DC5;
                        debug_hash_spab_b1_c1 <= 32'h811C_9DC5;
                        debug_hash_spab_b1_c1_raw <= 32'h811C_9DC5;
                        debug_spab_b1_c1_sample0 <= 32'd0;
                        debug_spab_b1_c1_sample1 <= 32'd0;
                        debug_spab_b1_c1_sample2 <= 32'd0;
                        debug_spab_b1_c1_sample3 <= 32'd0;
                        debug_hash_spab_b2_att <= 32'h811C_9DC5;
                        debug_hash_spab_b3_att <= 32'h811C_9DC5;
                        debug_hash_spab_b4_att <= 32'h811C_9DC5;
                        debug_hash_spab_b5_att <= 32'h811C_9DC5;
                        debug_hash_spab_b1_c2 <= 32'h811C_9DC5;
                        debug_hash_spab_b1_c2_replay <= 32'h811C_9DC5;
                        debug_hash_spab_b1_c2_window <= 32'h811C_9DC5;
                        debug_hash_spab_b1_c2_raw <= 32'h811C_9DC5;
                        debug_spab_b1_c2_sample0 <= 32'd0;
                        debug_spab_b1_c2_sample1 <= 32'd0;
                        debug_spab_b1_c2_sample2 <= 32'd0;
                        debug_spab_b1_c2_sample3 <= 32'd0;
                        debug_hash_spab_b1_c3 <= 32'h811C_9DC5;
                        debug_hash_spab_b1_residual <= 32'h811C_9DC5;
                        debug_hash_spab_b1_att <= 32'h811C_9DC5;
                        error_r <= 1'b0;
                        state <= ST_CONV_LOAD;
                    end
                end

                ST_CONV_LOAD: begin
                    if (buf0_load_done)
                        state <= ST_BLOCK_START;
                end

                ST_BLOCK_START: begin
                    if (spab_ready) begin
                        spab_start <= 1'b1;
                        if (current_sel == 1'b0)
                            buf0_stream_start <= 1'b1;
                        else
                            buf1_stream_start <= 1'b1;

                        if (!last_block) begin
                            if (target_sel == 1'b0)
                                buf0_load_start <= 1'b1;
                            else
                                buf1_load_start <= 1'b1;
                        end

                        current_stream_done_seen <= 1'b0;
                        target_load_done_seen <= last_block;
                        spab_done_seen <= 1'b0;
                        if (DEBUG_COUNTERS != 0)
                            block_start_count_r <= block_start_count_r + 1'b1;
                        state <= ST_BLOCK_RUN;
                    end
                end

                ST_BLOCK_RUN: begin
                    if (current_stream_done_now && target_load_done_now && spab_done_now) begin
                        if (last_block) begin
                            state <= ST_DONE;
                        end else begin
                            current_sel <= target_sel;
                            block_index_r <= block_index_r + 1'b1;
                            state <= ST_BLOCK_START;
                        end
                    end
                end

                ST_DONE: begin
                    done_r <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    error_r <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    wire unused_status = fetch_busy | fetch_done | buf0_load_busy | buf1_load_busy |
                         buf0_stream_busy | buf1_stream_busy | spab_busy |
                         |spab_residual_load_count | |spab_c1_load_count |
                         |spab_c1_output_count | |spab_c1_lane_output_count |
                         |spab_c2_load_count | |spab_c2_output_count |
                         |spab_c2_lane_output_count | |spab_c3_load_count |
                         |spab_c3_output_count | |spab_c3_lane_output_count |
                         |spab_att_input_count | |spab_att_output_count |
                         |spab_att_lane_output_count;
endmodule
