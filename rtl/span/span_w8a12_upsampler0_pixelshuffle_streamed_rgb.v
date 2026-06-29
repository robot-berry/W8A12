`timescale 1ns/1ps

// Streamed tail output slice:
//   upsampler.0 -> PixelShuffle x4 -> RGB q stream
module span_w8a12_upsampler0_pixelshuffle_streamed_rgb #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16
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
    output wire signed [3*ACT_W-1:0]    m_rgb,
    output wire                         m_user,
    output wire                         m_last
);
    wire up_valid;
    wire up_ready;
    wire signed [CH*ACT_W-1:0] up_feat;
    wire up_user;
    wire up_last;

    span_w8a12_upsampler0_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_upsampler0 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(up_valid),
        .m_ready(up_ready),
        .m_feat(up_feat),
        .m_user(up_user),
        .m_last(up_last)
    );

    span_w8a12_pixelshuffle_x4_streamed_rgb #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .CH(CH)
    ) u_pixelshuffle (
        .clk(clk),
        .rst(rst),
        .s_valid(up_valid),
        .s_ready(up_ready),
        .s_feat(up_feat),
        .s_user(up_user),
        .s_last(up_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
