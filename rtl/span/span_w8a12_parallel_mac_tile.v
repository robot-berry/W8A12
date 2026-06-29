`timescale 1ns/1ps

// Parallel MAC tile for the REDS-trained W8A12 video engine.
//
// This is the arithmetic building block for the future frame engine selected
// by the 2-D sizing report. It computes OUT_LANES independent output-channel
// partial sums across TAP_LANES input taps in one issued step:
//
//   acc_o[out] = acc_i[out] + sum_t act_i[t] * weight_i[out,t]
//
// Weight banking and layer scheduling stay outside this tile so the same
// arithmetic block can be reused for conv_1, SPAB convs, conv_cat, and tail.
module span_w8a12_parallel_mac_tile #(
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer PIPELINE = 2
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire signed [TAP_LANES*ACT_W-1:0]     act_i,
    input  wire signed [OUT_LANES*ACC_W-1:0]     acc_i,
    input  wire signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] weight_i,

    output wire                                  m_valid,
    input  wire                                  m_ready,
    output wire signed [OUT_LANES*ACC_W-1:0]     acc_o
);
    localparam integer PRODUCT_W = ACT_W + WEIGHT_W;
    localparam integer LO_TAPS = (TAP_LANES + 1) / 2;
    localparam integer Q0_END = (TAP_LANES + 3) / 4;
    localparam integer Q1_END = (TAP_LANES + 1) / 2;
    localparam integer Q2_END = (3 * TAP_LANES + 3) / 4;

    wire signed [OUT_LANES*ACC_W-1:0] acc_comb;
    wire signed [OUT_LANES*ACC_W-1:0] partial_lo_comb;
    wire signed [OUT_LANES*ACC_W-1:0] partial_hi_comb;
    wire signed [OUT_LANES*ACC_W-1:0] partial_q0_comb;
    wire signed [OUT_LANES*ACC_W-1:0] partial_q1_comb;
    wire signed [OUT_LANES*ACC_W-1:0] partial_q2_comb;
    wire signed [OUT_LANES*ACC_W-1:0] partial_q3_comb;
    reg                               valid_q;
    reg signed [OUT_LANES*ACC_W-1:0]  acc_q;

    genvar out_idx;
    genvar pipe_lane_idx;
    generate
        for (out_idx = 0; out_idx < OUT_LANES; out_idx = out_idx + 1) begin : g_out
            integer tap_idx;
            reg signed [ACC_W-1:0] sum_r;
            reg signed [ACC_W-1:0] partial_lo_r;
            reg signed [ACC_W-1:0] partial_hi_r;
            reg signed [ACC_W-1:0] partial_q0_r;
            reg signed [ACC_W-1:0] partial_q1_r;
            reg signed [ACC_W-1:0] partial_q2_r;
            reg signed [ACC_W-1:0] partial_q3_r;
            reg signed [ACT_W-1:0] act_r;
            reg signed [WEIGHT_W-1:0] weight_r;
            reg signed [PRODUCT_W-1:0] product_r;

            always @(*) begin
                sum_r = acc_i[out_idx*ACC_W +: ACC_W];
                partial_lo_r = {ACC_W{1'b0}};
                partial_hi_r = {ACC_W{1'b0}};
                partial_q0_r = {ACC_W{1'b0}};
                partial_q1_r = {ACC_W{1'b0}};
                partial_q2_r = {ACC_W{1'b0}};
                partial_q3_r = {ACC_W{1'b0}};
                for (tap_idx = 0; tap_idx < TAP_LANES; tap_idx = tap_idx + 1) begin
                    act_r = act_i[tap_idx*ACT_W +: ACT_W];
                    weight_r = weight_i[(out_idx*TAP_LANES + tap_idx)*WEIGHT_W +: WEIGHT_W];
                    product_r = act_r * weight_r;
                    sum_r = sum_r + {{(ACC_W-PRODUCT_W){product_r[PRODUCT_W-1]}}, product_r};
                    if (tap_idx < LO_TAPS)
                        partial_lo_r = partial_lo_r + {{(ACC_W-PRODUCT_W){product_r[PRODUCT_W-1]}}, product_r};
                    else
                        partial_hi_r = partial_hi_r + {{(ACC_W-PRODUCT_W){product_r[PRODUCT_W-1]}}, product_r};
                    if (tap_idx < Q0_END)
                        partial_q0_r = partial_q0_r + {{(ACC_W-PRODUCT_W){product_r[PRODUCT_W-1]}}, product_r};
                    else if (tap_idx < Q1_END)
                        partial_q1_r = partial_q1_r + {{(ACC_W-PRODUCT_W){product_r[PRODUCT_W-1]}}, product_r};
                    else if (tap_idx < Q2_END)
                        partial_q2_r = partial_q2_r + {{(ACC_W-PRODUCT_W){product_r[PRODUCT_W-1]}}, product_r};
                    else
                        partial_q3_r = partial_q3_r + {{(ACC_W-PRODUCT_W){product_r[PRODUCT_W-1]}}, product_r};
                end
            end

            assign acc_comb[out_idx*ACC_W +: ACC_W] = sum_r;
            assign partial_lo_comb[out_idx*ACC_W +: ACC_W] = partial_lo_r;
            assign partial_hi_comb[out_idx*ACC_W +: ACC_W] = partial_hi_r;
            assign partial_q0_comb[out_idx*ACC_W +: ACC_W] = partial_q0_r;
            assign partial_q1_comb[out_idx*ACC_W +: ACC_W] = partial_q1_r;
            assign partial_q2_comb[out_idx*ACC_W +: ACC_W] = partial_q2_r;
            assign partial_q3_comb[out_idx*ACC_W +: ACC_W] = partial_q3_r;
        end
    endgenerate

    generate
        if (PIPELINE > 2) begin : g_pipeline3
            reg                               valid_s1_q;
            reg                               valid_s2_q;
            reg                               valid_s3_q;
            reg signed [OUT_LANES*ACC_W-1:0]  acc_i_s1_q;
            reg signed [OUT_LANES*ACC_W-1:0]  acc_i_s2_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_q0_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_q1_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_q2_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_q3_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_lo_s2_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_hi_s2_q;
            reg signed [OUT_LANES*ACC_W-1:0]  acc_s3_q;
            wire signed [OUT_LANES*ACC_W-1:0] partial_lo_s2_next;
            wire signed [OUT_LANES*ACC_W-1:0] partial_hi_s2_next;
            wire signed [OUT_LANES*ACC_W-1:0] acc_s3_next;
            wire                              stage3_ready;
            wire                              stage2_ready;
            wire                              stage1_ready;

            for (pipe_lane_idx = 0; pipe_lane_idx < OUT_LANES; pipe_lane_idx = pipe_lane_idx + 1) begin : g_pipe_lane
                assign partial_lo_s2_next[pipe_lane_idx*ACC_W +: ACC_W] =
                    partial_q0_q[pipe_lane_idx*ACC_W +: ACC_W] +
                    partial_q1_q[pipe_lane_idx*ACC_W +: ACC_W];
                assign partial_hi_s2_next[pipe_lane_idx*ACC_W +: ACC_W] =
                    partial_q2_q[pipe_lane_idx*ACC_W +: ACC_W] +
                    partial_q3_q[pipe_lane_idx*ACC_W +: ACC_W];
                assign acc_s3_next[pipe_lane_idx*ACC_W +: ACC_W] =
                    acc_i_s2_q[pipe_lane_idx*ACC_W +: ACC_W] +
                    partial_lo_s2_q[pipe_lane_idx*ACC_W +: ACC_W] +
                    partial_hi_s2_q[pipe_lane_idx*ACC_W +: ACC_W];
            end

            assign stage3_ready = !valid_s3_q || m_ready;
            assign stage2_ready = !valid_s2_q || stage3_ready;
            assign stage1_ready = !valid_s1_q || stage2_ready;
            assign s_ready = stage1_ready;
            assign m_valid = valid_s3_q;
            assign acc_o = acc_s3_q;

            always @(posedge clk) begin
                if (rst) begin
                    valid_s1_q <= 1'b0;
                    valid_s2_q <= 1'b0;
                    valid_s3_q <= 1'b0;
                    acc_i_s1_q <= {OUT_LANES*ACC_W{1'b0}};
                    acc_i_s2_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_q0_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_q1_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_q2_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_q3_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_lo_s2_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_hi_s2_q <= {OUT_LANES*ACC_W{1'b0}};
                    acc_s3_q <= {OUT_LANES*ACC_W{1'b0}};
                end else begin
                    if (stage3_ready) begin
                        valid_s3_q <= valid_s2_q;
                        if (valid_s2_q)
                            acc_s3_q <= acc_s3_next;
                    end

                    if (stage2_ready) begin
                        valid_s2_q <= valid_s1_q;
                        if (valid_s1_q) begin
                            acc_i_s2_q <= acc_i_s1_q;
                            partial_lo_s2_q <= partial_lo_s2_next;
                            partial_hi_s2_q <= partial_hi_s2_next;
                        end
                    end

                    if (stage1_ready) begin
                        valid_s1_q <= s_valid;
                        if (s_valid) begin
                            acc_i_s1_q <= acc_i;
                            partial_q0_q <= partial_q0_comb;
                            partial_q1_q <= partial_q1_comb;
                            partial_q2_q <= partial_q2_comb;
                            partial_q3_q <= partial_q3_comb;
                        end
                    end
                end
            end
        end else if (PIPELINE > 1) begin : g_pipeline2
            reg                               valid_s1_q;
            reg                               valid_s2_q;
            reg signed [OUT_LANES*ACC_W-1:0]  acc_i_s1_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_lo_q;
            reg signed [OUT_LANES*ACC_W-1:0]  partial_hi_q;
            reg signed [OUT_LANES*ACC_W-1:0]  acc_s2_q;
            wire signed [OUT_LANES*ACC_W-1:0] acc_s2_next;
            wire                              stage2_ready;
            wire                              stage1_ready;

            for (pipe_lane_idx = 0; pipe_lane_idx < OUT_LANES; pipe_lane_idx = pipe_lane_idx + 1) begin : g_pipe_lane
                assign acc_s2_next[pipe_lane_idx*ACC_W +: ACC_W] =
                    acc_i_s1_q[pipe_lane_idx*ACC_W +: ACC_W] +
                    partial_lo_q[pipe_lane_idx*ACC_W +: ACC_W] +
                    partial_hi_q[pipe_lane_idx*ACC_W +: ACC_W];
            end

            assign stage2_ready = !valid_s2_q || m_ready;
            assign stage1_ready = !valid_s1_q || stage2_ready;
            assign s_ready = stage1_ready;
            assign m_valid = valid_s2_q;
            assign acc_o = acc_s2_q;

            always @(posedge clk) begin
                if (rst) begin
                    valid_s1_q <= 1'b0;
                    valid_s2_q <= 1'b0;
                    acc_i_s1_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_lo_q <= {OUT_LANES*ACC_W{1'b0}};
                    partial_hi_q <= {OUT_LANES*ACC_W{1'b0}};
                    acc_s2_q <= {OUT_LANES*ACC_W{1'b0}};
                end else begin
                    if (stage2_ready) begin
                        valid_s2_q <= valid_s1_q;
                        if (valid_s1_q)
                            acc_s2_q <= acc_s2_next;
                    end

                    if (stage1_ready) begin
                        valid_s1_q <= s_valid;
                        if (s_valid) begin
                            acc_i_s1_q <= acc_i;
                            partial_lo_q <= partial_lo_comb;
                            partial_hi_q <= partial_hi_comb;
                        end
                    end
                end
            end
        end else if (PIPELINE != 0) begin : g_pipeline
            assign s_ready = !valid_q || m_ready;
            assign m_valid = valid_q;
            assign acc_o = acc_q;

            always @(posedge clk) begin
                if (rst) begin
                    valid_q <= 1'b0;
                    acc_q <= {OUT_LANES*ACC_W{1'b0}};
                end else if (s_ready) begin
                    valid_q <= s_valid;
                    if (s_valid)
                        acc_q <= acc_comb;
                end
            end
        end else begin : g_comb
            assign s_ready = m_ready;
            assign m_valid = s_valid;
            assign acc_o = acc_comb;
        end
    endgenerate
endmodule
