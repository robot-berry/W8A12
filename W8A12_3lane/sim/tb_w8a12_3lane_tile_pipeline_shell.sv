`timescale 1ns/1ps

module tb_w8a12_3lane_tile_pipeline_shell;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start_i;
    wire load_start_o;
    logic load_done_i;
    logic load_error_i;
    wire conv1_start_o;
    logic conv1_done_i;
    logic conv1_error_i;
    wire spab_start_o;
    logic spab_done_i;
    logic spab_error_i;
    wire tail_start_o;
    logic tail_done_i;
    logic tail_error_i;
    wire write_start_o;
    logic write_done_i;
    logic write_error_i;
    wire done_o;
    wire error_o;
    wire [2:0] phase_o;
    wire [2:0] block_idx_o;
    wire read_buf_o;
    wire write_buf_o;
    wire [2:0] lane_valid_o;

    integer spab_count;

    always #5 clk = ~clk;

    w8a12_3lane_tile_pipeline_shell dut (
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .load_start_o(load_start_o),
        .load_done_i(load_done_i),
        .load_error_i(load_error_i),
        .conv1_start_o(conv1_start_o),
        .conv1_done_i(conv1_done_i),
        .conv1_error_i(conv1_error_i),
        .spab_start_o(spab_start_o),
        .spab_done_i(spab_done_i),
        .spab_error_i(spab_error_i),
        .tail_start_o(tail_start_o),
        .tail_done_i(tail_done_i),
        .tail_error_i(tail_error_i),
        .write_start_o(write_start_o),
        .write_done_i(write_done_i),
        .write_error_i(write_error_i),
        .done_o(done_o),
        .error_o(error_o),
        .phase_o(phase_o),
        .block_idx_o(block_idx_o),
        .read_buf_o(read_buf_o),
        .write_buf_o(write_buf_o),
        .lane_valid_o(lane_valid_o)
    );

    initial begin
        start_i = 1'b0;
        load_done_i = 1'b0;
        load_error_i = 1'b0;
        conv1_done_i = 1'b0;
        conv1_error_i = 1'b0;
        spab_done_i = 1'b0;
        spab_error_i = 1'b0;
        tail_done_i = 1'b0;
        tail_error_i = 1'b0;
        write_done_i = 1'b0;
        write_error_i = 1'b0;
        spab_count = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        start_i = 1'b1;

        wait (load_start_o);
        @(posedge clk);
        load_done_i = 1'b1;
        @(posedge clk);
        load_done_i = 1'b0;

        wait (conv1_start_o);
        @(posedge clk);
        conv1_done_i = 1'b1;
        @(posedge clk);
        conv1_done_i = 1'b0;

        while (spab_count < 6) begin
            wait (spab_start_o);
            if (lane_valid_o !== 3'b111)
                $fatal(1, "lane_valid_o mismatch");
            if (read_buf_o !== block_idx_o[0])
                $fatal(1, "read_buf_o mismatch block=%0d", block_idx_o);
            if (write_buf_o !== ~block_idx_o[0])
                $fatal(1, "write_buf_o mismatch block=%0d", block_idx_o);
            @(posedge clk);
            spab_done_i = 1'b1;
            @(posedge clk);
            spab_done_i = 1'b0;
            spab_count = spab_count + 1;
        end

        wait (tail_start_o);
        @(posedge clk);
        tail_done_i = 1'b1;
        @(posedge clk);
        tail_done_i = 1'b0;

        wait (write_start_o);
        @(posedge clk);
        write_done_i = 1'b1;
        @(posedge clk);
        write_done_i = 1'b0;

        wait (done_o);
        if (error_o)
            $fatal(1, "unexpected error_o");
        $display("PASS w8a12_3lane_tile_pipeline_shell spab_blocks=%0d", spab_count);
        $finish;
    end
endmodule
