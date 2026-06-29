`timescale 1ns/1ps

// Generic streamed SPAB block:
//   c1_r -> act1 LUT -> c2_r -> act2 LUT -> c3_r -> sim-att LUT -> attention.
module span_w8a12_spab_streamed_frontend #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
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
    parameter integer ATT_SHIFT = 31,
    parameter signed [31:0] ATT_OUT3_REQUANT_Q31 = 32'sd0,
    parameter signed [31:0] ATT_RESIDUAL_REQUANT_Q31 = 32'sd0
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
    output wire                         m_last,

    output wire                         tap_act1_valid,
    output wire signed [CH*ACT_W-1:0]   tap_act1_feat,
    output wire                         tap_act1_user,
    output wire                         tap_act1_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer FRAME_ADDR_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);

    wire c1_valid;
    wire c1_ready;
    wire signed [CH*ACT_W-1:0] c1_feat;
    wire c1_user;
    wire c1_last;

    wire c1_act_valid;
    wire c1_act_ready;
    wire signed [CH*ACT_W-1:0] c1_act_feat;
    wire signed [CH*ACT_W-1:0] c1_act_x_unused;
    wire c1_act_user;
    wire c1_act_last;

    wire c2_valid;
    wire c2_ready;
    wire signed [CH*ACT_W-1:0] c2_feat;
    wire c2_user;
    wire c2_last;

    wire c2_act_valid;
    wire c2_act_ready;
    wire signed [CH*ACT_W-1:0] c2_act_feat;
    wire signed [CH*ACT_W-1:0] c2_act_x_unused;
    wire c2_act_user;
    wire c2_act_last;

    wire c3_valid;
    wire c3_ready;
    wire signed [CH*ACT_W-1:0] c3_feat;
    wire c3_user;
    wire c3_last;

    wire sim_valid;
    wire sim_ready;
    wire signed [CH*ACT_W-1:0] sim_x_feat;
    wire signed [CH*ACT_W-1:0] sim_feat;
    wire sim_user;
    wire sim_last;
    reg signed [CH*ACT_W-1:0] sim_x_feat_q;
    reg signed [CH*ACT_W-1:0] sim_feat_q;
    reg signed [CH*ACT_W-1:0] residual_feat_q;
    reg out_valid_q;
    reg out_user_q;
    reg out_last_q;

    reg [FRAME_ADDR_W-1:0] input_wr_addr;
    reg [FRAME_ADDR_W-1:0] output_rd_addr;
    (* ram_style = "block" *) reg signed [CH*ACT_W-1:0] residual_mem [0:FRAME_PIXELS-1];

    wire input_take = s_valid && s_ready;
    wire sim_take = sim_valid && sim_ready;
    assign sim_ready = !out_valid_q || m_ready;

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

    span_w8a12_unary_lut_vector_stage #(
        .ACT_W(ACT_W),
        .CH(CH),
        .LUT_FILE(ACT1_LUT_FILE)
    ) u_act1_lut_stage (
        .clk(clk),
        .rst(rst),
        .s_valid(c1_valid),
        .s_ready(c1_ready),
        .s_feat(c1_feat),
        .s_user(c1_user),
        .s_last(c1_last),
        .m_valid(c1_act_valid),
        .m_ready(c1_act_ready),
        .m_lut_feat(c1_act_feat),
        .m_x_feat(c1_act_x_unused),
        .m_user(c1_act_user),
        .m_last(c1_act_last)
    );

    assign tap_act1_valid = c1_act_valid && c1_act_ready;
    assign tap_act1_feat = c1_act_feat;
    assign tap_act1_user = c1_act_user;
    assign tap_act1_last = c1_act_last;

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
        .s_valid(c1_act_valid),
        .s_ready(c1_act_ready),
        .s_feat(c1_act_feat),
        .s_user(c1_act_user),
        .s_last(c1_act_last),
        .m_valid(c2_valid),
        .m_ready(c2_ready),
        .m_feat(c2_feat),
        .m_user(c2_user),
        .m_last(c2_last)
    );

    span_w8a12_unary_lut_vector_stage #(
        .ACT_W(ACT_W),
        .CH(CH),
        .LUT_FILE(ACT2_LUT_FILE)
    ) u_act2_lut_stage (
        .clk(clk),
        .rst(rst),
        .s_valid(c2_valid),
        .s_ready(c2_ready),
        .s_feat(c2_feat),
        .s_user(c2_user),
        .s_last(c2_last),
        .m_valid(c2_act_valid),
        .m_ready(c2_act_ready),
        .m_lut_feat(c2_act_feat),
        .m_x_feat(c2_act_x_unused),
        .m_user(c2_act_user),
        .m_last(c2_act_last)
    );

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
        .s_valid(c2_act_valid),
        .s_ready(c2_act_ready),
        .s_feat(c2_act_feat),
        .s_user(c2_act_user),
        .s_last(c2_act_last),
        .m_valid(c3_valid),
        .m_ready(c3_ready),
        .m_feat(c3_feat),
        .m_user(c3_user),
        .m_last(c3_last)
    );

    span_w8a12_unary_lut_vector_stage #(
        .ACT_W(ACT_W),
        .CH(CH),
        .LUT_FILE(SIM_ATT_LUT_FILE)
    ) u_sim_lut_stage (
        .clk(clk),
        .rst(rst),
        .s_valid(c3_valid),
        .s_ready(c3_ready),
        .s_feat(c3_feat),
        .s_user(c3_user),
        .s_last(c3_last),
        .m_valid(sim_valid),
        .m_ready(sim_ready),
        .m_lut_feat(sim_feat),
        .m_x_feat(sim_x_feat),
        .m_user(sim_user),
        .m_last(sim_last)
    );

    genvar ch_i;
    generate
        for (ch_i = 0; ch_i < CH; ch_i = ch_i + 1) begin : g_attention
            span_w8a12_attention #(
                .ACT_W(ACT_W),
                .SHIFT(ATT_SHIFT),
                .OUT3_REQUANT_Q31(ATT_OUT3_REQUANT_Q31),
                .RESIDUAL_REQUANT_Q31(ATT_RESIDUAL_REQUANT_Q31)
            ) u_attention (
                .out3_i(sim_x_feat_q[ch_i*ACT_W +: ACT_W]),
                .residual_i(residual_feat_q[ch_i*ACT_W +: ACT_W]),
                .sim_att_i(sim_feat_q[ch_i*ACT_W +: ACT_W]),
                .q_o(m_feat[ch_i*ACT_W +: ACT_W])
            );
        end
    endgenerate

    assign m_valid = out_valid_q;
    assign m_user = out_user_q;
    assign m_last = out_last_q;

    always @(posedge clk) begin
        if (rst) begin
            input_wr_addr <= {FRAME_ADDR_W{1'b0}};
            output_rd_addr <= {FRAME_ADDR_W{1'b0}};
            residual_feat_q <= {CH*ACT_W{1'b0}};
            sim_x_feat_q <= {CH*ACT_W{1'b0}};
            sim_feat_q <= {CH*ACT_W{1'b0}};
            out_valid_q <= 1'b0;
            out_user_q <= 1'b0;
            out_last_q <= 1'b0;
        end else begin
            if (out_valid_q && m_ready)
                out_valid_q <= 1'b0;

            if (input_take) begin
                residual_mem[input_wr_addr] <= s_feat;
                if (s_user)
                    input_wr_addr <= (FRAME_PIXELS == 1) ? {FRAME_ADDR_W{1'b0}} : {{(FRAME_ADDR_W-1){1'b0}}, 1'b1};
                else if (input_wr_addr == FRAME_PIXELS - 1)
                    input_wr_addr <= {FRAME_ADDR_W{1'b0}};
                else
                    input_wr_addr <= input_wr_addr + 1'b1;
            end

            if (sim_take) begin
                residual_feat_q <= residual_mem[output_rd_addr];
                sim_x_feat_q <= sim_x_feat;
                sim_feat_q <= sim_feat;
                out_user_q <= sim_user;
                out_last_q <= sim_last;
                out_valid_q <= 1'b1;

                if (sim_user)
                    output_rd_addr <= (FRAME_PIXELS == 1) ? {FRAME_ADDR_W{1'b0}} : {{(FRAME_ADDR_W-1){1'b0}}, 1'b1};
                else if (output_rd_addr == FRAME_PIXELS - 1)
                    output_rd_addr <= {FRAME_ADDR_W{1'b0}};
                else
                    output_rd_addr <= output_rd_addr + 1'b1;
            end
        end
    end
endmodule
