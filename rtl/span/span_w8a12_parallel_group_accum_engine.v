`timescale 1ns/1ps

// Narrow tap-group accumulator for the REDS-trained W8A12 video engine.
//
// Unlike span_w8a12_parallel_accum_engine, this module does not accept the
// whole 432-tap window and weight vector at once. A scheduler or SRAM reader
// feeds one TAP_LANES group per transaction, which better matches the future
// video frame engine and avoids huge flat-bus muxes.
module span_w8a12_parallel_group_accum_engine #(
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer TILE_PIPELINE = 3
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire                                  s_first,
    input  wire                                  s_last,
    input  wire signed [TAP_LANES*ACT_W-1:0]     act_i,
    input  wire signed [OUT_LANES*ACC_W-1:0]     acc_i,
    input  wire signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] weight_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg signed [OUT_LANES*ACC_W-1:0]      acc_o
);
    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_ISSUE = 2'd1;
    localparam [1:0] ST_WAIT  = 2'd2;
    localparam [1:0] ST_OUT   = 2'd3;

    reg [1:0] state;
    reg last_q;
    reg signed [OUT_LANES*ACC_W-1:0] acc_q;
    reg signed [TAP_LANES*ACT_W-1:0] tile_act_q;
    reg signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] tile_weight_q;
    wire tile_s_ready;
    wire tile_m_valid;
    wire signed [OUT_LANES*ACC_W-1:0] tile_acc_o;

    assign s_ready = (state == ST_IDLE);

    span_w8a12_parallel_mac_tile #(
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .PIPELINE(TILE_PIPELINE)
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

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            last_q <= 1'b0;
            acc_q <= {OUT_LANES*ACC_W{1'b0}};
            tile_act_q <= {TAP_LANES*ACT_W{1'b0}};
            tile_weight_q <= {OUT_LANES*TAP_LANES*WEIGHT_W{1'b0}};
            acc_o <= {OUT_LANES*ACC_W{1'b0}};
            m_valid <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        tile_act_q <= act_i;
                        tile_weight_q <= weight_i;
                        acc_q <= s_first ? acc_i : acc_q;
                        last_q <= s_last;
                        m_valid <= 1'b0;
                        state <= ST_ISSUE;
                    end
                end

                ST_ISSUE: begin
                    if (tile_s_ready)
                        state <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (tile_m_valid) begin
                        acc_q <= tile_acc_o;
                        if (last_q) begin
                            acc_o <= tile_acc_o;
                            m_valid <= 1'b1;
                            state <= ST_OUT;
                        end else begin
                            state <= ST_IDLE;
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
