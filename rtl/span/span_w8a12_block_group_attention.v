`timescale 1ns/1ps

// Runtime-selected W8A12 SPAB attention multiply across blocks.
module span_w8a12_block_group_attention #(
    parameter integer ACT_W = 12,
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
    parameter OUT3_REQUANT_Q31_FILE = "",
    parameter RESIDUAL_REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = ""
) (
    input  wire [BLOCK_W-1:0]          block_i,
    input  wire signed [ACT_W-1:0]     out3_i,
    input  wire signed [ACT_W-1:0]     residual_i,
    input  wire signed [ACT_W-1:0]     sim_att_i,
    output reg  signed [ACT_W-1:0]     q_o
);
    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));

    reg signed [31:0] out3_requant_mem [0:BLOCKS-1];
    reg signed [31:0] residual_requant_mem [0:BLOCKS-1];
    reg [7:0] shift_mem [0:BLOCKS-1];

    wire block_in_range = (block_i < BLOCKS);
    wire signed [31:0] out3_requant_q31 = block_in_range ? out3_requant_mem[block_i] : 32'sd0;
    wire signed [31:0] residual_requant_q31 = block_in_range ? residual_requant_mem[block_i] : 32'sd0;
    wire [7:0] shift = block_in_range ? shift_mem[block_i] : 8'd31;

    wire signed [(2*ACT_W)-1:0] out3_term = out3_i * sim_att_i;
    wire signed [(2*ACT_W)-1:0] residual_term = residual_i * sim_att_i;
    wire signed [95:0] out3_product = out3_term * out3_requant_q31;
    wire signed [95:0] residual_product = residual_term * residual_requant_q31;
    wire signed [96:0] product_sum = {out3_product[95], out3_product} +
                                     {residual_product[95], residual_product};

    reg signed [96:0] rounded_sum;
    reg signed [96:0] shifted_sum;
    reg signed [96:0] round_offset;
    reg signed [63:0] shifted_s64;

    integer i;
    initial begin
        for (i = 0; i < BLOCKS; i = i + 1) begin
            out3_requant_mem[i] = 32'sd0;
            residual_requant_mem[i] = 32'sd0;
            shift_mem[i] = 8'd31;
        end

        if (OUT3_REQUANT_Q31_FILE != "")
            $readmemh(OUT3_REQUANT_Q31_FILE, out3_requant_mem);
        if (RESIDUAL_REQUANT_Q31_FILE != "")
            $readmemh(RESIDUAL_REQUANT_Q31_FILE, residual_requant_mem);
        if (REQUANT_SHIFT_FILE != "")
            $readmemh(REQUANT_SHIFT_FILE, shift_mem);
    end

    always @(*) begin
        rounded_sum = 97'sd0;
        shifted_sum = 97'sd0;
        round_offset = 97'sd0;
        shifted_s64 = 64'sd0;

        if (shift == 0) begin
            shifted_sum = product_sum;
        end else begin
            round_offset = 97'sd1 <<< (shift - 1);
            if (product_sum >= 97'sd0) begin
                rounded_sum = product_sum + round_offset;
                shifted_sum = rounded_sum >>> shift;
            end else begin
                rounded_sum = (-product_sum) + round_offset;
                shifted_sum = -(rounded_sum >>> shift);
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
