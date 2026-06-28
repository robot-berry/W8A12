`timescale 1ns/1ps

module tb_w8a12_3lane_accel_top;
    localparam int PH_IDLE  = 0;
    localparam int PH_DONE  = 6;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start_i = 1'b0;
    logic clear_i = 1'b0;

    wire load_start;
    logic load_done = 1'b0;
    logic load_error = 1'b0;
    wire conv1_start;
    logic conv1_done = 1'b0;
    logic conv1_error = 1'b0;
    wire spab_start;
    logic spab_done = 1'b0;
    logic spab_error = 1'b0;
    wire tail_start;
    logic tail_done = 1'b0;
    logic tail_error = 1'b0;
    wire write_start;
    logic write_done = 1'b0;
    logic write_error = 1'b0;

    wire frame_done;
    wire error;
    wire irq;
    wire busy;
    wire [2:0] phase;
    wire [2:0] block_idx;
    wire read_buf;
    wire write_buf;
    wire [2:0] lane_valid;
    wire [31:0] status;

    int spab_count;
    int completed_spab_count;
    int cycle_count;
    logic [31:0] completed_status;

    always #5 clk = ~clk;

    w8a12_3lane_accel_top #(
        .TILE_W(32),
        .TILE_H(32),
        .HALO(21),
        .SCALE(4),
        .BLOCKS(6)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .clear_i(clear_i),
        .load_start_o(load_start),
        .load_done_i(load_done),
        .load_error_i(load_error),
        .conv1_start_o(conv1_start),
        .conv1_done_i(conv1_done),
        .conv1_error_i(conv1_error),
        .spab_start_o(spab_start),
        .spab_done_i(spab_done),
        .spab_error_i(spab_error),
        .tail_start_o(tail_start),
        .tail_done_i(tail_done),
        .tail_error_i(tail_error),
        .write_start_o(write_start),
        .write_done_i(write_done),
        .write_error_i(write_error),
        .frame_done_o(frame_done),
        .error_o(error),
        .irq_o(irq),
        .busy_o(busy),
        .phase_o(phase),
        .block_idx_o(block_idx),
        .read_buf_o(read_buf),
        .write_buf_o(write_buf),
        .lane_valid_o(lane_valid),
        .status_o(status)
    );

    always @(posedge clk) begin
        if (rst || clear_i) begin
            load_done <= 1'b0;
            conv1_done <= 1'b0;
            spab_done <= 1'b0;
            tail_done <= 1'b0;
            write_done <= 1'b0;
            spab_count <= 0;
        end else begin
            load_done <= load_start;
            conv1_done <= conv1_start;
            tail_done <= tail_start;
            write_done <= write_start;
            if (spab_start) begin
                spab_done <= 1'b1;
                spab_count <= spab_count + 1;
            end else begin
                spab_done <= 1'b0;
            end
        end
    end

    initial begin
        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        start_i = 1'b1;

        cycle_count = 0;
        while (!frame_done) begin
            @(posedge clk);
            cycle_count++;
            if (cycle_count > 200)
                $fatal(1, "timeout waiting frame_done phase=%0d block=%0d status=%h", phase, block_idx, status);
        end

        if (error)
            $fatal(1, "unexpected error");
        if (!irq)
            $fatal(1, "irq should assert when frame_done is latched");
        if (phase != PH_DONE)
            $fatal(1, "expected PH_DONE got %0d", phase);
        if (spab_count != 6)
            $fatal(1, "expected 6 SPAB starts got %0d", spab_count);
        if (lane_valid != 3'b111)
            $fatal(1, "lane_valid mismatch %b", lane_valid);
        if (status[1] !== 1'b1 || status[3] !== 1'b1)
            $fatal(1, "status done/irq bits mismatch status=%h", status);
        completed_spab_count = spab_count;
        completed_status = status;

        start_i = 1'b0;
        repeat (3) @(posedge clk);
        clear_i = 1'b1;
        @(posedge clk);
        clear_i = 1'b0;
        @(posedge clk);
        if (frame_done || irq || error)
            $fatal(1, "clear did not reset latched status frame_done=%b irq=%b error=%b", frame_done, irq, error);

        if (phase != PH_IDLE)
            $fatal(1, "expected IDLE after clear got %0d", phase);

        $display("PASS w8a12_3lane_accel_top spab_count=%0d cycles=%0d status=%h", completed_spab_count, cycle_count, completed_status);
        $finish;
    end
endmodule
