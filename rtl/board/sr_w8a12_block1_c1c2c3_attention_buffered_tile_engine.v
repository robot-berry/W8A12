`timescale 1ns/1ps

// Block_1 c1->c2->c3 plus block_1 attention/residual postprocess.
//
// The residual feature tile is captured in hardware while the c1/c2/c3 core
// consumes the same input stream. After c3 produces a feature vector, the
// saved residual stream is replayed and joined with c3 for serialized
// attention.
module sr_w8a12_block1_c1c2c3_attention_buffered_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1),
    parameter integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W)
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    output wire                         ready,
    output wire                         busy,
    output reg                          done,
    output wire                         error,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [FEAT_W-1:0]     s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [FEAT_W-1:0]     m_feat,
    output wire                         m_user,
    output wire                         m_last,

    output reg  [PIX_W-1:0]             residual_load_count,
    output wire [PIX_W-1:0]             c1_load_count,
    output wire [PIX_W-1:0]             c1_output_count,
    output wire [31:0]                  c1_lane_output_count,
    output wire [PIX_W-1:0]             c2_load_count,
    output wire [PIX_W-1:0]             c2_output_count,
    output wire [31:0]                  c2_lane_output_count,
    output wire [PIX_W-1:0]             c3_load_count,
    output wire [PIX_W-1:0]             c3_output_count,
    output wire [31:0]                  c3_lane_output_count,
    output wire [PIX_W-1:0]             att_input_count,
    output wire [PIX_W-1:0]             att_output_count,
    output wire [31:0]                  att_lane_output_count
);
    reg active;
    reg error_q;
    reg residual_load_start_q;
    reg residual_stream_start_q;
    reg residual_stream_started;
    reg residual_stream_done_seen;
    reg core_done_seen;
    reg [X_W-1:0] residual_load_x;

    wire start_take = start && ready;

    wire core_ready;
    wire core_busy;
    wire core_done;
    wire core_error;
    wire core_s_ready;
    wire core_m_valid;
    wire core_m_ready;
    wire signed [FEAT_W-1:0] core_m_feat;
    wire core_m_user;
    wire core_m_last;

    wire residual_load_busy;
    wire residual_load_done;
    wire residual_load_error;
    wire residual_stream_busy;
    wire residual_stream_done;
    wire residual_s_ready;
    wire residual_m_valid;
    wire residual_m_ready;
    wire [FEAT_W-1:0] residual_m_feat;
    wire residual_m_user;
    wire residual_m_last;

    wire att_ready;
    wire att_busy;
    wire att_done;
    wire att_error;

    wire input_ready = active && core_s_ready && residual_s_ready;
    wire input_take = s_valid && input_ready;
    wire child_s_valid = s_valid && input_ready;
    wire residual_load_end_row = (residual_load_x == TILE_W - 1);
    wire residual_load_last_pixel = (residual_load_count == PIXELS - 1);

    assign ready = !active && core_ready && att_ready && !residual_load_busy && !residual_stream_busy;
    assign busy = active;
    assign error = error_q || core_error || residual_load_error || att_error;
    assign s_ready = input_ready;

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H)
    ) u_residual_buffer (
        .clk(clk),
        .rst(rst),
        .load_start(residual_load_start_q),
        .load_busy(residual_load_busy),
        .load_done(residual_load_done),
        .load_error(residual_load_error),
        .s_valid(child_s_valid),
        .s_ready(residual_s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .stream_start(residual_stream_start_q),
        .stream_busy(residual_stream_busy),
        .stream_done(residual_stream_done),
        .m_valid(residual_m_valid),
        .m_ready(residual_m_ready),
        .m_feat(residual_m_feat),
        .m_user(residual_m_user),
        .m_last(residual_m_last)
    );

    sr_w8a12_block1_c1c2c3_single_out_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH)
    ) u_core (
        .clk(clk),
        .rst(rst),
        .start(start_take),
        .ready(core_ready),
        .busy(core_busy),
        .done(core_done),
        .error(core_error),
        .s_valid(child_s_valid),
        .s_ready(core_s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(core_m_valid),
        .m_ready(core_m_ready),
        .m_feat(core_m_feat),
        .m_user(core_m_user),
        .m_last(core_m_last),
        .c1_load_count(c1_load_count),
        .c1_output_count(c1_output_count),
        .c1_lane_output_count(c1_lane_output_count),
        .c2_load_count(c2_load_count),
        .c2_output_count(c2_output_count),
        .c2_lane_output_count(c2_lane_output_count),
        .c3_load_count(c3_load_count),
        .c3_output_count(c3_output_count),
        .c3_lane_output_count(c3_lane_output_count)
    );

    sr_w8a12_block1_attention_residual_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .CH(CH)
    ) u_attention (
        .clk(clk),
        .rst(rst),
        .start(start_take),
        .ready(att_ready),
        .busy(att_busy),
        .done(att_done),
        .error(att_error),
        .s_c3_valid(core_m_valid),
        .s_c3_ready(core_m_ready),
        .s_c3_feat(core_m_feat),
        .s_c3_user(core_m_user),
        .s_c3_last(core_m_last),
        .s_res_valid(residual_m_valid),
        .s_res_ready(residual_m_ready),
        .s_res_feat(residual_m_feat),
        .s_res_user(residual_m_user),
        .s_res_last(residual_m_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last),
        .input_count(att_input_count),
        .output_count(att_output_count),
        .lane_output_count(att_lane_output_count)
    );

    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0;
            done <= 1'b0;
            error_q <= 1'b0;
            residual_load_start_q <= 1'b0;
            residual_stream_start_q <= 1'b0;
            residual_stream_started <= 1'b0;
            residual_stream_done_seen <= 1'b0;
            core_done_seen <= 1'b0;
            residual_load_count <= {PIX_W{1'b0}};
            residual_load_x <= {X_W{1'b0}};
        end else begin
            done <= 1'b0;
            residual_load_start_q <= 1'b0;
            residual_stream_start_q <= 1'b0;

            if (input_take) begin
                if (residual_load_count == {PIX_W{1'b0}} && !s_user)
                    error_q <= 1'b1;
                if (s_last != residual_load_end_row)
                    error_q <= 1'b1;
                if (!residual_load_last_pixel) begin
                    residual_load_count <= residual_load_count + 1'b1;
                    if (residual_load_end_row)
                        residual_load_x <= {X_W{1'b0}};
                    else
                        residual_load_x <= residual_load_x + 1'b1;
                end
            end

            if (core_error || residual_load_error || att_error)
                error_q <= 1'b1;
            if (core_done)
                core_done_seen <= 1'b1;
            if (residual_stream_done)
                residual_stream_done_seen <= 1'b1;

            if (start_take) begin
                active <= 1'b1;
                error_q <= 1'b0;
                residual_load_start_q <= 1'b1;
                residual_stream_started <= 1'b0;
                residual_stream_done_seen <= 1'b0;
                core_done_seen <= 1'b0;
                residual_load_count <= {PIX_W{1'b0}};
                residual_load_x <= {X_W{1'b0}};
            end else if (start && !ready) begin
                error_q <= 1'b1;
            end

            if (active && residual_load_done && !residual_stream_started) begin
                residual_stream_start_q <= 1'b1;
                residual_stream_started <= 1'b1;
            end

            if (active && att_done) begin
                done <= 1'b1;
                active <= 1'b0;
                if ((!core_done_seen && !core_done) ||
                    (!residual_stream_done_seen && !residual_stream_done))
                    error_q <= 1'b1;
            end
        end
    end

    wire unused_core_busy = core_busy;
    wire unused_att_busy = att_busy;
endmodule
