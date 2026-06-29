`timescale 1ns/1ps
`include "span_w8a12_generated_select.vh"

// Thin wrapper for REDS W8A12 block_3.
module span_w8a12_block3_streamed_frontend #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter C1_WEIGHT_GROUP_FILE = `REDS_SPAN_ACTIVE_BLOCK_3_C1_WEIGHT_GROUP_FILE,
    parameter C2_WEIGHT_GROUP_FILE = `REDS_SPAN_ACTIVE_BLOCK_3_C2_WEIGHT_GROUP_FILE,
    parameter C3_WEIGHT_GROUP_FILE = `REDS_SPAN_ACTIVE_BLOCK_3_C3_WEIGHT_GROUP_FILE
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,
    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [CH*ACT_W-1:0]   m_feat,
    output wire                         m_user,
    output wire                         m_last
);
    span_w8a12_spab_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .C1_WEIGHT_GROUP_FILE(C1_WEIGHT_GROUP_FILE),
        .C1_BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_7_BIAS_I64_FILE),
        .C1_REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_7_REQUANT_Q31_FILE),
        .C1_REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_7_REQUANT_SHIFT_FILE),
        .ACT1_LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_6_FILE),
        .C2_WEIGHT_GROUP_FILE(C2_WEIGHT_GROUP_FILE),
        .C2_BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_8_BIAS_I64_FILE),
        .C2_REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_8_REQUANT_Q31_FILE),
        .C2_REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_8_REQUANT_SHIFT_FILE),
        .ACT2_LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_7_FILE),
        .C3_WEIGHT_GROUP_FILE(C3_WEIGHT_GROUP_FILE),
        .C3_BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_9_BIAS_I64_FILE),
        .C3_REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_9_REQUANT_Q31_FILE),
        .C3_REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_9_REQUANT_SHIFT_FILE),
        .SIM_ATT_LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_8_FILE),
        .ATT_SHIFT(`REDS_SPAN_W8A12_POSTPROCESS_8_REQUANT_SHIFT),
        .ATT_OUT3_REQUANT_Q31(`REDS_SPAN_W8A12_POSTPROCESS_8_OUT3_REQUANT_Q31),
        .ATT_RESIDUAL_REQUANT_Q31(`REDS_SPAN_W8A12_POSTPROCESS_8_RESIDUAL_REQUANT_Q31)
    ) u_spab (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
