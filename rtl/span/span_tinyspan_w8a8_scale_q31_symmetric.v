`timescale 1ns/1ps

// Single-input W8A8 requantization with symmetric round-to-nearest.
//
// For the TinySPAN concat/base bridges this matches:
//   round(q * input_scale / output_scale)
// for the exported W8A8 scale ratios over the full int8 input range.
module span_tinyspan_w8a8_scale_q31_symmetric #(
    parameter integer ACT_W = 8,
    parameter integer SHIFT = 31,
    parameter signed [32:0] MUL_Q31 = 33'sd0
) (
    input  wire signed [ACT_W-1:0] q_i,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));

    (* use_dsp = "no" *) wire signed [40:0] product = q_i * MUL_Q31;

    reg signed [40:0] abs_product;
    reg signed [40:0] rounded_abs;
    reg signed [40:0] shifted_abs;
    reg signed [40:0] shifted_signed;
    reg signed [63:0] shifted_s64;

    always @(*) begin
        if (SHIFT == 0) begin
            shifted_signed = product;
        end else begin
            abs_product = (product < 41'sd0) ? -product : product;
            rounded_abs = abs_product + (41'sd1 <<< (SHIFT - 1));
            shifted_abs = rounded_abs >>> SHIFT;
            shifted_signed = (product < 41'sd0) ? -shifted_abs : shifted_abs;
        end

        shifted_s64 = {{23{shifted_signed[40]}}, shifted_signed};
        if (shifted_s64 > SAT_MAX)
            q_o = SAT_MAX[ACT_W-1:0];
        else if (shifted_s64 < SAT_MIN)
            q_o = SAT_MIN[ACT_W-1:0];
        else
            q_o = shifted_s64[ACT_W-1:0];
    end
endmodule

