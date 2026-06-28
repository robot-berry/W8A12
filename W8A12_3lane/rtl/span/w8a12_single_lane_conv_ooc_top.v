`timescale 1ns/1ps

`include "a0_3lane_files.vh"

module w8a12_single_lane_conv_ooc_top #(
    parameter integer IN_CH = 48,
    parameter integer OUT_CH = 16,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48
) (
    input  wire clk,
    input  wire rst,
    input  wire s_valid,
    output wire s_ready,
    input  wire [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,
    output wire m_valid,
    input  wire m_ready,
    output wire [OUT_CH*ACT_W-1:0] feat_o
);
    span_w8a12_conv_layer #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`W8A12_3LANE_A0_LANE0_WEIGHT_MEM),
        .BIAS_I64_FILE(`W8A12_3LANE_A0_LANE0_BIAS_MEM),
        .REQUANT_Q31_FILE(`W8A12_3LANE_A0_LANE0_REQUANT_MEM),
        .REQUANT_SHIFT_FILE(`W8A12_3LANE_A0_LANE0_SHIFT_MEM)
    ) u_lane0 (
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
