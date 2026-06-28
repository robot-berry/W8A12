`timescale 1ns/1ps

// OOC wrapper for the board-facing accelerator top shell.
//
// Stage engines are modeled as one-cycle done responders so synthesis keeps the
// control/status network without requiring DDR or arithmetic datapaths.
module w8a12_3lane_accel_top_ooc_top (
    input  wire clk,
    input  wire rst,
    input  wire start_i,
    input  wire clear_i,
    output wire frame_done_o,
    output wire error_o,
    output wire irq_o,
    output wire busy_o,
    output wire [31:0] status_o
);
    wire load_start;
    reg load_done;
    wire conv1_start;
    reg conv1_done;
    wire spab_start;
    reg spab_done;
    wire tail_start;
    reg tail_done;
    wire write_start;
    reg write_done;
    wire [2:0] phase;
    wire [2:0] block_idx;
    wire read_buf;
    wire write_buf;
    wire [2:0] lane_valid;

    always @(posedge clk) begin
        if (rst || clear_i) begin
            load_done <= 1'b0;
            conv1_done <= 1'b0;
            spab_done <= 1'b0;
            tail_done <= 1'b0;
            write_done <= 1'b0;
        end else begin
            load_done <= load_start;
            conv1_done <= conv1_start;
            spab_done <= spab_start;
            tail_done <= tail_start;
            write_done <= write_start;
        end
    end

    w8a12_3lane_accel_top #(
        .TILE_W(32),
        .TILE_H(32),
        .HALO(21),
        .SCALE(4),
        .BLOCKS(6)
    ) u_top (
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .clear_i(clear_i),
        .load_start_o(load_start),
        .load_done_i(load_done),
        .load_error_i(1'b0),
        .conv1_start_o(conv1_start),
        .conv1_done_i(conv1_done),
        .conv1_error_i(1'b0),
        .spab_start_o(spab_start),
        .spab_done_i(spab_done),
        .spab_error_i(1'b0),
        .tail_start_o(tail_start),
        .tail_done_i(tail_done),
        .tail_error_i(1'b0),
        .write_start_o(write_start),
        .write_done_i(write_done),
        .write_error_i(1'b0),
        .frame_done_o(frame_done_o),
        .error_o(error_o),
        .irq_o(irq_o),
        .busy_o(busy_o),
        .phase_o(phase),
        .block_idx_o(block_idx),
        .read_buf_o(read_buf),
        .write_buf_o(write_buf),
        .lane_valid_o(lane_valid),
        .status_o(status_o)
    );
endmodule
