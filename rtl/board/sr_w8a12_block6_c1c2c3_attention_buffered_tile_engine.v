`timescale 1ns/1ps
`include "../generated/reds_span_x4_f48_w8a12/span_w8a12_layers.vh"
`include "../generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess.vh"

module sr_w8a12_block6_c1c2c3_attention_buffered_tile_engine #(
    parameter integer TILE_W = 2, parameter integer TILE_H = 2, parameter integer ACT_W = 12,
    parameter integer ACC_W = 48, parameter integer CH = 48, parameter integer FEAT_W = CH * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H, parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1)
) (
    input wire clk, input wire rst, input wire start, output wire ready, output wire busy, output wire done, output wire error,
    input wire s_valid, output wire s_ready, input wire signed [FEAT_W-1:0] s_feat, input wire s_user, input wire s_last,
    output wire m_valid, input wire m_ready, output wire signed [FEAT_W-1:0] m_feat, output wire m_user, output wire m_last,
    output wire [PIX_W-1:0] residual_load_count,
    output wire [PIX_W-1:0] c1_load_count, output wire [PIX_W-1:0] c1_output_count, output wire [31:0] c1_lane_output_count,
    output wire [PIX_W-1:0] c2_load_count, output wire [PIX_W-1:0] c2_output_count, output wire [31:0] c2_lane_output_count,
    output wire [PIX_W-1:0] c3_load_count, output wire [PIX_W-1:0] c3_output_count, output wire [31:0] c3_lane_output_count,
    output wire [PIX_W-1:0] att_input_count, output wire [PIX_W-1:0] att_output_count, output wire [31:0] att_lane_output_count
);
    sr_w8a12_spab_c1c2c3_attention_buffered_tile_engine #(
        .TILE_W(TILE_W), .TILE_H(TILE_H), .ACT_W(ACT_W), .ACC_W(ACC_W), .CH(CH),
        .C1_WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_16_WEIGHT_FILE),
        .C1_BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_16_BIAS_I64_FILE),
        .C1_REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_16_REQUANT_Q31_FILE),
        .C1_REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_16_REQUANT_SHIFT_FILE),
        .C1_ACT_LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_15_FILE),
        .C2_WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_17_WEIGHT_FILE),
        .C2_BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_17_BIAS_I64_FILE),
        .C2_REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_17_REQUANT_Q31_FILE),
        .C2_REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_17_REQUANT_SHIFT_FILE),
        .C2_ACT_LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_16_FILE),
        .C3_WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_18_WEIGHT_FILE),
        .C3_BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_18_BIAS_I64_FILE),
        .C3_REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_18_REQUANT_Q31_FILE),
        .C3_REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_18_REQUANT_SHIFT_FILE),
        .SIM_ATT_LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_17_FILE),
        .ATT_SHIFT(`REDS_SPAN_W8A12_POSTPROCESS_17_REQUANT_SHIFT),
        .ATT_OUT3_REQUANT_Q31(`REDS_SPAN_W8A12_POSTPROCESS_17_OUT3_REQUANT_Q31),
        .ATT_RESIDUAL_REQUANT_Q31(`REDS_SPAN_W8A12_POSTPROCESS_17_RESIDUAL_REQUANT_Q31)
    ) u_spab (
        .clk(clk), .rst(rst), .start(start), .ready(ready), .busy(busy), .done(done), .error(error),
        .s_valid(s_valid), .s_ready(s_ready), .s_feat(s_feat), .s_user(s_user), .s_last(s_last),
        .m_valid(m_valid), .m_ready(m_ready), .m_feat(m_feat), .m_user(m_user), .m_last(m_last),
        .residual_load_count(residual_load_count),
        .c1_load_count(c1_load_count), .c1_output_count(c1_output_count), .c1_lane_output_count(c1_lane_output_count),
        .c2_load_count(c2_load_count), .c2_output_count(c2_output_count), .c2_lane_output_count(c2_lane_output_count),
        .c3_load_count(c3_load_count), .c3_output_count(c3_output_count), .c3_lane_output_count(c3_lane_output_count),
        .att_input_count(att_input_count), .att_output_count(att_output_count), .att_lane_output_count(att_lane_output_count)
    );
endmodule
