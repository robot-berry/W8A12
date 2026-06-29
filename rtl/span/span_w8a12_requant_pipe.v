`timescale 1ns/1ps

// Pipelined W8A12 per-channel requantization primitive.
//
// This keeps the same arithmetic contract as span_w8a12_requant, but splits
// the multiply, bias add, rounding, shift, sign restore, and saturation across
// registers so vector schedulers can close at video-rate clocks.
module span_w8a12_requant_pipe #(
    parameter integer ACC_W = 48,
    parameter integer ACT_W = 12
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     s_valid,
    input  wire signed [ACC_W-1:0]  acc_i,
    input  wire signed [63:0]       bias_i64,
    input  wire signed [31:0]       requant_q31_i,
    input  wire [7:0]               requant_shift_i,
    output reg                      m_valid,
    output reg signed [ACT_W-1:0]   q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));

    wire signed [63:0] acc_ext = {{(64-ACC_W){acc_i[ACC_W-1]}}, acc_i};

    reg valid_s1;
    reg valid_s2;
    reg valid_s3;
    reg valid_s4;
    reg valid_s5;
    reg valid_s6;

    reg signed [95:0] product_mul_s1;
    reg signed [63:0] bias_s1;
    reg [7:0] shift_s1;

    reg signed [95:0] product_s2;
    reg [7:0] shift_s2;

    reg signed [95:0] rounded_abs_s3;
    reg [7:0] shift_s3;
    reg negative_s3;

    reg signed [95:0] shifted_abs_s4;
    reg negative_s4;

    reg signed [63:0] shifted_s64_s5;

    reg signed [95:0] round_offset;
    reg signed [95:0] shifted_signed_next;

    always @(*) begin
        if (shift_s2 == 8'd0)
            round_offset = 96'sd0;
        else
            round_offset = 96'sd1 <<< (shift_s2 - 8'd1);

        if (negative_s4)
            shifted_signed_next = -shifted_abs_s4;
        else
            shifted_signed_next = shifted_abs_s4;
    end

    always @(posedge clk) begin
        if (rst) begin
            valid_s1 <= 1'b0;
            valid_s2 <= 1'b0;
            valid_s3 <= 1'b0;
            valid_s4 <= 1'b0;
            valid_s5 <= 1'b0;
            valid_s6 <= 1'b0;
            product_mul_s1 <= 96'sd0;
            bias_s1 <= 64'sd0;
            shift_s1 <= 8'd31;
            product_s2 <= 96'sd0;
            shift_s2 <= 8'd31;
            rounded_abs_s3 <= 96'sd0;
            shift_s3 <= 8'd31;
            negative_s3 <= 1'b0;
            shifted_abs_s4 <= 96'sd0;
            negative_s4 <= 1'b0;
            shifted_s64_s5 <= 64'sd0;
            m_valid <= 1'b0;
            q_o <= {ACT_W{1'b0}};
        end else begin
            valid_s1 <= s_valid;
            valid_s2 <= valid_s1;
            valid_s3 <= valid_s2;
            valid_s4 <= valid_s3;
            valid_s5 <= valid_s4;
            valid_s6 <= valid_s5;
            m_valid <= valid_s6;

            product_mul_s1 <= acc_ext * requant_q31_i;
            bias_s1 <= bias_i64;
            shift_s1 <= requant_shift_i;

            product_s2 <= product_mul_s1 + {{32{bias_s1[63]}}, bias_s1};
            shift_s2 <= shift_s1;

            shift_s3 <= shift_s2;
            if (product_s2 >= 96'sd0) begin
                rounded_abs_s3 <= product_s2 + round_offset;
                negative_s3 <= 1'b0;
            end else begin
                rounded_abs_s3 <= (-product_s2) + round_offset;
                negative_s3 <= 1'b1;
            end

            shifted_abs_s4 <= rounded_abs_s3 >>> shift_s3;
            negative_s4 <= negative_s3;

            shifted_s64_s5 <= shifted_signed_next[63:0];

            if (valid_s5) begin
                if (shifted_s64_s5 > SAT_MAX)
                    q_o <= SAT_MAX[ACT_W-1:0];
                else if (shifted_s64_s5 < SAT_MIN)
                    q_o <= SAT_MIN[ACT_W-1:0];
                else
                    q_o <= shifted_s64_s5[ACT_W-1:0];
            end
        end
    end
endmodule
