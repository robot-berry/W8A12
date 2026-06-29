`timescale 1ns/1ps
`include "../generated/reds_span_x4_f48_w8a12/span_w8a12_layers.vh"
`include "../generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess.vh"

// Runtime-selectable one-output-channel kernel for block_1.c1_r + act1.
module span_w8a12_block1_c1_single_out_kernel #(
    parameter integer ACT_W = 12,
    parameter integer CH = 48,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH_W = (CH <= 2) ? 1 : $clog2(CH)
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire [OUT_CH_W-1:0]          out_ch_i,
    input  wire signed [CH*9*ACT_W-1:0] window_i,
    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [ACT_W-1:0]      raw_o,
    output wire signed [ACT_W-1:0]      act_o
);
    wire signed [ACT_W-1:0] raw_feat;

    span_w8a12_single_out_conv_layer #(
        .IN_CH(CH),
        .OUT_CH_TOTAL(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_1_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_1_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_1_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_1_REQUANT_SHIFT_FILE)
    ) u_conv (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .out_ch_i(out_ch_i),
        .window_i(window_i),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .feat_o(raw_feat)
    );

    span_w8a12_unary_lut #(
        .ACT_W(ACT_W),
        .LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_0_FILE)
    ) u_act1_lut (
        .x_i(raw_feat),
        .y_o(act_o)
    );

    assign raw_o = raw_feat;
endmodule
