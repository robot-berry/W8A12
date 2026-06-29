`timescale 1ns/1ps

// Generic W8A12 SPAB tile backend:
// c1 + act1 -> c2 + act2 -> c3 -> attention/residual.
module sr_w8a12_spab_c1c2c3_attention_buffered_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1),
    parameter integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W),
    parameter C1_WEIGHT_FILE = "",
    parameter C1_BIAS_I64_FILE = "",
    parameter C1_REQUANT_Q31_FILE = "",
    parameter C1_REQUANT_SHIFT_FILE = "",
    parameter C1_ACT_LUT_FILE = "",
    parameter C2_WEIGHT_FILE = "",
    parameter C2_BIAS_I64_FILE = "",
    parameter C2_REQUANT_Q31_FILE = "",
    parameter C2_REQUANT_SHIFT_FILE = "",
    parameter C2_ACT_LUT_FILE = "",
    parameter C3_WEIGHT_FILE = "",
    parameter C3_BIAS_I64_FILE = "",
    parameter C3_REQUANT_Q31_FILE = "",
    parameter C3_REQUANT_SHIFT_FILE = "",
    parameter SIM_ATT_LUT_FILE = "",
    parameter integer ATT_SHIFT = 31,
    parameter signed [31:0] ATT_OUT3_REQUANT_Q31 = 32'sd0,
    parameter signed [31:0] ATT_RESIDUAL_REQUANT_Q31 = 32'sd0
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
    reg c1_done_seen;
    reg c2_done_seen;
    reg c3_done_seen;
    reg [X_W-1:0] residual_load_x;

    wire start_take = start && ready;

    wire c1_ready;
    wire c1_busy;
    wire c1_done;
    wire c1_error;
    wire c1_s_ready;
    wire c1_valid;
    wire c1_ready_downstream;
    wire signed [FEAT_W-1:0] c1_feat;
    wire c1_user;
    wire c1_last;
    wire [PIX_W-1:0] c1_core_input_count;

    wire c2_ready;
    wire c2_busy;
    wire c2_done;
    wire c2_error;
    wire c2_valid;
    wire c2_ready_downstream;
    wire signed [FEAT_W-1:0] c2_feat;
    wire c2_user;
    wire c2_last;
    wire [PIX_W-1:0] c2_core_input_count;

    wire c3_ready;
    wire c3_busy;
    wire c3_done;
    wire c3_error;
    wire c3_valid;
    wire c3_ready_downstream;
    wire signed [FEAT_W-1:0] c3_feat;
    wire c3_user;
    wire c3_last;
    wire [PIX_W-1:0] c3_core_input_count;

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

    wire input_ready = active && c1_s_ready && residual_s_ready;
    wire input_take = s_valid && input_ready;
    wire child_s_valid = s_valid && input_ready;
    wire residual_load_end_row = (residual_load_x == TILE_W - 1);
    wire residual_load_last_pixel = (residual_load_count == PIXELS - 1);

    assign ready = !active && c1_ready && c2_ready && c3_ready && att_ready &&
                   !residual_load_busy && !residual_stream_busy;
    assign busy = active;
    assign error = error_q || c1_error || c2_error || c3_error ||
                   residual_load_error || att_error;
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

    sr_w8a12_single_out_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .WEIGHT_FILE(C1_WEIGHT_FILE),
        .BIAS_I64_FILE(C1_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(C1_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(C1_REQUANT_SHIFT_FILE),
        .APPLY_ACT(1),
        .ACT_LUT_FILE(C1_ACT_LUT_FILE)
    ) u_c1_stage (
        .clk(clk),
        .rst(rst),
        .start(start_take),
        .ready(c1_ready),
        .busy(c1_busy),
        .done(c1_done),
        .error(c1_error),
        .s_valid(child_s_valid),
        .s_ready(c1_s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(c1_valid),
        .m_ready(c1_ready_downstream),
        .m_feat(c1_feat),
        .m_user(c1_user),
        .m_last(c1_last),
        .load_count(c1_load_count),
        .core_input_count(c1_core_input_count),
        .core_output_count(c1_output_count),
        .lane_output_count(c1_lane_output_count)
    );

    sr_w8a12_single_out_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .WEIGHT_FILE(C2_WEIGHT_FILE),
        .BIAS_I64_FILE(C2_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(C2_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(C2_REQUANT_SHIFT_FILE),
        .APPLY_ACT(1),
        .ACT_LUT_FILE(C2_ACT_LUT_FILE)
    ) u_c2_stage (
        .clk(clk),
        .rst(rst),
        .start(start_take),
        .ready(c2_ready),
        .busy(c2_busy),
        .done(c2_done),
        .error(c2_error),
        .s_valid(c1_valid),
        .s_ready(c1_ready_downstream),
        .s_feat(c1_feat),
        .s_user(c1_user),
        .s_last(c1_last),
        .m_valid(c2_valid),
        .m_ready(c2_ready_downstream),
        .m_feat(c2_feat),
        .m_user(c2_user),
        .m_last(c2_last),
        .load_count(c2_load_count),
        .core_input_count(c2_core_input_count),
        .core_output_count(c2_output_count),
        .lane_output_count(c2_lane_output_count)
    );

    sr_w8a12_single_out_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .WEIGHT_FILE(C3_WEIGHT_FILE),
        .BIAS_I64_FILE(C3_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(C3_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(C3_REQUANT_SHIFT_FILE),
        .APPLY_ACT(0),
        .ACT_LUT_FILE("")
    ) u_c3_stage (
        .clk(clk),
        .rst(rst),
        .start(start_take),
        .ready(c3_ready),
        .busy(c3_busy),
        .done(c3_done),
        .error(c3_error),
        .s_valid(c2_valid),
        .s_ready(c2_ready_downstream),
        .s_feat(c2_feat),
        .s_user(c2_user),
        .s_last(c2_last),
        .m_valid(c3_valid),
        .m_ready(c3_ready_downstream),
        .m_feat(c3_feat),
        .m_user(c3_user),
        .m_last(c3_last),
        .load_count(c3_load_count),
        .core_input_count(c3_core_input_count),
        .core_output_count(c3_output_count),
        .lane_output_count(c3_lane_output_count)
    );

    sr_w8a12_attention_residual_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .CH(CH),
        .SIM_ATT_LUT_FILE(SIM_ATT_LUT_FILE),
        .ATT_SHIFT(ATT_SHIFT),
        .ATT_OUT3_REQUANT_Q31(ATT_OUT3_REQUANT_Q31),
        .ATT_RESIDUAL_REQUANT_Q31(ATT_RESIDUAL_REQUANT_Q31)
    ) u_attention (
        .clk(clk),
        .rst(rst),
        .start(start_take),
        .ready(att_ready),
        .busy(att_busy),
        .done(att_done),
        .error(att_error),
        .s_c3_valid(c3_valid),
        .s_c3_ready(c3_ready_downstream),
        .s_c3_feat(c3_feat),
        .s_c3_user(c3_user),
        .s_c3_last(c3_last),
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
            c1_done_seen <= 1'b0;
            c2_done_seen <= 1'b0;
            c3_done_seen <= 1'b0;
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

            if (c1_error || c2_error || c3_error || residual_load_error || att_error)
                error_q <= 1'b1;
            if (c1_done)
                c1_done_seen <= 1'b1;
            if (c2_done)
                c2_done_seen <= 1'b1;
            if (c3_done)
                c3_done_seen <= 1'b1;
            if (residual_stream_done)
                residual_stream_done_seen <= 1'b1;

            if (start_take) begin
                active <= 1'b1;
                error_q <= 1'b0;
                residual_load_start_q <= 1'b1;
                residual_stream_started <= 1'b0;
                residual_stream_done_seen <= 1'b0;
                c1_done_seen <= 1'b0;
                c2_done_seen <= 1'b0;
                c3_done_seen <= 1'b0;
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
                if ((!c1_done_seen && !c1_done) ||
                    (!c2_done_seen && !c2_done) ||
                    (!c3_done_seen && !c3_done) ||
                    (!residual_stream_done_seen && !residual_stream_done))
                    error_q <= 1'b1;
            end
        end
    end

    wire unused_busy = c1_busy | c2_busy | c3_busy | att_busy;
    wire unused_input_counts = |c1_core_input_count | |c2_core_input_count | |c3_core_input_count;
endmodule
