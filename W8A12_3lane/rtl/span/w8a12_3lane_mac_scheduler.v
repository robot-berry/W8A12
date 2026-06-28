`timescale 1ns/1ps

// Three 16-channel lanes stitched into one 48-output-channel convolution stage.
//
// This A4 wrapper keeps the channel partition explicit:
//   lane0 -> output channels  0..15
//   lane1 -> output channels 16..31
//   lane2 -> output channels 32..47
// Each lane consumes the same full 48-channel 3x3 input window.
module w8a12_3lane_mac_scheduler #(
    parameter integer IN_CH = 48,
    parameter integer LANE_CH = 16,
    parameter integer KERNEL_TAPS = 9,
    parameter integer TAP_PAR = 8,
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter LANE0_WEIGHT_FILE = "",
    parameter LANE0_BIAS_I64_FILE = "",
    parameter LANE0_REQUANT_Q31_FILE = "",
    parameter LANE0_REQUANT_SHIFT_FILE = "",
    parameter LANE1_WEIGHT_FILE = "",
    parameter LANE1_BIAS_I64_FILE = "",
    parameter LANE1_REQUANT_Q31_FILE = "",
    parameter LANE1_REQUANT_SHIFT_FILE = "",
    parameter LANE2_WEIGHT_FILE = "",
    parameter LANE2_BIAS_I64_FILE = "",
    parameter LANE2_REQUANT_Q31_FILE = "",
    parameter LANE2_REQUANT_SHIFT_FILE = ""
) (
    input  wire clk,
    input  wire rst,
    input  wire s_valid,
    output wire s_ready,
    input  wire [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,
    output wire m_valid,
    input  wire m_ready,
    output wire [3*LANE_CH*ACT_W-1:0] feat_o
);
    wire [2:0] lane_s_ready;
    wire [2:0] lane_m_valid;

    assign s_ready = &lane_s_ready;
    assign m_valid = &lane_m_valid;

    w8a12_single_lane_mac_scheduler #(
        .IN_CH(IN_CH),
        .OUT_CH(LANE_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .TAP_PAR(TAP_PAR),
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(LANE0_WEIGHT_FILE),
        .BIAS_I64_FILE(LANE0_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(LANE0_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(LANE0_REQUANT_SHIFT_FILE)
    ) u_lane0 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid && s_ready),
        .s_ready(lane_s_ready[0]),
        .window_i(window_i),
        .m_valid(lane_m_valid[0]),
        .m_ready(m_ready && m_valid),
        .feat_o(feat_o[0*LANE_CH*ACT_W +: LANE_CH*ACT_W])
    );

    w8a12_single_lane_mac_scheduler #(
        .IN_CH(IN_CH),
        .OUT_CH(LANE_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .TAP_PAR(TAP_PAR),
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(LANE1_WEIGHT_FILE),
        .BIAS_I64_FILE(LANE1_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(LANE1_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(LANE1_REQUANT_SHIFT_FILE)
    ) u_lane1 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid && s_ready),
        .s_ready(lane_s_ready[1]),
        .window_i(window_i),
        .m_valid(lane_m_valid[1]),
        .m_ready(m_ready && m_valid),
        .feat_o(feat_o[1*LANE_CH*ACT_W +: LANE_CH*ACT_W])
    );

    w8a12_single_lane_mac_scheduler #(
        .IN_CH(IN_CH),
        .OUT_CH(LANE_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .TAP_PAR(TAP_PAR),
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(LANE2_WEIGHT_FILE),
        .BIAS_I64_FILE(LANE2_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(LANE2_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(LANE2_REQUANT_SHIFT_FILE)
    ) u_lane2 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid && s_ready),
        .s_ready(lane_s_ready[2]),
        .window_i(window_i),
        .m_valid(lane_m_valid[2]),
        .m_ready(m_ready && m_valid),
        .feat_o(feat_o[2*LANE_CH*ACT_W +: LANE_CH*ACT_W])
    );
endmodule
