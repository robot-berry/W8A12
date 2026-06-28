`timescale 1ns/1ps

`include "a1_3lane_files.vh"

module tb_w8a12_3lane_single_block;
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

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic [WINDOW_WORDS*ACT_W-1:0] window_i;

    logic c1_s_valid;
    logic c2_s_valid;
    logic c3_s_valid;
    wire c1_s_ready;
    wire c2_s_ready;
    wire c3_s_ready;
    wire c1_m_valid;
    wire c2_m_valid;
    wire c3_m_valid;
    logic m_ready;
    wire [CH*ACT_W-1:0] c1_feat_o;
    wire [CH*ACT_W-1:0] c2_feat_o;
    wire [CH*ACT_W-1:0] c3_feat_o;

    logic signed [ACT_W-1:0] block_input [0:TOTAL-1];
    logic signed [ACT_W-1:0] c1_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] act1 [0:TOTAL-1];
    logic signed [ACT_W-1:0] c2_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] act2 [0:TOTAL-1];
    logic signed [ACT_W-1:0] c3_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] sim_att [0:TOTAL-1];
    logic signed [ACT_W-1:0] block_output [0:TOTAL-1];

    logic signed [ACT_W-1:0] exp_c1_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_act1 [0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_c2_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_act2 [0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_c3_raw [0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_sim_att [0:TOTAL-1];
    logic signed [ACT_W-1:0] exp_block_output [0:TOTAL-1];

    logic signed [ACT_W-1:0] lut_x;
    wire signed [ACT_W-1:0] lut_act1_y;
    wire signed [ACT_W-1:0] lut_act2_y;
    wire signed [ACT_W-1:0] lut_sim_y;
    logic signed [ACT_W-1:0] att_out3;
    logic signed [ACT_W-1:0] att_residual;
    logic signed [ACT_W-1:0] att_sim;
    wire signed [ACT_W-1:0] att_y;

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
            if (fd == 0)
                $fatal(1, "failed to open %s", path);
            for (idx = 0; idx < TOTAL; idx = idx + 1) begin
                code = $fscanf(fd, "%d\n", value);
                if (code != 1)
                    $fatal(1, "failed to read %s index %0d", path, idx);
                vec[idx] = value[ACT_W-1:0];
            end
            $fclose(fd);
        end
    endtask

    task automatic build_window;
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
                                0: window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = block_input[(sy*IMG_W + sx)*CH + ch];
                                1: window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = act1[(sy*IMG_W + sx)*CH + ch];
                                default: window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = act2[(sy*IMG_W + sx)*CH + ch];
                            endcase
                        end else begin
                            window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = '0;
                        end
                    end
                end
            end
        end
    endtask

    task automatic run_conv_stage;
        input integer stage;
        input integer src_sel;
        begin
            active_stage = stage;
            out_pix = 0;
            c1_s_valid = 1'b0;
            c2_s_valid = 1'b0;
            c3_s_valid = 1'b0;

            for (pix = 0; pix < PIXELS; pix = pix + 1) begin
                @(negedge clk);
                wait_cyc = 0;
                while (((stage == 1) && !c1_s_ready) || ((stage == 2) && !c2_s_ready) || ((stage == 3) && !c3_s_ready)) begin
                    @(negedge clk);
                    wait_cyc = wait_cyc + 1;
                    if (wait_cyc > 200000)
                        $fatal(1, "timeout waiting for s_ready stage=%0d pixel=%0d", stage, pix);
                end
                build_window(src_sel, pix);
                if (stage == 1)
                    c1_s_valid = 1'b1;
                else if (stage == 2)
                    c2_s_valid = 1'b1;
                else
                    c3_s_valid = 1'b1;
                @(posedge clk);
                @(negedge clk);
                c1_s_valid = 1'b0;
                c2_s_valid = 1'b0;
                c3_s_valid = 1'b0;
            end

            wait_cyc = 0;
            while (out_pix < PIXELS) begin
                @(posedge clk);
                wait_cyc = wait_cyc + 1;
                if (wait_cyc > 5000000)
                    $fatal(1, "timeout waiting for outputs stage=%0d got=%0d expected=%0d", stage, out_pix, PIXELS);
            end
            active_stage = 0;
        end
    endtask

    task automatic check_lut_stage;
        input integer stage;
        begin
            for (idx = 0; idx < TOTAL; idx = idx + 1) begin
                if (stage == 1)
                    lut_x = c1_raw[idx];
                else if (stage == 2)
                    lut_x = c2_raw[idx];
                else
                    lut_x = c3_raw[idx];
                #1;
                if (stage == 1) begin
                    act1[idx] = lut_act1_y;
                    got = lut_act1_y;
                    exp = exp_act1[idx];
                end else if (stage == 2) begin
                    act2[idx] = lut_act2_y;
                    got = lut_act2_y;
                    exp = exp_act2[idx];
                end else begin
                    sim_att[idx] = lut_sim_y;
                    got = lut_sim_y;
                    exp = exp_sim_att[idx];
                end
                if (got !== exp) begin
                    $display("LUT MISMATCH stage=%0d idx=%0d got=%0d exp=%0d", stage, idx, got, exp);
                    mismatches = mismatches + 1;
                    stage_mismatches = stage_mismatches + 1;
                end
            end
        end
    endtask

    task automatic check_attention_stage;
        begin
            for (idx = 0; idx < TOTAL; idx = idx + 1) begin
                att_out3 = c3_raw[idx];
                att_residual = block_input[idx];
                att_sim = sim_att[idx];
                #1;
                block_output[idx] = att_y;
                got = att_y;
                exp = exp_block_output[idx];
                if (got !== exp) begin
                    $display("ATT MISMATCH idx=%0d got=%0d exp=%0d", idx, got, exp);
                    mismatches = mismatches + 1;
                    stage_mismatches = stage_mismatches + 1;
                end
            end
        end
    endtask

    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A1_C1_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A1_C1_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C1_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C1_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A1_C1_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A1_C1_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C1_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C1_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A1_C1_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A1_C1_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C1_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C1_LANE2_SHIFT_MEM)
    ) u_c1 (.clk(clk), .rst(rst), .s_valid(c1_s_valid), .s_ready(c1_s_ready), .window_i(window_i), .m_valid(c1_m_valid), .m_ready(m_ready), .feat_o(c1_feat_o));

    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A1_C2_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A1_C2_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C2_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C2_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A1_C2_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A1_C2_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C2_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C2_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A1_C2_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A1_C2_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C2_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C2_LANE2_SHIFT_MEM)
    ) u_c2 (.clk(clk), .rst(rst), .s_valid(c2_s_valid), .s_ready(c2_s_ready), .window_i(window_i), .m_valid(c2_m_valid), .m_ready(m_ready), .feat_o(c2_feat_o));

    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A1_C3_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A1_C3_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C3_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C3_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A1_C3_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A1_C3_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C3_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C3_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A1_C3_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A1_C3_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A1_C3_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A1_C3_LANE2_SHIFT_MEM)
    ) u_c3 (.clk(clk), .rst(rst), .s_valid(c3_s_valid), .s_ready(c3_s_ready), .window_i(window_i), .m_valid(c3_m_valid), .m_ready(m_ready), .feat_o(c3_feat_o));

    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A1_ACT1_LUT)) u_act1_lut (.x_i(lut_x), .y_o(lut_act1_y));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A1_ACT2_LUT)) u_act2_lut (.x_i(lut_x), .y_o(lut_act2_y));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A1_ATTENTION_LUT)) u_sim_lut (.x_i(lut_x), .y_o(lut_sim_y));

    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .OUT3_REQUANT_Q31(32'sd80193),
        .RESIDUAL_REQUANT_Q31(32'sd1123025)
    ) u_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y)
    );

    initial begin
        c1_s_valid = 1'b0;
        c2_s_valid = 1'b0;
        c3_s_valid = 1'b0;
        window_i = '0;
        m_ready = 1'b1;
        active_stage = 0;
        out_pix = 0;
        mismatches = 0;
        stage_mismatches = 0;

        read_vector(`W8A12_3LANE_A1_INPUT_TXT, block_input);
        read_vector(`W8A12_3LANE_A1_C1_RAW_TXT, exp_c1_raw);
        read_vector(`W8A12_3LANE_A1_ACT1_TXT, exp_act1);
        read_vector(`W8A12_3LANE_A1_C2_RAW_TXT, exp_c2_raw);
        read_vector(`W8A12_3LANE_A1_ACT2_TXT, exp_act2);
        read_vector(`W8A12_3LANE_A1_C3_RAW_TXT, exp_c3_raw);
        read_vector(`W8A12_3LANE_A1_SIM_ATT_TXT, exp_sim_att);
        read_vector(`W8A12_3LANE_A1_EXPECTED_TXT, exp_block_output);

        repeat (5) @(posedge clk);
        rst = 1'b0;

        stage_mismatches = 0;
        run_conv_stage(1, 0);
        if (stage_mismatches != 0)
            $fatal(1, "FAIL c1 mismatches=%0d", stage_mismatches);

        stage_mismatches = 0;
        check_lut_stage(1);
        if (stage_mismatches != 0)
            $fatal(1, "FAIL act1 mismatches=%0d", stage_mismatches);

        stage_mismatches = 0;
        run_conv_stage(2, 1);
        if (stage_mismatches != 0)
            $fatal(1, "FAIL c2 mismatches=%0d", stage_mismatches);

        stage_mismatches = 0;
        check_lut_stage(2);
        if (stage_mismatches != 0)
            $fatal(1, "FAIL act2 mismatches=%0d", stage_mismatches);

        stage_mismatches = 0;
        run_conv_stage(3, 2);
        if (stage_mismatches != 0)
            $fatal(1, "FAIL c3 mismatches=%0d", stage_mismatches);

        stage_mismatches = 0;
        check_lut_stage(3);
        if (stage_mismatches != 0)
            $fatal(1, "FAIL sim_att mismatches=%0d", stage_mismatches);

        stage_mismatches = 0;
        check_attention_stage();
        if (stage_mismatches != 0)
            $fatal(1, "FAIL attention mismatches=%0d", stage_mismatches);

        if (mismatches != 0)
            $fatal(1, "FAIL w8a12_3lane_single_block mismatches=%0d", mismatches);
        $display("PASS w8a12_3lane_single_block pixels=%0d channels=%0d", PIXELS, CH);
        $finish;
    end

    always @(posedge clk) begin
        if (!rst && m_ready) begin
            if ((active_stage == 1) && c1_m_valid) begin
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    got = c1_feat_o[ch*ACT_W +: ACT_W];
                    exp = exp_c1_raw[out_pix*CH + ch];
                    c1_raw[out_pix*CH + ch] <= got;
                    if (got !== exp) begin
                        $display("C1 MISMATCH pix=%0d ch=%0d got=%0d exp=%0d", out_pix, ch, got, exp);
                        mismatches <= mismatches + 1;
                        stage_mismatches <= stage_mismatches + 1;
                    end
                end
                out_pix <= out_pix + 1;
            end else if ((active_stage == 2) && c2_m_valid) begin
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    got = c2_feat_o[ch*ACT_W +: ACT_W];
                    exp = exp_c2_raw[out_pix*CH + ch];
                    c2_raw[out_pix*CH + ch] <= got;
                    if (got !== exp) begin
                        $display("C2 MISMATCH pix=%0d ch=%0d got=%0d exp=%0d", out_pix, ch, got, exp);
                        mismatches <= mismatches + 1;
                        stage_mismatches <= stage_mismatches + 1;
                    end
                end
                out_pix <= out_pix + 1;
            end else if ((active_stage == 3) && c3_m_valid) begin
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    got = c3_feat_o[ch*ACT_W +: ACT_W];
                    exp = exp_c3_raw[out_pix*CH + ch];
                    c3_raw[out_pix*CH + ch] <= got;
                    if (got !== exp) begin
                        $display("C3 MISMATCH pix=%0d ch=%0d got=%0d exp=%0d", out_pix, ch, got, exp);
                        mismatches <= mismatches + 1;
                        stage_mismatches <= stage_mismatches + 1;
                    end
                end
                out_pix <= out_pix + 1;
            end
        end
    end
endmodule
