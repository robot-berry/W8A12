`timescale 1ns/1ps
`include "reds_span_x4_f48_w8a12/span_w8a12_layers.vh"

module tb_span_w8a12_tail_frame;
    localparam int IMG_W = 4;
    localparam int IMG_H = 4;
    localparam int CH = 48;
    localparam int CAT_CH = 192;
    localparam int ACT_W = 12;
    localparam int ACC_W = 48;
    localparam int FRAME_PIXELS = IMG_W * IMG_H;
    localparam int TOTAL = FRAME_PIXELS * CH;
    localparam int OUT_W = IMG_W * 4;
    localparam int OUT_PIXELS = OUT_W * OUT_W;
    localparam int OUT_TOTAL = OUT_PIXELS * 3;
    localparam int MAX_CYCLES = 200000;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic s_valid;
    logic m_ready;
    logic [CH*9*ACT_W-1:0] window_i;
    logic signed [ACT_W-1:0] feat0 [0:TOTAL-1];
    logic signed [ACT_W-1:0] current_feat [0:TOTAL-1];
    logic signed [ACT_W-1:0] b1_feat [0:TOTAL-1];
    logic signed [ACT_W-1:0] b6_act1_feat [0:TOTAL-1];
    logic signed [ACT_W-1:0] c1_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] c1_act [0:TOTAL-1];
    logic signed [ACT_W-1:0] c2_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] c2_act [0:TOTAL-1];
    logic signed [ACT_W-1:0] c3_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] sim_att [0:TOTAL-1];
    logic signed [ACT_W-1:0] next_feat [0:TOTAL-1];
    logic signed [ACT_W-1:0] conv2_feat [0:TOTAL-1];
    logic signed [ACT_W-1:0] cat_feat [0:TOTAL-1];
    logic signed [ACT_W-1:0] up_feat [0:TOTAL-1];
    logic signed [ACT_W-1:0] rgb_out [0:OUT_TOTAL-1];
    logic signed [ACT_W-1:0] expected [0:OUT_TOTAL-1];
    logic signed [ACT_W-1:0] lut_x;
    logic signed [ACT_W-1:0] att_out3;
    logic signed [ACT_W-1:0] att_residual;
    logic signed [ACT_W-1:0] att_sim;

    int block_sel;
    int layer_sel;
    int pix;
    int ch;
    int cyc;
    int mismatches;
    int fd;
    int sx;
    int sy;
    int color;
    int in_ch;
    int out_pix;
    logic signed [ACT_W-1:0] got;

    always #5 clk = ~clk;


    wire b1_c1_valid;
    wire [CH*ACT_W-1:0] b1_c1_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_1_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_1_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_1_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_1_REQUANT_SHIFT_FILE)
    ) u_b1_c1 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b1_c1_valid), .m_ready(m_ready), .feat_o(b1_c1_feat)
    );

    wire b1_c2_valid;
    wire [CH*ACT_W-1:0] b1_c2_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_2_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_2_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_2_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_2_REQUANT_SHIFT_FILE)
    ) u_b1_c2 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b1_c2_valid), .m_ready(m_ready), .feat_o(b1_c2_feat)
    );

    wire b1_c3_valid;
    wire [CH*ACT_W-1:0] b1_c3_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_3_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_3_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_3_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_3_REQUANT_SHIFT_FILE)
    ) u_b1_c3 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b1_c3_valid), .m_ready(m_ready), .feat_o(b1_c3_feat)
    );

    wire b2_c1_valid;
    wire [CH*ACT_W-1:0] b2_c1_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_4_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_4_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_4_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_4_REQUANT_SHIFT_FILE)
    ) u_b2_c1 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b2_c1_valid), .m_ready(m_ready), .feat_o(b2_c1_feat)
    );

    wire b2_c2_valid;
    wire [CH*ACT_W-1:0] b2_c2_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_5_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_5_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_5_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_5_REQUANT_SHIFT_FILE)
    ) u_b2_c2 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b2_c2_valid), .m_ready(m_ready), .feat_o(b2_c2_feat)
    );

    wire b2_c3_valid;
    wire [CH*ACT_W-1:0] b2_c3_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_6_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_6_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_6_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_6_REQUANT_SHIFT_FILE)
    ) u_b2_c3 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b2_c3_valid), .m_ready(m_ready), .feat_o(b2_c3_feat)
    );

    wire b3_c1_valid;
    wire [CH*ACT_W-1:0] b3_c1_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_7_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_7_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_7_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_7_REQUANT_SHIFT_FILE)
    ) u_b3_c1 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b3_c1_valid), .m_ready(m_ready), .feat_o(b3_c1_feat)
    );

    wire b3_c2_valid;
    wire [CH*ACT_W-1:0] b3_c2_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_8_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_8_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_8_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_8_REQUANT_SHIFT_FILE)
    ) u_b3_c2 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b3_c2_valid), .m_ready(m_ready), .feat_o(b3_c2_feat)
    );

    wire b3_c3_valid;
    wire [CH*ACT_W-1:0] b3_c3_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_9_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_9_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_9_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_9_REQUANT_SHIFT_FILE)
    ) u_b3_c3 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b3_c3_valid), .m_ready(m_ready), .feat_o(b3_c3_feat)
    );

    wire b4_c1_valid;
    wire [CH*ACT_W-1:0] b4_c1_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_10_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_10_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_10_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_10_REQUANT_SHIFT_FILE)
    ) u_b4_c1 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b4_c1_valid), .m_ready(m_ready), .feat_o(b4_c1_feat)
    );

    wire b4_c2_valid;
    wire [CH*ACT_W-1:0] b4_c2_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_11_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_11_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_11_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_11_REQUANT_SHIFT_FILE)
    ) u_b4_c2 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b4_c2_valid), .m_ready(m_ready), .feat_o(b4_c2_feat)
    );

    wire b4_c3_valid;
    wire [CH*ACT_W-1:0] b4_c3_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_12_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_12_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_12_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_12_REQUANT_SHIFT_FILE)
    ) u_b4_c3 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b4_c3_valid), .m_ready(m_ready), .feat_o(b4_c3_feat)
    );

    wire b5_c1_valid;
    wire [CH*ACT_W-1:0] b5_c1_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_13_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_13_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_13_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_13_REQUANT_SHIFT_FILE)
    ) u_b5_c1 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b5_c1_valid), .m_ready(m_ready), .feat_o(b5_c1_feat)
    );

    wire b5_c2_valid;
    wire [CH*ACT_W-1:0] b5_c2_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_14_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_14_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_14_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_14_REQUANT_SHIFT_FILE)
    ) u_b5_c2 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b5_c2_valid), .m_ready(m_ready), .feat_o(b5_c2_feat)
    );

    wire b5_c3_valid;
    wire [CH*ACT_W-1:0] b5_c3_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_15_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_15_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_15_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_15_REQUANT_SHIFT_FILE)
    ) u_b5_c3 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b5_c3_valid), .m_ready(m_ready), .feat_o(b5_c3_feat)
    );

    wire b6_c1_valid;
    wire [CH*ACT_W-1:0] b6_c1_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_16_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_16_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_16_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_16_REQUANT_SHIFT_FILE)
    ) u_b6_c1 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b6_c1_valid), .m_ready(m_ready), .feat_o(b6_c1_feat)
    );

    wire b6_c2_valid;
    wire [CH*ACT_W-1:0] b6_c2_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_17_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_17_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_17_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_17_REQUANT_SHIFT_FILE)
    ) u_b6_c2 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b6_c2_valid), .m_ready(m_ready), .feat_o(b6_c2_feat)
    );

    wire b6_c3_valid;
    wire [CH*ACT_W-1:0] b6_c3_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_18_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_18_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_18_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_18_REQUANT_SHIFT_FILE)
    ) u_b6_c3 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(b6_c3_valid), .m_ready(m_ready), .feat_o(b6_c3_feat)
    );


    wire conv2_layer_valid;
    wire [CH*ACT_W-1:0] conv2_layer_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_19_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_19_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_19_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_19_REQUANT_SHIFT_FILE)
    ) u_conv2_layer (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(conv2_layer_valid), .m_ready(m_ready), .feat_o(conv2_layer_feat)
    );


    wire up0_layer_valid;
    wire [CH*ACT_W-1:0] up0_layer_feat;
    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_21_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_21_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_21_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_21_REQUANT_SHIFT_FILE)
    ) u_up0_layer (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(), .window_i(window_i),
        .m_valid(up0_layer_valid), .m_ready(m_ready), .feat_o(up0_layer_feat)
    );


    logic cat_s_valid;
    wire cat_valid;
    logic [CAT_CH*ACT_W-1:0] cat_window_i;
    wire [CH*ACT_W-1:0] cat_feat_o;
    span_w8a12_conv_layer #(
        .IN_CH(CAT_CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(1),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_20_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_20_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_20_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_20_REQUANT_SHIFT_FILE)
    ) u_conv_cat (
        .clk(clk), .rst(rst), .s_valid(cat_s_valid), .s_ready(), .window_i(cat_window_i),
        .m_valid(cat_valid), .m_ready(m_ready), .feat_o(cat_feat_o)
    );

    wire signed [ACT_W-1:0] b1_act1_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_1_act1_silu_s12.mem")) u_b1_act1 (.x_i(lut_x), .y_o(b1_act1_y));
    wire signed [ACT_W-1:0] b1_act2_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_1_act2_silu_s12.mem")) u_b1_act2 (.x_i(lut_x), .y_o(b1_act2_y));
    wire signed [ACT_W-1:0] b1_sim_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_1_attention_sim_att_s12.mem")) u_b1_sim (.x_i(lut_x), .y_o(b1_sim_y));
    wire signed [ACT_W-1:0] b2_act1_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_2_act1_silu_s12.mem")) u_b2_act1 (.x_i(lut_x), .y_o(b2_act1_y));
    wire signed [ACT_W-1:0] b2_act2_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_2_act2_silu_s12.mem")) u_b2_act2 (.x_i(lut_x), .y_o(b2_act2_y));
    wire signed [ACT_W-1:0] b2_sim_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_2_attention_sim_att_s12.mem")) u_b2_sim (.x_i(lut_x), .y_o(b2_sim_y));
    wire signed [ACT_W-1:0] b3_act1_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_3_act1_silu_s12.mem")) u_b3_act1 (.x_i(lut_x), .y_o(b3_act1_y));
    wire signed [ACT_W-1:0] b3_act2_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_3_act2_silu_s12.mem")) u_b3_act2 (.x_i(lut_x), .y_o(b3_act2_y));
    wire signed [ACT_W-1:0] b3_sim_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_3_attention_sim_att_s12.mem")) u_b3_sim (.x_i(lut_x), .y_o(b3_sim_y));
    wire signed [ACT_W-1:0] b4_act1_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_4_act1_silu_s12.mem")) u_b4_act1 (.x_i(lut_x), .y_o(b4_act1_y));
    wire signed [ACT_W-1:0] b4_act2_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_4_act2_silu_s12.mem")) u_b4_act2 (.x_i(lut_x), .y_o(b4_act2_y));
    wire signed [ACT_W-1:0] b4_sim_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_4_attention_sim_att_s12.mem")) u_b4_sim (.x_i(lut_x), .y_o(b4_sim_y));
    wire signed [ACT_W-1:0] b5_act1_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_5_act1_silu_s12.mem")) u_b5_act1 (.x_i(lut_x), .y_o(b5_act1_y));
    wire signed [ACT_W-1:0] b5_act2_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_5_act2_silu_s12.mem")) u_b5_act2 (.x_i(lut_x), .y_o(b5_act2_y));
    wire signed [ACT_W-1:0] b5_sim_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_5_attention_sim_att_s12.mem")) u_b5_sim (.x_i(lut_x), .y_o(b5_sim_y));
    wire signed [ACT_W-1:0] b6_act1_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_6_act1_silu_s12.mem")) u_b6_act1 (.x_i(lut_x), .y_o(b6_act1_y));
    wire signed [ACT_W-1:0] b6_act2_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_6_act2_silu_s12.mem")) u_b6_act2 (.x_i(lut_x), .y_o(b6_act2_y));
    wire signed [ACT_W-1:0] b6_sim_y;
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/postprocess/mem/block_6_attention_sim_att_s12.mem")) u_b6_sim (.x_i(lut_x), .y_o(b6_sim_y));


    wire signed [ACT_W-1:0] att_b1_y;
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .OUT3_REQUANT_Q31(32'sd80193),
        .RESIDUAL_REQUANT_Q31(32'sd1123025)
    ) u_att_b1 (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_b1_y)
    );

    wire signed [ACT_W-1:0] att_b2_y;
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .OUT3_REQUANT_Q31(32'sd325084),
        .RESIDUAL_REQUANT_Q31(32'sd881871)
    ) u_att_b2 (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_b2_y)
    );

    wire signed [ACT_W-1:0] att_b3_y;
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .OUT3_REQUANT_Q31(32'sd427693),
        .RESIDUAL_REQUANT_Q31(32'sd1236614)
    ) u_att_b3 (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_b3_y)
    );

    wire signed [ACT_W-1:0] att_b4_y;
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .OUT3_REQUANT_Q31(32'sd579183),
        .RESIDUAL_REQUANT_Q31(32'sd963342)
    ) u_att_b4 (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_b4_y)
    );

    wire signed [ACT_W-1:0] att_b5_y;
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .OUT3_REQUANT_Q31(32'sd1089880),
        .RESIDUAL_REQUANT_Q31(32'sd864186)
    ) u_att_b5 (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_b5_y)
    );

    wire signed [ACT_W-1:0] att_b6_y;
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .OUT3_REQUANT_Q31(32'sd1043397),
        .RESIDUAL_REQUANT_Q31(32'sd665513)
    ) u_att_b6 (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_b6_y)
    );

    function automatic bit selected_valid(input int block_sel, input int layer_sel);
        begin
            selected_valid = 1'b0;
            case (block_sel)
                1: begin
                    if (layer_sel == 1) selected_valid = b1_c1_valid;
                    else if (layer_sel == 2) selected_valid = b1_c2_valid;
                    else selected_valid = b1_c3_valid;
                end
                2: begin
                    if (layer_sel == 1) selected_valid = b2_c1_valid;
                    else if (layer_sel == 2) selected_valid = b2_c2_valid;
                    else selected_valid = b2_c3_valid;
                end
                3: begin
                    if (layer_sel == 1) selected_valid = b3_c1_valid;
                    else if (layer_sel == 2) selected_valid = b3_c2_valid;
                    else selected_valid = b3_c3_valid;
                end
                4: begin
                    if (layer_sel == 1) selected_valid = b4_c1_valid;
                    else if (layer_sel == 2) selected_valid = b4_c2_valid;
                    else selected_valid = b4_c3_valid;
                end
                5: begin
                    if (layer_sel == 1) selected_valid = b5_c1_valid;
                    else if (layer_sel == 2) selected_valid = b5_c2_valid;
                    else selected_valid = b5_c3_valid;
                end
                6: begin
                    if (layer_sel == 1) selected_valid = b6_c1_valid;
                    else if (layer_sel == 2) selected_valid = b6_c2_valid;
                    else selected_valid = b6_c3_valid;
                end
                default: selected_valid = 1'b0;
            endcase
        end
    endfunction

    task automatic store_selected_feat;
        input int block_sel;
        input int layer_sel;
        input int center_pix;
        begin
            case (block_sel)
                1: begin
                    if (layer_sel == 1) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c1_raw[center_pix * CH + ch] = b1_c1_feat[ch*ACT_W +: ACT_W];
                    end
                    else if (layer_sel == 2) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c2_raw[center_pix * CH + ch] = b1_c2_feat[ch*ACT_W +: ACT_W];
                    end
                    else begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c3_raw[center_pix * CH + ch] = b1_c3_feat[ch*ACT_W +: ACT_W];
                    end
                end
                2: begin
                    if (layer_sel == 1) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c1_raw[center_pix * CH + ch] = b2_c1_feat[ch*ACT_W +: ACT_W];
                    end
                    else if (layer_sel == 2) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c2_raw[center_pix * CH + ch] = b2_c2_feat[ch*ACT_W +: ACT_W];
                    end
                    else begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c3_raw[center_pix * CH + ch] = b2_c3_feat[ch*ACT_W +: ACT_W];
                    end
                end
                3: begin
                    if (layer_sel == 1) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c1_raw[center_pix * CH + ch] = b3_c1_feat[ch*ACT_W +: ACT_W];
                    end
                    else if (layer_sel == 2) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c2_raw[center_pix * CH + ch] = b3_c2_feat[ch*ACT_W +: ACT_W];
                    end
                    else begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c3_raw[center_pix * CH + ch] = b3_c3_feat[ch*ACT_W +: ACT_W];
                    end
                end
                4: begin
                    if (layer_sel == 1) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c1_raw[center_pix * CH + ch] = b4_c1_feat[ch*ACT_W +: ACT_W];
                    end
                    else if (layer_sel == 2) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c2_raw[center_pix * CH + ch] = b4_c2_feat[ch*ACT_W +: ACT_W];
                    end
                    else begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c3_raw[center_pix * CH + ch] = b4_c3_feat[ch*ACT_W +: ACT_W];
                    end
                end
                5: begin
                    if (layer_sel == 1) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c1_raw[center_pix * CH + ch] = b5_c1_feat[ch*ACT_W +: ACT_W];
                    end
                    else if (layer_sel == 2) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c2_raw[center_pix * CH + ch] = b5_c2_feat[ch*ACT_W +: ACT_W];
                    end
                    else begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c3_raw[center_pix * CH + ch] = b5_c3_feat[ch*ACT_W +: ACT_W];
                    end
                end
                6: begin
                    if (layer_sel == 1) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c1_raw[center_pix * CH + ch] = b6_c1_feat[ch*ACT_W +: ACT_W];
                    end
                    else if (layer_sel == 2) begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c2_raw[center_pix * CH + ch] = b6_c2_feat[ch*ACT_W +: ACT_W];
                    end
                    else begin
                        for (ch = 0; ch < CH; ch = ch + 1)
                            c3_raw[center_pix * CH + ch] = b6_c3_feat[ch*ACT_W +: ACT_W];
                    end
                end
            endcase
        end
    endtask

    function automatic signed [ACT_W-1:0] requant_scale(input signed [ACT_W-1:0] x, input longint signed mult);
        longint signed product;
        longint signed rounded;
        begin
            product = x * mult;
            if (product >= 0)
                rounded = (product + 64'sd1073741824) >>> 31;
            else
                rounded = -(((-product) + 64'sd1073741824) >>> 31);
            if (rounded > 2047)
                requant_scale = 12'sd2047;
            else if (rounded < -2048)
                requant_scale = -12'sd2048;
            else
                requant_scale = rounded[ACT_W-1:0];
        end
    endfunction

    task automatic apply_act1;
        input int block_sel;
        input logic signed [ACT_W-1:0] x;
        output logic signed [ACT_W-1:0] y;
        begin
            lut_x = x;
            #1;
            case (block_sel)
                1: y = b1_act1_y;
                2: y = b2_act1_y;
                3: y = b3_act1_y;
                4: y = b4_act1_y;
                5: y = b5_act1_y;
                6: y = b6_act1_y;
                default: y = {ACT_W{1'b0}};
            endcase
        end
    endtask

    task automatic apply_act2;
        input int block_sel;
        input logic signed [ACT_W-1:0] x;
        output logic signed [ACT_W-1:0] y;
        begin
            lut_x = x;
            #1;
            case (block_sel)
                1: y = b1_act2_y;
                2: y = b2_act2_y;
                3: y = b3_act2_y;
                4: y = b4_act2_y;
                5: y = b5_act2_y;
                6: y = b6_act2_y;
                default: y = {ACT_W{1'b0}};
            endcase
        end
    endtask

    task automatic apply_sim;
        input int block_sel;
        input logic signed [ACT_W-1:0] x;
        output logic signed [ACT_W-1:0] y;
        begin
            lut_x = x;
            #1;
            case (block_sel)
                1: y = b1_sim_y;
                2: y = b2_sim_y;
                3: y = b3_sim_y;
                4: y = b4_sim_y;
                5: y = b5_sim_y;
                6: y = b6_sim_y;
                default: y = {ACT_W{1'b0}};
            endcase
        end
    endtask

    task automatic apply_attention;
        input int block_sel;
        input logic signed [ACT_W-1:0] out3;
        input logic signed [ACT_W-1:0] residual;
        input logic signed [ACT_W-1:0] sim;
        output logic signed [ACT_W-1:0] y;
        begin
            att_out3 = out3;
            att_residual = residual;
            att_sim = sim;
            #1;
            case (block_sel)
                1: y = att_b1_y;
                2: y = att_b2_y;
                3: y = att_b3_y;
                4: y = att_b4_y;
                5: y = att_b5_y;
                6: y = att_b6_y;
                default: y = {ACT_W{1'b0}};
            endcase
        end
    endtask

    task automatic load_window;
        input int src_sel;
        input int center_pix;
        int c;
        int ky;
        int kx;
        int px;
        int py;
        int src_pix;
        int tap;
        logic signed [ACT_W-1:0] value;
        begin
            window_i = {CH*9*ACT_W{1'b0}};
            for (c = 0; c < CH; c = c + 1) begin
                for (ky = 0; ky < 3; ky = ky + 1) begin
                    for (kx = 0; kx < 3; kx = kx + 1) begin
                        px = (center_pix % IMG_W) + kx - 1;
                        py = (center_pix / IMG_W) + ky - 1;
                        tap = ky * 3 + kx;
                        value = 12'sd0;
                        if ((px >= 0) && (px < IMG_W) && (py >= 0) && (py < IMG_H)) begin
                            src_pix = py * IMG_W + px;
                            if (src_sel == 0)
                                value = current_feat[src_pix * CH + c];
                            else if (src_sel == 1)
                                value = c1_act[src_pix * CH + c];
                            else if (src_sel == 2)
                                value = c2_act[src_pix * CH + c];
                            else if (src_sel == 3)
                                value = conv2_feat[src_pix * CH + c];
                            else
                                value = cat_feat[src_pix * CH + c];
                        end
                        window_i[(c*9 + tap)*ACT_W +: ACT_W] = value;
                    end
                end
            end
        end
    endtask

    task automatic run_spab_conv_pixel;
        input int block_sel;
        input int layer_sel;
        input int src_sel;
        input int center_pix;
        begin
            @(negedge clk);
            load_window(src_sel, center_pix);
            s_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_valid = 1'b0;
            for (cyc = 0; cyc < MAX_CYCLES; cyc = cyc + 1) begin
                @(posedge clk);
                if (selected_valid(block_sel, layer_sel))
                    break;
            end
            if (cyc == MAX_CYCLES)
                $fatal(1, "SPAB conv timeout block=%0d layer=%0d pix=%0d", block_sel, layer_sel, center_pix);
            store_selected_feat(block_sel, layer_sel, center_pix);
        end
    endtask

    task automatic run_conv2_pixel;
        input int center_pix;
        begin
            @(negedge clk);
            load_window(0, center_pix);
            s_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_valid = 1'b0;
            for (cyc = 0; cyc < MAX_CYCLES; cyc = cyc + 1) begin
                @(posedge clk);
                if (conv2_layer_valid)
                    break;
            end
            if (cyc == MAX_CYCLES)
                $fatal(1, "conv2 timeout pix=%0d", center_pix);
            for (ch = 0; ch < CH; ch = ch + 1)
                conv2_feat[center_pix * CH + ch] = conv2_layer_feat[ch*ACT_W +: ACT_W];
        end
    endtask

    task automatic run_up_pixel;
        input int center_pix;
        begin
            @(negedge clk);
            load_window(4, center_pix);
            s_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_valid = 1'b0;
            for (cyc = 0; cyc < MAX_CYCLES; cyc = cyc + 1) begin
                @(posedge clk);
                if (up0_layer_valid)
                    break;
            end
            if (cyc == MAX_CYCLES)
                $fatal(1, "upsampler timeout pix=%0d", center_pix);
            for (ch = 0; ch < CH; ch = ch + 1)
                up_feat[center_pix * CH + ch] = up0_layer_feat[ch*ACT_W +: ACT_W];
        end
    endtask

    task automatic load_cat_window;
        input int center_pix;
        int c;
        begin
            for (c = 0; c < CH; c = c + 1) begin
                cat_window_i[(c)*ACT_W +: ACT_W] = requant_scale(feat0[center_pix * CH + c], 64'sd2147483648);
                cat_window_i[(CH + c)*ACT_W +: ACT_W] = requant_scale(conv2_feat[center_pix * CH + c], 64'sd69288640);
                cat_window_i[(2*CH + c)*ACT_W +: ACT_W] = requant_scale(b1_feat[center_pix * CH + c], 64'sd1002444872);
                cat_window_i[(3*CH + c)*ACT_W +: ACT_W] = requant_scale(b6_act1_feat[center_pix * CH + c], 64'sd80461022);
            end
        end
    endtask

    task automatic run_cat_pixel;
        input int center_pix;
        begin
            @(negedge clk);
            load_cat_window(center_pix);
            cat_s_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            cat_s_valid = 1'b0;
            for (cyc = 0; cyc < MAX_CYCLES; cyc = cyc + 1) begin
                @(posedge clk);
                if (cat_valid)
                    break;
            end
            if (cyc == MAX_CYCLES)
                $fatal(1, "conv_cat timeout pix=%0d", center_pix);
            for (ch = 0; ch < CH; ch = ch + 1)
                cat_feat[center_pix * CH + ch] = cat_feat_o[ch*ACT_W +: ACT_W];
        end
    endtask

    initial begin
        s_valid = 1'b0;
        cat_s_valid = 1'b0;
        window_i = {CH*9*ACT_W{1'b0}};
        cat_window_i = {CAT_CH*ACT_W{1'b0}};
        m_ready = 1'b1;
        mismatches = 0;

        feat0[0] = -12'sd2029;
        feat0[1] = -12'sd1992;
        feat0[2] = -12'sd1955;
        feat0[3] = -12'sd1918;
        feat0[4] = -12'sd1881;
        feat0[5] = -12'sd1844;
        feat0[6] = -12'sd1807;
        feat0[7] = -12'sd1770;
        feat0[8] = -12'sd1733;
        feat0[9] = -12'sd1696;
        feat0[10] = -12'sd1659;
        feat0[11] = -12'sd1622;
        feat0[12] = -12'sd1585;
        feat0[13] = -12'sd1548;
        feat0[14] = -12'sd1511;
        feat0[15] = -12'sd1474;
        feat0[16] = -12'sd1437;
        feat0[17] = -12'sd1400;
        feat0[18] = -12'sd1363;
        feat0[19] = -12'sd1326;
        feat0[20] = -12'sd1289;
        feat0[21] = -12'sd1252;
        feat0[22] = -12'sd1215;
        feat0[23] = -12'sd1178;
        feat0[24] = -12'sd1141;
        feat0[25] = -12'sd1104;
        feat0[26] = -12'sd1067;
        feat0[27] = -12'sd1030;
        feat0[28] = -12'sd993;
        feat0[29] = -12'sd956;
        feat0[30] = -12'sd919;
        feat0[31] = -12'sd882;
        feat0[32] = -12'sd845;
        feat0[33] = -12'sd808;
        feat0[34] = -12'sd771;
        feat0[35] = -12'sd734;
        feat0[36] = -12'sd697;
        feat0[37] = -12'sd660;
        feat0[38] = -12'sd623;
        feat0[39] = -12'sd586;
        feat0[40] = -12'sd549;
        feat0[41] = -12'sd512;
        feat0[42] = -12'sd475;
        feat0[43] = -12'sd438;
        feat0[44] = -12'sd401;
        feat0[45] = -12'sd364;
        feat0[46] = -12'sd327;
        feat0[47] = -12'sd290;
        feat0[48] = -12'sd1898;
        feat0[49] = -12'sd1861;
        feat0[50] = -12'sd1824;
        feat0[51] = -12'sd1787;
        feat0[52] = -12'sd1750;
        feat0[53] = -12'sd1713;
        feat0[54] = -12'sd1676;
        feat0[55] = -12'sd1639;
        feat0[56] = -12'sd1602;
        feat0[57] = -12'sd1565;
        feat0[58] = -12'sd1528;
        feat0[59] = -12'sd1491;
        feat0[60] = -12'sd1454;
        feat0[61] = -12'sd1417;
        feat0[62] = -12'sd1380;
        feat0[63] = -12'sd1343;
        feat0[64] = -12'sd1306;
        feat0[65] = -12'sd1269;
        feat0[66] = -12'sd1232;
        feat0[67] = -12'sd1195;
        feat0[68] = -12'sd1158;
        feat0[69] = -12'sd1121;
        feat0[70] = -12'sd1084;
        feat0[71] = -12'sd1047;
        feat0[72] = -12'sd1010;
        feat0[73] = -12'sd973;
        feat0[74] = -12'sd936;
        feat0[75] = -12'sd899;
        feat0[76] = -12'sd862;
        feat0[77] = -12'sd825;
        feat0[78] = -12'sd788;
        feat0[79] = -12'sd751;
        feat0[80] = -12'sd714;
        feat0[81] = -12'sd677;
        feat0[82] = -12'sd640;
        feat0[83] = -12'sd603;
        feat0[84] = -12'sd566;
        feat0[85] = -12'sd529;
        feat0[86] = -12'sd492;
        feat0[87] = -12'sd455;
        feat0[88] = -12'sd418;
        feat0[89] = -12'sd381;
        feat0[90] = -12'sd344;
        feat0[91] = -12'sd307;
        feat0[92] = -12'sd270;
        feat0[93] = -12'sd233;
        feat0[94] = -12'sd196;
        feat0[95] = -12'sd159;
        feat0[96] = -12'sd1767;
        feat0[97] = -12'sd1730;
        feat0[98] = -12'sd1693;
        feat0[99] = -12'sd1656;
        feat0[100] = -12'sd1619;
        feat0[101] = -12'sd1582;
        feat0[102] = -12'sd1545;
        feat0[103] = -12'sd1508;
        feat0[104] = -12'sd1471;
        feat0[105] = -12'sd1434;
        feat0[106] = -12'sd1397;
        feat0[107] = -12'sd1360;
        feat0[108] = -12'sd1323;
        feat0[109] = -12'sd1286;
        feat0[110] = -12'sd1249;
        feat0[111] = -12'sd1212;
        feat0[112] = -12'sd1175;
        feat0[113] = -12'sd1138;
        feat0[114] = -12'sd1101;
        feat0[115] = -12'sd1064;
        feat0[116] = -12'sd1027;
        feat0[117] = -12'sd990;
        feat0[118] = -12'sd953;
        feat0[119] = -12'sd916;
        feat0[120] = -12'sd879;
        feat0[121] = -12'sd842;
        feat0[122] = -12'sd805;
        feat0[123] = -12'sd768;
        feat0[124] = -12'sd731;
        feat0[125] = -12'sd694;
        feat0[126] = -12'sd657;
        feat0[127] = -12'sd620;
        feat0[128] = -12'sd583;
        feat0[129] = -12'sd546;
        feat0[130] = -12'sd509;
        feat0[131] = -12'sd472;
        feat0[132] = -12'sd435;
        feat0[133] = -12'sd398;
        feat0[134] = -12'sd361;
        feat0[135] = -12'sd324;
        feat0[136] = -12'sd287;
        feat0[137] = -12'sd250;
        feat0[138] = -12'sd213;
        feat0[139] = -12'sd176;
        feat0[140] = -12'sd139;
        feat0[141] = -12'sd102;
        feat0[142] = -12'sd65;
        feat0[143] = -12'sd28;
        feat0[144] = -12'sd1636;
        feat0[145] = -12'sd1599;
        feat0[146] = -12'sd1562;
        feat0[147] = -12'sd1525;
        feat0[148] = -12'sd1488;
        feat0[149] = -12'sd1451;
        feat0[150] = -12'sd1414;
        feat0[151] = -12'sd1377;
        feat0[152] = -12'sd1340;
        feat0[153] = -12'sd1303;
        feat0[154] = -12'sd1266;
        feat0[155] = -12'sd1229;
        feat0[156] = -12'sd1192;
        feat0[157] = -12'sd1155;
        feat0[158] = -12'sd1118;
        feat0[159] = -12'sd1081;
        feat0[160] = -12'sd1044;
        feat0[161] = -12'sd1007;
        feat0[162] = -12'sd970;
        feat0[163] = -12'sd933;
        feat0[164] = -12'sd896;
        feat0[165] = -12'sd859;
        feat0[166] = -12'sd822;
        feat0[167] = -12'sd785;
        feat0[168] = -12'sd748;
        feat0[169] = -12'sd711;
        feat0[170] = -12'sd674;
        feat0[171] = -12'sd637;
        feat0[172] = -12'sd600;
        feat0[173] = -12'sd563;
        feat0[174] = -12'sd526;
        feat0[175] = -12'sd489;
        feat0[176] = -12'sd452;
        feat0[177] = -12'sd415;
        feat0[178] = -12'sd378;
        feat0[179] = -12'sd341;
        feat0[180] = -12'sd304;
        feat0[181] = -12'sd267;
        feat0[182] = -12'sd230;
        feat0[183] = -12'sd193;
        feat0[184] = -12'sd156;
        feat0[185] = -12'sd119;
        feat0[186] = -12'sd82;
        feat0[187] = -12'sd45;
        feat0[188] = -12'sd8;
        feat0[189] = 12'sd29;
        feat0[190] = 12'sd66;
        feat0[191] = 12'sd103;
        feat0[192] = -12'sd1772;
        feat0[193] = -12'sd1735;
        feat0[194] = -12'sd1698;
        feat0[195] = -12'sd1661;
        feat0[196] = -12'sd1624;
        feat0[197] = -12'sd1587;
        feat0[198] = -12'sd1550;
        feat0[199] = -12'sd1513;
        feat0[200] = -12'sd1476;
        feat0[201] = -12'sd1439;
        feat0[202] = -12'sd1402;
        feat0[203] = -12'sd1365;
        feat0[204] = -12'sd1328;
        feat0[205] = -12'sd1291;
        feat0[206] = -12'sd1254;
        feat0[207] = -12'sd1217;
        feat0[208] = -12'sd1180;
        feat0[209] = -12'sd1143;
        feat0[210] = -12'sd1106;
        feat0[211] = -12'sd1069;
        feat0[212] = -12'sd1032;
        feat0[213] = -12'sd995;
        feat0[214] = -12'sd958;
        feat0[215] = -12'sd921;
        feat0[216] = -12'sd884;
        feat0[217] = -12'sd847;
        feat0[218] = -12'sd810;
        feat0[219] = -12'sd773;
        feat0[220] = -12'sd736;
        feat0[221] = -12'sd699;
        feat0[222] = -12'sd662;
        feat0[223] = -12'sd625;
        feat0[224] = -12'sd588;
        feat0[225] = -12'sd551;
        feat0[226] = -12'sd514;
        feat0[227] = -12'sd477;
        feat0[228] = -12'sd440;
        feat0[229] = -12'sd403;
        feat0[230] = -12'sd366;
        feat0[231] = -12'sd329;
        feat0[232] = -12'sd292;
        feat0[233] = -12'sd255;
        feat0[234] = -12'sd218;
        feat0[235] = -12'sd181;
        feat0[236] = -12'sd144;
        feat0[237] = -12'sd107;
        feat0[238] = -12'sd70;
        feat0[239] = -12'sd33;
        feat0[240] = -12'sd1641;
        feat0[241] = -12'sd1604;
        feat0[242] = -12'sd1567;
        feat0[243] = -12'sd1530;
        feat0[244] = -12'sd1493;
        feat0[245] = -12'sd1456;
        feat0[246] = -12'sd1419;
        feat0[247] = -12'sd1382;
        feat0[248] = -12'sd1345;
        feat0[249] = -12'sd1308;
        feat0[250] = -12'sd1271;
        feat0[251] = -12'sd1234;
        feat0[252] = -12'sd1197;
        feat0[253] = -12'sd1160;
        feat0[254] = -12'sd1123;
        feat0[255] = -12'sd1086;
        feat0[256] = -12'sd1049;
        feat0[257] = -12'sd1012;
        feat0[258] = -12'sd975;
        feat0[259] = -12'sd938;
        feat0[260] = -12'sd901;
        feat0[261] = -12'sd864;
        feat0[262] = -12'sd827;
        feat0[263] = -12'sd790;
        feat0[264] = -12'sd753;
        feat0[265] = -12'sd716;
        feat0[266] = -12'sd679;
        feat0[267] = -12'sd642;
        feat0[268] = -12'sd605;
        feat0[269] = -12'sd568;
        feat0[270] = -12'sd531;
        feat0[271] = -12'sd494;
        feat0[272] = -12'sd457;
        feat0[273] = -12'sd420;
        feat0[274] = -12'sd383;
        feat0[275] = -12'sd346;
        feat0[276] = -12'sd309;
        feat0[277] = -12'sd272;
        feat0[278] = -12'sd235;
        feat0[279] = -12'sd198;
        feat0[280] = -12'sd161;
        feat0[281] = -12'sd124;
        feat0[282] = -12'sd87;
        feat0[283] = -12'sd50;
        feat0[284] = -12'sd13;
        feat0[285] = 12'sd24;
        feat0[286] = 12'sd61;
        feat0[287] = 12'sd98;
        feat0[288] = -12'sd1510;
        feat0[289] = -12'sd1473;
        feat0[290] = -12'sd1436;
        feat0[291] = -12'sd1399;
        feat0[292] = -12'sd1362;
        feat0[293] = -12'sd1325;
        feat0[294] = -12'sd1288;
        feat0[295] = -12'sd1251;
        feat0[296] = -12'sd1214;
        feat0[297] = -12'sd1177;
        feat0[298] = -12'sd1140;
        feat0[299] = -12'sd1103;
        feat0[300] = -12'sd1066;
        feat0[301] = -12'sd1029;
        feat0[302] = -12'sd992;
        feat0[303] = -12'sd955;
        feat0[304] = -12'sd918;
        feat0[305] = -12'sd881;
        feat0[306] = -12'sd844;
        feat0[307] = -12'sd807;
        feat0[308] = -12'sd770;
        feat0[309] = -12'sd733;
        feat0[310] = -12'sd696;
        feat0[311] = -12'sd659;
        feat0[312] = -12'sd622;
        feat0[313] = -12'sd585;
        feat0[314] = -12'sd548;
        feat0[315] = -12'sd511;
        feat0[316] = -12'sd474;
        feat0[317] = -12'sd437;
        feat0[318] = -12'sd400;
        feat0[319] = -12'sd363;
        feat0[320] = -12'sd326;
        feat0[321] = -12'sd289;
        feat0[322] = -12'sd252;
        feat0[323] = -12'sd215;
        feat0[324] = -12'sd178;
        feat0[325] = -12'sd141;
        feat0[326] = -12'sd104;
        feat0[327] = -12'sd67;
        feat0[328] = -12'sd30;
        feat0[329] = 12'sd7;
        feat0[330] = 12'sd44;
        feat0[331] = 12'sd81;
        feat0[332] = 12'sd118;
        feat0[333] = 12'sd155;
        feat0[334] = 12'sd192;
        feat0[335] = 12'sd229;
        feat0[336] = -12'sd1379;
        feat0[337] = -12'sd1342;
        feat0[338] = -12'sd1305;
        feat0[339] = -12'sd1268;
        feat0[340] = -12'sd1231;
        feat0[341] = -12'sd1194;
        feat0[342] = -12'sd1157;
        feat0[343] = -12'sd1120;
        feat0[344] = -12'sd1083;
        feat0[345] = -12'sd1046;
        feat0[346] = -12'sd1009;
        feat0[347] = -12'sd972;
        feat0[348] = -12'sd935;
        feat0[349] = -12'sd898;
        feat0[350] = -12'sd861;
        feat0[351] = -12'sd824;
        feat0[352] = -12'sd787;
        feat0[353] = -12'sd750;
        feat0[354] = -12'sd713;
        feat0[355] = -12'sd676;
        feat0[356] = -12'sd639;
        feat0[357] = -12'sd602;
        feat0[358] = -12'sd565;
        feat0[359] = -12'sd528;
        feat0[360] = -12'sd491;
        feat0[361] = -12'sd454;
        feat0[362] = -12'sd417;
        feat0[363] = -12'sd380;
        feat0[364] = -12'sd343;
        feat0[365] = -12'sd306;
        feat0[366] = -12'sd269;
        feat0[367] = -12'sd232;
        feat0[368] = -12'sd195;
        feat0[369] = -12'sd158;
        feat0[370] = -12'sd121;
        feat0[371] = -12'sd84;
        feat0[372] = -12'sd47;
        feat0[373] = -12'sd10;
        feat0[374] = 12'sd27;
        feat0[375] = 12'sd64;
        feat0[376] = 12'sd101;
        feat0[377] = 12'sd138;
        feat0[378] = 12'sd175;
        feat0[379] = 12'sd212;
        feat0[380] = 12'sd249;
        feat0[381] = 12'sd286;
        feat0[382] = 12'sd323;
        feat0[383] = 12'sd360;
        feat0[384] = -12'sd1515;
        feat0[385] = -12'sd1478;
        feat0[386] = -12'sd1441;
        feat0[387] = -12'sd1404;
        feat0[388] = -12'sd1367;
        feat0[389] = -12'sd1330;
        feat0[390] = -12'sd1293;
        feat0[391] = -12'sd1256;
        feat0[392] = -12'sd1219;
        feat0[393] = -12'sd1182;
        feat0[394] = -12'sd1145;
        feat0[395] = -12'sd1108;
        feat0[396] = -12'sd1071;
        feat0[397] = -12'sd1034;
        feat0[398] = -12'sd997;
        feat0[399] = -12'sd960;
        feat0[400] = -12'sd923;
        feat0[401] = -12'sd886;
        feat0[402] = -12'sd849;
        feat0[403] = -12'sd812;
        feat0[404] = -12'sd775;
        feat0[405] = -12'sd738;
        feat0[406] = -12'sd701;
        feat0[407] = -12'sd664;
        feat0[408] = -12'sd627;
        feat0[409] = -12'sd590;
        feat0[410] = -12'sd553;
        feat0[411] = -12'sd516;
        feat0[412] = -12'sd479;
        feat0[413] = -12'sd442;
        feat0[414] = -12'sd405;
        feat0[415] = -12'sd368;
        feat0[416] = -12'sd331;
        feat0[417] = -12'sd294;
        feat0[418] = -12'sd257;
        feat0[419] = -12'sd220;
        feat0[420] = -12'sd183;
        feat0[421] = -12'sd146;
        feat0[422] = -12'sd109;
        feat0[423] = -12'sd72;
        feat0[424] = -12'sd35;
        feat0[425] = 12'sd2;
        feat0[426] = 12'sd39;
        feat0[427] = 12'sd76;
        feat0[428] = 12'sd113;
        feat0[429] = 12'sd150;
        feat0[430] = 12'sd187;
        feat0[431] = 12'sd224;
        feat0[432] = -12'sd1384;
        feat0[433] = -12'sd1347;
        feat0[434] = -12'sd1310;
        feat0[435] = -12'sd1273;
        feat0[436] = -12'sd1236;
        feat0[437] = -12'sd1199;
        feat0[438] = -12'sd1162;
        feat0[439] = -12'sd1125;
        feat0[440] = -12'sd1088;
        feat0[441] = -12'sd1051;
        feat0[442] = -12'sd1014;
        feat0[443] = -12'sd977;
        feat0[444] = -12'sd940;
        feat0[445] = -12'sd903;
        feat0[446] = -12'sd866;
        feat0[447] = -12'sd829;
        feat0[448] = -12'sd792;
        feat0[449] = -12'sd755;
        feat0[450] = -12'sd718;
        feat0[451] = -12'sd681;
        feat0[452] = -12'sd644;
        feat0[453] = -12'sd607;
        feat0[454] = -12'sd570;
        feat0[455] = -12'sd533;
        feat0[456] = -12'sd496;
        feat0[457] = -12'sd459;
        feat0[458] = -12'sd422;
        feat0[459] = -12'sd385;
        feat0[460] = -12'sd348;
        feat0[461] = -12'sd311;
        feat0[462] = -12'sd274;
        feat0[463] = -12'sd237;
        feat0[464] = -12'sd200;
        feat0[465] = -12'sd163;
        feat0[466] = -12'sd126;
        feat0[467] = -12'sd89;
        feat0[468] = -12'sd52;
        feat0[469] = -12'sd15;
        feat0[470] = 12'sd22;
        feat0[471] = 12'sd59;
        feat0[472] = 12'sd96;
        feat0[473] = 12'sd133;
        feat0[474] = 12'sd170;
        feat0[475] = 12'sd207;
        feat0[476] = 12'sd244;
        feat0[477] = 12'sd281;
        feat0[478] = 12'sd318;
        feat0[479] = 12'sd355;
        feat0[480] = -12'sd1253;
        feat0[481] = -12'sd1216;
        feat0[482] = -12'sd1179;
        feat0[483] = -12'sd1142;
        feat0[484] = -12'sd1105;
        feat0[485] = -12'sd1068;
        feat0[486] = -12'sd1031;
        feat0[487] = -12'sd994;
        feat0[488] = -12'sd957;
        feat0[489] = -12'sd920;
        feat0[490] = -12'sd883;
        feat0[491] = -12'sd846;
        feat0[492] = -12'sd809;
        feat0[493] = -12'sd772;
        feat0[494] = -12'sd735;
        feat0[495] = -12'sd698;
        feat0[496] = -12'sd661;
        feat0[497] = -12'sd624;
        feat0[498] = -12'sd587;
        feat0[499] = -12'sd550;
        feat0[500] = -12'sd513;
        feat0[501] = -12'sd476;
        feat0[502] = -12'sd439;
        feat0[503] = -12'sd402;
        feat0[504] = -12'sd365;
        feat0[505] = -12'sd328;
        feat0[506] = -12'sd291;
        feat0[507] = -12'sd254;
        feat0[508] = -12'sd217;
        feat0[509] = -12'sd180;
        feat0[510] = -12'sd143;
        feat0[511] = -12'sd106;
        feat0[512] = -12'sd69;
        feat0[513] = -12'sd32;
        feat0[514] = 12'sd5;
        feat0[515] = 12'sd42;
        feat0[516] = 12'sd79;
        feat0[517] = 12'sd116;
        feat0[518] = 12'sd153;
        feat0[519] = 12'sd190;
        feat0[520] = 12'sd227;
        feat0[521] = 12'sd264;
        feat0[522] = 12'sd301;
        feat0[523] = 12'sd338;
        feat0[524] = 12'sd375;
        feat0[525] = 12'sd412;
        feat0[526] = 12'sd449;
        feat0[527] = 12'sd486;
        feat0[528] = -12'sd1122;
        feat0[529] = -12'sd1085;
        feat0[530] = -12'sd1048;
        feat0[531] = -12'sd1011;
        feat0[532] = -12'sd974;
        feat0[533] = -12'sd937;
        feat0[534] = -12'sd900;
        feat0[535] = -12'sd863;
        feat0[536] = -12'sd826;
        feat0[537] = -12'sd789;
        feat0[538] = -12'sd752;
        feat0[539] = -12'sd715;
        feat0[540] = -12'sd678;
        feat0[541] = -12'sd641;
        feat0[542] = -12'sd604;
        feat0[543] = -12'sd567;
        feat0[544] = -12'sd530;
        feat0[545] = -12'sd493;
        feat0[546] = -12'sd456;
        feat0[547] = -12'sd419;
        feat0[548] = -12'sd382;
        feat0[549] = -12'sd345;
        feat0[550] = -12'sd308;
        feat0[551] = -12'sd271;
        feat0[552] = -12'sd234;
        feat0[553] = -12'sd197;
        feat0[554] = -12'sd160;
        feat0[555] = -12'sd123;
        feat0[556] = -12'sd86;
        feat0[557] = -12'sd49;
        feat0[558] = -12'sd12;
        feat0[559] = 12'sd25;
        feat0[560] = 12'sd62;
        feat0[561] = 12'sd99;
        feat0[562] = 12'sd136;
        feat0[563] = 12'sd173;
        feat0[564] = 12'sd210;
        feat0[565] = 12'sd247;
        feat0[566] = 12'sd284;
        feat0[567] = 12'sd321;
        feat0[568] = 12'sd358;
        feat0[569] = 12'sd395;
        feat0[570] = 12'sd432;
        feat0[571] = 12'sd469;
        feat0[572] = 12'sd506;
        feat0[573] = 12'sd543;
        feat0[574] = 12'sd580;
        feat0[575] = 12'sd617;
        feat0[576] = -12'sd1258;
        feat0[577] = -12'sd1221;
        feat0[578] = -12'sd1184;
        feat0[579] = -12'sd1147;
        feat0[580] = -12'sd1110;
        feat0[581] = -12'sd1073;
        feat0[582] = -12'sd1036;
        feat0[583] = -12'sd999;
        feat0[584] = -12'sd962;
        feat0[585] = -12'sd925;
        feat0[586] = -12'sd888;
        feat0[587] = -12'sd851;
        feat0[588] = -12'sd814;
        feat0[589] = -12'sd777;
        feat0[590] = -12'sd740;
        feat0[591] = -12'sd703;
        feat0[592] = -12'sd666;
        feat0[593] = -12'sd629;
        feat0[594] = -12'sd592;
        feat0[595] = -12'sd555;
        feat0[596] = -12'sd518;
        feat0[597] = -12'sd481;
        feat0[598] = -12'sd444;
        feat0[599] = -12'sd407;
        feat0[600] = -12'sd370;
        feat0[601] = -12'sd333;
        feat0[602] = -12'sd296;
        feat0[603] = -12'sd259;
        feat0[604] = -12'sd222;
        feat0[605] = -12'sd185;
        feat0[606] = -12'sd148;
        feat0[607] = -12'sd111;
        feat0[608] = -12'sd74;
        feat0[609] = -12'sd37;
        feat0[610] = 12'sd0;
        feat0[611] = 12'sd37;
        feat0[612] = 12'sd74;
        feat0[613] = 12'sd111;
        feat0[614] = 12'sd148;
        feat0[615] = 12'sd185;
        feat0[616] = 12'sd222;
        feat0[617] = 12'sd259;
        feat0[618] = 12'sd296;
        feat0[619] = 12'sd333;
        feat0[620] = 12'sd370;
        feat0[621] = 12'sd407;
        feat0[622] = 12'sd444;
        feat0[623] = 12'sd481;
        feat0[624] = -12'sd1127;
        feat0[625] = -12'sd1090;
        feat0[626] = -12'sd1053;
        feat0[627] = -12'sd1016;
        feat0[628] = -12'sd979;
        feat0[629] = -12'sd942;
        feat0[630] = -12'sd905;
        feat0[631] = -12'sd868;
        feat0[632] = -12'sd831;
        feat0[633] = -12'sd794;
        feat0[634] = -12'sd757;
        feat0[635] = -12'sd720;
        feat0[636] = -12'sd683;
        feat0[637] = -12'sd646;
        feat0[638] = -12'sd609;
        feat0[639] = -12'sd572;
        feat0[640] = -12'sd535;
        feat0[641] = -12'sd498;
        feat0[642] = -12'sd461;
        feat0[643] = -12'sd424;
        feat0[644] = -12'sd387;
        feat0[645] = -12'sd350;
        feat0[646] = -12'sd313;
        feat0[647] = -12'sd276;
        feat0[648] = -12'sd239;
        feat0[649] = -12'sd202;
        feat0[650] = -12'sd165;
        feat0[651] = -12'sd128;
        feat0[652] = -12'sd91;
        feat0[653] = -12'sd54;
        feat0[654] = -12'sd17;
        feat0[655] = 12'sd20;
        feat0[656] = 12'sd57;
        feat0[657] = 12'sd94;
        feat0[658] = 12'sd131;
        feat0[659] = 12'sd168;
        feat0[660] = 12'sd205;
        feat0[661] = 12'sd242;
        feat0[662] = 12'sd279;
        feat0[663] = 12'sd316;
        feat0[664] = 12'sd353;
        feat0[665] = 12'sd390;
        feat0[666] = 12'sd427;
        feat0[667] = 12'sd464;
        feat0[668] = 12'sd501;
        feat0[669] = 12'sd538;
        feat0[670] = 12'sd575;
        feat0[671] = 12'sd612;
        feat0[672] = -12'sd996;
        feat0[673] = -12'sd959;
        feat0[674] = -12'sd922;
        feat0[675] = -12'sd885;
        feat0[676] = -12'sd848;
        feat0[677] = -12'sd811;
        feat0[678] = -12'sd774;
        feat0[679] = -12'sd737;
        feat0[680] = -12'sd700;
        feat0[681] = -12'sd663;
        feat0[682] = -12'sd626;
        feat0[683] = -12'sd589;
        feat0[684] = -12'sd552;
        feat0[685] = -12'sd515;
        feat0[686] = -12'sd478;
        feat0[687] = -12'sd441;
        feat0[688] = -12'sd404;
        feat0[689] = -12'sd367;
        feat0[690] = -12'sd330;
        feat0[691] = -12'sd293;
        feat0[692] = -12'sd256;
        feat0[693] = -12'sd219;
        feat0[694] = -12'sd182;
        feat0[695] = -12'sd145;
        feat0[696] = -12'sd108;
        feat0[697] = -12'sd71;
        feat0[698] = -12'sd34;
        feat0[699] = 12'sd3;
        feat0[700] = 12'sd40;
        feat0[701] = 12'sd77;
        feat0[702] = 12'sd114;
        feat0[703] = 12'sd151;
        feat0[704] = 12'sd188;
        feat0[705] = 12'sd225;
        feat0[706] = 12'sd262;
        feat0[707] = 12'sd299;
        feat0[708] = 12'sd336;
        feat0[709] = 12'sd373;
        feat0[710] = 12'sd410;
        feat0[711] = 12'sd447;
        feat0[712] = 12'sd484;
        feat0[713] = 12'sd521;
        feat0[714] = 12'sd558;
        feat0[715] = 12'sd595;
        feat0[716] = 12'sd632;
        feat0[717] = 12'sd669;
        feat0[718] = 12'sd706;
        feat0[719] = 12'sd743;
        feat0[720] = -12'sd865;
        feat0[721] = -12'sd828;
        feat0[722] = -12'sd791;
        feat0[723] = -12'sd754;
        feat0[724] = -12'sd717;
        feat0[725] = -12'sd680;
        feat0[726] = -12'sd643;
        feat0[727] = -12'sd606;
        feat0[728] = -12'sd569;
        feat0[729] = -12'sd532;
        feat0[730] = -12'sd495;
        feat0[731] = -12'sd458;
        feat0[732] = -12'sd421;
        feat0[733] = -12'sd384;
        feat0[734] = -12'sd347;
        feat0[735] = -12'sd310;
        feat0[736] = -12'sd273;
        feat0[737] = -12'sd236;
        feat0[738] = -12'sd199;
        feat0[739] = -12'sd162;
        feat0[740] = -12'sd125;
        feat0[741] = -12'sd88;
        feat0[742] = -12'sd51;
        feat0[743] = -12'sd14;
        feat0[744] = 12'sd23;
        feat0[745] = 12'sd60;
        feat0[746] = 12'sd97;
        feat0[747] = 12'sd134;
        feat0[748] = 12'sd171;
        feat0[749] = 12'sd208;
        feat0[750] = 12'sd245;
        feat0[751] = 12'sd282;
        feat0[752] = 12'sd319;
        feat0[753] = 12'sd356;
        feat0[754] = 12'sd393;
        feat0[755] = 12'sd430;
        feat0[756] = 12'sd467;
        feat0[757] = 12'sd504;
        feat0[758] = 12'sd541;
        feat0[759] = 12'sd578;
        feat0[760] = 12'sd615;
        feat0[761] = 12'sd652;
        feat0[762] = 12'sd689;
        feat0[763] = 12'sd726;
        feat0[764] = 12'sd763;
        feat0[765] = 12'sd800;
        feat0[766] = 12'sd837;
        feat0[767] = 12'sd874;

        expected[0] = 12'sd1098;
        expected[1] = 12'sd2047;
        expected[2] = 12'sd1053;
        expected[3] = -12'sd601;
        expected[4] = -12'sd180;
        expected[5] = -12'sd248;
        expected[6] = 12'sd886;
        expected[7] = 12'sd947;
        expected[8] = -12'sd739;
        expected[9] = 12'sd1686;
        expected[10] = 12'sd1749;
        expected[11] = 12'sd933;
        expected[12] = 12'sd178;
        expected[13] = 12'sd263;
        expected[14] = 12'sd1529;
        expected[15] = -12'sd224;
        expected[16] = 12'sd583;
        expected[17] = -12'sd110;
        expected[18] = -12'sd133;
        expected[19] = 12'sd2047;
        expected[20] = -12'sd484;
        expected[21] = 12'sd1001;
        expected[22] = 12'sd1583;
        expected[23] = 12'sd1253;
        expected[24] = 12'sd668;
        expected[25] = 12'sd1802;
        expected[26] = 12'sd1177;
        expected[27] = 12'sd106;
        expected[28] = 12'sd563;
        expected[29] = -12'sd104;
        expected[30] = 12'sd268;
        expected[31] = 12'sd1430;
        expected[32] = 12'sd515;
        expected[33] = 12'sd1471;
        expected[34] = 12'sd2047;
        expected[35] = 12'sd2047;
        expected[36] = 12'sd1037;
        expected[37] = 12'sd1789;
        expected[38] = 12'sd1461;
        expected[39] = 12'sd908;
        expected[40] = 12'sd1335;
        expected[41] = 12'sd246;
        expected[42] = -12'sd435;
        expected[43] = 12'sd1235;
        expected[44] = -12'sd27;
        expected[45] = -12'sd782;
        expected[46] = 12'sd799;
        expected[47] = 12'sd719;
        expected[48] = 12'sd2047;
        expected[49] = 12'sd2047;
        expected[50] = 12'sd1270;
        expected[51] = 12'sd2001;
        expected[52] = 12'sd2047;
        expected[53] = 12'sd2047;
        expected[54] = 12'sd2047;
        expected[55] = 12'sd1816;
        expected[56] = 12'sd1190;
        expected[57] = 12'sd970;
        expected[58] = 12'sd1712;
        expected[59] = -12'sd423;
        expected[60] = 12'sd2047;
        expected[61] = 12'sd2047;
        expected[62] = 12'sd301;
        expected[63] = 12'sd1550;
        expected[64] = 12'sd2047;
        expected[65] = 12'sd1241;
        expected[66] = 12'sd314;
        expected[67] = 12'sd1309;
        expected[68] = 12'sd321;
        expected[69] = 12'sd1141;
        expected[70] = 12'sd1123;
        expected[71] = -12'sd1198;
        expected[72] = 12'sd2047;
        expected[73] = 12'sd2047;
        expected[74] = 12'sd356;
        expected[75] = 12'sd1623;
        expected[76] = 12'sd2047;
        expected[77] = 12'sd1121;
        expected[78] = 12'sd941;
        expected[79] = 12'sd1304;
        expected[80] = 12'sd1051;
        expected[81] = 12'sd1296;
        expected[82] = 12'sd1503;
        expected[83] = 12'sd327;
        expected[84] = 12'sd2047;
        expected[85] = 12'sd2047;
        expected[86] = 12'sd1199;
        expected[87] = 12'sd1420;
        expected[88] = 12'sd525;
        expected[89] = -12'sd86;
        expected[90] = 12'sd1541;
        expected[91] = 12'sd2047;
        expected[92] = 12'sd1427;
        expected[93] = -12'sd82;
        expected[94] = 12'sd91;
        expected[95] = -12'sd216;
        expected[96] = 12'sd1783;
        expected[97] = 12'sd985;
        expected[98] = -12'sd66;
        expected[99] = 12'sd755;
        expected[100] = 12'sd2047;
        expected[101] = -12'sd132;
        expected[102] = 12'sd1655;
        expected[103] = 12'sd800;
        expected[104] = 12'sd751;
        expected[105] = 12'sd424;
        expected[106] = 12'sd605;
        expected[107] = -12'sd552;
        expected[108] = 12'sd2047;
        expected[109] = 12'sd1093;
        expected[110] = -12'sd434;
        expected[111] = 12'sd106;
        expected[112] = -12'sd172;
        expected[113] = -12'sd712;
        expected[114] = 12'sd301;
        expected[115] = -12'sd246;
        expected[116] = -12'sd198;
        expected[117] = 12'sd108;
        expected[118] = 12'sd1856;
        expected[119] = -12'sd486;
        expected[120] = 12'sd2047;
        expected[121] = 12'sd1033;
        expected[122] = -12'sd212;
        expected[123] = 12'sd1243;
        expected[124] = -12'sd183;
        expected[125] = -12'sd775;
        expected[126] = 12'sd1394;
        expected[127] = 12'sd600;
        expected[128] = 12'sd1349;
        expected[129] = 12'sd2047;
        expected[130] = 12'sd1744;
        expected[131] = 12'sd772;
        expected[132] = 12'sd1998;
        expected[133] = 12'sd1860;
        expected[134] = 12'sd2047;
        expected[135] = 12'sd2047;
        expected[136] = -12'sd854;
        expected[137] = 12'sd494;
        expected[138] = 12'sd1441;
        expected[139] = 12'sd673;
        expected[140] = 12'sd2008;
        expected[141] = 12'sd1062;
        expected[142] = 12'sd1134;
        expected[143] = 12'sd810;
        expected[144] = 12'sd1042;
        expected[145] = -12'sd757;
        expected[146] = 12'sd1109;
        expected[147] = 12'sd428;
        expected[148] = 12'sd1414;
        expected[149] = 12'sd1290;
        expected[150] = -12'sd38;
        expected[151] = 12'sd497;
        expected[152] = 12'sd1566;
        expected[153] = 12'sd2047;
        expected[154] = 12'sd977;
        expected[155] = -12'sd375;
        expected[156] = 12'sd1512;
        expected[157] = -12'sd371;
        expected[158] = -12'sd929;
        expected[159] = -12'sd127;
        expected[160] = -12'sd240;
        expected[161] = -12'sd706;
        expected[162] = 12'sd434;
        expected[163] = 12'sd263;
        expected[164] = -12'sd267;
        expected[165] = 12'sd1203;
        expected[166] = 12'sd1013;
        expected[167] = 12'sd384;
        expected[168] = 12'sd1651;
        expected[169] = -12'sd77;
        expected[170] = -12'sd1577;
        expected[171] = 12'sd105;
        expected[172] = 12'sd826;
        expected[173] = -12'sd971;
        expected[174] = 12'sd2036;
        expected[175] = 12'sd1711;
        expected[176] = 12'sd1296;
        expected[177] = 12'sd1793;
        expected[178] = 12'sd867;
        expected[179] = 12'sd2047;
        expected[180] = 12'sd164;
        expected[181] = 12'sd614;
        expected[182] = -12'sd1296;
        expected[183] = 12'sd232;
        expected[184] = 12'sd73;
        expected[185] = 12'sd51;
        expected[186] = 12'sd2047;
        expected[187] = 12'sd1118;
        expected[188] = 12'sd805;
        expected[189] = 12'sd1063;
        expected[190] = 12'sd1616;
        expected[191] = 12'sd2047;
        expected[192] = 12'sd2047;
        expected[193] = -12'sd225;
        expected[194] = 12'sd1741;
        expected[195] = 12'sd772;
        expected[196] = 12'sd779;
        expected[197] = 12'sd483;
        expected[198] = 12'sd2047;
        expected[199] = 12'sd817;
        expected[200] = -12'sd894;
        expected[201] = 12'sd1245;
        expected[202] = 12'sd42;
        expected[203] = -12'sd511;
        expected[204] = 12'sd1796;
        expected[205] = 12'sd631;
        expected[206] = -12'sd264;
        expected[207] = 12'sd642;
        expected[208] = 12'sd401;
        expected[209] = 12'sd149;
        expected[210] = 12'sd2047;
        expected[211] = 12'sd1351;
        expected[212] = 12'sd578;
        expected[213] = 12'sd1748;
        expected[214] = 12'sd1553;
        expected[215] = 12'sd1389;
        expected[216] = 12'sd1365;
        expected[217] = -12'sd701;
        expected[218] = -12'sd146;
        expected[219] = 12'sd591;
        expected[220] = 12'sd654;
        expected[221] = 12'sd648;
        expected[222] = 12'sd2047;
        expected[223] = 12'sd2047;
        expected[224] = 12'sd633;
        expected[225] = 12'sd2047;
        expected[226] = 12'sd2047;
        expected[227] = 12'sd2047;
        expected[228] = 12'sd2047;
        expected[229] = 12'sd2047;
        expected[230] = 12'sd1411;
        expected[231] = 12'sd1734;
        expected[232] = 12'sd842;
        expected[233] = 12'sd590;
        expected[234] = 12'sd2047;
        expected[235] = 12'sd1172;
        expected[236] = 12'sd1743;
        expected[237] = 12'sd789;
        expected[238] = 12'sd2047;
        expected[239] = 12'sd1704;
        expected[240] = 12'sd2047;
        expected[241] = 12'sd2047;
        expected[242] = 12'sd1901;
        expected[243] = 12'sd894;
        expected[244] = 12'sd933;
        expected[245] = 12'sd2047;
        expected[246] = 12'sd1103;
        expected[247] = 12'sd841;
        expected[248] = 12'sd81;
        expected[249] = 12'sd401;
        expected[250] = -12'sd516;
        expected[251] = -12'sd1054;
        expected[252] = 12'sd1937;
        expected[253] = 12'sd1556;
        expected[254] = 12'sd599;
        expected[255] = 12'sd1508;
        expected[256] = 12'sd1110;
        expected[257] = 12'sd1354;
        expected[258] = 12'sd1184;
        expected[259] = 12'sd778;
        expected[260] = 12'sd455;
        expected[261] = 12'sd1729;
        expected[262] = 12'sd240;
        expected[263] = 12'sd758;
        expected[264] = 12'sd2047;
        expected[265] = 12'sd690;
        expected[266] = 12'sd706;
        expected[267] = 12'sd1561;
        expected[268] = 12'sd1512;
        expected[269] = 12'sd1431;
        expected[270] = 12'sd1867;
        expected[271] = 12'sd1544;
        expected[272] = -12'sd142;
        expected[273] = 12'sd1448;
        expected[274] = 12'sd793;
        expected[275] = 12'sd728;
        expected[276] = 12'sd1608;
        expected[277] = 12'sd1838;
        expected[278] = 12'sd1715;
        expected[279] = 12'sd1544;
        expected[280] = 12'sd1018;
        expected[281] = 12'sd724;
        expected[282] = 12'sd2047;
        expected[283] = 12'sd2047;
        expected[284] = 12'sd964;
        expected[285] = -12'sd149;
        expected[286] = 12'sd1968;
        expected[287] = 12'sd891;
        expected[288] = 12'sd1659;
        expected[289] = 12'sd1321;
        expected[290] = -12'sd858;
        expected[291] = -12'sd530;
        expected[292] = 12'sd1303;
        expected[293] = -12'sd784;
        expected[294] = 12'sd651;
        expected[295] = 12'sd484;
        expected[296] = -12'sd1459;
        expected[297] = 12'sd711;
        expected[298] = 12'sd1986;
        expected[299] = -12'sd906;
        expected[300] = 12'sd1974;
        expected[301] = 12'sd801;
        expected[302] = -12'sd572;
        expected[303] = -12'sd387;
        expected[304] = -12'sd419;
        expected[305] = -12'sd259;
        expected[306] = 12'sd748;
        expected[307] = 12'sd214;
        expected[308] = -12'sd661;
        expected[309] = 12'sd2032;
        expected[310] = 12'sd1919;
        expected[311] = -12'sd1025;
        expected[312] = 12'sd2047;
        expected[313] = -12'sd792;
        expected[314] = -12'sd1324;
        expected[315] = -12'sd368;
        expected[316] = -12'sd13;
        expected[317] = -12'sd72;
        expected[318] = 12'sd651;
        expected[319] = 12'sd1063;
        expected[320] = -12'sd337;
        expected[321] = 12'sd432;
        expected[322] = 12'sd2047;
        expected[323] = -12'sd451;
        expected[324] = 12'sd2047;
        expected[325] = -12'sd124;
        expected[326] = 12'sd629;
        expected[327] = 12'sd1729;
        expected[328] = 12'sd346;
        expected[329] = 12'sd219;
        expected[330] = 12'sd2047;
        expected[331] = 12'sd2047;
        expected[332] = 12'sd1494;
        expected[333] = 12'sd1387;
        expected[334] = 12'sd1684;
        expected[335] = 12'sd665;
        expected[336] = 12'sd1362;
        expected[337] = -12'sd853;
        expected[338] = -12'sd1055;
        expected[339] = -12'sd127;
        expected[340] = 12'sd233;
        expected[341] = -12'sd1096;
        expected[342] = -12'sd46;
        expected[343] = 12'sd1071;
        expected[344] = -12'sd1552;
        expected[345] = 12'sd444;
        expected[346] = 12'sd2047;
        expected[347] = -12'sd673;
        expected[348] = 12'sd1218;
        expected[349] = 12'sd472;
        expected[350] = -12'sd2048;
        expected[351] = 12'sd1644;
        expected[352] = -12'sd54;
        expected[353] = -12'sd716;
        expected[354] = 12'sd2047;
        expected[355] = 12'sd595;
        expected[356] = 12'sd661;
        expected[357] = 12'sd1861;
        expected[358] = 12'sd319;
        expected[359] = 12'sd692;
        expected[360] = 12'sd193;
        expected[361] = 12'sd338;
        expected[362] = -12'sd1257;
        expected[363] = 12'sd895;
        expected[364] = 12'sd506;
        expected[365] = -12'sd201;
        expected[366] = 12'sd967;
        expected[367] = 12'sd554;
        expected[368] = -12'sd961;
        expected[369] = 12'sd812;
        expected[370] = 12'sd1424;
        expected[371] = 12'sd1008;
        expected[372] = -12'sd442;
        expected[373] = 12'sd814;
        expected[374] = -12'sd98;
        expected[375] = 12'sd1226;
        expected[376] = 12'sd1400;
        expected[377] = 12'sd259;
        expected[378] = 12'sd2047;
        expected[379] = 12'sd1611;
        expected[380] = 12'sd932;
        expected[381] = 12'sd1222;
        expected[382] = 12'sd934;
        expected[383] = 12'sd1948;
        expected[384] = 12'sd1516;
        expected[385] = -12'sd333;
        expected[386] = 12'sd434;
        expected[387] = -12'sd177;
        expected[388] = 12'sd1200;
        expected[389] = -12'sd2042;
        expected[390] = 12'sd2047;
        expected[391] = 12'sd872;
        expected[392] = 12'sd111;
        expected[393] = 12'sd1138;
        expected[394] = 12'sd189;
        expected[395] = -12'sd404;
        expected[396] = 12'sd1482;
        expected[397] = -12'sd247;
        expected[398] = -12'sd604;
        expected[399] = 12'sd2047;
        expected[400] = 12'sd507;
        expected[401] = 12'sd367;
        expected[402] = 12'sd2047;
        expected[403] = 12'sd67;
        expected[404] = 12'sd1766;
        expected[405] = 12'sd2047;
        expected[406] = 12'sd1273;
        expected[407] = 12'sd660;
        expected[408] = 12'sd1866;
        expected[409] = -12'sd429;
        expected[410] = 12'sd245;
        expected[411] = 12'sd1462;
        expected[412] = 12'sd237;
        expected[413] = 12'sd1366;
        expected[414] = 12'sd2047;
        expected[415] = -12'sd700;
        expected[416] = 12'sd1437;
        expected[417] = 12'sd2047;
        expected[418] = 12'sd2047;
        expected[419] = 12'sd1999;
        expected[420] = 12'sd2047;
        expected[421] = 12'sd576;
        expected[422] = 12'sd2047;
        expected[423] = 12'sd2002;
        expected[424] = 12'sd783;
        expected[425] = 12'sd2047;
        expected[426] = 12'sd2047;
        expected[427] = 12'sd886;
        expected[428] = 12'sd1606;
        expected[429] = 12'sd2047;
        expected[430] = 12'sd2047;
        expected[431] = 12'sd2047;
        expected[432] = 12'sd2047;
        expected[433] = 12'sd2047;
        expected[434] = -12'sd566;
        expected[435] = 12'sd1402;
        expected[436] = 12'sd197;
        expected[437] = 12'sd971;
        expected[438] = 12'sd467;
        expected[439] = 12'sd1022;
        expected[440] = 12'sd945;
        expected[441] = 12'sd1621;
        expected[442] = -12'sd592;
        expected[443] = -12'sd517;
        expected[444] = 12'sd2047;
        expected[445] = 12'sd1390;
        expected[446] = 12'sd749;
        expected[447] = 12'sd1292;
        expected[448] = 12'sd298;
        expected[449] = 12'sd697;
        expected[450] = 12'sd1570;
        expected[451] = 12'sd1362;
        expected[452] = 12'sd401;
        expected[453] = 12'sd1695;
        expected[454] = 12'sd731;
        expected[455] = -12'sd357;
        expected[456] = 12'sd1872;
        expected[457] = 12'sd1006;
        expected[458] = 12'sd1533;
        expected[459] = 12'sd1450;
        expected[460] = -12'sd88;
        expected[461] = 12'sd1159;
        expected[462] = 12'sd1713;
        expected[463] = 12'sd1362;
        expected[464] = 12'sd68;
        expected[465] = 12'sd399;
        expected[466] = 12'sd1256;
        expected[467] = 12'sd415;
        expected[468] = 12'sd2047;
        expected[469] = 12'sd2047;
        expected[470] = 12'sd2047;
        expected[471] = 12'sd2047;
        expected[472] = 12'sd970;
        expected[473] = 12'sd1390;
        expected[474] = 12'sd1376;
        expected[475] = 12'sd1646;
        expected[476] = 12'sd177;
        expected[477] = -12'sd699;
        expected[478] = 12'sd2047;
        expected[479] = 12'sd554;
        expected[480] = 12'sd2047;
        expected[481] = 12'sd1894;
        expected[482] = 12'sd496;
        expected[483] = -12'sd733;
        expected[484] = 12'sd673;
        expected[485] = 12'sd462;
        expected[486] = 12'sd833;
        expected[487] = -12'sd291;
        expected[488] = -12'sd171;
        expected[489] = 12'sd1415;
        expected[490] = 12'sd2047;
        expected[491] = -12'sd341;
        expected[492] = 12'sd1754;
        expected[493] = 12'sd1486;
        expected[494] = 12'sd372;
        expected[495] = 12'sd293;
        expected[496] = 12'sd68;
        expected[497] = -12'sd876;
        expected[498] = 12'sd1582;
        expected[499] = 12'sd1229;
        expected[500] = 12'sd591;
        expected[501] = 12'sd2047;
        expected[502] = 12'sd2047;
        expected[503] = 12'sd756;
        expected[504] = 12'sd2047;
        expected[505] = 12'sd145;
        expected[506] = 12'sd948;
        expected[507] = -12'sd617;
        expected[508] = 12'sd205;
        expected[509] = -12'sd685;
        expected[510] = 12'sd1657;
        expected[511] = 12'sd1609;
        expected[512] = 12'sd239;
        expected[513] = 12'sd1988;
        expected[514] = 12'sd2047;
        expected[515] = 12'sd644;
        expected[516] = 12'sd2018;
        expected[517] = 12'sd1080;
        expected[518] = 12'sd1208;
        expected[519] = 12'sd1407;
        expected[520] = 12'sd1679;
        expected[521] = 12'sd349;
        expected[522] = 12'sd2047;
        expected[523] = 12'sd2047;
        expected[524] = 12'sd595;
        expected[525] = 12'sd341;
        expected[526] = 12'sd2047;
        expected[527] = 12'sd1025;
        expected[528] = 12'sd1588;
        expected[529] = 12'sd803;
        expected[530] = -12'sd1195;
        expected[531] = 12'sd220;
        expected[532] = -12'sd638;
        expected[533] = -12'sd970;
        expected[534] = 12'sd979;
        expected[535] = 12'sd1979;
        expected[536] = -12'sd400;
        expected[537] = 12'sd54;
        expected[538] = 12'sd1432;
        expected[539] = 12'sd1924;
        expected[540] = 12'sd174;
        expected[541] = 12'sd829;
        expected[542] = -12'sd497;
        expected[543] = 12'sd1592;
        expected[544] = 12'sd422;
        expected[545] = -12'sd536;
        expected[546] = 12'sd2047;
        expected[547] = 12'sd2047;
        expected[548] = 12'sd447;
        expected[549] = 12'sd1514;
        expected[550] = 12'sd1161;
        expected[551] = 12'sd1192;
        expected[552] = 12'sd153;
        expected[553] = 12'sd556;
        expected[554] = 12'sd882;
        expected[555] = 12'sd814;
        expected[556] = -12'sd3;
        expected[557] = -12'sd407;
        expected[558] = 12'sd1560;
        expected[559] = 12'sd1823;
        expected[560] = 12'sd325;
        expected[561] = 12'sd1136;
        expected[562] = 12'sd1433;
        expected[563] = 12'sd1084;
        expected[564] = -12'sd463;
        expected[565] = 12'sd1211;
        expected[566] = 12'sd753;
        expected[567] = 12'sd804;
        expected[568] = 12'sd1592;
        expected[569] = 12'sd54;
        expected[570] = 12'sd1134;
        expected[571] = 12'sd507;
        expected[572] = -12'sd547;
        expected[573] = 12'sd666;
        expected[574] = 12'sd2030;
        expected[575] = 12'sd595;
        expected[576] = 12'sd807;
        expected[577] = 12'sd591;
        expected[578] = 12'sd1561;
        expected[579] = -12'sd361;
        expected[580] = 12'sd474;
        expected[581] = -12'sd845;
        expected[582] = 12'sd558;
        expected[583] = -12'sd85;
        expected[584] = 12'sd568;
        expected[585] = 12'sd297;
        expected[586] = -12'sd417;
        expected[587] = 12'sd40;
        expected[588] = 12'sd488;
        expected[589] = 12'sd296;
        expected[590] = 12'sd1067;
        expected[591] = 12'sd532;
        expected[592] = 12'sd94;
        expected[593] = 12'sd978;
        expected[594] = 12'sd541;
        expected[595] = 12'sd220;
        expected[596] = 12'sd1646;
        expected[597] = 12'sd2047;
        expected[598] = 12'sd1521;
        expected[599] = 12'sd1060;
        expected[600] = 12'sd257;
        expected[601] = -12'sd271;
        expected[602] = 12'sd405;
        expected[603] = -12'sd215;
        expected[604] = -12'sd462;
        expected[605] = 12'sd608;
        expected[606] = -12'sd123;
        expected[607] = -12'sd178;
        expected[608] = 12'sd1197;
        expected[609] = 12'sd1479;
        expected[610] = 12'sd1572;
        expected[611] = 12'sd330;
        expected[612] = 12'sd717;
        expected[613] = 12'sd1464;
        expected[614] = 12'sd1087;
        expected[615] = 12'sd42;
        expected[616] = -12'sd555;
        expected[617] = 12'sd334;
        expected[618] = 12'sd333;
        expected[619] = -12'sd326;
        expected[620] = 12'sd1439;
        expected[621] = 12'sd661;
        expected[622] = 12'sd1882;
        expected[623] = -12'sd935;
        expected[624] = 12'sd2047;
        expected[625] = 12'sd1601;
        expected[626] = -12'sd647;
        expected[627] = 12'sd1381;
        expected[628] = -12'sd275;
        expected[629] = 12'sd315;
        expected[630] = 12'sd1063;
        expected[631] = 12'sd1302;
        expected[632] = 12'sd946;
        expected[633] = 12'sd922;
        expected[634] = -12'sd1425;
        expected[635] = -12'sd848;
        expected[636] = 12'sd1041;
        expected[637] = 12'sd2047;
        expected[638] = 12'sd159;
        expected[639] = 12'sd2047;
        expected[640] = -12'sd262;
        expected[641] = 12'sd134;
        expected[642] = 12'sd1836;
        expected[643] = 12'sd929;
        expected[644] = 12'sd1089;
        expected[645] = 12'sd1349;
        expected[646] = 12'sd1139;
        expected[647] = 12'sd367;
        expected[648] = 12'sd1332;
        expected[649] = 12'sd2047;
        expected[650] = -12'sd304;
        expected[651] = 12'sd1322;
        expected[652] = -12'sd557;
        expected[653] = -12'sd241;
        expected[654] = 12'sd1061;
        expected[655] = 12'sd924;
        expected[656] = 12'sd11;
        expected[657] = 12'sd654;
        expected[658] = 12'sd1269;
        expected[659] = 12'sd77;
        expected[660] = -12'sd80;
        expected[661] = 12'sd1170;
        expected[662] = -12'sd171;
        expected[663] = 12'sd829;
        expected[664] = -12'sd320;
        expected[665] = 12'sd82;
        expected[666] = 12'sd1059;
        expected[667] = 12'sd1248;
        expected[668] = 12'sd552;
        expected[669] = -12'sd1364;
        expected[670] = 12'sd351;
        expected[671] = -12'sd1193;
        expected[672] = 12'sd1283;
        expected[673] = 12'sd883;
        expected[674] = -12'sd4;
        expected[675] = 12'sd345;
        expected[676] = -12'sd563;
        expected[677] = 12'sd1527;
        expected[678] = 12'sd1696;
        expected[679] = 12'sd452;
        expected[680] = 12'sd902;
        expected[681] = 12'sd296;
        expected[682] = 12'sd2047;
        expected[683] = 12'sd484;
        expected[684] = 12'sd939;
        expected[685] = 12'sd1829;
        expected[686] = 12'sd2027;
        expected[687] = 12'sd1724;
        expected[688] = 12'sd1059;
        expected[689] = 12'sd1332;
        expected[690] = 12'sd2047;
        expected[691] = 12'sd1643;
        expected[692] = 12'sd1463;
        expected[693] = 12'sd1628;
        expected[694] = 12'sd1634;
        expected[695] = 12'sd2002;
        expected[696] = 12'sd1122;
        expected[697] = 12'sd1258;
        expected[698] = 12'sd1076;
        expected[699] = 12'sd1264;
        expected[700] = 12'sd1585;
        expected[701] = 12'sd540;
        expected[702] = 12'sd2047;
        expected[703] = 12'sd2036;
        expected[704] = 12'sd986;
        expected[705] = 12'sd1406;
        expected[706] = 12'sd1994;
        expected[707] = 12'sd2047;
        expected[708] = 12'sd2047;
        expected[709] = 12'sd995;
        expected[710] = 12'sd1052;
        expected[711] = 12'sd1273;
        expected[712] = 12'sd2040;
        expected[713] = 12'sd681;
        expected[714] = 12'sd2047;
        expected[715] = 12'sd1885;
        expected[716] = 12'sd579;
        expected[717] = 12'sd961;
        expected[718] = 12'sd1655;
        expected[719] = 12'sd1280;
        expected[720] = 12'sd99;
        expected[721] = 12'sd337;
        expected[722] = -12'sd903;
        expected[723] = 12'sd1291;
        expected[724] = 12'sd497;
        expected[725] = 12'sd120;
        expected[726] = 12'sd1056;
        expected[727] = 12'sd2047;
        expected[728] = 12'sd1294;
        expected[729] = 12'sd1202;
        expected[730] = 12'sd1294;
        expected[731] = 12'sd2047;
        expected[732] = 12'sd1343;
        expected[733] = 12'sd1687;
        expected[734] = 12'sd2047;
        expected[735] = 12'sd1808;
        expected[736] = 12'sd1930;
        expected[737] = 12'sd1523;
        expected[738] = 12'sd2047;
        expected[739] = 12'sd2047;
        expected[740] = 12'sd2047;
        expected[741] = 12'sd2047;
        expected[742] = 12'sd1965;
        expected[743] = 12'sd2047;
        expected[744] = 12'sd1203;
        expected[745] = 12'sd1283;
        expected[746] = 12'sd2039;
        expected[747] = 12'sd1910;
        expected[748] = 12'sd1653;
        expected[749] = 12'sd1103;
        expected[750] = 12'sd2047;
        expected[751] = 12'sd2047;
        expected[752] = 12'sd1506;
        expected[753] = 12'sd2047;
        expected[754] = 12'sd2047;
        expected[755] = 12'sd2047;
        expected[756] = 12'sd670;
        expected[757] = 12'sd1213;
        expected[758] = 12'sd1696;
        expected[759] = 12'sd1468;
        expected[760] = 12'sd1540;
        expected[761] = 12'sd671;
        expected[762] = 12'sd2047;
        expected[763] = 12'sd1471;
        expected[764] = 12'sd396;
        expected[765] = 12'sd1870;
        expected[766] = 12'sd1665;
        expected[767] = 12'sd1544;

        for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1) begin
            for (ch = 0; ch < CH; ch = ch + 1)
                current_feat[pix * CH + ch] = feat0[pix * CH + ch];
        end

        repeat (5) @(posedge clk);
        rst = 1'b0;

        for (block_sel = 1; block_sel <= 6; block_sel = block_sel + 1) begin
            for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1) begin
                run_spab_conv_pixel(block_sel, 1, 0, pix);
                for (ch = 0; ch < CH; ch = ch + 1)
                    apply_act1(block_sel, c1_raw[pix * CH + ch], c1_act[pix * CH + ch]);
            end
            if (block_sel == 6) begin
                for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1)
                    for (ch = 0; ch < CH; ch = ch + 1)
                        b6_act1_feat[pix * CH + ch] = c1_act[pix * CH + ch];
            end

            for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1) begin
                run_spab_conv_pixel(block_sel, 2, 1, pix);
                for (ch = 0; ch < CH; ch = ch + 1)
                    apply_act2(block_sel, c2_raw[pix * CH + ch], c2_act[pix * CH + ch]);
            end

            for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1) begin
                run_spab_conv_pixel(block_sel, 3, 2, pix);
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    apply_sim(block_sel, c3_raw[pix * CH + ch], sim_att[pix * CH + ch]);
                    apply_attention(block_sel, c3_raw[pix * CH + ch], current_feat[pix * CH + ch], sim_att[pix * CH + ch], next_feat[pix * CH + ch]);
                end
            end

            for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1) begin
                for (ch = 0; ch < CH; ch = ch + 1)
                    current_feat[pix * CH + ch] = next_feat[pix * CH + ch];
            end
            if (block_sel == 1) begin
                for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1)
                    for (ch = 0; ch < CH; ch = ch + 1)
                        b1_feat[pix * CH + ch] = current_feat[pix * CH + ch];
            end
        end

        for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1)
            run_conv2_pixel(pix);
        for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1)
            run_cat_pixel(pix);
        for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1)
            run_up_pixel(pix);

        for (pix = 0; pix < FRAME_PIXELS; pix = pix + 1) begin
            for (color = 0; color < 3; color = color + 1) begin
                for (sy = 0; sy < 4; sy = sy + 1) begin
                    for (sx = 0; sx < 4; sx = sx + 1) begin
                        in_ch = color * 16 + sy * 4 + sx;
                        out_pix = ((pix / IMG_W) * 4 + sy) * OUT_W + ((pix % IMG_W) * 4 + sx);
                        rgb_out[out_pix * 3 + color] = up_feat[pix * CH + in_ch];
                    end
                end
            end
        end

        fd = $fopen("span_w8a12_tail_frame_rgb_out.txt", "w");
        if (fd == 0)
            $fatal(1, "Failed to open span_w8a12_tail_frame_rgb_out.txt");
        for (pix = 0; pix < OUT_PIXELS; pix = pix + 1) begin
            for (ch = 0; ch < 3; ch = ch + 1) begin
                got = rgb_out[pix * 3 + ch];
                $fwrite(fd, "%0d %0d %0d\n", pix, ch, got);
                if (got !== expected[pix * 3 + ch]) begin
                    if (mismatches < 32)
                        $display("MISMATCH rgb pix=%0d ch=%0d got=%0d expected=%0d", pix, ch, got, expected[pix * 3 + ch]);
                    mismatches++;
                end
            end
        end
        $fclose(fd);

        if (mismatches != 0)
            $fatal(1, "W8A12 tail frame mismatch count=%0d", mismatches);

        $display("PASS span_w8a12_tail_frame values=768");
        $finish;
    end
endmodule
