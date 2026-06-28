`timescale 1ns/1ps

// One-output-channel convolution scheduler using the synthesis-friendly MAC core.
//
// This is the next A4 step after the raw MAC core: it walks a full 48x9 window
// in TAP_PAR chunks, accumulates one output channel, then applies the existing
// W8A12 requant primitive. A full lane scheduler will repeat this for 16 output
// channels and share/control ROM-backed constants.
module w8a12_single_out_mac_scheduler #(
    parameter integer IN_CH = 48,
    parameter integer KERNEL_TAPS = 9,
    parameter integer TAP_PAR = 8,
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer OUT_INDEX = 0,
    parameter integer LANE_OUT_CH = 16,
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = ""
) (
    input  wire clk,
    input  wire rst,
    input  wire s_valid,
    output wire s_ready,
    input  wire [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,
    output reg  m_valid,
    input  wire m_ready,
    output reg  signed [ACT_W-1:0] q_o
);
    localparam integer TAP_COUNT = IN_CH * KERNEL_TAPS;
    localparam integer CHUNK_COUNT = (TAP_COUNT + TAP_PAR - 1) / TAP_PAR;
    localparam integer WEIGHT_COUNT = LANE_OUT_CH * TAP_COUNT;
    localparam integer TAP_IDX_W = (TAP_COUNT <= 2) ? 1 : $clog2(TAP_COUNT + TAP_PAR);
    localparam integer CHUNK_W = (CHUNK_COUNT <= 2) ? 1 : $clog2(CHUNK_COUNT);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_MAC_WAIT = 2'd1;
    localparam [1:0] ST_OUT = 2'd2;

    reg [1:0] state;
    reg [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_q;
    reg [CHUNK_W-1:0] chunk_idx;
    reg signed [ACC_W-1:0] acc_q;
    reg mac_s_valid;
    wire mac_s_ready;
    wire mac_m_valid;
    wire signed [ACC_W-1:0] mac_acc_o;
    reg [TAP_PAR*ACT_W-1:0] mac_act_i;
    reg [TAP_PAR*WEIGHT_W-1:0] mac_weight_i;

    reg signed [WEIGHT_W-1:0] weight_mem [0:WEIGHT_COUNT-1];
    reg signed [63:0] bias_mem [0:LANE_OUT_CH-1];
    reg signed [31:0] requant_mem [0:LANE_OUT_CH-1];
    reg [7:0] shift_mem [0:LANE_OUT_CH-1];

    wire signed [63:0] bias_i64 = bias_mem[OUT_INDEX];
    wire signed [31:0] requant_q31 = requant_mem[OUT_INDEX];
    wire [7:0] requant_shift = shift_mem[OUT_INDEX];
    wire signed [ACT_W-1:0] q_next;

    integer i;
    integer tap_abs;
    integer weight_abs;

    initial begin
        if (WEIGHT_FILE != "")
            $readmemh(WEIGHT_FILE, weight_mem);
        if (BIAS_I64_FILE != "")
            $readmemh(BIAS_I64_FILE, bias_mem);
        if (REQUANT_Q31_FILE != "")
            $readmemh(REQUANT_Q31_FILE, requant_mem);
        if (REQUANT_SHIFT_FILE != "")
            $readmemh(REQUANT_SHIFT_FILE, shift_mem);
    end

    always @(*) begin
        mac_act_i = {TAP_PAR*ACT_W{1'b0}};
        mac_weight_i = {TAP_PAR*WEIGHT_W{1'b0}};
        for (i = 0; i < TAP_PAR; i = i + 1) begin
            tap_abs = chunk_idx * TAP_PAR + i;
            if (tap_abs < TAP_COUNT) begin
                weight_abs = OUT_INDEX * TAP_COUNT + tap_abs;
                mac_act_i[i*ACT_W +: ACT_W] = window_q[tap_abs*ACT_W +: ACT_W];
                mac_weight_i[i*WEIGHT_W +: WEIGHT_W] = weight_mem[weight_abs];
            end
        end
    end

    w8a12_lane_mac_core #(
        .TAP_PAR(TAP_PAR),
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .clk(clk),
        .rst(rst),
        .s_valid(mac_s_valid),
        .s_ready(mac_s_ready),
        .acc_i(acc_q),
        .act_i(mac_act_i),
        .weight_i(mac_weight_i),
        .m_valid(mac_m_valid),
        .m_ready(1'b1),
        .acc_o(mac_acc_o)
    );

    span_w8a12_requant #(
        .ACC_W(ACC_W),
        .ACT_W(ACT_W)
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
            window_q <= {IN_CH*KERNEL_TAPS*ACT_W{1'b0}};
            chunk_idx <= {CHUNK_W{1'b0}};
            acc_q <= {ACC_W{1'b0}};
            mac_s_valid <= 1'b0;
            m_valid <= 1'b0;
            q_o <= {ACT_W{1'b0}};
        end else begin
            mac_s_valid <= 1'b0;
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        window_q <= window_i;
                        chunk_idx <= {CHUNK_W{1'b0}};
                        acc_q <= {ACC_W{1'b0}};
                        mac_s_valid <= 1'b1;
                        state <= ST_MAC_WAIT;
                    end
                end

                ST_MAC_WAIT: begin
                    if (mac_m_valid) begin
                        acc_q <= mac_acc_o;
                        if (chunk_idx == CHUNK_COUNT-1) begin
                            state <= ST_OUT;
                        end else begin
                            chunk_idx <= chunk_idx + 1'b1;
                            mac_s_valid <= 1'b1;
                        end
                    end
                end

                ST_OUT: begin
                    q_o <= q_next;
                    m_valid <= 1'b1;
                    if (!m_valid || m_ready)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
