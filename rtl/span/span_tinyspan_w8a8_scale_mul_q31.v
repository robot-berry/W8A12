`timescale 1ns/1ps

// TinySPAN W8A8 scale-and-multiply with a narrow Q31 constant.
module span_tinyspan_w8a8_scale_mul_q31 #(
    parameter integer ACT_W = 8,
    parameter integer SHIFT = 31,
    parameter signed [32:0] MUL_Q31 = 33'sd0
) (
    input  wire signed [ACT_W-1:0] a_i,
    input  wire signed [ACT_W-1:0] b_i,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));
    localparam integer AB_W = 2 * ACT_W;

    wire signed [AB_W-1:0] ab_product = a_i * b_i;
    (* use_dsp = "no" *) wire signed [48:0] product = ab_product * MUL_Q31;

    reg signed [48:0] rounded_product;
    reg signed [48:0] shifted_product;
    reg signed [48:0] round_offset;
    reg signed [63:0] shifted_s64;

    always @(*) begin
        if (SHIFT == 0) begin
            shifted_product = product;
        end else begin
            round_offset = 49'sd1 <<< (SHIFT - 1);
            if (product >= 49'sd0)
                rounded_product = product + round_offset;
            else
                rounded_product = product - round_offset;
            shifted_product = rounded_product >>> SHIFT;
        end

        shifted_s64 = {{15{shifted_product[48]}}, shifted_product};
        if (shifted_s64 > SAT_MAX)
            q_o = SAT_MAX[ACT_W-1:0];
        else if (shifted_s64 < SAT_MIN)
            q_o = SAT_MIN[ACT_W-1:0];
        else
            q_o = shifted_s64[ACT_W-1:0];
    end
endmodule
