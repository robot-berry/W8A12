`timescale 1ns/1ps

// TinySPAN W8A8 streamed block:
//   c1 -> act1 LUT -> c2 -> act2 LUT -> c3 -> sim-att LUT
//   -> scale_add(c3, residual) -> scale_mul(sum, sim_att).
module span_tinyspan_w8a8_block_streamed_frontend #(
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32,
    parameter integer ACT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer CH = 32,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter C1_WEIGHT_GROUP_FILE = "",
    parameter C1_BIAS_I64_FILE = "",
    parameter C1_REQUANT_Q31_FILE = "",
    parameter C1_REQUANT_SHIFT_FILE = "",
    parameter ACT1_LUT_FILE = "",
    parameter C2_WEIGHT_GROUP_FILE = "",
    parameter C2_BIAS_I64_FILE = "",
    parameter C2_REQUANT_Q31_FILE = "",
    parameter C2_REQUANT_SHIFT_FILE = "",
    parameter ACT2_LUT_FILE = "",
    parameter C3_WEIGHT_GROUP_FILE = "",
    parameter C3_BIAS_I64_FILE = "",
    parameter C3_REQUANT_Q31_FILE = "",
    parameter C3_REQUANT_SHIFT_FILE = "",
    parameter SIM_ATT_LUT_FILE = "",
    parameter signed [63:0] SUM_A_Q31 = 64'sd0,
    parameter signed [63:0] SUM_B_Q31 = 64'sd0,
    parameter integer SUM_SHIFT = 31,
    parameter signed [63:0] MUL_Q31 = 64'sd0,
    parameter integer MUL_SHIFT = 31
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [CH*ACT_W-1:0]   m_feat,
    output wire                         m_user,
    output wire                         m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer FRAME_ADDR_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);

    wire c1_valid;
    wire c1_ready;
    wire signed [CH*ACT_W-1:0] c1_feat;
    wire c1_user;
    wire c1_last;
    wire signed [CH*ACT_W-1:0] c1_act_feat;

    wire c2_valid;
    wire c2_ready;
    wire signed [CH*ACT_W-1:0] c2_feat;
    wire c2_user;
    wire c2_last;
    wire signed [CH*ACT_W-1:0] c2_act_feat;

    wire c3_valid;
    wire c3_ready;
    wire signed [CH*ACT_W-1:0] c3_feat;
    wire c3_user;
    wire c3_last;
    wire signed [CH*ACT_W-1:0] residual_feat;

    reg [FRAME_ADDR_W-1:0] input_wr_addr;
    reg [FRAME_ADDR_W-1:0] output_rd_addr;
    reg signed [CH*ACT_W-1:0] residual_mem [0:FRAME_PIXELS-1];

    wire input_take = s_valid && s_ready;
    wire output_take = c3_valid && c3_ready;

    span_w8a12_feature_conv_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(C1_WEIGHT_GROUP_FILE),
        .BIAS_I64_FILE(C1_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(C1_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(C1_REQUANT_SHIFT_FILE)
    ) u_c1 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(c1_valid),
        .m_ready(c1_ready),
        .m_feat(c1_feat),
        .m_user(c1_user),
        .m_last(c1_last)
    );

    genvar ch_i;
    generate
        for (ch_i = 0; ch_i < CH; ch_i = ch_i + 1) begin : g_act1
            span_w8a12_unary_lut #(
                .ACT_W(ACT_W),
                .LUT_FILE(ACT1_LUT_FILE)
            ) u_act1_lut (
                .x_i(c1_feat[ch_i*ACT_W +: ACT_W]),
                .y_o(c1_act_feat[ch_i*ACT_W +: ACT_W])
            );
        end
    endgenerate

    span_w8a12_feature_conv_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(C2_WEIGHT_GROUP_FILE),
        .BIAS_I64_FILE(C2_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(C2_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(C2_REQUANT_SHIFT_FILE)
    ) u_c2 (
        .clk(clk),
        .rst(rst),
        .s_valid(c1_valid),
        .s_ready(c1_ready),
        .s_feat(c1_act_feat),
        .s_user(c1_user),
        .s_last(c1_last),
        .m_valid(c2_valid),
        .m_ready(c2_ready),
        .m_feat(c2_feat),
        .m_user(c2_user),
        .m_last(c2_last)
    );

    generate
        for (ch_i = 0; ch_i < CH; ch_i = ch_i + 1) begin : g_act2
            span_w8a12_unary_lut #(
                .ACT_W(ACT_W),
                .LUT_FILE(ACT2_LUT_FILE)
            ) u_act2_lut (
                .x_i(c2_feat[ch_i*ACT_W +: ACT_W]),
                .y_o(c2_act_feat[ch_i*ACT_W +: ACT_W])
            );
        end
    endgenerate

    span_w8a12_feature_conv_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(C3_WEIGHT_GROUP_FILE),
        .BIAS_I64_FILE(C3_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(C3_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(C3_REQUANT_SHIFT_FILE)
    ) u_c3 (
        .clk(clk),
        .rst(rst),
        .s_valid(c2_valid),
        .s_ready(c2_ready),
        .s_feat(c2_act_feat),
        .s_user(c2_user),
        .s_last(c2_last),
        .m_valid(c3_valid),
        .m_ready(c3_ready),
        .m_feat(c3_feat),
        .m_user(c3_user),
        .m_last(c3_last)
    );

    assign residual_feat = residual_mem[output_rd_addr];

    span_tinyspan_w8a8_block_postprocess_serial #(
        .ACT_W(ACT_W),
        .CH(CH),
        .SIM_ATT_LUT_FILE(SIM_ATT_LUT_FILE),
        .SUM_A_Q31(SUM_A_Q31),
        .SUM_B_Q31(SUM_B_Q31),
        .SUM_SHIFT(SUM_SHIFT),
        .MUL_Q31(MUL_Q31),
        .MUL_SHIFT(MUL_SHIFT)
    ) u_post (
        .clk(clk),
        .rst(rst),
        .s_valid(c3_valid),
        .s_ready(c3_ready),
        .s_c3_feat(c3_feat),
        .s_residual_feat(residual_feat),
        .s_user(c3_user),
        .s_last(c3_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );

    integer init_idx;
    always @(posedge clk) begin
        if (rst) begin
            input_wr_addr <= {FRAME_ADDR_W{1'b0}};
            output_rd_addr <= {FRAME_ADDR_W{1'b0}};
            for (init_idx = 0; init_idx < FRAME_PIXELS; init_idx = init_idx + 1)
                residual_mem[init_idx] <= {CH*ACT_W{1'b0}};
        end else begin
            if (input_take) begin
                residual_mem[input_wr_addr] <= s_feat;
                if (s_user)
                    input_wr_addr <= (FRAME_PIXELS == 1) ? {FRAME_ADDR_W{1'b0}} : {{(FRAME_ADDR_W-1){1'b0}}, 1'b1};
                else if (input_wr_addr == FRAME_PIXELS - 1)
                    input_wr_addr <= {FRAME_ADDR_W{1'b0}};
                else
                    input_wr_addr <= input_wr_addr + 1'b1;
            end

            if (output_take) begin
                if (m_user)
                    output_rd_addr <= (FRAME_PIXELS == 1) ? {FRAME_ADDR_W{1'b0}} : {{(FRAME_ADDR_W-1){1'b0}}, 1'b1};
                else if (output_rd_addr == FRAME_PIXELS - 1)
                    output_rd_addr <= {FRAME_ADDR_W{1'b0}};
                else
                    output_rd_addr <= output_rd_addr + 1'b1;
            end
        end
    end
endmodule
