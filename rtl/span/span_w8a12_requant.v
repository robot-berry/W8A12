`timescale 1ns/1ps

// W8A12 per-channel requantization primitive.
//
// The REDS-trained SPAN W8A12 plan stores:
//   bias_i64        = round((bias_fp32 / output_scale) * 2^31)
//   requant_q31     = round((input_scale * weight_scale[channel] / output_scale) * 2^31)
//   requant_shift   = 31
//
// This block computes:
//   q = saturate_s12(round((acc_i * requant_q31 + bias_i64) / 2^requant_shift))
module span_w8a12_requant #(
    parameter integer ACC_W = 48,
    parameter integer ACT_W = 12,
    parameter integer BIAS_BEFORE_REQUANT = 0
) (
    input  wire signed [ACC_W-1:0] acc_i,
    input  wire signed [63:0]      bias_i64,
    input  wire signed [31:0]      requant_q31_i,
    input  wire [7:0]              requant_shift_i,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));

    wire signed [63:0] acc_ext = {{(64-ACC_W){acc_i[ACC_W-1]}}, acc_i};
    wire signed [63:0] acc_plus_bias = acc_ext + bias_i64;
    wire signed [63:0] mul_input = (BIAS_BEFORE_REQUANT != 0) ? acc_plus_bias : acc_ext;
    wire signed [95:0] product_mul = mul_input * requant_q31_i;
    wire signed [95:0] bias_ext = {{32{bias_i64[63]}}, bias_i64};
    wire signed [95:0] product = (BIAS_BEFORE_REQUANT != 0) ? product_mul : (product_mul + bias_ext);

    reg signed [95:0] rounded_product;
    reg signed [95:0] shifted_product;
    reg signed [63:0] shifted_s64;
    reg signed [95:0] round_offset;

    always @(*) begin
        if (requant_shift_i == 8'd0) begin
            shifted_product = product;
        end else begin
            round_offset = 96'sd1 <<< (requant_shift_i - 8'd1);
            if (product >= 96'sd0) begin
                rounded_product = product + round_offset;
                shifted_product = rounded_product >>> requant_shift_i;
            end else begin
                rounded_product = (-product) + round_offset;
                shifted_product = -(rounded_product >>> requant_shift_i);
            end
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
