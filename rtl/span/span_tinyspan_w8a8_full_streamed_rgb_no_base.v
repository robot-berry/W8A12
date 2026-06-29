`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

// TinySPAN W8A8 learned path from RGB input to X4 RGB q pixels.
//
// This intentionally excludes the bicubic-upsampled RGB base-add used by the
// software reference. It is a synthesis/integration staging top, not a final
// board-acceptance top.
module span_tinyspan_w8a8_full_streamed_rgb_no_base #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = `TINYSPAN_W8A8_ACT_W,
    parameter integer ACC_W = 48,
    parameter integer CH = `TINYSPAN_W8A8_CHANNELS,
    parameter integer OUT_LANES = `TINYSPAN_W8A8_OUT_LANES,
    parameter integer TAP_LANES = `TINYSPAN_W8A8_TAP_LANES
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
    output wire signed [3*ACT_W-1:0]  m_rgb,
    output wire                       m_user,
    output wire                       m_last
);
    wire head_valid;
    wire head_ready;
    wire signed [CH*ACT_W-1:0] head_feat;
    wire head_user;
    wire head_last;

    span_tinyspan_w8a8_head_streamed_frontend #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_head (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(head_valid),
        .m_ready(head_ready),
        .m_feat(head_feat),
        .m_user(head_user),
        .m_last(head_last)
    );

    span_tinyspan_w8a8_trunk_tail_streamed_rgb_no_base #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_learned_path (
        .clk(clk),
        .rst(rst),
        .s_valid(head_valid),
        .s_ready(head_ready),
        .s_head(head_feat),
        .s_user(head_user),
        .s_last(head_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule

