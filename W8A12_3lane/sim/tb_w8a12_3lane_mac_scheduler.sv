`timescale 1ns/1ps

`include "a0_3lane_files.vh"

module tb_w8a12_3lane_mac_scheduler;
    localparam int ACT_W = 12;
    localparam int CH = 48;
    localparam int LANE_CH = 16;
    localparam int IMG_W = 4;
    localparam int IMG_H = 4;
    localparam int PIXELS = IMG_W * IMG_H;
    localparam int KERNEL_TAPS = 9;
    localparam int WINDOW_WORDS = CH * KERNEL_TAPS;
    localparam int TOTAL = PIXELS * CH;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic s_valid;
    wire s_ready;
    logic [WINDOW_WORDS*ACT_W-1:0] window_i;
    wire m_valid;
    logic m_ready;
    wire [CH*ACT_W-1:0] feat_o;

    logic signed [ACT_W-1:0] input_feature [0:TOTAL-1];
    logic signed [ACT_W-1:0] expected_full [0:TOTAL-1];

    integer fd;
    integer code;
    integer idx;
    integer pix;
    integer out_pix;
    integer ch;
    integer ky;
    integer kx;
    integer sx;
    integer sy;
    integer wait_cyc;
    integer value;
    integer mismatches;
    integer cycle_count;
    integer first_input_cycle;
    integer last_output_cycle;
    integer accepted_pixels;
    integer total_cycles;
    integer cycles_per_pixel_ceil;
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
        input integer p;
        begin
            for (ch = 0; ch < CH; ch = ch + 1) begin
                for (ky = 0; ky < 3; ky = ky + 1) begin
                    for (kx = 0; kx < 3; kx = kx + 1) begin
                        sx = (p % IMG_W) + kx - 1;
                        sy = (p / IMG_W) + ky - 1;
                        if (sx >= 0 && sx < IMG_W && sy >= 0 && sy < IMG_H)
                            window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = input_feature[(sy*IMG_W + sx)*CH + ch];
                        else
                            window_i[(ch*9 + ky*3 + kx)*ACT_W +: ACT_W] = '0;
                    end
                end
            end
        end
    endtask

    w8a12_3lane_mac_scheduler #(
        .IN_CH(CH),
        .LANE_CH(LANE_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .TAP_PAR(8),
        .ACT_W(ACT_W),
        .LANE0_WEIGHT_FILE(`W8A12_3LANE_A0_LANE0_WEIGHT_MEM),
        .LANE0_BIAS_I64_FILE(`W8A12_3LANE_A0_LANE0_BIAS_MEM),
        .LANE0_REQUANT_Q31_FILE(`W8A12_3LANE_A0_LANE0_REQUANT_MEM),
        .LANE0_REQUANT_SHIFT_FILE(`W8A12_3LANE_A0_LANE0_SHIFT_MEM),
        .LANE1_WEIGHT_FILE(`W8A12_3LANE_A0_LANE1_WEIGHT_MEM),
        .LANE1_BIAS_I64_FILE(`W8A12_3LANE_A0_LANE1_BIAS_MEM),
        .LANE1_REQUANT_Q31_FILE(`W8A12_3LANE_A0_LANE1_REQUANT_MEM),
        .LANE1_REQUANT_SHIFT_FILE(`W8A12_3LANE_A0_LANE1_SHIFT_MEM),
        .LANE2_WEIGHT_FILE(`W8A12_3LANE_A0_LANE2_WEIGHT_MEM),
        .LANE2_BIAS_I64_FILE(`W8A12_3LANE_A0_LANE2_BIAS_MEM),
        .LANE2_REQUANT_Q31_FILE(`W8A12_3LANE_A0_LANE2_REQUANT_MEM),
        .LANE2_REQUANT_SHIFT_FILE(`W8A12_3LANE_A0_LANE2_SHIFT_MEM)
    ) dut (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .window_i(window_i),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .feat_o(feat_o)
    );

    initial begin
        s_valid = 1'b0;
        window_i = '0;
        m_ready = 1'b1;
        out_pix = 0;
        mismatches = 0;
        cycle_count = 0;
        first_input_cycle = -1;
        last_output_cycle = -1;
        accepted_pixels = 0;
        total_cycles = 0;
        cycles_per_pixel_ceil = 0;

        read_vector(`W8A12_3LANE_A0_INPUT_TXT, input_feature);
        read_vector(`W8A12_3LANE_A0_EXPECTED_TXT, expected_full);

        repeat (5) @(posedge clk);
        rst = 1'b0;

        for (pix = 0; pix < PIXELS; pix = pix + 1) begin
            @(negedge clk);
            wait_cyc = 0;
            while (!s_ready) begin
                @(negedge clk);
                wait_cyc = wait_cyc + 1;
                if (wait_cyc > 10000)
                    $fatal(1, "timeout waiting for s_ready at pixel %0d", pix);
            end
            build_window(pix);
            s_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_valid = 1'b0;
        end

        wait_cyc = 0;
        while (out_pix < PIXELS) begin
            @(posedge clk);
            wait_cyc = wait_cyc + 1;
            if (wait_cyc > 200000)
                $fatal(1, "timeout waiting outputs got=%0d", out_pix);
        end

        if (mismatches != 0)
            $fatal(1, "FAIL w8a12_3lane_mac_scheduler mismatches=%0d", mismatches);
        total_cycles = last_output_cycle - first_input_cycle + 1;
        cycles_per_pixel_ceil = (total_cycles + PIXELS - 1) / PIXELS;
        $display("PASS w8a12_3lane_mac_scheduler pixels=%0d channels=%0d accepted=%0d cycles=%0d cycles_per_pixel_ceil=%0d",
                 PIXELS, CH, accepted_pixels, total_cycles, cycles_per_pixel_ceil);
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
            first_input_cycle <= -1;
            last_output_cycle <= -1;
            accepted_pixels <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (s_valid && s_ready) begin
                if (accepted_pixels == 0)
                    first_input_cycle <= cycle_count;
                accepted_pixels <= accepted_pixels + 1;
            end
            if (m_valid && m_ready)
                last_output_cycle <= cycle_count;
        end
    end

    always @(posedge clk) begin
        if (!rst && m_valid && m_ready) begin
            for (ch = 0; ch < CH; ch = ch + 1) begin
                got = feat_o[ch*ACT_W +: ACT_W];
                exp = expected_full[out_pix*CH + ch];
                if (got !== exp) begin
                    $display("MISMATCH pix=%0d ch=%0d got=%0d exp=%0d", out_pix, ch, got, exp);
                    mismatches <= mismatches + 1;
                end
            end
            out_pix <= out_pix + 1;
        end
    end
endmodule
