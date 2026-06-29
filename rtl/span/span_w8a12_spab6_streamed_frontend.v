`timescale 1ns/1ps

// Streamed REDS W8A12 SPAB chain: block_1 -> block_2 -> ... -> block_6.
module span_w8a12_spab6_streamed_frontend #(
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
    output wire signed [CH*ACT_W-1:0]   m_feat,
    output wire                         m_user,
    output wire                         m_last
);
    wire b1_valid;
    wire b1_ready;
    wire signed [CH*ACT_W-1:0] b1_feat;
    wire b1_user;
    wire b1_last;

    wire b2_valid;
    wire b2_ready;
    wire signed [CH*ACT_W-1:0] b2_feat;
    wire b2_user;
    wire b2_last;

    wire b3_valid;
    wire b3_ready;
    wire signed [CH*ACT_W-1:0] b3_feat;
    wire b3_user;
    wire b3_last;

    wire b4_valid;
    wire b4_ready;
    wire signed [CH*ACT_W-1:0] b4_feat;
    wire b4_user;
    wire b4_last;

    wire b5_valid;
    wire b5_ready;
    wire signed [CH*ACT_W-1:0] b5_feat;
    wire b5_user;
    wire b5_last;

    span_w8a12_block1_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block1 (
        .clk(clk), .rst(rst),
        .s_valid(s_valid), .s_ready(s_ready), .s_feat(s_feat),
        .s_user(s_user), .s_last(s_last),
        .m_valid(b1_valid), .m_ready(b1_ready), .m_feat(b1_feat),
        .m_user(b1_user), .m_last(b1_last)
    );

    span_w8a12_block2_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block2 (
        .clk(clk), .rst(rst),
        .s_valid(b1_valid), .s_ready(b1_ready), .s_feat(b1_feat),
        .s_user(b1_user), .s_last(b1_last),
        .m_valid(b2_valid), .m_ready(b2_ready), .m_feat(b2_feat),
        .m_user(b2_user), .m_last(b2_last)
    );

    span_w8a12_block3_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block3 (
        .clk(clk), .rst(rst),
        .s_valid(b2_valid), .s_ready(b2_ready), .s_feat(b2_feat),
        .s_user(b2_user), .s_last(b2_last),
        .m_valid(b3_valid), .m_ready(b3_ready), .m_feat(b3_feat),
        .m_user(b3_user), .m_last(b3_last)
    );

    span_w8a12_block4_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block4 (
        .clk(clk), .rst(rst),
        .s_valid(b3_valid), .s_ready(b3_ready), .s_feat(b3_feat),
        .s_user(b3_user), .s_last(b3_last),
        .m_valid(b4_valid), .m_ready(b4_ready), .m_feat(b4_feat),
        .m_user(b4_user), .m_last(b4_last)
    );

    span_w8a12_block5_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block5 (
        .clk(clk), .rst(rst),
        .s_valid(b4_valid), .s_ready(b4_ready), .s_feat(b4_feat),
        .s_user(b4_user), .s_last(b4_last),
        .m_valid(b5_valid), .m_ready(b5_ready), .m_feat(b5_feat),
        .m_user(b5_user), .m_last(b5_last)
    );

    span_w8a12_block6_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block6 (
        .clk(clk), .rst(rst),
        .s_valid(b5_valid), .s_ready(b5_ready), .s_feat(b5_feat),
        .s_user(b5_user), .s_last(b5_last),
        .m_valid(m_valid), .m_ready(m_ready), .m_feat(m_feat),
        .m_user(m_user), .m_last(m_last)
    );
endmodule
