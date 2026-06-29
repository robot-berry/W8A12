`timescale 1ns/1ps

// Low-state W8A10 tap-group accumulator prototype.
//
// This variant targets the W8A10 20-30fps exploration. It removes the
// LOAD/ISSUE/WAIT handshake around each tap and updates the accumulator once
// per clock. The packed vector MAC is used in combinational mode here, so OOC
// timing decides whether this form can close or needs a lighter pipelined
// reduction strategy.
module span_w8a10_packed_group_accum_fast #(
    parameter integer OUT_LANES = 16,
    parameter integer TAP_LANES = 16,
    parameter integer ACC_W = 48
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire signed [TAP_LANES*10-1:0]        act_i,
    input  wire signed [OUT_LANES*ACC_W-1:0]     acc_i,
    input  wire signed [OUT_LANES*TAP_LANES*8-1:0] weight_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg signed [OUT_LANES*ACC_W-1:0]      acc_o
);
    localparam integer TAP_W = (TAP_LANES <= 2) ? 1 : $clog2(TAP_LANES);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_RUN  = 2'd1;
    localparam [1:0] ST_OUT  = 2'd2;

    initial begin
        if (OUT_LANES < 2 || (OUT_LANES % 2) != 0) begin
            $error("OUT_LANES must be an even integer >= 2");
        end
        if (TAP_LANES < 1) begin
            $error("TAP_LANES must be >= 1");
        end
    end

    reg [1:0] state;
    reg [TAP_W-1:0] tap_idx;
    reg signed [TAP_LANES*10-1:0] act_q;
    reg signed [OUT_LANES*TAP_LANES*8-1:0] weight_q;
    reg signed [OUT_LANES*ACC_W-1:0] acc_q;
    reg signed [OUT_LANES*8-1:0] vector_weight;

    wire signed [9:0] vector_act = act_q[tap_idx*10 +: 10];
    wire signed [OUT_LANES*ACC_W-1:0] vector_acc_o;
    wire vector_unused_ready;
    wire vector_unused_valid;

    integer lane_idx;

    always @(*) begin
        vector_weight = {OUT_LANES*8{1'b0}};
        for (lane_idx = 0; lane_idx < OUT_LANES; lane_idx = lane_idx + 1) begin
            vector_weight[lane_idx*8 +: 8] =
                weight_q[(lane_idx*TAP_LANES + tap_idx)*8 +: 8];
        end
    end

    span_w8a10_packed_vector_mac #(
        .LANES(OUT_LANES),
        .ACC_W(ACC_W),
        .PIPELINE(0)
    ) u_vector_mac (
        .clk(clk),
        .rst(rst),
        .s_valid(state == ST_RUN),
        .s_ready(vector_unused_ready),
        .act_i(vector_act),
        .weights_i(vector_weight),
        .acc_i(acc_q),
        .m_valid(vector_unused_valid),
        .m_ready(1'b1),
        .acc_o(vector_acc_o)
    );

    assign s_ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            tap_idx <= {TAP_W{1'b0}};
            act_q <= {TAP_LANES*10{1'b0}};
            weight_q <= {OUT_LANES*TAP_LANES*8{1'b0}};
            acc_q <= {OUT_LANES*ACC_W{1'b0}};
            acc_o <= {OUT_LANES*ACC_W{1'b0}};
            m_valid <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    m_valid <= 1'b0;
                    if (s_valid) begin
                        act_q <= act_i;
                        weight_q <= weight_i;
                        acc_q <= acc_i;
                        tap_idx <= {TAP_W{1'b0}};
                        state <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    acc_q <= vector_acc_o;
                    if (tap_idx == TAP_LANES - 1) begin
                        acc_o <= vector_acc_o;
                        m_valid <= 1'b1;
                        state <= ST_OUT;
                    end else begin
                        tap_idx <= tap_idx + 1'b1;
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
