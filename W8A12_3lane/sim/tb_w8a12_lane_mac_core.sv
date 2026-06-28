`timescale 1ns/1ps

module tb_w8a12_lane_mac_core;
    localparam int TAP_PAR = 8;
    localparam int ACT_W = 12;
    localparam int WEIGHT_W = 8;
    localparam int ACC_W = 48;
    localparam int CASES = 16;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic s_valid;
    wire s_ready;
    logic signed [ACC_W-1:0] acc_i;
    logic [TAP_PAR*ACT_W-1:0] act_i;
    logic [TAP_PAR*WEIGHT_W-1:0] weight_i;
    wire m_valid;
    logic m_ready;
    wire signed [ACC_W-1:0] acc_o;

    integer case_idx;
    integer tap;
    integer wait_cyc;
    integer mismatches;
    integer signed act_v;
    integer signed weight_v;
    longint signed expected;

    always #5 clk = ~clk;

    w8a12_lane_mac_core #(
        .TAP_PAR(TAP_PAR),
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .acc_i(acc_i),
        .act_i(act_i),
        .weight_i(weight_i),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .acc_o(acc_o)
    );

    task automatic drive_case;
        input integer c;
        begin
            expected = -1000 + c * 37;
            acc_i = expected[ACC_W-1:0];
            act_i = '0;
            weight_i = '0;
            for (tap = 0; tap < TAP_PAR; tap = tap + 1) begin
                act_v = -2048 + ((c * 211 + tap * 37 + 19) % 4096);
                weight_v = -128 + ((c * 43 + tap * 17 + 7) % 256);
                expected = expected + act_v * weight_v;
                act_i[tap*ACT_W +: ACT_W] = act_v[ACT_W-1:0];
                weight_i[tap*WEIGHT_W +: WEIGHT_W] = weight_v[WEIGHT_W-1:0];
            end

            @(negedge clk);
            wait_cyc = 0;
            while (!s_ready) begin
                @(negedge clk);
                wait_cyc = wait_cyc + 1;
                if (wait_cyc > 100)
                    $fatal(1, "timeout waiting s_ready case=%0d", c);
            end
            s_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_valid = 1'b0;

            wait_cyc = 0;
            while (!m_valid) begin
                @(posedge clk);
                wait_cyc = wait_cyc + 1;
                if (wait_cyc > 100)
                    $fatal(1, "timeout waiting m_valid case=%0d", c);
            end
            if (acc_o !== expected[ACC_W-1:0]) begin
                $display("MISMATCH case=%0d got=%0d expected=%0d", c, acc_o, expected);
                mismatches = mismatches + 1;
            end
            @(posedge clk);
        end
    endtask

    initial begin
        s_valid = 1'b0;
        acc_i = '0;
        act_i = '0;
        weight_i = '0;
        m_ready = 1'b1;
        mismatches = 0;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        for (case_idx = 0; case_idx < CASES; case_idx = case_idx + 1)
            drive_case(case_idx);
        if (mismatches != 0)
            $fatal(1, "FAIL w8a12_lane_mac_core mismatches=%0d", mismatches);
        $display("PASS w8a12_lane_mac_core cases=%0d tap_par=%0d", CASES, TAP_PAR);
        $finish;
    end
endmodule
