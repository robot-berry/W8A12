`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

module span_tinyspan_w8a8_block0_c1_vector_top #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
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
    input  wire signed [CH*9*ACT_W-1:0] window_i,
    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [CH*ACT_W-1:0]   feat_o
);
    wire unused_img = |{IMG_W[0], IMG_H[0]};
    wire weight_req_valid;
    wire weight_req_ready;
    wire [31:0] weight_req_out_group;
    wire [31:0] weight_req_tap_group;
    wire signed [OUT_LANES*TAP_LANES*8-1:0] weight_group;

    span_w8a12_weight_group_rom #(
        .OUT_CH(CH),
        .TAP_COUNT(CH*9),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_W(8),
        .MEM_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_WEIGHT_GROUP_FILE)
    ) u_weight_groups (
        .clk(clk),
        .rst(rst),
        .req_valid(weight_req_valid),
        .req_ready(weight_req_ready),
        .req_out_group(weight_req_out_group),
        .req_tap_group(weight_req_tap_group),
        .weight_group_o(weight_group)
    );

    span_w8a12_parallel_conv_vector_streamed_weights #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .WEIGHT_W(8),
        .ACC_W(ACC_W),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .BIAS_I64_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`TINYSPAN_W8A8_BLOCKS_0_C1_REQUANT_SHIFT_FILE)
    ) u_conv (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .window_i(window_i),
        .weight_req_valid(weight_req_valid),
        .weight_req_ready(weight_req_ready),
        .weight_req_out_group(weight_req_out_group),
        .weight_req_tap_group(weight_req_tap_group),
        .weight_group_i(weight_group),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .feat_o(feat_o)
    );
endmodule
