`timescale 1ns/1ps

// Complete streamed REDS W8A12 SPAN path for small-frame proof:
//   RGB -> conv_1 -> block_1..block_6 -> tail -> PixelShuffle x4 -> RGB q
(* keep_hierarchy = "yes" *)
module span_w8a12_full_streamed_rgb #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer SCALE_LANES = 2
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
    wire trunk_valid;
    wire trunk_ready;
    wire signed [CH*ACT_W-1:0] trunk_feat0;
    wire signed [CH*ACT_W-1:0] trunk_block6;
    wire signed [CH*ACT_W-1:0] trunk_b1;
    wire signed [CH*ACT_W-1:0] trunk_b6_act1;
    wire trunk_user;
    wire trunk_last;

    span_w8a12_conv1_spab6_taps_streamed_frontend #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_trunk (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(trunk_valid),
        .m_ready(trunk_ready),
        .m_feat0(trunk_feat0),
        .m_block6(trunk_block6),
        .m_b1(trunk_b1),
        .m_b6_act1(trunk_b6_act1),
        .m_user(trunk_user),
        .m_last(trunk_last)
    );

    span_w8a12_tail_streamed_rgb #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .SCALE_LANES(SCALE_LANES)
    ) u_tail (
        .clk(clk),
        .rst(rst),
        .s_valid(trunk_valid),
        .s_ready(trunk_ready),
        .feat0_i(trunk_feat0),
        .block6_i(trunk_block6),
        .b1_i(trunk_b1),
        .b6_act1_i(trunk_b6_act1),
        .s_user(trunk_user),
        .s_last(trunk_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
