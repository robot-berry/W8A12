`timescale 1ns/1ps

// W8A12 SPAB attention multiply:
//   q_out = saturate_s12(round((out3_q * out3_scale + residual_q * residual_scale)
//                             * (sim_att_q * sim_att_scale) / output_scale))
//
// The two real multipliers are exported as Q31:
//   out3_requant_q31     = round(out3_scale * sim_att_scale / output_scale * 2^31)
//   residual_requant_q31 = round(residual_scale * sim_att_scale / output_scale * 2^31)
//
// Rounding is applied once after the two terms are summed.
module span_w8a12_attention #(
    parameter integer ACT_W = 12,
    parameter integer SHIFT = 31,
    parameter signed [31:0] OUT3_REQUANT_Q31 = 32'sd0,
    parameter signed [31:0] RESIDUAL_REQUANT_Q31 = 32'sd0
) (
    input  wire signed [ACT_W-1:0] out3_i,
    input  wire signed [ACT_W-1:0] residual_i,
    input  wire signed [ACT_W-1:0] sim_att_i,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));

    wire signed [(2*ACT_W)-1:0] out3_term = out3_i * sim_att_i;
    wire signed [(2*ACT_W)-1:0] residual_term = residual_i * sim_att_i;
    wire signed [95:0] out3_product = out3_term * OUT3_REQUANT_Q31;
    wire signed [95:0] residual_product = residual_term * RESIDUAL_REQUANT_Q31;
    wire signed [96:0] product_sum = {out3_product[95], out3_product} + {residual_product[95], residual_product};

    reg signed [96:0] rounded_sum;
    reg signed [96:0] shifted_sum;
    reg signed [96:0] round_offset;
    reg signed [63:0] shifted_s64;

    always @(*) begin
        if (SHIFT == 0) begin
            shifted_sum = product_sum;
        end else begin
            round_offset = 97'sd1 <<< (SHIFT - 1);
            if (product_sum >= 97'sd0) begin
                rounded_sum = product_sum + round_offset;
                shifted_sum = rounded_sum >>> SHIFT;
            end else begin
                rounded_sum = (-product_sum) + round_offset;
                shifted_sum = -(rounded_sum >>> SHIFT);
            end
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
