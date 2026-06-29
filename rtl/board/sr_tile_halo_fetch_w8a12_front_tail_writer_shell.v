`timescale 1ns/1ps

// Hardware-side large-image tile loop using the partitioned W8A12 path:
// halo fetch -> conv1 -> runtime SPAB6 -> tail/pixelshuffle -> RGB888 writer.
//
// This shell keeps the SD/DDR tiling boundary in hardware. It accepts only
// full tiles for now; edge valid_w/h support belongs in the later tile-loop
// refinement.
module sr_tile_halo_fetch_w8a12_front_tail_writer_shell #(
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
    parameter integer OUT_PIXELS = TILE_W * TILE_H * SCALE * SCALE,
    parameter integer OUT_PIX_W = (OUT_PIXELS <= 2) ? 1 : $clog2(OUT_PIXELS + 1),
    parameter integer Q_TO_U8_MULT = 140277620,
    parameter integer Q_TO_U8_SHIFT = 30
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  start,
    input  wire [COORD_W-1:0]    image_w,
    input  wire [COORD_W-1:0]    image_h,
    input  wire [ADDR_W-1:0]     input_base,
    input  wire [ADDR_W-1:0]     output_base,

    output wire                  rd_req_valid,
    input  wire                  rd_req_ready,
    output wire [ADDR_W-1:0]     rd_req_addr,
    input  wire                  rd_resp_valid,
    input  wire [DATA_W-1:0]     rd_resp_data,

    output wire                  wr_valid,
    input  wire                  wr_ready,
    output wire [ADDR_W-1:0]     wr_addr,
    output wire [DATA_W-1:0]     wr_data,

    output reg                   busy,
    output reg                   done,
    output reg                   error,
    output reg  [31:0]           tiles_done,
    output wire [15:0]           block_start_count,
    output wire [31:0]           replay_feature_count,
    output wire [31:0]           block_output_count,
    output wire [OUT_PIX_W-1:0]  rgb_output_count,
    output wire [31:0]           front_debug_state,
    output wire [31:0]           front_debug_c1_counts,
    output wire [31:0]           front_debug_c2_counts,
    output wire [31:0]           front_debug_c3_counts,
    output wire [31:0]           front_debug_att_counts,
    output wire [31:0]           front_debug_c1_lane_outputs,
    output wire [31:0]           front_debug_c2_lane_outputs,
    output wire [31:0]           front_debug_c3_lane_outputs,
    output wire [31:0]           front_debug_att_lane_outputs,
    output wire [31:0]           front_debug_c1_detail,
    output wire [31:0]           front_debug_c1_core_detail,
    output wire [31:0]           front_debug_c1_lane_detail,
    output wire [31:0]           front_debug_c1_io_detail,
    output wire [31:0]           front_debug_c2_detail,
    output wire [31:0]           front_debug_c3_detail,
    output wire [31:0]           front_debug_c2_core_detail,
    output wire [31:0]           front_debug_c2_lane_detail,
    output wire [31:0]           front_debug_c3_core_detail,
    output wire [31:0]           front_debug_c3_lane_detail,
    output wire [31:0]           front_debug_c3_io_detail,
    output wire [31:0]           front_debug_spab_flags,
    output wire [31:0]           front_debug_att_detail,
    output wire [31:0]           front_debug_tail_feat0_hash,
    output wire [31:0]           front_debug_tail_block6_hash,
    output wire [31:0]           front_debug_tail_b1_hash,
    output wire [31:0]           front_debug_tail_b6_act1_hash,
    output wire [31:0]           front_debug_tail_rgb_q_hash,
    output wire [31:0]           front_debug_src_feat0_hash,
    output wire [31:0]           front_debug_src_block6_hash,
    output wire [31:0]           front_debug_src_b1_hash,
    output wire [31:0]           front_debug_src_b6_act1_hash,
    output wire [31:0]           front_debug_spab_hash_input,
    output wire [31:0]           front_debug_spab_hash_c1,
    output wire [31:0]           front_debug_spab_hash_c2,
    output wire [31:0]           front_debug_spab_hash_c3,
    output wire [31:0]           front_debug_spab_hash_residual,
    output wire [31:0]           front_debug_spab_hash_att,
    output wire [31:0]           front_debug_spab_b1_hash_input,
    output wire [31:0]           front_debug_spab_b1_hash_c1,
    output wire [31:0]           front_debug_spab_b1_hash_c1_raw,
    output wire [31:0]           front_debug_spab_b1_c1_sample0,
    output wire [31:0]           front_debug_spab_b1_c1_sample1,
    output wire [31:0]           front_debug_spab_b1_c1_sample2,
    output wire [31:0]           front_debug_spab_b1_c1_sample3,
    output wire [31:0]           front_debug_spab_b2_hash_att,
    output wire [31:0]           front_debug_spab_b3_hash_att,
    output wire [31:0]           front_debug_spab_b4_hash_att,
    output wire [31:0]           front_debug_spab_b5_hash_att,
    output wire [31:0]           front_debug_writer_rgb_hash,
    output wire [31:0]           front_debug_writer_rgb_range,
    output wire [31:0]           front_debug_writer_rgb_first,
    output wire [31:0]           front_debug_writer_rgb_last,
    output wire [31:0]           front_debug_writeback_hash,
    output wire [31:0]           front_debug_writeback_range,
    output wire [31:0]           front_debug_writeback_first,
    output wire [31:0]           front_debug_writeback_last,
    output wire [31:0]           front_debug_spab_b1_hash_c2,
    output wire [31:0]           front_debug_spab_b1_hash_c2_replay,
    output wire [31:0]           front_debug_spab_b1_hash_c2_window,
    output wire [31:0]           front_debug_spab_b1_hash_c2_raw,
    output wire [31:0]           front_debug_spab_b1_c2_sample0,
    output wire [31:0]           front_debug_spab_b1_c2_sample1,
    output wire [31:0]           front_debug_spab_b1_c2_sample2,
    output wire [31:0]           front_debug_spab_b1_c2_sample3,
    output wire [31:0]           front_debug_spab_b1_hash_c3,
    output wire [31:0]           front_debug_spab_b1_hash_residual,
    output wire [31:0]           front_debug_spab_b1_hash_att
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WAIT_TILE  = 3'd1;
    localparam [2:0] ST_START_TILE = 3'd2;
    localparam [2:0] ST_RUN_TILE   = 3'd3;
    localparam [2:0] ST_DONE       = 3'd4;

    localparam [COORD_W-1:0] TILE_W_C = TILE_W[COORD_W-1:0];
    localparam [COORD_W-1:0] TILE_H_C = TILE_H[COORD_W-1:0];

    reg [2:0] state;
    reg sched_start;
    wire sched_busy;
    wire sched_done;
    wire sched_error;
    wire sched_tile_valid;
    wire sched_tile_ready;
    wire [COORD_W-1:0] sched_tile_x;
    wire [COORD_W-1:0] sched_tile_y;
    wire [COORD_W-1:0] sched_valid_w;
    wire [COORD_W-1:0] sched_valid_h;
    wire [31:0] sched_tile_index;
    wire sched_tile_last;
    wire [ADDR_W-1:0] sched_tile_input_addr;
    wire [ADDR_W-1:0] sched_tile_output_addr;

    reg [COORD_W-1:0] tile_x_q;
    reg [COORD_W-1:0] tile_y_q;
    reg [COORD_W-1:0] valid_w_q;
    reg [COORD_W-1:0] valid_h_q;
    reg tile_last_q;

    reg front_cmd_valid;
    wire front_cmd_ready;
    wire front_busy;
    wire front_done;
    wire front_error;
    reg front_done_seen;

    wire front_m_valid;
    wire front_m_ready;
    wire signed [3*ACT_W-1:0] front_m_rgb_q;
    wire front_m_user;
    wire front_m_last;
    wire [DATA_W-1:0] front_m_rgb888;

    reg writer_cmd_valid;
    wire writer_cmd_ready;
    wire writer_busy;
    wire writer_done;
    wire writer_error;
    reg writer_done_seen;
    reg [31:0] writer_debug_latched;
    reg [31:0] writer_wr_hash;
    reg [31:0] writer_wr_first;
    reg [31:0] writer_wr_last;
    reg [15:0] writer_wr_count;
    reg [7:0] writer_wr_min;
    reg [7:0] writer_wr_max;
    reg writer_wr_seen;
    wire [31:0] front_debug_spab_b5_hash_att_inner;
    wire early_entry_error = error && (tiles_done == 32'd0) && (block_start_count == 16'd0);
    wire writer_wr_take = wr_valid && wr_ready;
    wire [7:0] writer_wr_r = wr_data[23:16];
    wire [7:0] writer_wr_g = wr_data[15:8];
    wire [7:0] writer_wr_b = wr_data[7:0];
    wire [7:0] writer_wr_sample_min =
        (writer_wr_r <= writer_wr_g && writer_wr_r <= writer_wr_b) ? writer_wr_r :
        (writer_wr_g <= writer_wr_b) ? writer_wr_g : writer_wr_b;
    wire [7:0] writer_wr_sample_max =
        (writer_wr_r >= writer_wr_g && writer_wr_r >= writer_wr_b) ? writer_wr_r :
        (writer_wr_g >= writer_wr_b) ? writer_wr_g : writer_wr_b;

    wire tile_is_full = (sched_valid_w == TILE_W_C) && (sched_valid_h == TILE_H_C);
    wire [31:0] writer_debug_live = {
        sched_valid_h[7:0],
        sched_valid_w[7:0],
        tile_last_q,
        sched_done,
        sched_busy,
        writer_busy,
        front_busy,
        writer_done,
        front_done,
        writer_error,
        front_error,
        tile_is_full,
        sched_tile_ready,
        sched_tile_valid,
        sched_error,
        state
    };

    assign sched_tile_ready = (state == ST_WAIT_TILE);

    function [7:0] q_to_u8;
        input signed [ACT_W-1:0] q;
        reg signed [63:0] product;
        reg signed [63:0] rounded;
        begin
            if (q <= 0) begin
                q_to_u8 = 8'd0;
            end else begin
                product = q * Q_TO_U8_MULT;
                rounded = (product + (64'sd1 <<< (Q_TO_U8_SHIFT - 1))) >>> Q_TO_U8_SHIFT;
                if (rounded <= 0)
                    q_to_u8 = 8'd0;
                else if (rounded >= 255)
                    q_to_u8 = 8'd255;
                else
                    q_to_u8 = rounded[7:0];
            end
        end
    endfunction

    function [31:0] rotl5;
        input [31:0] value;
        begin
            rotl5 = {value[26:0], value[31:27]};
        end
    endfunction

    assign front_m_rgb888 = {
        q_to_u8($signed(front_m_rgb_q[0*ACT_W +: ACT_W])),
        q_to_u8($signed(front_m_rgb_q[1*ACT_W +: ACT_W])),
        q_to_u8($signed(front_m_rgb_q[2*ACT_W +: ACT_W]))
    };

    sr_tile_scheduler #(
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .SCALE(SCALE),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_scheduler (
        .clk(clk),
        .rst(rst),
        .start(sched_start),
        .image_w(image_w),
        .image_h(image_h),
        .tile_w(TILE_W_C),
        .tile_h(TILE_H_C),
        .stride_x(TILE_W_C),
        .stride_y(TILE_H_C),
        .input_base(input_base),
        .output_base(output_base),
        .busy(sched_busy),
        .done(sched_done),
        .error(sched_error),
        .tile_valid(sched_tile_valid),
        .tile_ready(sched_tile_ready),
        .tile_x(sched_tile_x),
        .tile_y(sched_tile_y),
        .tile_valid_w(sched_valid_w),
        .tile_valid_h(sched_valid_h),
        .tile_index(sched_tile_index),
        .tile_last(sched_tile_last),
        .tile_input_addr(sched_tile_input_addr),
        .tile_output_addr(sched_tile_output_addr)
    );

    sr_tile_halo_fetch_w8a12_front_tail_rgb_shell #(
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
        .DEBUG_SPAB_HASH(DEBUG_SPAB_HASH),
        .DEBUG_TAIL_HANDSHAKE(DEBUG_TAIL_HANDSHAKE),
        .BLOCKS(BLOCKS)
    ) u_front_tail (
        .clk(clk),
        .rst(rst),
        .cmd_valid(front_cmd_valid),
        .cmd_ready(front_cmd_ready),
        .cmd_image_w(image_w),
        .cmd_image_h(image_h),
        .cmd_tile_x(tile_x_q),
        .cmd_tile_y(tile_y_q),
        .cmd_input_base(input_base),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .m_valid(front_m_valid),
        .m_ready(front_m_ready),
        .m_rgb(front_m_rgb_q),
        .m_user(front_m_user),
        .m_last(front_m_last),
        .busy(front_busy),
        .done(front_done),
        .error(front_error),
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
        .front_debug_spab_b5_hash_att(front_debug_spab_b5_hash_att_inner),
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

    sr_tile_output_writer #(
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .SCALE(SCALE),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_writer (
        .clk(clk),
        .rst(rst),
        .cmd_valid(writer_cmd_valid),
        .cmd_ready(writer_cmd_ready),
        .cmd_image_w(image_w),
        .cmd_tile_x(tile_x_q),
        .cmd_tile_y(tile_y_q),
        .cmd_valid_w(valid_w_q),
        .cmd_valid_h(valid_h_q),
        .cmd_output_base(output_base),
        .s_valid(front_m_valid),
        .s_ready(front_m_ready),
        .s_data(front_m_rgb888),
        .s_user(front_m_user),
        .s_last(front_m_last),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(writer_busy),
        .done(writer_done),
        .error(writer_error)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            sched_start <= 1'b0;
            front_cmd_valid <= 1'b0;
            writer_cmd_valid <= 1'b0;
            front_done_seen <= 1'b0;
            writer_done_seen <= 1'b0;
            tile_x_q <= {COORD_W{1'b0}};
            tile_y_q <= {COORD_W{1'b0}};
            valid_w_q <= {COORD_W{1'b0}};
            valid_h_q <= {COORD_W{1'b0}};
            tile_last_q <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            tiles_done <= 32'd0;
            writer_debug_latched <= 32'd0;
            writer_wr_hash <= 32'h811C_9DC5;
            writer_wr_first <= 32'd0;
            writer_wr_last <= 32'd0;
            writer_wr_count <= 16'd0;
            writer_wr_min <= 8'hff;
            writer_wr_max <= 8'd0;
            writer_wr_seen <= 1'b0;
        end else begin
            sched_start <= 1'b0;
            done <= 1'b0;
            if (!error && (state != ST_IDLE || start))
                writer_debug_latched <= writer_debug_live;
            if (writer_wr_take) begin
                writer_wr_hash <= rotl5(writer_wr_hash) ^
                                  {8'd0, wr_data} ^
                                  wr_addr ^
                                  {16'd0, writer_wr_count};
                writer_wr_last <= {8'd0, wr_data};
                if (!writer_wr_seen) begin
                    writer_wr_first <= {8'd0, wr_data};
                    writer_wr_min <= writer_wr_sample_min;
                    writer_wr_max <= writer_wr_sample_max;
                    writer_wr_seen <= 1'b1;
                end else begin
                    if (writer_wr_sample_min < writer_wr_min)
                        writer_wr_min <= writer_wr_sample_min;
                    if (writer_wr_sample_max > writer_wr_max)
                        writer_wr_max <= writer_wr_sample_max;
                end
                if (writer_wr_count != 16'hffff)
                    writer_wr_count <= writer_wr_count + 16'd1;
            end

            if (front_cmd_valid && front_cmd_ready)
                front_cmd_valid <= 1'b0;
            if (writer_cmd_valid && writer_cmd_ready)
                writer_cmd_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        error <= 1'b0;
                        tiles_done <= 32'd0;
                        front_done_seen <= 1'b0;
                        writer_done_seen <= 1'b0;
                        writer_wr_hash <= 32'h811C_9DC5;
                        writer_wr_first <= 32'd0;
                        writer_wr_last <= 32'd0;
                        writer_wr_count <= 16'd0;
                        writer_wr_min <= 8'hff;
                        writer_wr_max <= 8'd0;
                        writer_wr_seen <= 1'b0;
                        sched_start <= 1'b1;
                        state <= ST_WAIT_TILE;
                    end
                end

                ST_WAIT_TILE: begin
                    busy <= 1'b1;
                    if (sched_error) begin
                        error <= 1'b1;
                        state <= ST_DONE;
                    end else if (sched_tile_valid && sched_tile_ready) begin
                        tile_x_q <= sched_tile_x;
                        tile_y_q <= sched_tile_y;
                        valid_w_q <= sched_valid_w;
                        valid_h_q <= sched_valid_h;
                        tile_last_q <= sched_tile_last;
                        if (!tile_is_full) begin
                            error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_START_TILE;
                        end
                    end
                end

                ST_START_TILE: begin
                    busy <= 1'b1;
                    front_cmd_valid <= 1'b1;
                    writer_cmd_valid <= 1'b1;
                    front_done_seen <= 1'b0;
                    writer_done_seen <= 1'b0;
                    state <= ST_RUN_TILE;
                end

                ST_RUN_TILE: begin
                    busy <= 1'b1;
                    if (front_done)
                        front_done_seen <= 1'b1;
                    if (writer_done)
                        writer_done_seen <= 1'b1;
                    if (front_error || writer_error) begin
                        error <= 1'b1;
                        state <= ST_DONE;
                    end else if ((front_done_seen || front_done) && (writer_done_seen || writer_done)) begin
                        tiles_done <= tiles_done + 32'd1;
                        if (tile_last_q)
                            state <= ST_DONE;
                        else
                            state <= ST_WAIT_TILE;
                    end
                end

                ST_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    error <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    wire unused_sched = sched_busy ^ sched_done ^ |sched_tile_index ^
                        |sched_tile_input_addr ^ |sched_tile_output_addr;
    assign front_debug_spab_b5_hash_att =
        early_entry_error ? writer_debug_latched : front_debug_spab_b5_hash_att_inner;
    assign front_debug_writer_rgb_hash = writer_debug_latched;
    assign front_debug_writer_rgb_range = writer_debug_live;
    assign front_debug_writer_rgb_first = {16'd0, tile_x_q[7:0], tile_y_q[7:0]};
    assign front_debug_writer_rgb_last = {16'd0, valid_w_q[7:0], valid_h_q[7:0]};
    assign front_debug_writeback_hash = writer_wr_seen ? writer_wr_hash : writer_debug_latched;
    assign front_debug_writeback_range = writer_wr_seen ?
        {writer_wr_min, writer_wr_max, writer_wr_count} :
        writer_debug_live;
    assign front_debug_writeback_first = writer_wr_seen ?
        writer_wr_first :
        {16'd0, tile_x_q[7:0], tile_y_q[7:0]};
    assign front_debug_writeback_last = writer_wr_seen ?
        writer_wr_last :
        {16'd0, valid_w_q[7:0], valid_h_q[7:0]};

    wire unused_blocks_busy = front_busy ^ writer_busy;
endmodule
