`timescale 1ns/1ps

// Generic signed W8A8 scale-and-multiply:
//   q = saturate(round((a_q * b_q * MUL_Q31) / 2^SHIFT))
module span_w8a8_scale_mul #(
    parameter integer ACT_W = 8,
    parameter integer SHIFT = 31,
    parameter signed [63:0] MUL_Q31 = 64'sd0
) (
    input  wire signed [ACT_W-1:0] a_i,
    input  wire signed [ACT_W-1:0] b_i,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));
    localparam integer AB_W = 2 * ACT_W;

    wire signed [AB_W-1:0] ab_product = a_i * b_i;
    wire signed [63:0] ab_ext = {{(64-AB_W){ab_product[AB_W-1]}}, ab_product};
    wire signed [95:0] product = ab_ext * MUL_Q31;

    reg signed [95:0] rounded_product;
    reg signed [95:0] shifted_product;
    reg signed [95:0] round_offset;
    reg signed [63:0] shifted_s64;

    always @(*) begin
        if (SHIFT == 0) begin
            shifted_product = product;
        end else begin
            round_offset = 96'sd1 <<< (SHIFT - 1);
            if (product >= 96'sd0)
                rounded_product = product + round_offset;
            else
                rounded_product = product - round_offset;
            shifted_product = rounded_product >>> SHIFT;
        end

        shifted_s64 = shifted_product[63:0];
        if (shifted_s64 > SAT_MAX)
            q_o = SAT_MAX[ACT_W-1:0];
        else if (shifted_s64 < SAT_MIN)
            q_o = SAT_MIN[ACT_W-1:0];
        else
            q_o = shifted_s64[ACT_W-1:0];
    end
endmodule
