`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

module span_tinyspan_w8a8_block0_streamed_frontend #(
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32,
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
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [CH*ACT_W-1:0]   m_feat,
    output wire                         m_user,
    output wire                         m_last
);
    span_tinyspan_w8a8_block_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .C1_WEIGHT_GROUP_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_WEIGHT_GROUP_FILE),
        .C1_BIAS_I64_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_BIAS_I64_FILE),
        .C1_REQUANT_Q31_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_REQUANT_Q31_FILE),
        .C1_REQUANT_SHIFT_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_REQUANT_SHIFT_FILE),
        .ACT1_LUT_FILE(`TINYSPAN_W8A8_BLOCKS_0_ACT1_LUT_FILE),
        .C2_WEIGHT_GROUP_FILE(`TINYSPAN_W8A8_BLOCKS_0_C2_WEIGHT_GROUP_FILE),
        .C2_BIAS_I64_FILE(`TINYSPAN_W8A8_BLOCKS_0_C2_BIAS_I64_FILE),
        .C2_REQUANT_Q31_FILE(`TINYSPAN_W8A8_BLOCKS_0_C2_REQUANT_Q31_FILE),
        .C2_REQUANT_SHIFT_FILE(`TINYSPAN_W8A8_BLOCKS_0_C2_REQUANT_SHIFT_FILE),
        .ACT2_LUT_FILE(`TINYSPAN_W8A8_BLOCKS_0_ACT2_LUT_FILE),
        .C3_WEIGHT_GROUP_FILE(`TINYSPAN_W8A8_BLOCKS_0_C3_WEIGHT_GROUP_FILE),
        .C3_BIAS_I64_FILE(`TINYSPAN_W8A8_BLOCKS_0_C3_BIAS_I64_FILE),
        .C3_REQUANT_Q31_FILE(`TINYSPAN_W8A8_BLOCKS_0_C3_REQUANT_Q31_FILE),
        .C3_REQUANT_SHIFT_FILE(`TINYSPAN_W8A8_BLOCKS_0_C3_REQUANT_SHIFT_FILE),
        .SIM_ATT_LUT_FILE(`TINYSPAN_W8A8_BLOCKS_0_SIM_ATT_LUT_FILE),
        .SUM_A_Q31(`TINYSPAN_W8A8_BLOCKS_0_SUM_A_Q31),
        .SUM_B_Q31(`TINYSPAN_W8A8_BLOCKS_0_SUM_B_Q31),
        .SUM_SHIFT(`TINYSPAN_W8A8_BLOCKS_0_SUM_SHIFT),
        .MUL_Q31(`TINYSPAN_W8A8_BLOCKS_0_MUL_Q31),
        .MUL_SHIFT(`TINYSPAN_W8A8_BLOCKS_0_MUL_SHIFT)
    ) u_block (
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
