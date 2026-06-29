`timescale 1ns/1ps

// Streamed REDS W8A12 frontend through the repeated SPAN body:
//   RGB -> conv_1 -> block_1 -> ... -> block_6.
module span_w8a12_conv1_spab6_streamed_frontend #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       s_valid,
    output wire                       s_ready,
    input  wire [DATA_W-1:0]          s_data,
    input  wire                       s_user,
    input  wire                       s_last,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire signed [CH*ACT_W-1:0] m_feat,
    output wire                       m_user,
    output wire                       m_last
);
    wire conv1_valid;
    wire conv1_ready;
    wire [CH*ACT_W-1:0] conv1_feat;
    wire conv1_user;
    wire conv1_last;

    span_w8a12_conv1_streamed_frontend #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_conv1 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_pixel_valid(1'b1),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(conv1_valid),
        .m_ready(conv1_ready),
        .m_feat(conv1_feat),
        .m_user(conv1_user),
        .m_last(conv1_last)
    );

    span_w8a12_spab6_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_spab6 (
        .clk(clk),
        .rst(rst),
        .s_valid(conv1_valid),
        .s_ready(conv1_ready),
        .s_feat(conv1_feat),
        .s_user(conv1_user),
        .s_last(conv1_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
