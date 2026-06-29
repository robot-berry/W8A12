`timescale 1ns/1ps
`include "../generated/reds_span_x4_f48_w8a12/span_w8a12_layers.vh"

// W8A12 conv_1 frontend:
//   RGB stream -> frame 3x3 window -> PyTorch/SPAN RGB normalization -> conv_1.
module span_w8a12_conv1_frontend #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 3,
    parameter integer IMG_H = 3,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH = 48
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       s_valid,
    output wire                       s_ready,
    input  wire [DATA_W-1:0]          s_data,
    input  wire                       s_user,
    input  wire                       s_last,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire [OUT_CH*ACT_W-1:0]    m_feat,
    output reg                        m_user,
    output reg                        m_last
);
    wire window_valid;
    wire window_ready;
    wire [3*9*8-1:0] rgb_window;
    wire window_user;
    wire window_last;
    wire [8:0] window_valid_mask;
    wire [3*9*ACT_W-1:0] norm_window;

    span_rgb_frame_window3x3 #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) u_window (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(window_valid),
        .m_ready(window_ready),
        .window_o(rgb_window),
        .window_valid_mask_o(window_valid_mask),
        .m_user(window_user),
        .m_last(window_last)
    );

    span_w8a12_rgb_window_normalize #(
        .ACT_W(ACT_W)
    ) u_normalize (
        .rgb_window_i(rgb_window),
        .valid_mask_i(window_valid_mask),
        .norm_window_o(norm_window)
    );

    span_w8a12_conv_layer #(
        .IN_CH(3),
        .OUT_CH(OUT_CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_0_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_0_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_SHIFT_FILE)
    ) u_conv1 (
        .clk(clk),
        .rst(rst),
        .s_valid(window_valid),
        .s_ready(window_ready),
        .window_i(norm_window),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .feat_o(m_feat)
    );

    always @(posedge clk) begin
        if (rst) begin
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else if (window_valid && window_ready) begin
            m_user <= window_user;
            m_last <= window_last;
        end
    end
endmodule
