`timescale 1ns/1ps

// Block_1 c1->c2->c3 buffered half-pipeline.
//
// This top keeps tile movement on hardware: each layer output is captured in a
// tile-local feature buffer, replayed through a 3x3 window generator, and then
// consumed by the next W8A12 single-output-channel compute stage.
module sr_w8a12_block1_c1c2c3_single_out_buffered_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1)
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

    output wire [PIX_W-1:0]             c1_load_count,
    output wire [PIX_W-1:0]             c1_output_count,
    output wire [31:0]                  c1_lane_output_count,
    output wire [PIX_W-1:0]             c2_load_count,
    output wire [PIX_W-1:0]             c2_output_count,
    output wire [31:0]                  c2_lane_output_count,
    output wire [PIX_W-1:0]             c3_load_count,
    output wire [PIX_W-1:0]             c3_output_count,
    output wire [31:0]                  c3_lane_output_count
);
    reg active;
    reg error_q;
    reg c1_done_seen;
    reg c2_done_seen;

    wire start_take = start && ready;

    wire c1_ready;
    wire c1_busy;
    wire c1_done;
    wire c1_error;
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
    wire [PIX_W-1:0] c3_core_input_count;

    assign ready = !active && c1_ready && c2_ready && c3_ready;
    assign busy = active;
    assign error = error_q || c1_error || c2_error || c3_error;

    sr_w8a12_block1_c1_single_out_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH)
    ) u_c1_stage (
        .clk(clk),
        .rst(rst),
        .start(start_take),
        .ready(c1_ready),
        .busy(c1_busy),
        .done(c1_done),
        .error(c1_error),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(c1_valid),
        .m_ready(c1_ready_downstream),
        .m_feat(c1_feat),
        .m_user(c1_user),
        .m_last(c1_last),
        .load_count(c1_load_count),
        .c1_input_count(c1_core_input_count),
        .c1_output_count(c1_output_count),
        .lane_output_count(c1_lane_output_count)
    );

    sr_w8a12_block1_c2_single_out_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH)
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
        .c2_input_count(c2_core_input_count),
        .c2_output_count(c2_output_count),
        .lane_output_count(c2_lane_output_count)
    );

    sr_w8a12_block1_c3_single_out_buffered_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH)
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
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last),
        .load_count(c3_load_count),
        .c3_input_count(c3_core_input_count),
        .c3_output_count(c3_output_count),
        .lane_output_count(c3_lane_output_count)
    );

    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0;
            done <= 1'b0;
            error_q <= 1'b0;
            c1_done_seen <= 1'b0;
            c2_done_seen <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start_take) begin
                active <= 1'b1;
                error_q <= 1'b0;
                c1_done_seen <= 1'b0;
                c2_done_seen <= 1'b0;
            end else if (start && !ready) begin
                error_q <= 1'b1;
            end

            if (c1_error || c2_error || c3_error)
                error_q <= 1'b1;
            if (active && c1_done)
                c1_done_seen <= 1'b1;
            if (active && c2_done)
                c2_done_seen <= 1'b1;

            if (active && c3_done) begin
                done <= 1'b1;
                active <= 1'b0;
                if ((!c1_done_seen && !c1_done) || (!c2_done_seen && !c2_done))
                    error_q <= 1'b1;
            end
        end
    end

    wire unused_busy = c1_busy | c2_busy | c3_busy;
    wire unused_input_counts = |c1_core_input_count | |c2_core_input_count | |c3_core_input_count;
endmodule
