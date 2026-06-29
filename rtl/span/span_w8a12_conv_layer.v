`timescale 1ns/1ps

// Generic sequential W8A12 convolution layer for the REDS-trained SPAN path.
//
// The layer consumes a fully unfolded input window:
//   window_i[(tap*ACT_W)+:ACT_W], tap = input_channel*KERNEL_TAPS + kernel_index
//
// It emits all output channels in one packed vector:
//   feat_o[(out_channel*ACT_W)+:ACT_W]
//
// KERNEL_TAPS=9 covers 3x3 convs. KERNEL_TAPS=1 covers conv_cat's 1x1 conv
// when IN_CH is set to CH*4.
module span_w8a12_conv_layer #(
    parameter integer IN_CH = 48,
    parameter integer OUT_CH = 48,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CONST_SYNC_READ = 0,
    parameter integer PIPELINE_REQUANT = 0,
    parameter integer BIAS_BEFORE_REQUANT = 0,
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = ""
) (
    input  wire                              clk,
    input  wire                              rst,

    input  wire                              s_valid,
    output wire                              s_ready,
    input  wire [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,

    output reg                               m_valid,
    input  wire                              m_ready,
    output reg [OUT_CH*ACT_W-1:0]            feat_o
);
    localparam integer TAP_COUNT = IN_CH * KERNEL_TAPS;
    localparam integer WEIGHT_COUNT = OUT_CH * TAP_COUNT;
    localparam integer TAP_W = (TAP_COUNT <= 2) ? 1 : $clog2(TAP_COUNT);
    localparam integer OUT_W = (OUT_CH <= 2) ? 1 : $clog2(OUT_CH);

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_MAC        = 3'd1;
    localparam [2:0] ST_OUT        = 3'd2;
    localparam [2:0] ST_SYNC_ISSUE = 3'd3;
    localparam [2:0] ST_REQUANT    = 3'd4;
    localparam [2:0] ST_RQ_PRODUCT = 3'd5;

    reg [2:0] state;
    reg [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_q;
    reg [TAP_W-1:0] tap_idx;
    reg [OUT_W-1:0] out_idx;
    reg signed [ACC_W-1:0] acc_q;
    reg signed [ACC_W-1:0] final_acc_q;
    reg signed [95:0] requant_product_q;
    reg [7:0] requant_shift_q;

    wire [31:0] weight_addr = out_idx * TAP_COUNT + tap_idx;
    wire [7:0] out_ch_addr = {{(8-OUT_W){1'b0}}, out_idx};
    wire signed [7:0] weight_i;
    wire signed [63:0] bias_i64;
    wire signed [31:0] requant_q31;
    wire [7:0] requant_shift;

    span_w8a12_layer_const_bank #(
        .WEIGHT_COUNT(WEIGHT_COUNT),
        .OUT_CH(OUT_CH),
        .WEIGHT_FILE(WEIGHT_FILE),
        .BIAS_I64_FILE(BIAS_I64_FILE),
        .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE),
        .SYNC_READ(CONST_SYNC_READ)
    ) u_const_bank (
        .clk             (clk),
        .weight_addr     (weight_addr),
        .out_ch_addr     (out_ch_addr),
        .weight_o        (weight_i),
        .bias_i64_o      (bias_i64),
        .requant_q31_o   (requant_q31),
        .requant_shift_o (requant_shift)
    );

    wire signed [ACT_W-1:0] act_i = window_q[tap_idx*ACT_W +: ACT_W];
    wire signed [ACT_W+8-1:0] product = act_i * weight_i;
    wire signed [ACC_W-1:0] product_ext = {{(ACC_W-(ACT_W+8)){product[ACT_W+8-1]}}, product};
    wire signed [ACC_W-1:0] acc_next = acc_q + product_ext;
    wire signed [ACC_W-1:0] requant_acc = (PIPELINE_REQUANT != 0) ? final_acc_q : acc_next;
    wire signed [ACT_W-1:0] q_next;

    localparam signed [63:0] SAT_MAX = (64'sd1 <<< (ACT_W - 1)) - 64'sd1;
    localparam signed [63:0] SAT_MIN = -(64'sd1 <<< (ACT_W - 1));
    wire signed [63:0] final_acc_ext = {{(64-ACC_W){final_acc_q[ACC_W-1]}}, final_acc_q};
    wire signed [63:0] final_acc_plus_bias = final_acc_ext + bias_i64;
    wire signed [63:0] final_mul_input = (BIAS_BEFORE_REQUANT != 0) ? final_acc_plus_bias : final_acc_ext;
    wire signed [95:0] final_product_mul = final_mul_input * requant_q31;
    wire signed [95:0] final_bias_ext = {{32{bias_i64[63]}}, bias_i64};
    wire signed [95:0] requant_product_next = (BIAS_BEFORE_REQUANT != 0) ? final_product_mul : (final_product_mul + final_bias_ext);

    reg signed [95:0] rq_round_offset;
    reg signed [95:0] rq_rounded_product;
    reg signed [95:0] rq_shifted_product;
    reg signed [63:0] rq_shifted_s64;
    reg signed [ACT_W-1:0] q_deep_next;

    always @(*) begin
        rq_round_offset = 96'sd0;
        rq_rounded_product = requant_product_q;
        if (requant_shift_q == 8'd0) begin
            rq_shifted_product = requant_product_q;
        end else begin
            rq_round_offset = 96'sd1 <<< (requant_shift_q - 8'd1);
            if (requant_product_q >= 96'sd0) begin
                rq_rounded_product = requant_product_q + rq_round_offset;
                rq_shifted_product = rq_rounded_product >>> requant_shift_q;
            end else begin
                rq_rounded_product = (-requant_product_q) + rq_round_offset;
                rq_shifted_product = -(rq_rounded_product >>> requant_shift_q);
            end
        end

        rq_shifted_s64 = rq_shifted_product[63:0];
        if (rq_shifted_s64 > SAT_MAX)
            q_deep_next = SAT_MAX[ACT_W-1:0];
        else if (rq_shifted_s64 < SAT_MIN)
            q_deep_next = SAT_MIN[ACT_W-1:0];
        else
            q_deep_next = rq_shifted_s64[ACT_W-1:0];
    end

    span_w8a12_requant #(
        .ACC_W(ACC_W),
        .ACT_W(ACT_W),
        .BIAS_BEFORE_REQUANT(BIAS_BEFORE_REQUANT)
    ) u_requant (
        .acc_i            (requant_acc),
        .bias_i64         (bias_i64),
        .requant_q31_i    (requant_q31),
        .requant_shift_i  (requant_shift),
        .q_o              (q_next)
    );

    assign s_ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state    <= ST_IDLE;
            window_q <= {IN_CH*KERNEL_TAPS*ACT_W{1'b0}};
            tap_idx  <= {TAP_W{1'b0}};
            out_idx  <= {OUT_W{1'b0}};
            acc_q    <= {ACC_W{1'b0}};
            final_acc_q <= {ACC_W{1'b0}};
            requant_product_q <= 96'sd0;
            requant_shift_q <= 8'd31;
            m_valid  <= 1'b0;
            feat_o   <= {OUT_CH*ACT_W{1'b0}};
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        window_q <= window_i;
                        tap_idx  <= {TAP_W{1'b0}};
                        out_idx  <= {OUT_W{1'b0}};
                        acc_q    <= {ACC_W{1'b0}};
                        state    <= (CONST_SYNC_READ != 0) ? ST_SYNC_ISSUE : ST_MAC;
                    end
                end

                ST_SYNC_ISSUE: begin
                    state <= ST_MAC;
                end

                ST_MAC: begin
                    acc_q <= acc_next;
                    if (tap_idx == TAP_COUNT-1) begin
                        if (PIPELINE_REQUANT != 0) begin
                            final_acc_q <= acc_next;
                            state <= (PIPELINE_REQUANT > 1) ? ST_REQUANT : ST_RQ_PRODUCT;
                        end else begin
                            feat_o[out_idx*ACT_W +: ACT_W] <= q_next;
                            tap_idx <= {TAP_W{1'b0}};
                            if (out_idx == OUT_CH-1) begin
                                state   <= ST_OUT;
                                m_valid <= 1'b1;
                            end else begin
                                out_idx <= out_idx + 1'b1;
                                acc_q   <= {ACC_W{1'b0}};
                                state   <= (CONST_SYNC_READ != 0) ? ST_SYNC_ISSUE : ST_MAC;
                            end
                        end
                    end else begin
                        tap_idx <= tap_idx + 1'b1;
                        state   <= (CONST_SYNC_READ != 0) ? ST_SYNC_ISSUE : ST_MAC;
                    end
                end

                ST_REQUANT: begin
                    requant_product_q <= requant_product_next;
                    requant_shift_q <= requant_shift;
                    state <= ST_RQ_PRODUCT;
                end

                ST_RQ_PRODUCT: begin
                    if (PIPELINE_REQUANT > 1)
                        feat_o[out_idx*ACT_W +: ACT_W] <= q_deep_next;
                    else
                        feat_o[out_idx*ACT_W +: ACT_W] <= q_next;
                    tap_idx <= {TAP_W{1'b0}};
                    if (out_idx == OUT_CH-1) begin
                        acc_q <= {ACC_W{1'b0}};
                        state <= ST_OUT;
                        m_valid <= 1'b1;
                    end else begin
                        out_idx <= out_idx + 1'b1;
                        acc_q <= {ACC_W{1'b0}};
                        state <= (CONST_SYNC_READ != 0) ? ST_SYNC_ISSUE : ST_MAC;
                    end
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
