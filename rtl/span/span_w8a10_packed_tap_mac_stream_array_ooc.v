`timescale 1ns/1ps

// ROM-free OOC array for the streamed W8A10 tap-MAC primitive.
//
// This block is a resource/timing slope probe for the 32x32/720p30 route. It
// intentionally excludes weight ROMs, activation banks, accumulator banks, and
// AXIS/DMA control so the OOC result isolates the replicated MAC tile cost.
(* keep_hierarchy = "yes" *)
module span_w8a10_packed_tap_mac_stream_array_ooc #(
    parameter integer INSTANCE_COUNT = 8,
    parameter integer LANES = 16,
    parameter integer ACC_W = 48,
    parameter integer CONTEXT_W = 8,
    parameter integer PIPELINE = 2
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire [INSTANCE_COUNT-1:0]             s_valid,
    output wire [INSTANCE_COUNT-1:0]             s_ready,
    input  wire [INSTANCE_COUNT*CONTEXT_W-1:0]   s_context_i,
    input  wire [INSTANCE_COUNT-1:0]             s_tap_last_i,
    input  wire signed [INSTANCE_COUNT*10-1:0]   act_i,
    input  wire [INSTANCE_COUNT*LANES*8-1:0]     weights_i,
    input  wire [INSTANCE_COUNT*LANES*ACC_W-1:0] acc_i,

    output wire [INSTANCE_COUNT-1:0]             m_valid,
    input  wire [INSTANCE_COUNT-1:0]             m_ready,
    output wire [INSTANCE_COUNT*CONTEXT_W-1:0]   m_context_o,
    output wire [INSTANCE_COUNT-1:0]             m_tap_last_o,
    output wire [INSTANCE_COUNT*LANES*ACC_W-1:0] acc_o
);
    initial begin
        if (INSTANCE_COUNT < 1) begin
            $error("INSTANCE_COUNT must be >= 1");
        end
        if (LANES < 2 || (LANES % 2) != 0) begin
            $error("LANES must be an even integer >= 2");
        end
        if (CONTEXT_W < 1) begin
            $error("CONTEXT_W must be >= 1");
        end
    end

    genvar inst;
    generate
        for (inst = 0; inst < INSTANCE_COUNT; inst = inst + 1) begin : g_tap_mac
            (* dont_touch = "yes" *)
            span_w8a10_packed_tap_mac_stream #(
                .LANES(LANES),
                .ACC_W(ACC_W),
                .CONTEXT_W(CONTEXT_W),
                .PIPELINE(PIPELINE)
            ) u_tap_mac (
                .clk(clk),
                .rst(rst),
                .s_valid(s_valid[inst]),
                .s_ready(s_ready[inst]),
                .s_context_i(s_context_i[inst*CONTEXT_W +: CONTEXT_W]),
                .s_tap_last_i(s_tap_last_i[inst]),
                .act_i(act_i[inst*10 +: 10]),
                .weights_i(weights_i[inst*LANES*8 +: LANES*8]),
                .acc_i(acc_i[inst*LANES*ACC_W +: LANES*ACC_W]),
                .m_valid(m_valid[inst]),
                .m_ready(m_ready[inst]),
                .m_context_o(m_context_o[inst*CONTEXT_W +: CONTEXT_W]),
                .m_tap_last_o(m_tap_last_o[inst]),
                .acc_o(acc_o[inst*LANES*ACC_W +: LANES*ACC_W])
            );
        end
    endgenerate
endmodule
