`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

// TinySPAN W8A8 learned path from quantized head features to X4 RGB q pixels.
// This excludes the bicubic RGB base-add path required by the software
// reference, so it is an integration staging top rather than an acceptance top.
module span_tinyspan_w8a8_trunk_tail_streamed_rgb_no_base #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = `TINYSPAN_W8A8_ACT_W,
    parameter integer ACC_W = 48,
    parameter integer CH = `TINYSPAN_W8A8_CHANNELS,
    parameter integer OUT_LANES = `TINYSPAN_W8A8_OUT_LANES,
    parameter integer TAP_LANES = `TINYSPAN_W8A8_TAP_LANES
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_head,
    input  wire                         s_user,
    input  wire                         s_last,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [3*ACT_W-1:0]    m_rgb,
    output wire                         m_user,
    output wire                         m_last
);
    wire taps_valid;
    wire taps_ready;
    wire signed [CH*ACT_W-1:0] tap_head;
    wire signed [CH*ACT_W-1:0] tap_block0;
    wire signed [CH*ACT_W-1:0] tap_block3;
    wire taps_user;
    wire taps_last;

    span_tinyspan_w8a8_blocks0123_taps_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_trunk_taps (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(s_head),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(taps_valid),
        .m_ready(taps_ready),
        .m_head(tap_head),
        .m_block0(tap_block0),
        .m_block3(tap_block3),
        .m_user(taps_user),
        .m_last(taps_last)
    );

    span_tinyspan_w8a8_tail_streamed_rgb_no_base #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_tail (
        .clk(clk),
        .rst(rst),
        .s_valid(taps_valid),
        .s_ready(taps_ready),
        .head_i(tap_head),
        .block0_i(tap_block0),
        .block3_i(tap_block3),
        .s_user(taps_user),
        .s_last(taps_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule

