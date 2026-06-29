`timescale 1ns/1ps

// Board-facing TinySPAN W8A8 final-output equivalent that emits RGB888.
module span_tinyspan_w8a8_full_streamed_rgb888_base_equiv #(
    parameter integer DATA_W = 24,
    parameter integer ACT_W = 8,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer USE_SERIAL_BASE = 1
) (
    input  wire               clk,
    input  wire               rst,

    input  wire               s_valid,
    output wire               s_ready,
    input  wire [DATA_W-1:0]  s_data,
    input  wire               s_user,
    input  wire               s_last,

    output wire               m_valid,
    input  wire               m_ready,
    output wire [23:0]        m_data,
    output wire               m_user,
    output wire               m_last
);
    wire signed [3*ACT_W-1:0] q_rgb;

    span_tinyspan_w8a8_full_streamed_rgb_base_equiv #(
        .DATA_W(DATA_W),
        .ACT_W(ACT_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .USE_SERIAL_BASE(USE_SERIAL_BASE)
    ) u_q_base_equiv (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(q_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );

    span_tinyspan_w8a8_qrgb_to_rgb888 #(
        .ACT_W(ACT_W)
    ) u_to_rgb888 (
        .q_rgb_i(q_rgb),
        .rgb_o(m_data)
    );
endmodule
