`timescale 1ns/1ps

// TinySPAN W8A8 scale-and-add with narrow Q31 constants.
module span_tinyspan_w8a8_scale_add_q31 #(
    parameter integer ACT_W = 8,
    parameter integer SHIFT = 31,
    parameter signed [32:0] A_Q31 = 33'sd0,
    parameter signed [32:0] B_Q31 = 33'sd0
) (
    input  wire signed [ACT_W-1:0] a_i,
    input  wire signed [ACT_W-1:0] b_i,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));

    (* use_dsp = "no" *) wire signed [40:0] a_product = a_i * A_Q31;
    (* use_dsp = "no" *) wire signed [40:0] b_product = b_i * B_Q31;
    wire signed [41:0] product_sum = {a_product[40], a_product} + {b_product[40], b_product};

    reg signed [41:0] rounded_sum;
    reg signed [41:0] shifted_sum;
    reg signed [41:0] round_offset;
    reg signed [63:0] shifted_s64;

    always @(*) begin
        if (SHIFT == 0) begin
            shifted_sum = product_sum;
        end else begin
            round_offset = 42'sd1 <<< (SHIFT - 1);
            if (product_sum >= 42'sd0)
                rounded_sum = product_sum + round_offset;
            else
                rounded_sum = product_sum - round_offset;
            shifted_sum = rounded_sum >>> SHIFT;
        end

        shifted_s64 = {{22{shifted_sum[41]}}, shifted_sum};
        if (shifted_s64 > SAT_MAX)
            q_o = SAT_MAX[ACT_W-1:0];
        else if (shifted_s64 < SAT_MIN)
            q_o = SAT_MIN[ACT_W-1:0];
        else
            q_o = shifted_s64[ACT_W-1:0];
    end
endmodule
