`timescale 1ns/1ps

// Tile-level control shell for the W8A12 3-lane pipeline.
//
// This module is a synthesizable scheduler contract. It does not implement the
// arithmetic stages; it sequences load/conv1/SPAB/tail/write engines and exports
// the ping-pong buffer state needed to wire the proven A0-A3 datapaths into a
// board-capable tile pipeline.
module w8a12_3lane_tile_pipeline_shell #(
    parameter integer TILE_W = 32,
    parameter integer TILE_H = 32,
    parameter integer HALO = 21,
    parameter integer SCALE = 4,
    parameter integer BLOCKS = 6
) (
    input  wire clk,
    input  wire rst,
    input  wire start_i,

    output reg  load_start_o,
    input  wire load_done_i,
    input  wire load_error_i,

    output reg  conv1_start_o,
    input  wire conv1_done_i,
    input  wire conv1_error_i,

    output reg  spab_start_o,
    input  wire spab_done_i,
    input  wire spab_error_i,

    output reg  tail_start_o,
    input  wire tail_done_i,
    input  wire tail_error_i,

    output reg  write_start_o,
    input  wire write_done_i,
    input  wire write_error_i,

    output reg  done_o,
    output reg  error_o,
    output reg  [2:0] phase_o,
    output reg  [2:0] block_idx_o,
    output wire read_buf_o,
    output wire write_buf_o,
    output wire [2:0] lane_valid_o
);
    localparam [2:0] PH_IDLE  = 3'd0;
    localparam [2:0] PH_LOAD  = 3'd1;
    localparam [2:0] PH_CONV1 = 3'd2;
    localparam [2:0] PH_SPAB  = 3'd3;
    localparam [2:0] PH_TAIL  = 3'd4;
    localparam [2:0] PH_WRITE = 3'd5;
    localparam [2:0] PH_DONE  = 3'd6;
    localparam [2:0] PH_ERROR = 3'd7;

    assign lane_valid_o = 3'b111;

    // 0 = buffer A, 1 = buffer B.
    assign read_buf_o = block_idx_o[0];
    assign write_buf_o = ~block_idx_o[0];

    wire any_error = load_error_i | conv1_error_i | spab_error_i | tail_error_i | write_error_i;

    always @(posedge clk) begin
        if (rst) begin
            phase_o <= PH_IDLE;
            block_idx_o <= 3'd0;
            load_start_o <= 1'b0;
            conv1_start_o <= 1'b0;
            spab_start_o <= 1'b0;
            tail_start_o <= 1'b0;
            write_start_o <= 1'b0;
            done_o <= 1'b0;
            error_o <= 1'b0;
        end else begin
            load_start_o <= 1'b0;
            conv1_start_o <= 1'b0;
            spab_start_o <= 1'b0;
            tail_start_o <= 1'b0;
            write_start_o <= 1'b0;

            if (any_error) begin
                phase_o <= PH_ERROR;
                error_o <= 1'b1;
                done_o <= 1'b0;
            end else begin
                case (phase_o)
                    PH_IDLE: begin
                        done_o <= 1'b0;
                        error_o <= 1'b0;
                        block_idx_o <= 3'd0;
                        if (start_i) begin
                            phase_o <= PH_LOAD;
                            load_start_o <= 1'b1;
                        end
                    end

                    PH_LOAD: begin
                        if (load_done_i) begin
                            phase_o <= PH_CONV1;
                            conv1_start_o <= 1'b1;
                        end
                    end

                    PH_CONV1: begin
                        if (conv1_done_i) begin
                            phase_o <= PH_SPAB;
                            block_idx_o <= 3'd0;
                            spab_start_o <= 1'b1;
                        end
                    end

                    PH_SPAB: begin
                        if (spab_done_i) begin
                            if (block_idx_o == BLOCKS-1) begin
                                phase_o <= PH_TAIL;
                                tail_start_o <= 1'b1;
                            end else begin
                                block_idx_o <= block_idx_o + 1'b1;
                                spab_start_o <= 1'b1;
                            end
                        end
                    end

                    PH_TAIL: begin
                        if (tail_done_i) begin
                            phase_o <= PH_WRITE;
                            write_start_o <= 1'b1;
                        end
                    end

                    PH_WRITE: begin
                        if (write_done_i) begin
                            phase_o <= PH_DONE;
                            done_o <= 1'b1;
                        end
                    end

                    PH_DONE: begin
                        if (!start_i) begin
                            phase_o <= PH_IDLE;
                            done_o <= 1'b0;
                        end
                    end

                    PH_ERROR: begin
                        if (!start_i) begin
                            phase_o <= PH_IDLE;
                            error_o <= 1'b0;
                        end
                    end

                    default: begin
                        phase_o <= PH_ERROR;
                        error_o <= 1'b1;
                    end
                endcase
            end
        end
    end
endmodule
