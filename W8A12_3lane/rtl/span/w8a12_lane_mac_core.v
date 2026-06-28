`timescale 1ns/1ps

// Synthesis-friendly time-multiplexed MAC slice for one output channel.
//
// This block intentionally covers only the inner product accumulation:
//   acc_o = acc_i + sum(act_i[k] * weight_i[k]), k = 0..TAP_PAR-1
//
// Bias and W8A12 requantization stay in the downstream requant stage. Keeping
// this primitive small gives A4 a fast OOC resource baseline before rebuilding
// the full lane scheduler around ROM-backed constants.
module w8a12_lane_mac_core #(
    parameter integer TAP_PAR = 8,
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48
) (
    input  wire clk,
    input  wire rst,
    input  wire s_valid,
    output wire s_ready,
    input  wire signed [ACC_W-1:0] acc_i,
    input  wire [TAP_PAR*ACT_W-1:0] act_i,
    input  wire [TAP_PAR*WEIGHT_W-1:0] weight_i,
    output reg  m_valid,
    input  wire m_ready,
    output reg  signed [ACC_W-1:0] acc_o
);
    localparam integer PRODUCT_W = ACT_W + WEIGHT_W;

    integer i;
    reg signed [ACC_W-1:0] sum_comb;

    assign s_ready = !m_valid || m_ready;

    function automatic signed [ACC_W-1:0] calc_sum;
        input signed [ACC_W-1:0] acc_base;
        input [TAP_PAR*ACT_W-1:0] acts;
        input [TAP_PAR*WEIGHT_W-1:0] weights;
        integer tap;
        reg signed [ACT_W-1:0] act_word;
        reg signed [WEIGHT_W-1:0] weight_word;
        reg signed [PRODUCT_W-1:0] product_word;
        reg signed [ACC_W-1:0] product_ext;
        begin
            calc_sum = acc_base;
            for (tap = 0; tap < TAP_PAR; tap = tap + 1) begin
                act_word = acts[tap*ACT_W +: ACT_W];
                weight_word = weights[tap*WEIGHT_W +: WEIGHT_W];
                product_word = act_word * weight_word;
                product_ext = {{(ACC_W-PRODUCT_W){product_word[PRODUCT_W-1]}}, product_word};
                calc_sum = calc_sum + product_ext;
            end
        end
    endfunction

    always @(*) begin
        sum_comb = calc_sum(acc_i, act_i, weight_i);
    end

    always @(posedge clk) begin
        if (rst) begin
            m_valid <= 1'b0;
            acc_o <= {ACC_W{1'b0}};
        end else begin
            if (s_valid && s_ready) begin
                acc_o <= sum_comb;
                m_valid <= 1'b1;
            end else if (m_valid && m_ready) begin
                m_valid <= 1'b0;
            end
        end
    end
endmodule
