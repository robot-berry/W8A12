`timescale 1ns/1ps

// Tap-group accumulator for the full-SPAN W8A10 realtime route.
//
// This is the first scheduler-shaped block above span_w8a10_packed_vector_mac:
// it consumes TAP_LANES activation taps and the matching OUT_LANES x TAP_LANES
// weights, then issues one packed vector MAC per tap.
module span_w8a10_packed_group_accum_engine #(
    parameter integer OUT_LANES = 16,
    parameter integer TAP_LANES = 16,
    parameter integer ACC_W = 48,
    parameter integer PIPELINE = 2
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

    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_LOAD  = 3'd1;
    localparam [2:0] ST_ISSUE = 3'd2;
    localparam [2:0] ST_WAIT  = 3'd3;
    localparam [2:0] ST_OUT   = 3'd4;

    initial begin
        if (OUT_LANES < 2 || (OUT_LANES % 2) != 0) begin
            $error("OUT_LANES must be an even integer >= 2");
        end
        if (TAP_LANES < 1) begin
            $error("TAP_LANES must be >= 1");
        end
    end

    reg [2:0] state;
    reg [TAP_W-1:0] tap_idx;
    reg signed [TAP_LANES*10-1:0] act_q;
    reg signed [OUT_LANES*TAP_LANES*8-1:0] weight_q;
    reg signed [OUT_LANES*ACC_W-1:0] acc_q;

    reg signed [9:0] vector_act_next;
    reg signed [OUT_LANES*8-1:0] vector_weight_next;
    reg signed [9:0] vector_act_q;
    reg signed [OUT_LANES*8-1:0] vector_weight_q;
    reg signed [OUT_LANES*ACC_W-1:0] vector_acc_i_q;
    wire vector_s_ready;
    wire vector_m_valid;
    wire signed [OUT_LANES*ACC_W-1:0] vector_acc_o;

    integer lane_idx;

    always @(*) begin
        vector_act_next = act_q[tap_idx*10 +: 10];
        vector_weight_next = {OUT_LANES*8{1'b0}};
        for (lane_idx = 0; lane_idx < OUT_LANES; lane_idx = lane_idx + 1) begin
            vector_weight_next[lane_idx*8 +: 8] =
                weight_q[(lane_idx*TAP_LANES + tap_idx)*8 +: 8];
        end
    end

    span_w8a10_packed_vector_mac #(
        .LANES(OUT_LANES),
        .ACC_W(ACC_W),
        .PIPELINE(PIPELINE)
    ) u_vector_mac (
        .clk(clk),
        .rst(rst),
        .s_valid(state == ST_ISSUE),
        .s_ready(vector_s_ready),
        .act_i(vector_act_q),
        .weights_i(vector_weight_q),
        .acc_i(vector_acc_i_q),
        .m_valid(vector_m_valid),
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
            vector_act_q <= 10'sd0;
            vector_weight_q <= {OUT_LANES*8{1'b0}};
            vector_acc_i_q <= {OUT_LANES*ACC_W{1'b0}};
            acc_o <= {OUT_LANES*ACC_W{1'b0}};
            m_valid <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        act_q <= act_i;
                        weight_q <= weight_i;
                        acc_q <= acc_i;
                        tap_idx <= {TAP_W{1'b0}};
                        m_valid <= 1'b0;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    vector_act_q <= vector_act_next;
                    vector_weight_q <= vector_weight_next;
                    vector_acc_i_q <= acc_q;
                    state <= ST_ISSUE;
                end

                ST_ISSUE: begin
                    if (vector_s_ready)
                        state <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (vector_m_valid) begin
                        acc_q <= vector_acc_o;
                        if (tap_idx == TAP_LANES - 1) begin
                            acc_o <= vector_acc_o;
                            m_valid <= 1'b1;
                            state <= ST_OUT;
                        end else begin
                            tap_idx <= tap_idx + 1'b1;
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
