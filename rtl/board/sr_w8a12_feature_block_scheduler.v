`timescale 1ns/1ps

// Minimal W8A12 feature-domain block scheduler.
//
// It sequences a tile-local feature buffer replay through a time-multiplexed
// block/SPAB compute engine. The data path is intentionally external: this
// module only provides the control boundary needed after conv1 feature buffering.
module sr_w8a12_feature_block_scheduler #(
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_INDEX_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS)
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    output wire                         ready,
    output reg                          busy,
    output reg                          done,
    output reg                          error,

    output reg                          feature_stream_start,
    input  wire                         feature_stream_done,

    output reg                          block_start,
    input  wire                         block_done,
    output reg  [BLOCK_INDEX_W-1:0]     block_index
);
    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_START_BLOCK = 3'd1;
    localparam [2:0] ST_WAIT_BLOCK = 3'd2;
    localparam [2:0] ST_DONE = 3'd3;

    reg [2:0] state;
    reg stream_done_seen;
    reg block_done_seen;

    wire last_block = (block_index == BLOCKS - 1);

    assign ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            feature_stream_start <= 1'b0;
            block_start <= 1'b0;
            block_index <= {BLOCK_INDEX_W{1'b0}};
            stream_done_seen <= 1'b0;
            block_done_seen <= 1'b0;
        end else begin
            done <= 1'b0;
            feature_stream_start <= 1'b0;
            block_start <= 1'b0;

            if (feature_stream_done)
                stream_done_seen <= 1'b1;
            if (block_done)
                block_done_seen <= 1'b1;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        error <= 1'b0;
                        block_index <= {BLOCK_INDEX_W{1'b0}};
                        stream_done_seen <= 1'b0;
                        block_done_seen <= 1'b0;
                        state <= ST_START_BLOCK;
                    end
                end

                ST_START_BLOCK: begin
                    feature_stream_start <= 1'b1;
                    block_start <= 1'b1;
                    stream_done_seen <= 1'b0;
                    block_done_seen <= 1'b0;
                    state <= ST_WAIT_BLOCK;
                end

                ST_WAIT_BLOCK: begin
                    if (stream_done_seen && block_done_seen) begin
                        if (last_block) begin
                            state <= ST_DONE;
                        end else begin
                            block_index <= block_index + 1'b1;
                            state <= ST_START_BLOCK;
                        end
                    end
                end

                ST_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    error <= 1'b1;
                    busy <= 1'b0;
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
