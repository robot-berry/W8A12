`timescale 1ns/1ps

// Quantize an RGB888 3x3 window into TinySPAN W8A8 activation space.
//
// The frozen C32B4 plan uses input scale close to 1/127 for RGB tensors in
// [0, 1], so q = round((rgb / 255) / input_scale).  The default multiplier is
// round((127 / 255) * 2^16).
module span_tinyspan_w8a8_rgb_window_quantize #(
    parameter integer ACT_W = 8,
    parameter integer Q_MULT = 32639,
    parameter integer Q_SHIFT = 16
) (
    input  wire [3*9*8-1:0]       rgb_window_i,
    input  wire [8:0]             valid_mask_i,
    output wire [3*9*ACT_W-1:0]   q_window_o
);
    function automatic signed [ACT_W-1:0] quant_u8;
        input [7:0] value;
        reg [31:0] product;
        reg [31:0] rounded;
        reg [31:0] shifted;
        begin
            product = value * Q_MULT;
            rounded = product + (32'd1 << (Q_SHIFT - 1));
            shifted = rounded >> Q_SHIFT;
            if (shifted > 127)
                quant_u8 = 8'sd127;
            else
                quant_u8 = shifted[ACT_W-1:0];
        end
    endfunction

    genvar tap;
    generate
        for (tap = 0; tap < 9; tap = tap + 1) begin : g_tap_quant
            assign q_window_o[(0*9 + tap)*ACT_W +: ACT_W] =
                valid_mask_i[tap] ? quant_u8(rgb_window_i[(0*9 + tap)*8 +: 8]) : {ACT_W{1'b0}};
            assign q_window_o[(1*9 + tap)*ACT_W +: ACT_W] =
                valid_mask_i[tap] ? quant_u8(rgb_window_i[(1*9 + tap)*8 +: 8]) : {ACT_W{1'b0}};
            assign q_window_o[(2*9 + tap)*ACT_W +: ACT_W] =
                valid_mask_i[tap] ? quant_u8(rgb_window_i[(2*9 + tap)*8 +: 8]) : {ACT_W{1'b0}};
        end
    endgenerate
endmodule
