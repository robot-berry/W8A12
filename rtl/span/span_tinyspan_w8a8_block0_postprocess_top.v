`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

module span_tinyspan_w8a8_block0_postprocess_top #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = `TINYSPAN_W8A8_ACT_W,
    parameter integer CH = `TINYSPAN_W8A8_CHANNELS,
    parameter integer OUT_LANES = `TINYSPAN_W8A8_OUT_LANES,
    parameter integer TAP_LANES = `TINYSPAN_W8A8_TAP_LANES
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_c3_feat,
    input  wire signed [CH*ACT_W-1:0]   s_residual_feat,
    input  wire                         s_user,
    input  wire                         s_last,
    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [CH*ACT_W-1:0]   m_feat,
    output wire                         m_user,
    output wire                         m_last
);
    wire unused_params = |{IMG_W[0], IMG_H[0], OUT_LANES[0], TAP_LANES[0]};
    span_tinyspan_w8a8_block_postprocess_serial #(
        .ACT_W(ACT_W),
        .CH(CH),
        .SIM_ATT_LUT_FILE(`TINYSPAN_W8A8_BLOCKS_0_SIM_ATT_LUT_FILE),
        .SUM_A_Q31(`TINYSPAN_W8A8_BLOCKS_0_SUM_A_Q31),
        .SUM_B_Q31(`TINYSPAN_W8A8_BLOCKS_0_SUM_B_Q31),
        .SUM_SHIFT(`TINYSPAN_W8A8_BLOCKS_0_SUM_SHIFT),
        .MUL_Q31(`TINYSPAN_W8A8_BLOCKS_0_MUL_Q31),
        .MUL_SHIFT(`TINYSPAN_W8A8_BLOCKS_0_MUL_SHIFT)
    ) u_post (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_c3_feat(s_c3_feat),
        .s_residual_feat(s_residual_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
