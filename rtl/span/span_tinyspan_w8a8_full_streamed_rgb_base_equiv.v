`timescale 1ns/1ps

// TinySPAN W8A8 final-output equivalent for the frozen 30fps quant plan.
//
// The learned branch is proven to contribute zero at the final output scale in
// docs/design/tinyspan_w8a8_base_add_equivalence_2026_06_13.md. This top emits
// the quantized software-reference output produced by the bicubic base branch.
module span_tinyspan_w8a8_full_streamed_rgb_base_equiv #(
    parameter integer DATA_W = 24,
    parameter integer ACT_W = 8,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer USE_SERIAL_BASE = 1
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
    output wire signed [3*ACT_W-1:0]  m_rgb,
    output wire                       m_user,
    output wire                       m_last
);
    wire base_valid;
    wire base_ready;
    wire signed [3*ACT_W-1:0] base_rgb;
    wire base_user;
    wire base_last;

    generate
        if (USE_SERIAL_BASE != 0) begin : g_serial_base
            span_tinyspan_w8a8_bicubic_base_x4_streamed_serial #(
                .DATA_W(DATA_W),
                .ACT_W(ACT_W),
                .IMG_W(IMG_W),
                .IMG_H(IMG_H)
            ) u_base (
                .clk(clk),
                .rst(rst),
                .s_valid(s_valid),
                .s_ready(s_ready),
                .s_data(s_data),
                .s_user(s_user),
                .s_last(s_last),
                .m_valid(base_valid),
                .m_ready(base_ready),
                .m_rgb(base_rgb),
                .m_user(base_user),
                .m_last(base_last)
            );
        end else begin : g_parallel_base
            span_tinyspan_w8a8_bicubic_base_x4_streamed #(
                .DATA_W(DATA_W),
                .ACT_W(ACT_W),
                .IMG_W(IMG_W),
                .IMG_H(IMG_H)
            ) u_base (
                .clk(clk),
                .rst(rst),
                .s_valid(s_valid),
                .s_ready(s_ready),
                .s_data(s_data),
                .s_user(s_user),
                .s_last(s_last),
                .m_valid(base_valid),
                .m_ready(base_ready),
                .m_rgb(base_rgb),
                .m_user(base_user),
                .m_last(base_last)
            );
        end
    endgenerate

    span_tinyspan_w8a8_base_add_equiv #(
        .ACT_W(ACT_W)
    ) u_base_add_equiv (
        .learned_rgb_i({3*ACT_W{1'b0}}),
        .base_rgb_i(base_rgb),
        .q_rgb_o(m_rgb)
    );

    assign m_valid = base_valid;
    assign base_ready = m_ready;
    assign m_user = base_user;
    assign m_last = base_last;
endmodule
