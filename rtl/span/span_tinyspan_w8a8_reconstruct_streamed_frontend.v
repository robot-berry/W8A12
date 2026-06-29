`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

module span_tinyspan_w8a8_reconstruct_streamed_frontend #(
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32,
    parameter integer ACT_W = `TINYSPAN_W8A8_ACT_W,
    parameter integer ACC_W = 48,
    parameter integer IN_CH = `TINYSPAN_W8A8_RECONSTRUCT_IN_CH,
    parameter integer OUT_CH = `TINYSPAN_W8A8_RECONSTRUCT_OUT_CH,
    parameter integer OUT_LANES = `TINYSPAN_W8A8_OUT_LANES,
    parameter integer TAP_LANES = `TINYSPAN_W8A8_TAP_LANES
) (
    input  wire                             clk,
    input  wire                             rst,

    input  wire                             s_valid,
    output wire                             s_ready,
    input  wire signed [IN_CH*ACT_W-1:0]    s_feat,
    input  wire                             s_user,
    input  wire                             s_last,

    output wire                             m_valid,
    input  wire                             m_ready,
    output wire signed [OUT_CH*ACT_W-1:0]   m_feat,
    output wire                             m_user,
    output wire                             m_last
);
    span_tinyspan_w8a8_feature_conv_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(`TINYSPAN_W8A8_RECONSTRUCT_WEIGHT_GROUP_FILE),
        .BIAS_I64_FILE(`TINYSPAN_W8A8_RECONSTRUCT_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`TINYSPAN_W8A8_RECONSTRUCT_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`TINYSPAN_W8A8_RECONSTRUCT_REQUANT_SHIFT_FILE)
    ) u_reconstruct (
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

