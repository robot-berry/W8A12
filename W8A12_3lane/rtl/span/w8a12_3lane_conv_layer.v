`timescale 1ns/1ps

module w8a12_3lane_conv_layer #(
    parameter integer IN_CH = 48,
    parameter integer LANES = 3,
    parameter integer OUT_CH_PER_LANE = 16,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 12,
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
    input  wire                                      clk,
    input  wire                                      rst,
    input  wire                                      s_valid,
    output wire                                      s_ready,
    input  wire [IN_CH*KERNEL_TAPS*ACT_W-1:0]        window_i,
    output wire                                      m_valid,
    input  wire                                      m_ready,
    output wire [LANES*OUT_CH_PER_LANE*ACT_W-1:0]    feat_o
);
    wire [LANES-1:0] lane_s_ready;
    wire [LANES-1:0] lane_m_valid;
    wire [OUT_CH_PER_LANE*ACT_W-1:0] lane_feat [0:LANES-1];

    assign s_ready = &lane_s_ready;
    assign m_valid = &lane_m_valid;

    genvar lane;
    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : g_lane_pack
            assign feat_o[lane*OUT_CH_PER_LANE*ACT_W +: OUT_CH_PER_LANE*ACT_W] = lane_feat[lane];
        end
    endgenerate

    span_w8a12_conv_layer #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH_PER_LANE),
        .KERNEL_TAPS(KERNEL_TAPS),
        .ACT_W(ACT_W),
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
        .feat_o(lane_feat[0])
    );

    span_w8a12_conv_layer #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH_PER_LANE),
        .KERNEL_TAPS(KERNEL_TAPS),
        .ACT_W(ACT_W),
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
        .feat_o(lane_feat[1])
    );

    span_w8a12_conv_layer #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH_PER_LANE),
        .KERNEL_TAPS(KERNEL_TAPS),
        .ACT_W(ACT_W),
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
        .feat_o(lane_feat[2])
    );
endmodule
