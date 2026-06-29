`timescale 1ns/1ps

// Generic signed W8A8 scale-and-add:
//   q = saturate(round((a_q * A_Q31 + b_q * B_Q31) / 2^SHIFT))
module span_w8a8_scale_add #(
    parameter integer ACT_W = 8,
    parameter integer SHIFT = 31,
    parameter signed [63:0] A_Q31 = 64'sd0,
    parameter signed [63:0] B_Q31 = 64'sd0
) (
    input  wire signed [ACT_W-1:0] a_i,
    input  wire signed [ACT_W-1:0] b_i,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));

    wire signed [63:0] a_ext = {{(64-ACT_W){a_i[ACT_W-1]}}, a_i};
    wire signed [63:0] b_ext = {{(64-ACT_W){b_i[ACT_W-1]}}, b_i};
    wire signed [95:0] a_product = a_ext * A_Q31;
    wire signed [95:0] b_product = b_ext * B_Q31;
    wire signed [96:0] product_sum = {a_product[95], a_product} + {b_product[95], b_product};

    reg signed [96:0] rounded_sum;
    reg signed [96:0] shifted_sum;
    reg signed [96:0] round_offset;
    reg signed [63:0] shifted_s64;

    always @(*) begin
        if (SHIFT == 0) begin
            shifted_sum = product_sum;
        end else begin
            round_offset = 97'sd1 <<< (SHIFT - 1);
            if (product_sum >= 97'sd0)
                rounded_sum = product_sum + round_offset;
            else
                rounded_sum = product_sum - round_offset;
            shifted_sum = rounded_sum >>> SHIFT;
        end

        shifted_s64 = shifted_sum[63:0];
        if (shifted_s64 > SAT_MAX)
            q_o = SAT_MAX[ACT_W-1:0];
        else if (shifted_s64 < SAT_MIN)
            q_o = SAT_MIN[ACT_W-1:0];
        else
            q_o = shifted_s64[ACT_W-1:0];
    end
endmodule
