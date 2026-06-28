"""Generate the A2 six-block 3-lane SystemVerilog testbench."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "W8A12_3lane" / "sim" / "tb_w8a12_3lane_six_blocks.sv"


def conv_inst(block: int, stage: str) -> str:
    upper = stage.upper()
    return f"""
    w8a12_3lane_conv_layer #(
        .IN_CH(CH), .LANES(LANES), .OUT_CH_PER_LANE(OUT_CH_PER_LANE), .KERNEL_TAPS(KERNEL_TAPS), .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A2_BLOCK{block}_{upper}_LANE2_SHIFT_MEM)
    ) u_b{block}_{stage} (
        .clk(clk), .rst(rst), .s_valid({stage}_s_valid[{block}]), .s_ready({stage}_s_ready[{block}]),
        .window_i(window_i), .m_valid({stage}_m_valid[{block}]), .m_ready(m_ready), .feat_o({stage}_feat_o[{block}])
    );
"""


def lut_att_inst(block: int) -> str:
    return f"""
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK{block}_ACT1_LUT))
        u_b{block}_act1_lut (.x_i(lut_x), .y_o(lut_act1_y[{block}]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK{block}_ACT2_LUT))
        u_b{block}_act2_lut (.x_i(lut_x), .y_o(lut_act2_y[{block}]));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE(`W8A12_3LANE_A2_BLOCK{block}_ATTENTION_LUT))
        u_b{block}_sim_lut (.x_i(lut_x), .y_o(lut_sim_y[{block}]));
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(`W8A12_3LANE_A2_BLOCK{block}_ATT_SHIFT),
        .OUT3_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK{block}_ATT_OUT3_Q31),
        .RESIDUAL_REQUANT_Q31(`W8A12_3LANE_A2_BLOCK{block}_ATT_RESIDUAL_Q31)
    ) u_b{block}_attention (
        .out3_i(att_out3),
        .residual_i(att_residual),
        .sim_att_i(att_sim),
        .q_o(att_y[{block}])
    );
"""


def read_expected_calls() -> str:
    lines = ['        read_vector(`W8A12_3LANE_A2_BLOCK0_INPUT_TXT, block_feature[0]);']
    for block in range(1, 7):
        lines.extend(
            [
                f"        read_vector(`W8A12_3LANE_A2_BLOCK{block}_C1_RAW_TXT, exp_c1_raw[{block}]);",
                f"        read_vector(`W8A12_3LANE_A2_BLOCK{block}_ACT1_TXT, exp_act1[{block}]);",
                f"        read_vector(`W8A12_3LANE_A2_BLOCK{block}_C2_RAW_TXT, exp_c2_raw[{block}]);",
                f"        read_vector(`W8A12_3LANE_A2_BLOCK{block}_ACT2_TXT, exp_act2[{block}]);",
                f"        read_vector(`W8A12_3LANE_A2_BLOCK{block}_C3_RAW_TXT, exp_c3_raw[{block}]);",
                f"        read_vector(`W8A12_3LANE_A2_BLOCK{block}_SIM_ATT_TXT, exp_sim_att[{block}]);",
                f"        read_vector(`W8A12_3LANE_A2_BLOCK{block}_OUTPUT_TXT, exp_block_output[{block}]);",
            ]
        )
    return "\n".join(lines)


def main() -> None:
    convs = "\n".join(conv_inst(block, stage) for block in range(1, 7) for stage in ("c1", "c2", "c3"))
    luts = "\n".join(lut_att_inst(block) for block in range(1, 7))
    read_calls = read_expected_calls()
    text = f"""`timescale 1ns/1ps

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
                code = $fscanf(fd, "%d\\n", value);
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

{convs}
{luts}

    initial begin
        clear_valids();
        window_i = '0;
        m_ready = 1'b1;
        active_block = 0;
        active_stage = 0;
        out_pix = 0;
        mismatches = 0;
        stage_mismatches = 0;

{read_calls}

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
"""
    OUT.write_text(text, encoding="ascii")
    print(OUT)


if __name__ == "__main__":
    main()
