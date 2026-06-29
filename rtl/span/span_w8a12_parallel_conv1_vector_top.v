`timescale 1ns/1ps
`include "reds_span_x4_f48_w8a12/span_w8a12_layers.vh"

// Fixed conv_1 wrapper for OOC synthesis of the group-scheduled parallel layer.
module span_w8a12_parallel_conv1_vector_top #(
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [3*9*12-1:0]      window_i,
    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [48*12-1:0]       feat_o
);
    span_w8a12_parallel_conv_vector_layer #(
        .IN_CH(3),
        .OUT_CH(48),
        .KERNEL_TAPS(9),
        .ACT_W(12),
        .WEIGHT_W(8),
        .ACC_W(48),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_0_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_0_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_SHIFT_FILE)
    ) u_layer (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .window_i(window_i),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .feat_o(feat_o)
    );
endmodule
