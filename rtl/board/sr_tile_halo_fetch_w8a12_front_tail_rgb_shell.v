`timescale 1ns/1ps

// Hardware-side halo tile front end through runtime SPAB6 plus W8A12 tail.
//
// The front end fetches tile+halo from the large SD/DDR image address stream,
// computes conv1, reuses one runtime block-group SPAB backend for blocks 1..6,
// captures the skip taps required by the SPAN tail, then emits X4 RGB q values.
module sr_tile_halo_fetch_w8a12_front_tail_rgb_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer HALO = 1,
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
    parameter integer DEBUG_SRC_HASH = 0,
    parameter integer DEBUG_SPAB_HASH = 0,
    parameter integer DEBUG_TAIL_HANDSHAKE = 0,
    parameter integer BLOCKS = 6,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer IN_PIXELS = TILE_W * TILE_H,
    parameter integer OUT_PIXELS = TILE_W * TILE_H * SCALE * SCALE,
    parameter integer OUT_PIX_W = (OUT_PIXELS <= 2) ? 1 : $clog2(OUT_PIXELS + 1)
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
    output wire signed [3*ACT_W-1:0]  m_rgb,
    output wire                       m_user,
    output wire                       m_last,

    output wire                       busy,
    output reg                        done,
    output wire                       error,
    output wire [15:0]                block_start_count,
    output wire [31:0]                replay_feature_count,
    output wire [31:0]                block_output_count,
    output reg  [OUT_PIX_W-1:0]       rgb_output_count,
    output wire [31:0]                front_debug_state,
    output wire [31:0]                front_debug_c1_counts,
    output wire [31:0]                front_debug_c2_counts,
    output wire [31:0]                front_debug_c3_counts,
    output wire [31:0]                front_debug_att_counts,
    output wire [31:0]                front_debug_c1_lane_outputs,
    output wire [31:0]                front_debug_c2_lane_outputs,
    output wire [31:0]                front_debug_c3_lane_outputs,
    output wire [31:0]                front_debug_att_lane_outputs,
    output wire [31:0]                front_debug_c1_detail,
    output wire [31:0]                front_debug_c1_core_detail,
    output wire [31:0]                front_debug_c1_lane_detail,
    output wire [31:0]                front_debug_c1_io_detail,
    output wire [31:0]                front_debug_c2_detail,
    output wire [31:0]                front_debug_c3_detail,
    output wire [31:0]                front_debug_c2_core_detail,
    output wire [31:0]                front_debug_c2_lane_detail,
    output wire [31:0]                front_debug_c3_core_detail,
    output wire [31:0]                front_debug_c3_lane_detail,
    output wire [31:0]                front_debug_c3_io_detail,
    output wire [31:0]                front_debug_spab_flags,
    output wire [31:0]                front_debug_att_detail,
    output reg  [31:0]                front_debug_tail_feat0_hash,
    output reg  [31:0]                front_debug_tail_block6_hash,
    output reg  [31:0]                front_debug_tail_b1_hash,
    output reg  [31:0]                front_debug_tail_b6_act1_hash,
    output reg  [31:0]                front_debug_tail_rgb_q_hash,
    output reg  [31:0]                front_debug_src_feat0_hash,
    output reg  [31:0]                front_debug_src_block6_hash,
    output reg  [31:0]                front_debug_src_b1_hash,
    output reg  [31:0]                front_debug_src_b6_act1_hash,
    output wire [31:0]                front_debug_spab_hash_input,
    output wire [31:0]                front_debug_spab_hash_c1,
    output wire [31:0]                front_debug_spab_hash_c2,
    output wire [31:0]                front_debug_spab_hash_c3,
    output wire [31:0]                front_debug_spab_hash_residual,
    output wire [31:0]                front_debug_spab_hash_att,
    output wire [31:0]                front_debug_spab_b1_hash_input,
    output wire [31:0]                front_debug_spab_b1_hash_c1,
    output wire [31:0]                front_debug_spab_b1_hash_c1_raw,
    output wire [31:0]                front_debug_spab_b1_c1_sample0,
    output wire [31:0]                front_debug_spab_b1_c1_sample1,
    output wire [31:0]                front_debug_spab_b1_c1_sample2,
    output wire [31:0]                front_debug_spab_b1_c1_sample3,
    output wire [31:0]                front_debug_spab_b2_hash_att,
    output wire [31:0]                front_debug_spab_b3_hash_att,
    output wire [31:0]                front_debug_spab_b4_hash_att,
    output wire [31:0]                front_debug_spab_b5_hash_att,
    output wire [31:0]                front_debug_spab_b1_hash_c2,
    output wire [31:0]                front_debug_spab_b1_hash_c2_replay,
    output wire [31:0]                front_debug_spab_b1_hash_c2_window,
    output wire [31:0]                front_debug_spab_b1_hash_c2_raw,
    output wire [31:0]                front_debug_spab_b1_c2_sample0,
    output wire [31:0]                front_debug_spab_b1_c2_sample1,
    output wire [31:0]                front_debug_spab_b1_c2_sample2,
    output wire [31:0]                front_debug_spab_b1_c2_sample3,
    output wire [31:0]                front_debug_spab_b1_hash_c3,
    output wire [31:0]                front_debug_spab_b1_hash_residual,
    output wire [31:0]                front_debug_spab_b1_hash_att
);
    localparam [2:0] ST_IDLE         = 3'd0;
    localparam [2:0] ST_LOAD         = 3'd1;
    localparam [2:0] ST_STREAM_START = 3'd2;
    localparam [2:0] ST_STREAM       = 3'd3;
    localparam [2:0] ST_DONE         = 3'd4;
    localparam integer DBG_COUNT_W = (OUT_PIX_W < 16) ? OUT_PIX_W : 16;

    reg [2:0] state;
    reg front_cmd_valid;
    reg feat0_load_start;
    reg b1_load_start;
    reg b6_act1_load_start;
    reg block6_load_start;
    reg feat0_stream_start;
    reg b1_stream_start;
    reg b6_act1_stream_start;
    reg block6_stream_start;
    reg front_done_seen;
    reg feat0_load_done_seen;
    reg b1_load_done_seen;
    reg b6_act1_load_done_seen;
    reg block6_load_done_seen;
    reg error_r;
    reg [OUT_PIX_W-1:0] src_feat0_count;
    reg [OUT_PIX_W-1:0] src_block6_count;
    reg [OUT_PIX_W-1:0] src_b1_count;
    reg [OUT_PIX_W-1:0] src_b6_act1_count;
    reg [15:0] tail_input_count;
    reg [15:0] tail_ready_cycle_count;
    reg [15:0] tail_all_valid_cycle_count;
    reg [15:0] tail_m_valid_cycle_count;
    reg [15:0] feat0_valid_cycle_count;
    reg [15:0] b1_valid_cycle_count;
    reg [15:0] b6_act1_valid_cycle_count;
    reg [15:0] block6_valid_cycle_count;
    reg [15:0] feat0_take_count;
    reg [15:0] b1_take_count;
    reg [15:0] b6_act1_take_count;
    reg [15:0] block6_take_count;

    wire front_cmd_ready;
    wire front_busy;
    wire front_done;
    wire front_error;
    wire front_m_valid;
    wire front_m_ready;
    wire [FEAT_W-1:0] front_m_feat;
    wire front_m_user;
    wire front_m_last;

    wire tap_feat0_valid;
    wire tap_feat0_ready;
    wire [FEAT_W-1:0] tap_feat0_feat;
    wire tap_feat0_user;
    wire tap_feat0_last;

    wire tap_b1_valid;
    wire tap_b1_ready;
    wire [FEAT_W-1:0] tap_b1_feat;
    wire tap_b1_user;
    wire tap_b1_last;

    wire tap_b6_act1_valid;
    wire tap_b6_act1_ready;
    wire [FEAT_W-1:0] tap_b6_act1_feat;
    wire tap_b6_act1_user;
    wire tap_b6_act1_last;
    wire [31:0] sched_debug_hash_feat0;
    wire [31:0] sched_debug_hash_block6;
    wire [31:0] sched_debug_hash_b1;
    wire [31:0] sched_debug_hash_b6_act1;

    wire feat0_load_busy;
    wire feat0_load_done;
    wire feat0_load_error;
    wire feat0_stream_busy;
    wire feat0_stream_done;
    wire feat0_m_valid;
    wire feat0_m_ready;
    wire [FEAT_W-1:0] feat0_m_feat;
    wire feat0_m_user;
    wire feat0_m_last;

    wire b1_load_busy;
    wire b1_load_done;
    wire b1_load_error;
    wire b1_stream_busy;
    wire b1_stream_done;
    wire b1_m_valid;
    wire b1_m_ready;
    wire [FEAT_W-1:0] b1_m_feat;
    wire b1_m_user;
    wire b1_m_last;

    wire b6_act1_load_busy;
    wire b6_act1_load_done;
    wire b6_act1_load_error;
    wire b6_act1_stream_busy;
    wire b6_act1_stream_done;
    wire b6_act1_m_valid;
    wire b6_act1_m_ready;
    wire [FEAT_W-1:0] b6_act1_m_feat;
    wire b6_act1_m_user;
    wire b6_act1_m_last;

    wire block6_load_busy;
    wire block6_load_done;
    wire block6_load_error;
    wire block6_stream_busy;
    wire block6_stream_done;
    wire block6_m_valid;
    wire block6_m_ready;
    wire [FEAT_W-1:0] block6_m_feat;
    wire block6_m_user;
    wire block6_m_last;

    wire tail_s_valid;
    wire tail_s_ready;
    wire tail_input_take;
    wire rgb_output_take;
    wire src_feat0_take;
    wire src_block6_take;
    wire src_b1_take;
    wire src_b6_act1_take;
    wire all_load_done = front_done_seen &&
                         feat0_load_done_seen && b1_load_done_seen &&
                         b6_act1_load_done_seen && block6_load_done_seen;
    wire all_tail_inputs_valid = feat0_m_valid && b1_m_valid &&
                                 b6_act1_m_valid && block6_m_valid;
    wire sideband_mismatch = tail_input_take &&
                             ((feat0_m_user != block6_m_user) ||
                              (b1_m_user != block6_m_user) ||
                              (b6_act1_m_user != block6_m_user) ||
                              (feat0_m_last != block6_m_last) ||
                              (b1_m_last != block6_m_last) ||
                              (b6_act1_m_last != block6_m_last));

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
            for (sig_ch = 0; sig_ch < CH; sig_ch = sig_ch + 1) begin
                sample = $signed(feat[sig_ch*ACT_W +: ACT_W]);
                acc = rotl5(acc) ^
                      {{(32-ACT_W){sample[ACT_W-1]}}, sample} ^
                      (32'h7F4A_7C15 + sig_ch[31:0]);
            end
            feature_signature = acc;
        end
    endfunction

    function [31:0] rgb_q_signature;
        input [3*ACT_W-1:0] rgb;
        integer sig_ch;
        reg signed [ACT_W-1:0] sample;
        reg [31:0] acc;
        begin
            acc = 32'h85EB_CA6B;
            for (sig_ch = 0; sig_ch < 3; sig_ch = sig_ch + 1) begin
                sample = $signed(rgb[sig_ch*ACT_W +: ACT_W]);
                acc = rotl5(acc) ^
                      {{(32-ACT_W){sample[ACT_W-1]}}, sample} ^
                      (32'hC2B2_AE35 + sig_ch[31:0]);
            end
            rgb_q_signature = acc;
        end
    endfunction

    assign cmd_ready = (state == ST_IDLE) && front_cmd_ready &&
                       !feat0_load_busy && !b1_load_busy &&
                       !b6_act1_load_busy && !block6_load_busy &&
                       !feat0_stream_busy && !b1_stream_busy &&
                       !b6_act1_stream_busy && !block6_stream_busy;
    assign busy = (state != ST_IDLE) || front_busy || front_cmd_valid;
    assign error = error_r || front_error || feat0_load_error || b1_load_error ||
                   b6_act1_load_error || block6_load_error;

    assign tail_s_valid = (state == ST_STREAM) && all_tail_inputs_valid;
    assign feat0_m_ready = (state == ST_STREAM) && tail_s_ready &&
                           b1_m_valid && b6_act1_m_valid && block6_m_valid;
    assign b1_m_ready = (state == ST_STREAM) && tail_s_ready &&
                        feat0_m_valid && b6_act1_m_valid && block6_m_valid;
    assign b6_act1_m_ready = (state == ST_STREAM) && tail_s_ready &&
                             feat0_m_valid && b1_m_valid && block6_m_valid;
    assign block6_m_ready = (state == ST_STREAM) && tail_s_ready &&
                            feat0_m_valid && b1_m_valid && b6_act1_m_valid;
    assign tail_input_take = tail_s_valid && tail_s_ready;
    assign rgb_output_take = m_valid && m_ready;
    assign src_feat0_take = tap_feat0_valid && tap_feat0_ready;
    assign src_block6_take = front_m_valid && front_m_ready;
    assign src_b1_take = tap_b1_valid && tap_b1_ready;
    assign src_b6_act1_take = tap_b6_act1_valid && tap_b6_act1_ready;

    wire signed [15:0] rgb_q_r16 =
        {{(16-ACT_W){m_rgb[0*ACT_W + ACT_W - 1]}}, m_rgb[0*ACT_W +: ACT_W]};
    wire signed [15:0] rgb_q_g16 =
        {{(16-ACT_W){m_rgb[1*ACT_W + ACT_W - 1]}}, m_rgb[1*ACT_W +: ACT_W]};
    wire signed [15:0] rgb_q_b16 =
        {{(16-ACT_W){m_rgb[2*ACT_W + ACT_W - 1]}}, m_rgb[2*ACT_W +: ACT_W]};
    wire signed [15:0] rgb_q_sample_min =
        (rgb_q_r16 <= rgb_q_g16 && rgb_q_r16 <= rgb_q_b16) ? rgb_q_r16 :
        (rgb_q_g16 <= rgb_q_b16) ? rgb_q_g16 : rgb_q_b16;
    wire signed [15:0] rgb_q_sample_max =
        (rgb_q_r16 >= rgb_q_g16 && rgb_q_r16 >= rgb_q_b16) ? rgb_q_r16 :
        (rgb_q_g16 >= rgb_q_b16) ? rgb_q_g16 : rgb_q_b16;
    wire [1:0] rgb_q_positive_inc =
        (rgb_q_r16 > 16'sd0 ? 2'd1 : 2'd0) +
        (rgb_q_g16 > 16'sd0 ? 2'd1 : 2'd0) +
        (rgb_q_b16 > 16'sd0 ? 2'd1 : 2'd0);
    wire [15:0] rgb_output_count_dbg16 =
        {{(16-DBG_COUNT_W){1'b0}}, rgb_output_count[DBG_COUNT_W-1:0]};

    sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .HALO(HALO),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .BLOCKS(BLOCKS),
        .DEBUG_HASHES(DEBUG_SPAB_HASH)
    ) u_front (
        .clk(clk),
        .rst(rst),
        .cmd_valid(front_cmd_valid),
        .cmd_ready(front_cmd_ready),
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
        .m_valid(front_m_valid),
        .m_ready(front_m_ready),
        .m_feat(front_m_feat),
        .m_user(front_m_user),
        .m_last(front_m_last),
        .tap_feat0_valid(tap_feat0_valid),
        .tap_feat0_ready(tap_feat0_ready),
        .tap_feat0_feat(tap_feat0_feat),
        .tap_feat0_user(tap_feat0_user),
        .tap_feat0_last(tap_feat0_last),
        .tap_b1_valid(tap_b1_valid),
        .tap_b1_ready(tap_b1_ready),
        .tap_b1_feat(tap_b1_feat),
        .tap_b1_user(tap_b1_user),
        .tap_b1_last(tap_b1_last),
        .tap_b6_act1_valid(tap_b6_act1_valid),
        .tap_b6_act1_ready(tap_b6_act1_ready),
        .tap_b6_act1_feat(tap_b6_act1_feat),
        .tap_b6_act1_user(tap_b6_act1_user),
        .tap_b6_act1_last(tap_b6_act1_last),
        .busy(front_busy),
        .done(front_done),
        .error(front_error),
        .block_index(),
        .block_start_count(block_start_count),
        .replay_feature_count(replay_feature_count),
        .block_output_count(block_output_count),
        .debug_state(front_debug_state),
        .debug_c1_counts(front_debug_c1_counts),
        .debug_c2_counts(front_debug_c2_counts),
        .debug_c3_counts(front_debug_c3_counts),
        .debug_att_counts(front_debug_att_counts),
        .debug_c1_lane_outputs(front_debug_c1_lane_outputs),
        .debug_c2_lane_outputs(front_debug_c2_lane_outputs),
        .debug_c3_lane_outputs(front_debug_c3_lane_outputs),
        .debug_att_lane_outputs(front_debug_att_lane_outputs),
        .debug_c1_detail(front_debug_c1_detail),
        .debug_c1_core_detail(front_debug_c1_core_detail),
        .debug_c1_lane_detail(front_debug_c1_lane_detail),
        .debug_c1_io_detail(front_debug_c1_io_detail),
        .debug_c2_detail(front_debug_c2_detail),
        .debug_c3_detail(front_debug_c3_detail),
        .debug_c2_core_detail(front_debug_c2_core_detail),
        .debug_c2_lane_detail(front_debug_c2_lane_detail),
        .debug_c3_core_detail(front_debug_c3_core_detail),
        .debug_c3_lane_detail(front_debug_c3_lane_detail),
        .debug_c3_io_detail(front_debug_c3_io_detail),
        .debug_spab_flags(front_debug_spab_flags),
        .debug_att_detail(front_debug_att_detail),
        .debug_hash_feat0(sched_debug_hash_feat0),
        .debug_hash_block6(sched_debug_hash_block6),
        .debug_hash_b1(sched_debug_hash_b1),
        .debug_hash_b6_act1(sched_debug_hash_b6_act1),
        .debug_hash_spab_input(front_debug_spab_hash_input),
        .debug_hash_spab_c1(front_debug_spab_hash_c1),
        .debug_hash_spab_c2(front_debug_spab_hash_c2),
        .debug_spab_c2_sample0(),
        .debug_spab_c2_sample1(),
        .debug_spab_c2_sample2(),
        .debug_spab_c2_sample3(),
        .debug_hash_spab_c3(front_debug_spab_hash_c3),
        .debug_hash_spab_residual(front_debug_spab_hash_residual),
        .debug_hash_spab_att(front_debug_spab_hash_att),
        .debug_hash_spab_b1_input(front_debug_spab_b1_hash_input),
        .debug_hash_spab_b1_c1(front_debug_spab_b1_hash_c1),
        .debug_hash_spab_b1_c1_raw(front_debug_spab_b1_hash_c1_raw),
        .debug_spab_b1_c1_sample0(front_debug_spab_b1_c1_sample0),
        .debug_spab_b1_c1_sample1(front_debug_spab_b1_c1_sample1),
        .debug_spab_b1_c1_sample2(front_debug_spab_b1_c1_sample2),
        .debug_spab_b1_c1_sample3(front_debug_spab_b1_c1_sample3),
        .debug_hash_spab_b2_att(front_debug_spab_b2_hash_att),
        .debug_hash_spab_b3_att(front_debug_spab_b3_hash_att),
        .debug_hash_spab_b4_att(front_debug_spab_b4_hash_att),
        .debug_hash_spab_b5_att(front_debug_spab_b5_hash_att),
        .debug_hash_spab_b1_c2(front_debug_spab_b1_hash_c2),
        .debug_hash_spab_b1_c2_replay(front_debug_spab_b1_hash_c2_replay),
        .debug_hash_spab_b1_c2_window(front_debug_spab_b1_hash_c2_window),
        .debug_hash_spab_b1_c2_raw(front_debug_spab_b1_hash_c2_raw),
        .debug_spab_b1_c2_sample0(front_debug_spab_b1_c2_sample0),
        .debug_spab_b1_c2_sample1(front_debug_spab_b1_c2_sample1),
        .debug_spab_b1_c2_sample2(front_debug_spab_b1_c2_sample2),
        .debug_spab_b1_c2_sample3(front_debug_spab_b1_c2_sample3),
        .debug_hash_spab_b1_c3(front_debug_spab_b1_hash_c3),
        .debug_hash_spab_b1_residual(front_debug_spab_b1_hash_residual),
        .debug_hash_spab_b1_att(front_debug_spab_b1_hash_att)
    );

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W), .TILE_W(TILE_W), .TILE_H(TILE_H)
    ) u_feat0_buf (
        .clk(clk), .rst(rst),
        .load_start(feat0_load_start), .load_busy(feat0_load_busy),
        .load_done(feat0_load_done), .load_error(feat0_load_error),
        .s_valid(tap_feat0_valid), .s_ready(tap_feat0_ready),
        .s_feat(tap_feat0_feat), .s_user(tap_feat0_user), .s_last(tap_feat0_last),
        .stream_start(feat0_stream_start), .stream_busy(feat0_stream_busy),
        .stream_done(feat0_stream_done),
        .m_valid(feat0_m_valid), .m_ready(feat0_m_ready),
        .m_feat(feat0_m_feat), .m_user(feat0_m_user), .m_last(feat0_m_last)
    );

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W), .TILE_W(TILE_W), .TILE_H(TILE_H)
    ) u_b1_buf (
        .clk(clk), .rst(rst),
        .load_start(b1_load_start), .load_busy(b1_load_busy),
        .load_done(b1_load_done), .load_error(b1_load_error),
        .s_valid(tap_b1_valid), .s_ready(tap_b1_ready),
        .s_feat(tap_b1_feat), .s_user(tap_b1_user), .s_last(tap_b1_last),
        .stream_start(b1_stream_start), .stream_busy(b1_stream_busy),
        .stream_done(b1_stream_done),
        .m_valid(b1_m_valid), .m_ready(b1_m_ready),
        .m_feat(b1_m_feat), .m_user(b1_m_user), .m_last(b1_m_last)
    );

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W), .TILE_W(TILE_W), .TILE_H(TILE_H)
    ) u_b6_act1_buf (
        .clk(clk), .rst(rst),
        .load_start(b6_act1_load_start), .load_busy(b6_act1_load_busy),
        .load_done(b6_act1_load_done), .load_error(b6_act1_load_error),
        .s_valid(tap_b6_act1_valid), .s_ready(tap_b6_act1_ready),
        .s_feat(tap_b6_act1_feat), .s_user(tap_b6_act1_user), .s_last(tap_b6_act1_last),
        .stream_start(b6_act1_stream_start), .stream_busy(b6_act1_stream_busy),
        .stream_done(b6_act1_stream_done),
        .m_valid(b6_act1_m_valid), .m_ready(b6_act1_m_ready),
        .m_feat(b6_act1_m_feat), .m_user(b6_act1_m_user), .m_last(b6_act1_m_last)
    );

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W), .TILE_W(TILE_W), .TILE_H(TILE_H)
    ) u_block6_buf (
        .clk(clk), .rst(rst),
        .load_start(block6_load_start), .load_busy(block6_load_busy),
        .load_done(block6_load_done), .load_error(block6_load_error),
        .s_valid(front_m_valid), .s_ready(front_m_ready),
        .s_feat(front_m_feat), .s_user(front_m_user), .s_last(front_m_last),
        .stream_start(block6_stream_start), .stream_busy(block6_stream_busy),
        .stream_done(block6_stream_done),
        .m_valid(block6_m_valid), .m_ready(block6_m_ready),
        .m_feat(block6_m_feat), .m_user(block6_m_user), .m_last(block6_m_last)
    );

    span_w8a12_tail_streamed_rgb #(
        .IMG_W(TILE_W),
        .IMG_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .SCALE_LANES(SCALE_LANES)
    ) u_tail (
        .clk(clk),
        .rst(rst),
        .s_valid(tail_s_valid),
        .s_ready(tail_s_ready),
        .feat0_i(feat0_m_feat),
        .block6_i(block6_m_feat),
        .b1_i(b1_m_feat),
        .b6_act1_i(b6_act1_m_feat),
        .s_user(block6_m_user),
        .s_last(block6_m_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            front_cmd_valid <= 1'b0;
            feat0_load_start <= 1'b0;
            b1_load_start <= 1'b0;
            b6_act1_load_start <= 1'b0;
            block6_load_start <= 1'b0;
            feat0_stream_start <= 1'b0;
            b1_stream_start <= 1'b0;
            b6_act1_stream_start <= 1'b0;
            block6_stream_start <= 1'b0;
            front_done_seen <= 1'b0;
            feat0_load_done_seen <= 1'b0;
            b1_load_done_seen <= 1'b0;
            b6_act1_load_done_seen <= 1'b0;
            block6_load_done_seen <= 1'b0;
            rgb_output_count <= {OUT_PIX_W{1'b0}};
            front_debug_tail_feat0_hash <= 32'h7FFF_8000;
            front_debug_tail_block6_hash <= 32'd0;
            front_debug_tail_b1_hash <= 32'h811C_9DC5;
            front_debug_tail_b6_act1_hash <= 32'h811C_9DC5;
            front_debug_tail_rgb_q_hash <= 32'h811C_9DC5;
            front_debug_src_feat0_hash <= 32'h811C_9DC5;
            front_debug_src_block6_hash <= 32'h811C_9DC5;
            front_debug_src_b1_hash <= 32'h811C_9DC5;
            front_debug_src_b6_act1_hash <= 32'h811C_9DC5;
            src_feat0_count <= {OUT_PIX_W{1'b0}};
            src_block6_count <= {OUT_PIX_W{1'b0}};
            src_b1_count <= {OUT_PIX_W{1'b0}};
            src_b6_act1_count <= {OUT_PIX_W{1'b0}};
            tail_input_count <= 16'd0;
            tail_ready_cycle_count <= 16'd0;
            tail_all_valid_cycle_count <= 16'd0;
            tail_m_valid_cycle_count <= 16'd0;
            feat0_valid_cycle_count <= 16'd0;
            b1_valid_cycle_count <= 16'd0;
            b6_act1_valid_cycle_count <= 16'd0;
            block6_valid_cycle_count <= 16'd0;
            feat0_take_count <= 16'd0;
            b1_take_count <= 16'd0;
            b6_act1_take_count <= 16'd0;
            block6_take_count <= 16'd0;
            done <= 1'b0;
            error_r <= 1'b0;
        end else begin
            feat0_load_start <= 1'b0;
            b1_load_start <= 1'b0;
            b6_act1_load_start <= 1'b0;
            block6_load_start <= 1'b0;
            feat0_stream_start <= 1'b0;
            b1_stream_start <= 1'b0;
            b6_act1_stream_start <= 1'b0;
            block6_stream_start <= 1'b0;
            done <= 1'b0;

            if (front_cmd_valid && front_cmd_ready)
                front_cmd_valid <= 1'b0;
            if (front_done)
                front_done_seen <= 1'b1;
            if (feat0_load_done)
                feat0_load_done_seen <= 1'b1;
            if (b1_load_done)
                b1_load_done_seen <= 1'b1;
            if (b6_act1_load_done)
                b6_act1_load_done_seen <= 1'b1;
            if (block6_load_done)
                block6_load_done_seen <= 1'b1;
            if (front_error || feat0_load_error || b1_load_error ||
                b6_act1_load_error || block6_load_error || sideband_mismatch)
                error_r <= 1'b1;

            if (DEBUG_TAIL_HANDSHAKE != 0 && state != ST_STREAM) begin
                front_debug_tail_feat0_hash <=
                    {4'hA, state,
                     cmd_valid, cmd_ready, front_cmd_valid, front_cmd_ready,
                     front_busy, front_done, front_error, front_done_seen,
                     all_load_done,
                     feat0_load_start, b1_load_start,
                     b6_act1_load_start, block6_load_start,
                     feat0_load_busy, b1_load_busy,
                     b6_act1_load_busy, block6_load_busy,
                     feat0_load_done, b1_load_done,
                     b6_act1_load_done, block6_load_done,
                     feat0_load_done_seen, b1_load_done_seen,
                     b6_act1_load_done_seen, block6_load_done_seen};
                front_debug_tail_block6_hash <=
                    {feat0_load_busy, b1_load_busy,
                     b6_act1_load_busy, block6_load_busy,
                     feat0_load_done_seen, b1_load_done_seen,
                     b6_act1_load_done_seen, block6_load_done_seen,
                     8'd0, block_start_count};
                front_debug_tail_b1_hash <=
                    {front_debug_state[15:0], block_start_count};
                front_debug_tail_b6_act1_hash <=
                    {16'd0,
                     feat0_stream_busy, b1_stream_busy,
                     b6_act1_stream_busy, block6_stream_busy,
                     feat0_stream_done, b1_stream_done,
                     b6_act1_stream_done, block6_stream_done,
                     feat0_m_valid, b1_m_valid,
                     b6_act1_m_valid, block6_m_valid,
                     tail_s_valid, tail_s_ready, m_valid, m_ready};
                front_debug_tail_rgb_q_hash <=
                    {block_start_count, rgb_output_count_dbg16};
                front_debug_src_feat0_hash <= front_debug_state;
                front_debug_src_block6_hash <=
                    {front_debug_c1_counts[15:0], front_debug_c2_counts[15:0]};
                front_debug_src_b1_hash <=
                    {front_debug_c3_counts[15:0], front_debug_att_counts[15:0]};
                front_debug_src_b6_act1_hash <=
                    {16'd0, tail_input_count};
            end

            if (state == ST_STREAM) begin
                if (tail_s_ready && tail_ready_cycle_count != 16'hffff)
                    tail_ready_cycle_count <= tail_ready_cycle_count + 16'd1;
                if (all_tail_inputs_valid && tail_all_valid_cycle_count != 16'hffff)
                    tail_all_valid_cycle_count <= tail_all_valid_cycle_count + 16'd1;
                if (m_valid && tail_m_valid_cycle_count != 16'hffff)
                    tail_m_valid_cycle_count <= tail_m_valid_cycle_count + 16'd1;
                if (feat0_m_valid && feat0_valid_cycle_count != 16'hffff)
                    feat0_valid_cycle_count <= feat0_valid_cycle_count + 16'd1;
                if (b1_m_valid && b1_valid_cycle_count != 16'hffff)
                    b1_valid_cycle_count <= b1_valid_cycle_count + 16'd1;
                if (b6_act1_m_valid && b6_act1_valid_cycle_count != 16'hffff)
                    b6_act1_valid_cycle_count <= b6_act1_valid_cycle_count + 16'd1;
                if (block6_m_valid && block6_valid_cycle_count != 16'hffff)
                    block6_valid_cycle_count <= block6_valid_cycle_count + 16'd1;
            end

            if (rgb_output_take && state == ST_STREAM) begin
                if (DEBUG_TAIL_HANDSHAKE == 0) begin
                    front_debug_tail_rgb_q_hash <= rotl5(front_debug_tail_rgb_q_hash) ^
                                                   rgb_q_signature(m_rgb) ^
                                                   {{(32-OUT_PIX_W){1'b0}}, rgb_output_count};
                    if (front_debug_tail_block6_hash[15:0] == 16'd0) begin
                        front_debug_tail_feat0_hash <= {rgb_q_sample_min[15:0], rgb_q_sample_max[15:0]};
                    end else begin
                        if (rgb_q_sample_min < $signed(front_debug_tail_feat0_hash[31:16]))
                            front_debug_tail_feat0_hash[31:16] <= rgb_q_sample_min[15:0];
                        if (rgb_q_sample_max > $signed(front_debug_tail_feat0_hash[15:0]))
                            front_debug_tail_feat0_hash[15:0] <= rgb_q_sample_max[15:0];
                    end
                    if (front_debug_tail_block6_hash[15:0] != 16'hffff)
                        front_debug_tail_block6_hash[15:0] <= front_debug_tail_block6_hash[15:0] + 16'd1;
                    if (front_debug_tail_block6_hash[31:16] <= (16'hffff - {14'd0, rgb_q_positive_inc}))
                        front_debug_tail_block6_hash[31:16] <=
                            front_debug_tail_block6_hash[31:16] + {14'd0, rgb_q_positive_inc};
                    else
                        front_debug_tail_block6_hash[31:16] <= 16'hffff;
                end
                if (rgb_output_count != OUT_PIXELS)
                    rgb_output_count <= rgb_output_count + 1'b1;
            end

            if (tail_input_take) begin
                if (tail_input_count != 16'hffff)
                    tail_input_count <= tail_input_count + 16'd1;
                if (feat0_take_count != 16'hffff)
                    feat0_take_count <= feat0_take_count + 16'd1;
                if (b1_take_count != 16'hffff)
                    b1_take_count <= b1_take_count + 16'd1;
                if (b6_act1_take_count != 16'hffff)
                    b6_act1_take_count <= b6_act1_take_count + 16'd1;
                if (block6_take_count != 16'hffff)
                    block6_take_count <= block6_take_count + 16'd1;
                if (DEBUG_TAIL_HANDSHAKE == 0) begin
                    front_debug_tail_b1_hash <= rotl5(front_debug_tail_b1_hash) ^
                                                feature_signature(b1_m_feat);
                    front_debug_tail_b6_act1_hash <= rotl5(front_debug_tail_b6_act1_hash) ^
                                                     feature_signature(b6_act1_m_feat);
                end
            end
            if (DEBUG_SRC_HASH != 0 && src_feat0_take) begin
                front_debug_src_feat0_hash <= rotl5(front_debug_src_feat0_hash) ^
                                              feature_signature(tap_feat0_feat) ^
                                              {{(32-OUT_PIX_W){1'b0}}, src_feat0_count};
                if (src_feat0_count != IN_PIXELS - 1)
                    src_feat0_count <= src_feat0_count + 1'b1;
            end
            if (DEBUG_SRC_HASH != 0 && src_block6_take) begin
                front_debug_src_block6_hash <= rotl5(front_debug_src_block6_hash) ^
                                               feature_signature(front_m_feat) ^
                                               {{(32-OUT_PIX_W){1'b0}}, src_block6_count};
                if (src_block6_count != IN_PIXELS - 1)
                    src_block6_count <= src_block6_count + 1'b1;
            end
            if (DEBUG_SRC_HASH != 0 && src_b1_take) begin
                front_debug_src_b1_hash <= rotl5(front_debug_src_b1_hash) ^
                                           feature_signature(tap_b1_feat) ^
                                           {{(32-OUT_PIX_W){1'b0}}, src_b1_count};
                if (src_b1_count != IN_PIXELS - 1)
                    src_b1_count <= src_b1_count + 1'b1;
            end
            if (DEBUG_SRC_HASH != 0 && src_b6_act1_take) begin
                front_debug_src_b6_act1_hash <= rotl5(front_debug_src_b6_act1_hash) ^
                                                feature_signature(tap_b6_act1_feat) ^
                                                {{(32-OUT_PIX_W){1'b0}}, src_b6_act1_count};
                if (src_b6_act1_count != IN_PIXELS - 1)
                    src_b6_act1_count <= src_b6_act1_count + 1'b1;
            end
            case (state)
                ST_IDLE: begin
                    if (cmd_valid && cmd_ready) begin
                        front_debug_tail_feat0_hash <= 32'h7FFF_8000;
                        front_debug_tail_block6_hash <= 32'd0;
                        front_debug_tail_b1_hash <= 32'h811C_9DC5;
                        front_debug_tail_b6_act1_hash <= 32'h811C_9DC5;
                        front_debug_tail_rgb_q_hash <= 32'h811C_9DC5;
                        front_debug_src_feat0_hash <= 32'h811C_9DC5;
                        front_debug_src_block6_hash <= 32'h811C_9DC5;
                        front_debug_src_b1_hash <= 32'h811C_9DC5;
                        front_debug_src_b6_act1_hash <= 32'h811C_9DC5;
                        src_feat0_count <= {OUT_PIX_W{1'b0}};
                        src_block6_count <= {OUT_PIX_W{1'b0}};
                        src_b1_count <= {OUT_PIX_W{1'b0}};
                        src_b6_act1_count <= {OUT_PIX_W{1'b0}};
                        tail_input_count <= 16'd0;
                        tail_ready_cycle_count <= 16'd0;
                        tail_all_valid_cycle_count <= 16'd0;
                        tail_m_valid_cycle_count <= 16'd0;
                        feat0_valid_cycle_count <= 16'd0;
                        b1_valid_cycle_count <= 16'd0;
                        b6_act1_valid_cycle_count <= 16'd0;
                        block6_valid_cycle_count <= 16'd0;
                        feat0_take_count <= 16'd0;
                        b1_take_count <= 16'd0;
                        b6_act1_take_count <= 16'd0;
                        block6_take_count <= 16'd0;
                        front_cmd_valid <= 1'b1;
                        feat0_load_start <= 1'b1;
                        b1_load_start <= 1'b1;
                        b6_act1_load_start <= 1'b1;
                        block6_load_start <= 1'b1;
                        front_done_seen <= 1'b0;
                        feat0_load_done_seen <= 1'b0;
                        b1_load_done_seen <= 1'b0;
                        b6_act1_load_done_seen <= 1'b0;
                        block6_load_done_seen <= 1'b0;
                        error_r <= 1'b0;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    if (all_load_done)
                        state <= ST_STREAM_START;
                end

                ST_STREAM_START: begin
                    feat0_stream_start <= 1'b1;
                    b1_stream_start <= 1'b1;
                    b6_act1_stream_start <= 1'b1;
                    block6_stream_start <= 1'b1;
                    rgb_output_count <= {OUT_PIX_W{1'b0}};
                    state <= ST_STREAM;
                end

                ST_STREAM: begin
                    if (DEBUG_TAIL_HANDSHAKE != 0) begin
                        front_debug_tail_feat0_hash <=
                            {24'd0, state, tail_s_ready, all_tail_inputs_valid,
                             m_valid, m_ready, feat0_m_valid, b1_m_valid,
                             b6_act1_m_valid, block6_m_valid};
                        front_debug_tail_block6_hash <=
                            {tail_ready_cycle_count, tail_all_valid_cycle_count};
                        front_debug_tail_b1_hash <=
                            {tail_input_count, rgb_output_count_dbg16};
                        front_debug_tail_b6_act1_hash <=
                            {feat0_valid_cycle_count, feat0_take_count};
                        front_debug_tail_rgb_q_hash <=
                            {b1_valid_cycle_count, b1_take_count};
                        front_debug_src_feat0_hash <=
                            {b6_act1_valid_cycle_count, b6_act1_take_count};
                        front_debug_src_block6_hash <=
                            {block6_valid_cycle_count, block6_take_count};
                        front_debug_src_b1_hash <=
                            {tail_m_valid_cycle_count, rgb_output_count_dbg16};
                        front_debug_src_b6_act1_hash <=
                            {16'd0, tail_input_count};
                    end else if (!rgb_output_take && rgb_output_count == {OUT_PIX_W{1'b0}}) begin
                        front_debug_tail_feat0_hash <=
                            {24'd0, state, tail_s_ready, all_tail_inputs_valid,
                             m_valid, m_ready, feat0_m_valid, b1_m_valid,
                             b6_act1_m_valid, block6_m_valid};
                        front_debug_tail_block6_hash <=
                            {tail_ready_cycle_count, tail_all_valid_cycle_count};
                        front_debug_src_feat0_hash <=
                            {tail_m_valid_cycle_count, tail_input_count};
                        front_debug_src_block6_hash <=
                            {feat0_valid_cycle_count, feat0_take_count};
                        front_debug_src_b1_hash <=
                            {b1_valid_cycle_count, b1_take_count};
                        front_debug_src_b6_act1_hash <=
                            {block6_valid_cycle_count, block6_take_count};
                    end
                    if (rgb_output_take && rgb_output_count == OUT_PIXELS - 1)
                        state <= ST_DONE;
                end

                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    error_r <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    wire unused_stream_done = feat0_stream_done | b1_stream_done |
                              b6_act1_stream_done | block6_stream_done;
endmodule
