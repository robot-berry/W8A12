`timescale 1ns/1ps
`include "span_w8a12_generated_select.vh"

// Thin streamed wrapper for REDS W8A12 upsampler.0 before PixelShuffle.
module span_w8a12_upsampler0_streamed_frontend #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter WEIGHT_GROUP_FILE = `REDS_SPAN_ACTIVE_UPSAMPLER_0_WEIGHT_GROUP_FILE
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
    span_w8a12_feature_conv_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(WEIGHT_GROUP_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_21_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_21_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_21_REQUANT_SHIFT_FILE)
    ) u_conv (
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
