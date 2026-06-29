`timescale 1ns/1ps
`include "span_w8a12_generated_select.vh"

// Streamed W8A12 SPAN tail from aligned trunk/skip features to X4 RGB q pixels.
//
// Inputs are one LR raster pixel per handshake:
//   feat0_i     = conv_1 output skip
//   block6_i    = block_6 output, consumed by conv_2
//   b1_i        = block_1 output skip
//   b6_act1_i   = block_6 act1 skip
module span_w8a12_tail_streamed_rgb #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer CAT_CH = 192,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer SCALE_LANES = 2
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   feat0_i,
    input  wire signed [CH*ACT_W-1:0]   block6_i,
    input  wire signed [CH*ACT_W-1:0]   b1_i,
    input  wire signed [CH*ACT_W-1:0]   b6_act1_i,
    input  wire                         s_user,
    input  wire                         s_last,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [3*ACT_W-1:0]    m_rgb,
    output wire                         m_user,
    output wire                         m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer PIX_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);

    (* ram_style = "block" *) reg signed [CH*ACT_W-1:0] feat0_mem [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg signed [CH*ACT_W-1:0] b1_mem [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg signed [CH*ACT_W-1:0] b6_act1_mem [0:FRAME_PIXELS-1];
    reg [PIX_W-1:0] input_pix;
    reg [PIX_W-1:0] conv2_pix;
    reg scale_in_valid_q;
    reg signed [CH*ACT_W-1:0] feat0_q;
    reg signed [CH*ACT_W-1:0] b1_q;
    reg signed [CH*ACT_W-1:0] b6_act1_q;
    reg signed [CH*ACT_W-1:0] conv2_feat_q;
    reg scale_user_q;
    reg scale_last_q;

    wire conv2_valid;
    wire conv2_ready;
    wire signed [CH*ACT_W-1:0] conv2_feat;
    wire conv2_user;
    wire conv2_last;

    wire scale_valid;
    wire scale_ready;
    wire signed [CAT_CH*ACT_W-1:0] cat_input;
    wire scale_user;
    wire scale_last;

    wire cat_valid;
    wire cat_ready;
    wire cat_ready_to_up;
    wire signed [CH*ACT_W-1:0] cat_feat;
    wire cat_user;
    wire cat_last;
    wire conv2_take = conv2_valid && conv2_ready;

    span_w8a12_conv2_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_conv2 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(block6_i),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(conv2_valid),
        .m_ready(conv2_ready),
        .m_feat(conv2_feat),
        .m_user(conv2_user),
        .m_last(conv2_last)
    );

    assign conv2_ready = !scale_in_valid_q || scale_ready;

    span_w8a12_conv_cat_scale_concat #(
        .ACT_W(ACT_W),
        .CH(CH),
        .SCALE_LANES(SCALE_LANES),
        .FEAT0_Q31(`REDS_SPAN_ACTIVE_CONV_CAT_FEAT0_Q31),
        .B6CONV_Q31(`REDS_SPAN_ACTIVE_CONV_CAT_B6CONV_Q31),
        .B1_Q31(`REDS_SPAN_ACTIVE_CONV_CAT_B1_Q31),
        .B6_ACT1_Q31(`REDS_SPAN_ACTIVE_CONV_CAT_B6_ACT1_Q31)
    ) u_scale_concat (
        .clk(clk),
        .rst(rst),
        .s_valid(scale_in_valid_q),
        .s_ready(scale_ready),
        .feat0_i(feat0_q),
        .b6conv_i(conv2_feat_q),
        .b1_i(b1_q),
        .b6_act1_i(b6_act1_q),
        .s_user(scale_user_q),
        .s_last(scale_last_q),
        .m_valid(scale_valid),
        .m_ready(cat_ready),
        .cat_o(cat_input),
        .m_user(scale_user),
        .m_last(scale_last)
    );

    span_w8a12_conv1x1_streamed_frontend #(
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .IN_CH(CAT_CH),
        .OUT_CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_GROUP_FILE(`REDS_SPAN_ACTIVE_CONV_CAT_WEIGHT_GROUP_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_20_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_20_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_20_REQUANT_SHIFT_FILE)
    ) u_conv_cat (
        .clk(clk),
        .rst(rst),
        .s_valid(scale_valid),
        .s_ready(cat_ready),
        .s_feat(cat_input),
        .s_user(scale_user),
        .s_last(scale_last),
        .m_valid(cat_valid),
        .m_ready(cat_ready_to_up),
        .m_feat(cat_feat),
        .m_user(cat_user),
        .m_last(cat_last)
    );

    span_w8a12_upsampler0_pixelshuffle_streamed_rgb #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_up_rgb (
        .clk(clk),
        .rst(rst),
        .s_valid(cat_valid),
        .s_ready(cat_ready_to_up),
        .s_feat(cat_feat),
        .s_user(cat_user),
        .s_last(cat_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            input_pix <= {PIX_W{1'b0}};
            conv2_pix <= {PIX_W{1'b0}};
            scale_in_valid_q <= 1'b0;
            feat0_q <= {CH*ACT_W{1'b0}};
            b1_q <= {CH*ACT_W{1'b0}};
            b6_act1_q <= {CH*ACT_W{1'b0}};
            conv2_feat_q <= {CH*ACT_W{1'b0}};
            scale_user_q <= 1'b0;
            scale_last_q <= 1'b0;
        end else begin
            if (scale_in_valid_q && scale_ready)
                scale_in_valid_q <= 1'b0;

            if (s_valid && s_ready) begin
                feat0_mem[input_pix] <= feat0_i;
                b1_mem[input_pix] <= b1_i;
                b6_act1_mem[input_pix] <= b6_act1_i;
                if (input_pix == FRAME_PIXELS - 1)
                    input_pix <= {PIX_W{1'b0}};
                else
                    input_pix <= input_pix + 1'b1;
            end

            if (conv2_take) begin
                feat0_q <= feat0_mem[conv2_pix];
                b1_q <= b1_mem[conv2_pix];
                b6_act1_q <= b6_act1_mem[conv2_pix];
                conv2_feat_q <= conv2_feat;
                scale_user_q <= conv2_user;
                scale_last_q <= conv2_last;
                scale_in_valid_q <= 1'b1;

                if (conv2_pix == FRAME_PIXELS - 1)
                    conv2_pix <= {PIX_W{1'b0}};
                else
                    conv2_pix <= conv2_pix + 1'b1;
            end
        end
    end
endmodule
