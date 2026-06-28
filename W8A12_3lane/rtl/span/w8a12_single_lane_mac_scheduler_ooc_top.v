`timescale 1ns/1ps

`include "a0_3lane_files.vh"

module w8a12_single_lane_mac_scheduler_ooc_top #(
    parameter integer IN_CH = 48,
    parameter integer LANE_CH = 16,
    parameter integer KERNEL_TAPS = 9,
    parameter integer TAP_PAR = 8,
    parameter integer ACT_W = 12
) (
    input  wire clk,
    input  wire rst,
    input  wire s_valid,
    output wire s_ready,
    input  wire [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,
    output wire m_valid,
    input  wire m_ready,
    output wire [LANE_CH*ACT_W-1:0] feat_o
);
    w8a12_single_lane_mac_scheduler #(
        .IN_CH(IN_CH),
        .OUT_CH(LANE_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .TAP_PAR(TAP_PAR),
        .ACT_W(ACT_W),
        .WEIGHT_FILE(`W8A12_3LANE_A0_LANE0_WEIGHT_MEM),
        .BIAS_I64_FILE(`W8A12_3LANE_A0_LANE0_BIAS_MEM),
        .REQUANT_Q31_FILE(`W8A12_3LANE_A0_LANE0_REQUANT_MEM),
        .REQUANT_SHIFT_FILE(`W8A12_3LANE_A0_LANE0_SHIFT_MEM)
    ) u_dut (
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
