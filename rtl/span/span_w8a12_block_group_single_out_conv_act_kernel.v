`timescale 1ns/1ps

// Runtime block-selectable one-output-channel W8A12 conv kernel.
module span_w8a12_block_group_single_out_conv_act_kernel #(
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
    parameter integer ACT_W = 12,
    parameter integer CH = 48,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH_W = (CH <= 2) ? 1 : $clog2(CH),
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = "",
    parameter integer APPLY_ACT = 1,
    parameter ACT_LUT_FILE = ""
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire [BLOCK_W-1:0]           block_i,
    input  wire [OUT_CH_W-1:0]          out_ch_i,
    input  wire signed [CH*9*ACT_W-1:0] window_i,
    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [ACT_W-1:0]      raw_o,
    output wire signed [ACT_W-1:0]      act_o,
    output wire [31:0]                  debug_state
);
    wire conv_valid;
    wire conv_ready;
    wire signed [ACT_W-1:0] raw_feat;

    span_w8a12_block_group_single_out_conv_layer #(
        .BLOCKS(BLOCKS),
        .BLOCK_W(BLOCK_W),
        .IN_CH(CH),
        .OUT_CH_TOTAL(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(WEIGHT_FILE),
        .BIAS_I64_FILE(BIAS_I64_FILE),
        .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE)
    ) u_conv (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .block_i(block_i),
        .out_ch_i(out_ch_i),
        .window_i(window_i),
        .m_valid(conv_valid),
        .m_ready(conv_ready),
        .feat_o(raw_feat),
        .debug_state(debug_state)
    );

    generate
        if (APPLY_ACT != 0) begin : g_act
            span_w8a12_block_group_unary_lut #(
                .ACT_W(ACT_W),
                .BLOCKS(BLOCKS),
                .BLOCK_W(BLOCK_W),
                .LUT_FILE(ACT_LUT_FILE)
            ) u_act_lut (
                .block_i(block_i),
                .x_i(raw_feat),
                .y_o(act_o)
            );

            assign conv_ready = m_ready;
            assign m_valid = conv_valid;
            assign raw_o = raw_feat;
        end else begin : g_no_act
            assign conv_ready = m_ready;
            assign m_valid = conv_valid;
            assign raw_o = raw_feat;
            assign act_o = raw_feat;
        end
    endgenerate
endmodule
