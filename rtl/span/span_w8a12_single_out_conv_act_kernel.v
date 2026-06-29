`timescale 1ns/1ps

// Runtime-selectable one-output-channel W8A12 conv kernel with an optional
// unary activation LUT. This is the generic form used by tiled SPAB stages
// after block_1 proved the single-channel time-mux route.
module span_w8a12_single_out_conv_act_kernel #(
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
    input  wire [OUT_CH_W-1:0]          out_ch_i,
    input  wire signed [CH*9*ACT_W-1:0] window_i,
    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [ACT_W-1:0]      raw_o,
    output wire signed [ACT_W-1:0]      act_o
);
    wire signed [ACT_W-1:0] raw_feat;

    span_w8a12_single_out_conv_layer #(
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
        .out_ch_i(out_ch_i),
        .window_i(window_i),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .feat_o(raw_feat)
    );

    generate
        if (APPLY_ACT != 0) begin : g_act
            span_w8a12_unary_lut #(
                .ACT_W(ACT_W),
                .LUT_FILE(ACT_LUT_FILE)
            ) u_act_lut (
                .x_i(raw_feat),
                .y_o(act_o)
            );
        end else begin : g_no_act
            assign act_o = raw_feat;
        end
    endgenerate

    assign raw_o = raw_feat;
endmodule
