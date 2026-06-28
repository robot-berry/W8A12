`timescale 1ns/1ps

// One 16-output-channel lane built from single-output-channel schedulers.
//
// This is an A4 bring-up wrapper: it proves that the TAP_PAR MAC scheduler can
// reproduce one lane of the A0 convolution. A later production scheduler can
// time-multiplex fewer single-output schedulers if resource pressure requires it.
module w8a12_single_lane_mac_scheduler #(
    parameter integer IN_CH = 48,
    parameter integer OUT_CH = 16,
    parameter integer KERNEL_TAPS = 9,
    parameter integer TAP_PAR = 8,
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
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
    output wire m_valid,
    input  wire m_ready,
    output wire [OUT_CH*ACT_W-1:0] feat_o
);
    wire [OUT_CH-1:0] out_s_ready;
    wire [OUT_CH-1:0] out_m_valid;

    assign s_ready = &out_s_ready;
    assign m_valid = &out_m_valid;

    genvar out_idx;
    generate
        for (out_idx = 0; out_idx < OUT_CH; out_idx = out_idx + 1) begin : g_out
            w8a12_single_out_mac_scheduler #(
                .IN_CH(IN_CH),
                .KERNEL_TAPS(KERNEL_TAPS),
                .TAP_PAR(TAP_PAR),
                .ACT_W(ACT_W),
                .WEIGHT_W(WEIGHT_W),
                .ACC_W(ACC_W),
                .OUT_INDEX(out_idx),
                .LANE_OUT_CH(OUT_CH),
                .WEIGHT_FILE(WEIGHT_FILE),
                .BIAS_I64_FILE(BIAS_I64_FILE),
                .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
                .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE)
            ) u_out (
                .clk(clk),
                .rst(rst),
                .s_valid(s_valid && s_ready),
                .s_ready(out_s_ready[out_idx]),
                .window_i(window_i),
                .m_valid(out_m_valid[out_idx]),
                .m_ready(m_ready && m_valid),
                .q_o(feat_o[out_idx*ACT_W +: ACT_W])
            );
        end
    endgenerate
endmodule
