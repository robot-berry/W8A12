`timescale 1ns/1ps

// Multi-group accumulator around span_w8a12_parallel_mac_tile.
//
// This wrapper is the next step from a single MAC tile toward a real W8A12
// frame engine. It accepts a complete input window and the weights for one
// output-channel group, then issues ceil(TAP_COUNT / TAP_LANES) groups through
// the tile and returns final accumulators.
module span_w8a12_parallel_accum_engine #(
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_COUNT = 432,
    parameter integer TAP_LANES = 16
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire signed [TAP_COUNT*ACT_W-1:0]     window_i,
    input  wire signed [OUT_LANES*ACC_W-1:0]     acc_i,
    input  wire signed [OUT_LANES*TAP_COUNT*WEIGHT_W-1:0] weight_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg signed [OUT_LANES*ACC_W-1:0]      acc_o
);
    localparam integer GROUP_COUNT = (TAP_COUNT + TAP_LANES - 1) / TAP_LANES;
    localparam integer GROUP_W = (GROUP_COUNT <= 2) ? 1 : $clog2(GROUP_COUNT);

    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_LOAD  = 3'd1;
    localparam [2:0] ST_ISSUE = 3'd2;
    localparam [2:0] ST_WAIT  = 3'd3;
    localparam [2:0] ST_OUT   = 3'd4;

    reg [2:0] state;
    reg [GROUP_W-1:0] group_idx;
    reg signed [TAP_COUNT*ACT_W-1:0] window_q;
    reg signed [OUT_LANES*TAP_COUNT*WEIGHT_W-1:0] weight_q;
    reg signed [OUT_LANES*ACC_W-1:0] acc_q;

    reg signed [TAP_LANES*ACT_W-1:0] tile_act_next;
    reg signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] tile_weight_next;
    reg signed [TAP_LANES*ACT_W-1:0] tile_act_q;
    reg signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] tile_weight_q;
    wire tile_s_ready;
    wire tile_m_valid;
    wire signed [OUT_LANES*ACC_W-1:0] tile_acc_o;

    integer tap_idx;
    integer out_idx;
    integer global_tap;

    always @(*) begin
        tile_act_next = {TAP_LANES*ACT_W{1'b0}};
        tile_weight_next = {OUT_LANES*TAP_LANES*WEIGHT_W{1'b0}};
        for (tap_idx = 0; tap_idx < TAP_LANES; tap_idx = tap_idx + 1) begin
            global_tap = group_idx * TAP_LANES + tap_idx;
            if (global_tap < TAP_COUNT) begin
                tile_act_next[tap_idx*ACT_W +: ACT_W] = window_q[global_tap*ACT_W +: ACT_W];
                for (out_idx = 0; out_idx < OUT_LANES; out_idx = out_idx + 1) begin
                    tile_weight_next[(out_idx*TAP_LANES + tap_idx)*WEIGHT_W +: WEIGHT_W] =
                        weight_q[(out_idx*TAP_COUNT + global_tap)*WEIGHT_W +: WEIGHT_W];
                end
            end
        end
    end

    span_w8a12_parallel_mac_tile #(
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .PIPELINE(2)
    ) u_mac_tile (
        .clk(clk),
        .rst(rst),
        .s_valid(state == ST_ISSUE),
        .s_ready(tile_s_ready),
        .act_i(tile_act_q),
        .acc_i(acc_q),
        .weight_i(tile_weight_q),
        .m_valid(tile_m_valid),
        .m_ready(1'b1),
        .acc_o(tile_acc_o)
    );

    assign s_ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            group_idx <= {GROUP_W{1'b0}};
            window_q <= {TAP_COUNT*ACT_W{1'b0}};
            weight_q <= {OUT_LANES*TAP_COUNT*WEIGHT_W{1'b0}};
            acc_q <= {OUT_LANES*ACC_W{1'b0}};
            tile_act_q <= {TAP_LANES*ACT_W{1'b0}};
            tile_weight_q <= {OUT_LANES*TAP_LANES*WEIGHT_W{1'b0}};
            acc_o <= {OUT_LANES*ACC_W{1'b0}};
            m_valid <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        window_q <= window_i;
                        weight_q <= weight_i;
                        acc_q <= acc_i;
                        group_idx <= {GROUP_W{1'b0}};
                        m_valid <= 1'b0;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    tile_act_q <= tile_act_next;
                    tile_weight_q <= tile_weight_next;
                    state <= ST_ISSUE;
                end

                ST_ISSUE: begin
                    if (tile_s_ready)
                        state <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (tile_m_valid) begin
                        acc_q <= tile_acc_o;
                        if (group_idx == GROUP_COUNT - 1) begin
                            acc_o <= tile_acc_o;
                            m_valid <= 1'b1;
                            state <= ST_OUT;
                        end else begin
                            group_idx <= group_idx + 1'b1;
                            state <= ST_LOAD;
                        end
                    end
                end

                ST_OUT: begin
                    if (m_valid && m_ready) begin
                        m_valid <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
