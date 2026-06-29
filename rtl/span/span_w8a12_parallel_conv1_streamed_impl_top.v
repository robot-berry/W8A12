`timescale 1ns/1ps
`include "reds_span_x4_f48_w8a12/span_w8a12_layers.vh"

module span_w8a12_parallel_conv1_streamed_impl_top #(
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter WEIGHT_GROUP_FILE = "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/conv_1_w_i8_group_ol8_tl16.mem"
) (
    input  wire          clk,
    input  wire          rst,
    output wire [31:0]   status_o
);
    localparam integer IN_CH = 3;
    localparam integer OUT_CH = 48;
    localparam integer KERNEL_TAPS = 9;
    localparam integer ACT_W = 12;
    localparam integer WEIGHT_W = 8;
    localparam integer TAP_COUNT = IN_CH * KERNEL_TAPS;

    reg s_valid;
    wire s_ready;
    reg signed [TAP_COUNT*ACT_W-1:0] window_q;
    wire weight_req_valid;
    wire weight_req_ready;
    wire [31:0] weight_req_out_group;
    wire [31:0] weight_req_tap_group;
    wire signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] weight_group;
    wire m_valid;
    wire signed [OUT_CH*ACT_W-1:0] feat_o;

    reg [31:0] frame_count_q;
    reg [31:0] checksum_q;
    reg [31:0] feature_fold;
    reg [7:0] seed_q;

    integer init_idx;
    integer fold_idx;

    span_w8a12_weight_group_rom #(
        .OUT_CH(OUT_CH),
        .TAP_COUNT(TAP_COUNT),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_W(WEIGHT_W),
        .MEM_FILE(WEIGHT_GROUP_FILE)
    ) u_weight_groups (
        .clk(clk),
        .rst(rst),
        .req_valid(weight_req_valid),
        .req_ready(weight_req_ready),
        .req_out_group(weight_req_out_group),
        .req_tap_group(weight_req_tap_group),
        .weight_group_o(weight_group)
    );

    span_w8a12_parallel_conv_vector_streamed_weights #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(48),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_0_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_SHIFT_FILE)
    ) u_layer (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .window_i(window_q),
        .weight_req_valid(weight_req_valid),
        .weight_req_ready(weight_req_ready),
        .weight_req_out_group(weight_req_out_group),
        .weight_req_tap_group(weight_req_tap_group),
        .weight_group_i(weight_group),
        .m_valid(m_valid),
        .m_ready(1'b1),
        .feat_o(feat_o)
    );

    assign status_o = checksum_q ^ frame_count_q ^ {24'd0, seed_q};

    always @(*) begin
        feature_fold = 32'd0;
        for (fold_idx = 0; fold_idx < OUT_CH; fold_idx = fold_idx + 1)
            feature_fold = feature_fold ^ {{20{feat_o[fold_idx*ACT_W + ACT_W - 1]}}, feat_o[fold_idx*ACT_W +: ACT_W]} ^ fold_idx;
    end

    always @(posedge clk) begin
        if (rst) begin
            s_valid <= 1'b0;
            frame_count_q <= 32'd0;
            checksum_q <= 32'd0;
            seed_q <= 8'd1;
            for (init_idx = 0; init_idx < TAP_COUNT; init_idx = init_idx + 1)
                window_q[init_idx*ACT_W +: ACT_W] <= (init_idx * 12'sd37) - 12'sd512;
        end else begin
            s_valid <= 1'b0;
            if (s_ready)
                s_valid <= 1'b1;

            if (m_valid) begin
                frame_count_q <= frame_count_q + 1'b1;
                seed_q <= seed_q + 8'd17;
                for (init_idx = 0; init_idx < TAP_COUNT; init_idx = init_idx + 1)
                    window_q[init_idx*ACT_W +: ACT_W] <= window_q[init_idx*ACT_W +: ACT_W] + {{(ACT_W-8){seed_q[7]}}, seed_q};
                checksum_q <= checksum_q ^ feature_fold;
            end
        end
    end
endmodule
