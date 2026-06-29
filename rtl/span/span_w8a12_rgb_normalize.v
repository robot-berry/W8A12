`timescale 1ns/1ps
`include "span_w8a12_generated_select.vh"

// RGB888 to W8A12 centered-input quantization for REDS-trained SPAN.
//
// PyTorch input path:
//   centered = (rgb / 255 - mean) * 255 = rgb - mean * 255
//
// Hardware path:
//   q_s12 = saturate_s12(round(centered / conv_1.input_scale))
module span_w8a12_rgb_normalize #(
    parameter integer ACT_W = 12,
    parameter integer FRAC_BITS = `REDS_SPAN_W8A12_RGB_NORM_FRAC_BITS,
    parameter integer GAIN_Q = `REDS_SPAN_W8A12_RGB_NORM_GAIN_Q,
    parameter integer BIAS_R_Q = `REDS_SPAN_W8A12_RGB_NORM_BIAS_R_Q,
    parameter integer BIAS_G_Q = `REDS_SPAN_W8A12_RGB_NORM_BIAS_G_Q,
    parameter integer BIAS_B_Q = `REDS_SPAN_W8A12_RGB_NORM_BIAS_B_Q
) (
    input  wire [23:0]                    rgb_i,
    output wire signed [ACT_W-1:0]        r_o,
    output wire signed [ACT_W-1:0]        g_o,
    output wire signed [ACT_W-1:0]        b_o
);
    function automatic signed [ACT_W-1:0] normalize_channel;
        input [7:0] value_u8;
        input signed [31:0] bias_q;
        reg signed [47:0] acc;
        reg signed [47:0] rounded;
        reg signed [47:0] shifted;
        reg signed [47:0] round_offset;
        reg signed [47:0] sat_max;
        reg signed [47:0] sat_min;
        begin
            acc = $signed({1'b0, value_u8}) * $signed(GAIN_Q) + bias_q;
            round_offset = 48'sd1 <<< (FRAC_BITS - 1);
            sat_max = (48'sd1 <<< (ACT_W - 1)) - 48'sd1;
            sat_min = -(48'sd1 <<< (ACT_W - 1));
            if (acc >= 48'sd0) begin
                rounded = acc + round_offset;
                shifted = rounded >>> FRAC_BITS;
            end else begin
                rounded = (-acc) + round_offset;
                shifted = -(rounded >>> FRAC_BITS);
            end
            if (shifted > sat_max)
                normalize_channel = sat_max[ACT_W-1:0];
            else if (shifted < sat_min)
                normalize_channel = sat_min[ACT_W-1:0];
            else
                normalize_channel = shifted[ACT_W-1:0];
        end
    endfunction

    assign r_o = normalize_channel(rgb_i[23:16], BIAS_R_Q);
    assign g_o = normalize_channel(rgb_i[15:8], BIAS_G_Q);
    assign b_o = normalize_channel(rgb_i[7:0], BIAS_B_Q);
endmodule
