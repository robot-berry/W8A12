`timescale 1ns/1ps

// Convert a raw RGB888 3x3 window into the signed 12-bit centered domain
// expected by W8A12 conv_1.
module span_w8a12_rgb_window_normalize #(
    parameter integer ACT_W = 12
) (
    input  wire [3*9*8-1:0]          rgb_window_i,
    input  wire [8:0]                valid_mask_i,
    output wire [3*9*ACT_W-1:0]      norm_window_o
);
    genvar tap;
    generate
        for (tap = 0; tap < 9; tap = tap + 1) begin : g_tap_norm
            wire [23:0] rgb_pix;
            wire signed [ACT_W-1:0] r_norm;
            wire signed [ACT_W-1:0] g_norm;
            wire signed [ACT_W-1:0] b_norm;

            assign rgb_pix = {
                rgb_window_i[(0*9 + tap)*8 +: 8],
                rgb_window_i[(1*9 + tap)*8 +: 8],
                rgb_window_i[(2*9 + tap)*8 +: 8]
            };

            span_w8a12_rgb_normalize #(
                .ACT_W(ACT_W)
            ) u_rgb_norm (
                .rgb_i(rgb_pix),
                .r_o(r_norm),
                .g_o(g_norm),
                .b_o(b_norm)
            );

            assign norm_window_o[(0*9 + tap)*ACT_W +: ACT_W] = valid_mask_i[tap] ? r_norm : {ACT_W{1'b0}};
            assign norm_window_o[(1*9 + tap)*ACT_W +: ACT_W] = valid_mask_i[tap] ? g_norm : {ACT_W{1'b0}};
            assign norm_window_o[(2*9 + tap)*ACT_W +: ACT_W] = valid_mask_i[tap] ? b_norm : {ACT_W{1'b0}};
        end
    endgenerate
endmodule
