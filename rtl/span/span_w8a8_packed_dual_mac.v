`timescale 1ns/1ps

// TinySPAN/W8A8 two-lane packed MAC wrapper.
//
// This reuses the proven packed-dual-MAC structure with 8-bit activations,
// 8-bit weights, and a tighter lane spacing that still leaves a guard bit.
module span_w8a8_packed_dual_mac #(
    parameter integer ACC_W = 48,
    parameter integer PIPELINE = 1
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [7:0]            act_i,
    input  wire signed [7:0]            weight0_i,
    input  wire signed [7:0]            weight1_i,
    input  wire signed [ACC_W-1:0]      acc0_i,
    input  wire signed [ACC_W-1:0]      acc1_i,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [ACC_W-1:0]      acc0_o,
    output wire signed [ACC_W-1:0]      acc1_o
);
    span_w8a10_packed_dual_mac #(
        .ACT_W(8),
        .WEIGHT_W(8),
        .ACC_W(ACC_W),
        .PACK_SHIFT(17),
        .PIPELINE(PIPELINE)
    ) u_packed_dual_mac (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .act_i(act_i),
        .weight0_i(weight0_i),
        .weight1_i(weight1_i),
        .acc0_i(acc0_i),
        .acc1_i(acc1_i),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .acc0_o(acc0_o),
        .acc1_o(acc1_o)
    );
endmodule
