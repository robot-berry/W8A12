`timescale 1ns/1ps
`include "../generated/reds_span_x4_f48_w8a12/span_w8a12_layers.vh"
`include "../generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess.vh"

// Streamed block_1.c1_r -> SiLU(act1) -> block_1.c2_r frame prototype.
module span_w8a12_block1_c1c2_streamed_frontend #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter C1_WEIGHT_GROUP_FILE = "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_1_c1_r_w_i8_group_ol8_tl16.mem",
    parameter C2_WEIGHT_GROUP_FILE = "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_1_c2_r_w_i8_group_ol8_tl16.mem"
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
    wire c1_valid;
    wire c1_ready;
    wire signed [CH*ACT_W-1:0] c1_feat;
    wire c1_user;
    wire c1_last;
    wire signed [CH*ACT_W-1:0] c1_act_feat;

    span_w8a12_block1_c1_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(C1_WEIGHT_GROUP_FILE)
    ) u_c1 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(c1_valid),
        .m_ready(c1_ready),
        .m_feat(c1_feat),
        .m_user(c1_user),
        .m_last(c1_last)
    );

    genvar ch_i;
    generate
        for (ch_i = 0; ch_i < CH; ch_i = ch_i + 1) begin : g_act1
            span_w8a12_unary_lut #(
                .ACT_W(ACT_W),
                .LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_0_FILE)
            ) u_act1_lut (
                .x_i(c1_feat[ch_i*ACT_W +: ACT_W]),
                .y_o(c1_act_feat[ch_i*ACT_W +: ACT_W])
            );
        end
    endgenerate

    span_w8a12_feature_conv_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(C2_WEIGHT_GROUP_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_2_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_2_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_2_REQUANT_SHIFT_FILE)
    ) u_c2 (
        .clk(clk),
        .rst(rst),
        .s_valid(c1_valid),
        .s_ready(c1_ready),
        .s_feat(c1_act_feat),
        .s_user(c1_user),
        .s_last(c1_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
