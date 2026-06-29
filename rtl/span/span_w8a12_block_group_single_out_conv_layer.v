`timescale 1ns/1ps

// Sequential W8A12 convolution for one output channel with runtime block select.
module span_w8a12_block_group_single_out_conv_layer #(
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
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
    input  wire [BLOCK_W-1:0]                    block_i,
    input  wire [OUT_CH_W-1:0]                   out_ch_i,
    input  wire signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg  signed [ACT_W-1:0]               feat_o,
    output wire [31:0]                           debug_state
);
    localparam integer TAP_COUNT = IN_CH * KERNEL_TAPS;
    localparam integer WEIGHT_COUNT_PER_BLOCK = OUT_CH_TOTAL * TAP_COUNT;
    localparam integer TAP_W = (TAP_COUNT <= 2) ? 1 : $clog2(TAP_COUNT);
    localparam [TAP_W-1:0] TAP_LAST = TAP_COUNT - 1;

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_SYNC_ISSUE = 3'd1;
    localparam [2:0] ST_MAC        = 3'd2;
    localparam [2:0] ST_REQUANT    = 3'd3;
    localparam [2:0] ST_OUT        = 3'd4;

    reg [2:0] state;
    reg [BLOCK_W-1:0] block_q;
    reg [OUT_CH_W-1:0] out_ch_q;
    reg signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_q;
    reg [TAP_W-1:0] tap_idx;
    reg signed [ACC_W-1:0] acc_q;
    wire [8:0] tap_idx_dbg;
    wire [2:0] block_dbg;
    wire [5:0] out_ch_dbg;
    wire tap_is_last = (tap_idx == TAP_LAST);
    wire tap_past_last = (tap_idx > TAP_LAST);

    wire [31:0] weight_addr = out_ch_q * TAP_COUNT + tap_idx;
    wire [7:0] out_ch_addr = {{(8-OUT_CH_W){1'b0}}, out_ch_q};
    wire dbg_block_in_range = (block_q < BLOCKS);
    wire dbg_weight_in_range = dbg_block_in_range && (weight_addr < WEIGHT_COUNT_PER_BLOCK);
    wire dbg_ch_in_range = dbg_block_in_range && (out_ch_addr < OUT_CH_TOTAL);
    wire signed [7:0] weight_i;
    wire signed [63:0] bias_i64;
    wire signed [31:0] requant_q31;
    wire [7:0] requant_shift;

    span_w8a12_block_group_const_bank #(
        .BLOCKS(BLOCKS),
        .BLOCK_W(BLOCK_W),
        .WEIGHT_COUNT_PER_BLOCK(WEIGHT_COUNT_PER_BLOCK),
        .OUT_CH(OUT_CH_TOTAL),
        .WEIGHT_FILE(WEIGHT_FILE),
        .BIAS_I64_FILE(BIAS_I64_FILE),
        .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE),
        .SYNC_READ(1)
    ) u_const_bank (
        .clk(clk),
        .block_i(block_q),
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

    assign debug_state = {
        3'd0,
        tap_past_last,
        tap_is_last,
        block_dbg,
        out_ch_dbg,
        dbg_weight_in_range,
        dbg_ch_in_range,
        state,
        tap_idx_dbg,
        s_valid,
        s_ready,
        m_valid,
        m_ready
    };

    generate
        if (TAP_W >= 9) begin : gen_tap_idx_dbg_wide
            assign tap_idx_dbg = tap_idx[8:0];
        end else begin : gen_tap_idx_dbg_narrow
            assign tap_idx_dbg = {{(9-TAP_W){1'b0}}, tap_idx};
        end

        if (BLOCK_W >= 3) begin : gen_block_dbg_wide
            assign block_dbg = block_q[2:0];
        end else begin : gen_block_dbg_narrow
            assign block_dbg = {{(3-BLOCK_W){1'b0}}, block_q};
        end

        if (OUT_CH_W >= 6) begin : gen_out_ch_dbg_wide
            assign out_ch_dbg = out_ch_q[5:0];
        end else begin : gen_out_ch_dbg_narrow
            assign out_ch_dbg = {{(6-OUT_CH_W){1'b0}}, out_ch_q};
        end
    endgenerate

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
            block_q <= {BLOCK_W{1'b0}};
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
                        block_q <= block_i;
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
                    if (tap_is_last) begin
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
