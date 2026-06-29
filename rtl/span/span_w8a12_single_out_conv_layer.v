`timescale 1ns/1ps

// Sequential W8A12 convolution for one runtime-selected output channel.
//
// This is the lane primitive needed for a time-multiplexed SPAB scheduler:
// one MAC lane can be called repeatedly with out_ch_i = 0..47 to build a full
// 48-channel feature vector without synthesizing all output channels at once.
module span_w8a12_single_out_conv_layer #(
    parameter integer IN_CH = 48,
    parameter integer OUT_CH_TOTAL = 48,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH_W = (OUT_CH_TOTAL <= 2) ? 1 : $clog2(OUT_CH_TOTAL),
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = ""
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire [OUT_CH_W-1:0]                   out_ch_i,
    input  wire signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg  signed [ACT_W-1:0]               feat_o
);
    localparam integer TAP_COUNT = IN_CH * KERNEL_TAPS;
    localparam integer WEIGHT_COUNT = OUT_CH_TOTAL * TAP_COUNT;
    localparam integer TAP_W = (TAP_COUNT <= 2) ? 1 : $clog2(TAP_COUNT);

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_SYNC_ISSUE = 3'd1;
    localparam [2:0] ST_MAC        = 3'd2;
    localparam [2:0] ST_REQUANT    = 3'd3;
    localparam [2:0] ST_OUT        = 3'd4;

    reg [2:0] state;
    reg [OUT_CH_W-1:0] out_ch_q;
    reg signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_q;
    reg [TAP_W-1:0] tap_idx;
    reg signed [ACC_W-1:0] acc_q;

    wire [31:0] weight_addr = out_ch_q * TAP_COUNT + tap_idx;
    wire [7:0] out_ch_addr = {{(8-OUT_CH_W){1'b0}}, out_ch_q};
    wire signed [7:0] weight_i;
    wire signed [63:0] bias_i64;
    wire signed [31:0] requant_q31;
    wire [7:0] requant_shift;

    span_w8a12_layer_const_bank #(
        .WEIGHT_COUNT(WEIGHT_COUNT),
        .OUT_CH(OUT_CH_TOTAL),
        .WEIGHT_FILE(WEIGHT_FILE),
        .BIAS_I64_FILE(BIAS_I64_FILE),
        .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE),
        .SYNC_READ(1)
    ) u_const_bank (
        .clk(clk),
        .weight_addr(weight_addr),
        .out_ch_addr(out_ch_addr),
        .weight_o(weight_i),
        .bias_i64_o(bias_i64),
        .requant_q31_o(requant_q31),
        .requant_shift_o(requant_shift)
    );

    wire signed [ACT_W-1:0] act_i = window_q[tap_idx*ACT_W +: ACT_W];
    wire signed [ACT_W+8-1:0] product = act_i * weight_i;
    wire signed [ACC_W-1:0] product_ext = {{(ACC_W-(ACT_W+8)){product[ACT_W+8-1]}}, product};
    wire signed [ACC_W-1:0] acc_next = acc_q + product_ext;
    wire signed [ACT_W-1:0] q_next;

    span_w8a12_requant #(
        .ACC_W(ACC_W),
        .ACT_W(ACT_W),
        .BIAS_BEFORE_REQUANT(0)
    ) u_requant (
        .acc_i(acc_q),
        .bias_i64(bias_i64),
        .requant_q31_i(requant_q31),
        .requant_shift_i(requant_shift),
        .q_o(q_next)
    );

    assign s_ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            out_ch_q <= {OUT_CH_W{1'b0}};
            window_q <= {IN_CH*KERNEL_TAPS*ACT_W{1'b0}};
            tap_idx <= {TAP_W{1'b0}};
            acc_q <= {ACC_W{1'b0}};
            m_valid <= 1'b0;
            feat_o <= {ACT_W{1'b0}};
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        out_ch_q <= out_ch_i;
                        window_q <= window_i;
                        tap_idx <= {TAP_W{1'b0}};
                        acc_q <= {ACC_W{1'b0}};
                        state <= ST_SYNC_ISSUE;
                    end
                end

                ST_SYNC_ISSUE: begin
                    state <= ST_MAC;
                end

                ST_MAC: begin
                    acc_q <= acc_next;
                    if (tap_idx == TAP_COUNT-1) begin
                        state <= ST_REQUANT;
                    end else begin
                        tap_idx <= tap_idx + 1'b1;
                        state <= ST_SYNC_ISSUE;
                    end
                end

                ST_REQUANT: begin
                    feat_o <= q_next;
                    m_valid <= 1'b1;
                    state <= ST_OUT;
                end

                ST_OUT: begin
                    if (!m_valid || m_ready)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
