`timescale 1ns/1ps

// Board-facing control/status shell for the W8A12 3-lane accelerator.
//
// This top-level wrapper intentionally keeps data movers and arithmetic engines
// external. It provides a stable integration point for A5 board bring-up:
// software asserts start_i, external stage engines consume start pulses and
// return done/error, and software observes frame_done/error/phase/block status.
module w8a12_3lane_accel_top #(
    parameter integer TILE_W = 32,
    parameter integer TILE_H = 32,
    parameter integer HALO = 21,
    parameter integer SCALE = 4,
    parameter integer BLOCKS = 6
) (
    input  wire clk,
    input  wire rst,

    input  wire start_i,
    input  wire clear_i,

    output wire load_start_o,
    input  wire load_done_i,
    input  wire load_error_i,

    output wire conv1_start_o,
    input  wire conv1_done_i,
    input  wire conv1_error_i,

    output wire spab_start_o,
    input  wire spab_done_i,
    input  wire spab_error_i,

    output wire tail_start_o,
    input  wire tail_done_i,
    input  wire tail_error_i,

    output wire write_start_o,
    input  wire write_done_i,
    input  wire write_error_i,

    output wire frame_done_o,
    output wire error_o,
    output wire irq_o,
    output wire busy_o,
    output wire [2:0] phase_o,
    output wire [2:0] block_idx_o,
    output wire read_buf_o,
    output wire write_buf_o,
    output wire [2:0] lane_valid_o,
    output wire [31:0] status_o
);
    localparam [2:0] PH_IDLE  = 3'd0;
    localparam [2:0] PH_DONE  = 3'd6;
    localparam [2:0] PH_ERROR = 3'd7;

    wire shell_done;
    wire shell_error;
    reg start_q;
    reg done_latched;
    reg error_latched;

    wire start_level = start_i & ~clear_i;
    assign busy_o = (phase_o != PH_IDLE) && (phase_o != PH_DONE) && (phase_o != PH_ERROR);
    assign frame_done_o = done_latched;
    assign error_o = error_latched;
    assign irq_o = done_latched | error_latched;

    assign status_o = {
        16'd0,
        lane_valid_o,          // [15:13]
        write_buf_o,           // [12]
        read_buf_o,            // [11]
        block_idx_o,           // [10:8]
        phase_o,               // [7:5]
        busy_o,                // [4]
        irq_o,                 // [3]
        error_latched,         // [2]
        done_latched,          // [1]
        start_q                // [0]
    };

    always @(posedge clk) begin
        if (rst || clear_i) begin
            start_q <= 1'b0;
            done_latched <= 1'b0;
            error_latched <= 1'b0;
        end else begin
            start_q <= start_level;
            if (shell_done)
                done_latched <= 1'b1;
            if (shell_error)
                error_latched <= 1'b1;
            if (!start_i && (done_latched || error_latched))
                start_q <= 1'b0;
        end
    end

    w8a12_3lane_tile_pipeline_shell #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .HALO(HALO),
        .SCALE(SCALE),
        .BLOCKS(BLOCKS)
    ) u_tile_shell (
        .clk(clk),
        .rst(rst | clear_i),
        .start_i(start_q),
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
        .done_o(shell_done),
        .error_o(shell_error),
        .phase_o(phase_o),
        .block_idx_o(block_idx_o),
        .read_buf_o(read_buf_o),
        .write_buf_o(write_buf_o),
        .lane_valid_o(lane_valid_o)
    );
endmodule
