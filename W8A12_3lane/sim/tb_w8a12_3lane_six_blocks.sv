`timescale 1ns/1ps

`include "a2_3lane_files.vh"

module tb_w8a12_3lane_six_blocks;
    localparam int ACT_W = 12;
    localparam int CH = 48;
    localparam int LANES = 3;
    localparam int OUT_CH_PER_LANE = 16;
    localparam int IMG_W = 4;
    localparam int IMG_H = 4;
    localparam int PIXELS = IMG_W * IMG_H;
    localparam int KERNEL_TAPS = 9;
    localparam int WINDOW_WORDS = CH * KERNEL_TAPS;
    localparam int TOTAL = PIXELS * CH;
    localparam int BLOCKS = 6;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic [WINDOW_WORDS*ACT_W-1:0] window_i;
    logic m_ready;

    logic c1_s_valid [0:BLOCKS];
    logic c2_s_valid [0:BLOCKS];
    logic c3_s_valid [0:BLOCKS];
    wire c1_s_ready [0:BLOCKS];
    wire c2_s_ready [0:BLOCKS];
    wire c3_s_ready [0:BLOCKS];
    wire c1_m_valid [0:BLOCKS];
    wire c2_m_valid [0:BLOCKS];
    wire c3_m_valid [0:BLOCKS];
    wire [CH*ACT_W-1:0] c1_feat_o [0:BLOCKS];
    wire [CH*ACT_W-1:0] c2_feat_o [0:BLOCKS];
    wire [CH*ACT_W-1:0] c3_feat_o [0:BLOCKS];

    logic signed [ACT_W-1:0] block_feature [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] c1_raw [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] act1 [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] c2_raw [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] act2 [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] c3_raw [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] sim_att [0:BLOCKS][0:TOTAL-1];

    logic signed [ACT_W-1:0] exp_c1_raw [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_act1 [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_c2_raw [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_act2 [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_c3_raw [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_sim_att [0:BLOCKS][0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_block_output [0:BLOCKS][0:TOTAL-1];

    logic signed [ACT_W-1:0] lut_x;
    wire signed [ACT_W-1:0] lut_act1_y [0:BLOCKS];
    wire signed [ACT_W-1:0] lut_act2_y [0:BLOCKS];
    wire signed [ACT_W-1:0] lut_sim_y [0:BLOCKS];
    logic signed [ACT_W-1:0] att_out3;
    logic signed [ACT_W-1:0] att_residual;
    logic signed [ACT_W-1:0] att_sim;
    wire signed [ACT_W-1:0] att_y [0:BLOCKS];

    integer fd;
    integer code;
    integer idx;
    integer pix;
    integer ch;
    integer ky;
    integer kx;
    integer sx;
    integer sy;
    integer wait_cyc;
    integer value;
    integer active_block;
    integer active_stage;
    integer out_pix;
    integer mismatches;
    integer stage_mismatches;
    logic signed [ACT_W-1:0] got;
    logic signed [ACT_W-1:0] exp;

    always #5 clk = ~clk;

    task automatic read_vector;
        input string path;
        output logic signed [ACT_W-1:0] vec [0:TOTAL-1];
        begin
            fd = $fopen(path, "r");
            if (fd == 0) $fatal(1, "failed to open %s", path);
            for (idx = 0; idx < TOTAL; idx = idx + 1) begin
                code = $fscanf(fd, "%d\n", value);
                if (code != 1) $fatal(1, "failed to read %s index %0d", path, idx);
                vec[idx] = value[ACT_W-1:0];
            end
            $fclose(fd);
        end
    endtask

    task automatic build_window;
        input integer block;
        input integer src_sel;
        input integer p;
        begin
            for (ch = 0; ch < CH; ch = ch + 1) begin
                for (ky = 0; ky < 3; ky = ky + 1) begin
                    for (kx = 0; kx < 3; kx = kx + 1) begin
                        sx = (p % IMG_W) + kx - 1;
                        sy = (p / IMG_W) + ky - 1;
                        if (sx >= 0 && sx < IMG_W && sy >= 0 && sy < IMG_H) begin
                            case (src_sel)
                                0: window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = block_feature[block-1][(sy*IMG_W + sx)*CH + ch];
                                1: window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = act1[block][(sy*IMG_W + sx)*CH + ch];
                                default: window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = act2[block][(sy*IMG_W + sx)*CH + ch];
                            endcase
                        end else begin
                            window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = '0;
                        end
                    end
                end
            end
        end
    endtask

    task automatic clear_valids;
        integer b;
        begin
            for (b = 0; b <= BLOCKS; b = b + 1) begin
                c1_s_valid[b] = 1'b0;
                c2_s_valid[b] = 1'b0;
                c3_s_valid[b] = 1'b0;
            end
        end
    endtask

    task automatic run_conv_stage;
        input integer block;
        input integer stage;
        input integer src_sel;
        begin
            active_block = block;
            active_stage = stage;
            out_pix = 0;
            clear_valids();
            for (pix = 0; pix < PIXELS; pix = pix + 1) begin
                @(negedge clk);
                wait_cyc = 0;
                while (((stage == 1) && !c1_s_ready[block]) || ((stage == 2) && !c2_s_ready[block]) || ((stage == 3) && !c3_s_ready[block])) begin
                    @(negedge clk);
                    wait_cyc = wait_cyc + 1;
                    if (wait_cyc > 200000) $fatal(1, "timeout waiting ready block=%0d stage=%0d pix=%0d", block, stage, pix);
                end
                build_window(block, src_sel, pix);
                if (stage == 1) c1_s_valid[block] = 1'b1;
                else if (stage == 2) c2_s_valid[block] = 1'b1;
                else c3_s_valid[block] = 1'b1;
                @(posedge clk);
                @(negedge clk);
                clear_valids();
            end
            wait_cyc = 0;
            while (out_pix < PIXELS) begin
                @(posedge clk);
                wait_cyc = wait_cyc + 1;
                if (wait_cyc > 5000000) $fatal(1, "timeout outputs block=%0d stage=%0d got=%0d", block, stage, out_pix);
            end
            active_stage = 0;
            active_block = 0;
        end
    endtask

    task automatic check_lut_stage;
        input integer block;
        input integer stage;
        begin
            for (idx = 0; idx < TOTAL; idx = idx + 1) begin
                if (stage == 1) lut_x = c1_raw[block][idx];
                else if (stage == 2) lut_x = c2_raw[block][idx];
                else lut_x = c3_raw[block][idx];
                #1;
                if (stage == 1) begin
                    act1[block][idx] = lut_act1_y[block];
                    got = lut_act1_y[block];
                    exp = exp_act1[block][idx];
                end else if (stage == 2) begin
                    act2[block][idx] = lut_act2_y[block];
                    got = lut_act2_y[block];
                    exp = exp_act2[block][idx];
                end else begin
                    sim_att[block][idx] = lut_sim_y[block];
                    got = lut_sim_y[block];
                    exp = exp_sim_att[block][idx];
                end
                if (got !== exp) begin
                    $display("LUT MISMATCH block=%0d stage=%0d idx=%0d got=%0d exp=%0d", block, stage, idx, got, exp);
                    mismatches = mismatches + 1;
                    stage_mismatches = stage_mismatches + 1;
                end
            end
        end
    endtask

    task automatic check_attention_stage;
        input integer block;
        begin
            for (idx = 0; idx < TOTAL; idx = idx + 1) begin
                att_out3 = c3_raw[block][idx];
                att_residual = block_feature[block-1][idx];
                att_sim = sim_att[block][idx];
                #1;
                block_feature[block][idx] = att_y[block];
                got = att_y[block];
                exp = exp_block_output[block][idx];
                if (got !== exp) begin
                    $display("ATT MISMATCH block=%0d idx=%0d got=%0d exp=%0d", block, idx, got, exp);
                    mismatches = mismatches + 1;
                    stage_mismatches = stage_mismatches + 1;
                end
            end
        end
    endtask


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C1_LANE2_SHIFT_MEM)
    ) u_b1_c1 (
        .clk(clk), .rst(rst), .s_valid(c1_s_valid[1]), .s_ready(c1_s_ready[1]),
        .window_i(window_i), .m_valid(c1_m_valid[1]), .m_ready(m_ready), .feat_o(c1_feat_o[1])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C2_LANE2_SHIFT_MEM)
    ) u_b1_c2 (
        .clk(clk), .rst(rst), .s_valid(c2_s_valid[1]), .s_ready(c2_s_ready[1]),
        .window_i(window_i), .m_valid(c2_m_valid[1]), .m_ready(m_ready), .feat_o(c2_feat_o[1])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK1_C3_LANE2_SHIFT_MEM)
    ) u_b1_c3 (
        .clk(clk), .rst(rst), .s_valid(c3_s_valid[1]), .s_ready(c3_s_ready[1]),
        .window_i(window_i), .m_valid(c3_m_valid[1]), .m_ready(m_ready), .feat_o(c3_feat_o[1])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C1_LANE2_SHIFT_MEM)
    ) u_b2_c1 (
        .clk(clk), .rst(rst), .s_valid(c1_s_valid[2]), .s_ready(c1_s_ready[2]),
        .window_i(window_i), .m_valid(c1_m_valid[2]), .m_ready(m_ready), .feat_o(c1_feat_o[2])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C2_LANE2_SHIFT_MEM)
    ) u_b2_c2 (
        .clk(clk), .rst(rst), .s_valid(c2_s_valid[2]), .s_ready(c2_s_ready[2]),
        .window_i(window_i), .m_valid(c2_m_valid[2]), .m_ready(m_ready), .feat_o(c2_feat_o[2])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK2_C3_LANE2_SHIFT_MEM)
    ) u_b2_c3 (
        .clk(clk), .rst(rst), .s_valid(c3_s_valid[2]), .s_ready(c3_s_ready[2]),
        .window_i(window_i), .m_valid(c3_m_valid[2]), .m_ready(m_ready), .feat_o(c3_feat_o[2])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C1_LANE2_SHIFT_MEM)
    ) u_b3_c1 (
        .clk(clk), .rst(rst), .s_valid(c1_s_valid[3]), .s_ready(c1_s_ready[3]),
        .window_i(window_i), .m_valid(c1_m_valid[3]), .m_ready(m_ready), .feat_o(c1_feat_o[3])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C2_LANE2_SHIFT_MEM)
    ) u_b3_c2 (
        .clk(clk), .rst(rst), .s_valid(c2_s_valid[3]), .s_ready(c2_s_ready[3]),
        .window_i(window_i), .m_valid(c2_m_valid[3]), .m_ready(m_ready), .feat_o(c2_feat_o[3])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK3_C3_LANE2_SHIFT_MEM)
    ) u_b3_c3 (
        .clk(clk), .rst(rst), .s_valid(c3_s_valid[3]), .s_ready(c3_s_ready[3]),
        .window_i(window_i), .m_valid(c3_m_valid[3]), .m_ready(m_ready), .feat_o(c3_feat_o[3])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C1_LANE2_SHIFT_MEM)
    ) u_b4_c1 (
        .clk(clk), .rst(rst), .s_valid(c1_s_valid[4]), .s_ready(c1_s_ready[4]),
        .window_i(window_i), .m_valid(c1_m_valid[4]), .m_ready(m_ready), .feat_o(c1_feat_o[4])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C2_LANE2_SHIFT_MEM)
    ) u_b4_c2 (
        .clk(clk), .rst(rst), .s_valid(c2_s_valid[4]), .s_ready(c2_s_ready[4]),
        .window_i(window_i), .m_valid(c2_m_valid[4]), .m_ready(m_ready), .feat_o(c2_feat_o[4])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK4_C3_LANE2_SHIFT_MEM)
    ) u_b4_c3 (
        .clk(clk), .rst(rst), .s_valid(c3_s_valid[4]), .s_ready(c3_s_ready[4]),
        .window_i(window_i), .m_valid(c3_m_valid[4]), .m_ready(m_ready), .feat_o(c3_feat_o[4])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C1_LANE2_SHIFT_MEM)
    ) u_b5_c1 (
        .clk(clk), .rst(rst), .s_valid(c1_s_valid[5]), .s_ready(c1_s_ready[5]),
        .window_i(window_i), .m_valid(c1_m_valid[5]), .m_ready(m_ready), .feat_o(c1_feat_o[5])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C2_LANE2_SHIFT_MEM)
    ) u_b5_c2 (
        .clk(clk), .rst(rst), .s_valid(c2_s_valid[5]), .s_ready(c2_s_ready[5]),
        .window_i(window_i), .m_valid(c2_m_valid[5]), .m_ready(m_ready), .feat_o(c2_feat_o[5])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK5_C3_LANE2_SHIFT_MEM)
    ) u_b5_c3 (
        .clk(clk), .rst(rst), .s_valid(c3_s_valid[5]), .s_ready(c3_s_ready[5]),
        .window_i(window_i), .m_valid(c3_m_valid[5]), .m_ready(m_ready), .feat_o(c3_feat_o[5])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C1_LANE2_SHIFT_MEM)
    ) u_b6_c1 (
        .clk(clk), .rst(rst), .s_valid(c1_s_valid[6]), .s_ready(c1_s_ready[6]),
        .window_i(window_i), .m_valid(c1_m_valid[6]), .m_ready(m_ready), .feat_o(c1_feat_o[6])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C2_LANE2_SHIFT_MEM)
    ) u_b6_c2 (
        .clk(clk), .rst(rst), .s_valid(c2_s_valid[6]), .s_ready(c2_s_ready[6]),
        .window_i(window_i), .m_valid(c2_m_valid[6]), .m_ready(m_ready), .feat_o(c2_feat_o[6])
    );


    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK6_C3_LANE2_SHIFT_MEM)
    ) u_b6_c3 (
        .clk(clk), .rst(rst), .s_valid(c3_s_valid[6]), .s_ready(c3_s_ready[6]),
        .window_i(window_i), .m_valid(c3_m_valid[6]), .m_ready(m_ready), .feat_o(c3_feat_o[6])
    );


    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK1_ACT1_LUT))
        u_b1_act1_lut (.x_i(lut_x), .y_o(lut_act1_y[1]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK1_ACT2_LUT))
        u_b1_act2_lut (.x_i(lut_x), .y_o(lut_act2_y[1]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK1_ATTENTION_LUT))
        u_b1_sim_lut (.x_i(lut_x), .y_o(lut_sim_y[1]));
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(`W8A12_3LANE_A2_BLOCK1_ATT_SHIFT),
        .OUT3_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK1_ATT_OUT3_Q31),
        .RESIDUAL_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK1_ATT_RESIDUAL_Q31)
    ) u_b1_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y[1])
    );


    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK2_ACT1_LUT))
        u_b2_act1_lut (.x_i(lut_x), .y_o(lut_act1_y[2]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK2_ACT2_LUT))
        u_b2_act2_lut (.x_i(lut_x), .y_o(lut_act2_y[2]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK2_ATTENTION_LUT))
        u_b2_sim_lut (.x_i(lut_x), .y_o(lut_sim_y[2]));
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(`W8A12_3LANE_A2_BLOCK2_ATT_SHIFT),
        .OUT3_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK2_ATT_OUT3_Q31),
        .RESIDUAL_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK2_ATT_RESIDUAL_Q31)
    ) u_b2_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y[2])
    );


    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK3_ACT1_LUT))
        u_b3_act1_lut (.x_i(lut_x), .y_o(lut_act1_y[3]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK3_ACT2_LUT))
        u_b3_act2_lut (.x_i(lut_x), .y_o(lut_act2_y[3]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK3_ATTENTION_LUT))
        u_b3_sim_lut (.x_i(lut_x), .y_o(lut_sim_y[3]));
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(`W8A12_3LANE_A2_BLOCK3_ATT_SHIFT),
        .OUT3_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK3_ATT_OUT3_Q31),
        .RESIDUAL_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK3_ATT_RESIDUAL_Q31)
    ) u_b3_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y[3])
    );


    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK4_ACT1_LUT))
        u_b4_act1_lut (.x_i(lut_x), .y_o(lut_act1_y[4]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK4_ACT2_LUT))
        u_b4_act2_lut (.x_i(lut_x), .y_o(lut_act2_y[4]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK4_ATTENTION_LUT))
        u_b4_sim_lut (.x_i(lut_x), .y_o(lut_sim_y[4]));
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(`W8A12_3LANE_A2_BLOCK4_ATT_SHIFT),
        .OUT3_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK4_ATT_OUT3_Q31),
        .RESIDUAL_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK4_ATT_RESIDUAL_Q31)
    ) u_b4_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y[4])
    );


    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK5_ACT1_LUT))
        u_b5_act1_lut (.x_i(lut_x), .y_o(lut_act1_y[5]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK5_ACT2_LUT))
        u_b5_act2_lut (.x_i(lut_x), .y_o(lut_act2_y[5]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK5_ATTENTION_LUT))
        u_b5_sim_lut (.x_i(lut_x), .y_o(lut_sim_y[5]));
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(`W8A12_3LANE_A2_BLOCK5_ATT_SHIFT),
        .OUT3_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK5_ATT_OUT3_Q31),
        .RESIDUAL_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK5_ATT_RESIDUAL_Q31)
    ) u_b5_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y[5])
    );


    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK6_ACT1_LUT))
        u_b6_act1_lut (.x_i(lut_x), .y_o(lut_act1_y[6]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK6_ACT2_LUT))
        u_b6_act2_lut (.x_i(lut_x), .y_o(lut_act2_y[6]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK6_ATTENTION_LUT))
        u_b6_sim_lut (.x_i(lut_x), .y_o(lut_sim_y[6]));
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(`W8A12_3LANE_A2_BLOCK6_ATT_SHIFT),
        .OUT3_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK6_ATT_OUT3_Q31),
        .RESIDUAL_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK6_ATT_RESIDUAL_Q31)
    ) u_b6_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y[6])
    );


    initial begin
        clear_valids();
        window_i = '0;
        m_ready = 1'b1;
        active_block = 0;
        active_stage = 0;
        out_pix = 0;
        mismatches = 0;
        stage_mismatches = 0;

        read_vector(`W8A12_3LANE_A2_BLOCK0_INPUT_TXT, block_feature[0]);
        read_vector(`W8A12_3LANE_A2_BLOCK1_C1_RAW_TXT, exp_c1_raw[1]);
        read_vector(`W8A12_3LANE_A2_BLOCK1_ACT1_TXT, exp_act1[1]);
        read_vector(`W8A12_3LANE_A2_BLOCK1_C2_RAW_TXT, exp_c2_raw[1]);
        read_vector(`W8A12_3LANE_A2_BLOCK1_ACT2_TXT, exp_act2[1]);
        read_vector(`W8A12_3LANE_A2_BLOCK1_C3_RAW_TXT, exp_c3_raw[1]);
        read_vector(`W8A12_3LANE_A2_BLOCK1_SIM_ATT_TXT, exp_sim_att[1]);
        read_vector(`W8A12_3LANE_A2_BLOCK1_OUTPUT_TXT, exp_block_output[1]);
        read_vector(`W8A12_3LANE_A2_BLOCK2_C1_RAW_TXT, exp_c1_raw[2]);
        read_vector(`W8A12_3LANE_A2_BLOCK2_ACT1_TXT, exp_act1[2]);
        read_vector(`W8A12_3LANE_A2_BLOCK2_C2_RAW_TXT, exp_c2_raw[2]);
        read_vector(`W8A12_3LANE_A2_BLOCK2_ACT2_TXT, exp_act2[2]);
        read_vector(`W8A12_3LANE_A2_BLOCK2_C3_RAW_TXT, exp_c3_raw[2]);
        read_vector(`W8A12_3LANE_A2_BLOCK2_SIM_ATT_TXT, exp_sim_att[2]);
        read_vector(`W8A12_3LANE_A2_BLOCK2_OUTPUT_TXT, exp_block_output[2]);
        read_vector(`W8A12_3LANE_A2_BLOCK3_C1_RAW_TXT, exp_c1_raw[3]);
        read_vector(`W8A12_3LANE_A2_BLOCK3_ACT1_TXT, exp_act1[3]);
        read_vector(`W8A12_3LANE_A2_BLOCK3_C2_RAW_TXT, exp_c2_raw[3]);
        read_vector(`W8A12_3LANE_A2_BLOCK3_ACT2_TXT, exp_act2[3]);
        read_vector(`W8A12_3LANE_A2_BLOCK3_C3_RAW_TXT, exp_c3_raw[3]);
        read_vector(`W8A12_3LANE_A2_BLOCK3_SIM_ATT_TXT, exp_sim_att[3]);
        read_vector(`W8A12_3LANE_A2_BLOCK3_OUTPUT_TXT, exp_block_output[3]);
        read_vector(`W8A12_3LANE_A2_BLOCK4_C1_RAW_TXT, exp_c1_raw[4]);
        read_vector(`W8A12_3LANE_A2_BLOCK4_ACT1_TXT, exp_act1[4]);
        read_vector(`W8A12_3LANE_A2_BLOCK4_C2_RAW_TXT, exp_c2_raw[4]);
        read_vector(`W8A12_3LANE_A2_BLOCK4_ACT2_TXT, exp_act2[4]);
        read_vector(`W8A12_3LANE_A2_BLOCK4_C3_RAW_TXT, exp_c3_raw[4]);
        read_vector(`W8A12_3LANE_A2_BLOCK4_SIM_ATT_TXT, exp_sim_att[4]);
        read_vector(`W8A12_3LANE_A2_BLOCK4_OUTPUT_TXT, exp_block_output[4]);
        read_vector(`W8A12_3LANE_A2_BLOCK5_C1_RAW_TXT, exp_c1_raw[5]);
        read_vector(`W8A12_3LANE_A2_BLOCK5_ACT1_TXT, exp_act1[5]);
        read_vector(`W8A12_3LANE_A2_BLOCK5_C2_RAW_TXT, exp_c2_raw[5]);
        read_vector(`W8A12_3LANE_A2_BLOCK5_ACT2_TXT, exp_act2[5]);
        read_vector(`W8A12_3LANE_A2_BLOCK5_C3_RAW_TXT, exp_c3_raw[5]);
        read_vector(`W8A12_3LANE_A2_BLOCK5_SIM_ATT_TXT, exp_sim_att[5]);
        read_vector(`W8A12_3LANE_A2_BLOCK5_OUTPUT_TXT, exp_block_output[5]);
        read_vector(`W8A12_3LANE_A2_BLOCK6_C1_RAW_TXT, exp_c1_raw[6]);
        read_vector(`W8A12_3LANE_A2_BLOCK6_ACT1_TXT, exp_act1[6]);
        read_vector(`W8A12_3LANE_A2_BLOCK6_C2_RAW_TXT, exp_c2_raw[6]);
        read_vector(`W8A12_3LANE_A2_BLOCK6_ACT2_TXT, exp_act2[6]);
        read_vector(`W8A12_3LANE_A2_BLOCK6_C3_RAW_TXT, exp_c3_raw[6]);
        read_vector(`W8A12_3LANE_A2_BLOCK6_SIM_ATT_TXT, exp_sim_att[6]);
        read_vector(`W8A12_3LANE_A2_BLOCK6_OUTPUT_TXT, exp_block_output[6]);

        repeat (5) @(posedge clk);
        rst = 1'b0;

        for (integer block = 1; block <= BLOCKS; block = block + 1) begin
            stage_mismatches = 0;
            run_conv_stage(block, 1, 0);
            if (stage_mismatches != 0) $fatal(1, "FAIL block=%0d c1 mismatches=%0d", block, stage_mismatches);

            stage_mismatches = 0;
            check_lut_stage(block, 1);
            if (stage_mismatches != 0) $fatal(1, "FAIL block=%0d act1 mismatches=%0d", block, stage_mismatches);

            stage_mismatches = 0;
            run_conv_stage(block, 2, 1);
            if (stage_mismatches != 0) $fatal(1, "FAIL block=%0d c2 mismatches=%0d", block, stage_mismatches);

            stage_mismatches = 0;
            check_lut_stage(block, 2);
            if (stage_mismatches != 0) $fatal(1, "FAIL block=%0d act2 mismatches=%0d", block, stage_mismatches);

            stage_mismatches = 0;
            run_conv_stage(block, 3, 2);
            if (stage_mismatches != 0) $fatal(1, "FAIL block=%0d c3 mismatches=%0d", block, stage_mismatches);

            stage_mismatches = 0;
            check_lut_stage(block, 3);
            if (stage_mismatches != 0) $fatal(1, "FAIL block=%0d sim_att mismatches=%0d", block, stage_mismatches);

            stage_mismatches = 0;
            check_attention_stage(block);
            if (stage_mismatches != 0) $fatal(1, "FAIL block=%0d attention mismatches=%0d", block, stage_mismatches);
        end

        if (mismatches != 0) $fatal(1, "FAIL w8a12_3lane_six_blocks mismatches=%0d", mismatches);
        $display("PASS w8a12_3lane_six_blocks blocks=%0d pixels=%0d channels=%0d", BLOCKS, PIXELS, CH);
        $finish;
    end

    always @(posedge clk) begin
        if (!rst && m_ready && active_block != 0) begin
            if ((active_stage == 1) && c1_m_valid[active_block]) begin
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    got = c1_feat_o[active_block][ch*ACT_W +: ACT_W];
                    exp = exp_c1_raw[active_block][out_pix*CH + ch];
                    c1_raw[active_block][out_pix*CH + ch] <= got;
                    if (got !== exp) begin
                        $display("C1 MISMATCH block=%0d pix=%0d ch=%0d got=%0d exp=%0d", active_block, out_pix, ch, got, exp);
                        mismatches <= mismatches + 1;
                        stage_mismatches <= stage_mismatches + 1;
                    end
                end
                out_pix <= out_pix + 1;
            end else if ((active_stage == 2) && c2_m_valid[active_block]) begin
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    got = c2_feat_o[active_block][ch*ACT_W +: ACT_W];
                    exp = exp_c2_raw[active_block][out_pix*CH + ch];
                    c2_raw[active_block][out_pix*CH + ch] <= got;
                    if (got !== exp) begin
                        $display("C2 MISMATCH block=%0d pix=%0d ch=%0d got=%0d exp=%0d", active_block, out_pix, ch, got, exp);
                        mismatches <= mismatches + 1;
                        stage_mismatches <= stage_mismatches + 1;
                    end
                end
                out_pix <= out_pix + 1;
            end else if ((active_stage == 3) && c3_m_valid[active_block]) begin
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    got = c3_feat_o[active_block][ch*ACT_W +: ACT_W];
                    exp = exp_c3_raw[active_block][out_pix*CH + ch];
                    c3_raw[active_block][out_pix*CH + ch] <= got;
                    if (got !== exp) begin
                        $display("C3 MISMATCH block=%0d pix=%0d ch=%0d got=%0d exp=%0d", active_block, out_pix, ch, got, exp);
                        mismatches <= mismatches + 1;
                        stage_mismatches <= stage_mismatches + 1;
                    end
                end
                out_pix <= out_pix + 1;
            end
        end
    end
endmodule
