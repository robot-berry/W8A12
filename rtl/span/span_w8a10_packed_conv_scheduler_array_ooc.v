`timescale 1ns/1ps

// OOC resource/timing prototype for a replicated W8A10 packed scheduler array.
//
// This is a planning block for the W8A10 20-30fps route. It deliberately
// replicates full layer scheduler instances and preserves hierarchy so Vivado
// reports a realistic per-instance resource slope before full-frame integration.
(* keep_hierarchy = "yes" *)
module span_w8a10_packed_conv_scheduler_array_ooc #(
    parameter integer INSTANCE_COUNT = 4,
    parameter integer IN_CH = 48,
    parameter integer OUT_CH = 48,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 10,
    parameter integer ACC_W = 48,
    parameter integer OUT_LANES = 16,
    parameter integer TAP_LANES = 16,
    parameter WEIGHT_FILE = "rtl/generated/reds_span_x4_f48_w8a10/mem/block_1_c1_r_w_i8.mem",
    parameter BIAS_I64_FILE = "rtl/generated/reds_span_x4_f48_w8a10/mem/block_1_c1_r_bias_i64.mem",
    parameter REQUANT_Q31_FILE = "rtl/generated/reds_span_x4_f48_w8a10/mem/block_1_c1_r_requant_q31.mem",
    parameter REQUANT_SHIFT_FILE = "rtl/generated/reds_span_x4_f48_w8a10/mem/block_1_c1_r_requant_shift_u8.mem"
) (
    input  wire                                      clk,
    input  wire                                      rst,
    input  wire                                      s_valid,
    output wire [INSTANCE_COUNT-1:0]                 s_ready,
    input  wire signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,
    output wire [INSTANCE_COUNT-1:0]                 m_valid,
    input  wire [INSTANCE_COUNT-1:0]                 m_ready,
    output wire signed [INSTANCE_COUNT*OUT_CH*ACT_W-1:0] feat_o
);
    initial begin
        if (INSTANCE_COUNT < 1) begin
            $error("INSTANCE_COUNT must be >= 1");
        end
    end

    genvar inst;
    generate
        for (inst = 0; inst < INSTANCE_COUNT; inst = inst + 1) begin : g_sched
            (* dont_touch = "yes" *)
            span_w8a10_packed_conv_vector_layer #(
                .IN_CH(IN_CH),
                .OUT_CH(OUT_CH),
                .KERNEL_TAPS(KERNEL_TAPS),
                .ACT_W(ACT_W),
                .ACC_W(ACC_W),
                .OUT_LANES(OUT_LANES),
                .TAP_LANES(TAP_LANES),
                .WEIGHT_FILE(WEIGHT_FILE),
                .BIAS_I64_FILE(BIAS_I64_FILE),
                .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
                .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE)
            ) u_scheduler (
                .clk(clk),
                .rst(rst),
                .s_valid(s_valid),
                .s_ready(s_ready[inst]),
                .window_i(window_i),
                .m_valid(m_valid[inst]),
                .m_ready(m_ready[inst]),
                .feat_o(feat_o[inst*OUT_CH*ACT_W +: OUT_CH*ACT_W])
            );
        end
    endgenerate
endmodule
