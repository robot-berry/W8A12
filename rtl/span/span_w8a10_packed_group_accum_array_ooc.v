`timescale 1ns/1ps

// ROM-free OOC array for W8A10 packed group accumulators.
//
// This block is a resource/timing slope probe for the W8A10 20-30fps path.
// It avoids layer ROM initialization and full convolution scheduling so Vivado
// can report how replicated packed MAC tiles scale before full-frame RTL work.
(* keep_hierarchy = "yes" *)
module span_w8a10_packed_group_accum_array_ooc #(
    parameter integer INSTANCE_COUNT = 8,
    parameter integer OUT_LANES = 16,
    parameter integer TAP_LANES = 16,
    parameter integer ACC_W = 48,
    parameter integer PIPELINE = 2
) (
    input  wire                                      clk,
    input  wire                                      rst,
    input  wire                                      s_valid,
    output wire [INSTANCE_COUNT-1:0]                 s_ready,
    input  wire signed [TAP_LANES*10-1:0]            act_i,
    input  wire signed [OUT_LANES*ACC_W-1:0]         acc_i,
    input  wire signed [OUT_LANES*TAP_LANES*8-1:0]   weight_i,
    output wire [INSTANCE_COUNT-1:0]                 m_valid,
    input  wire [INSTANCE_COUNT-1:0]                 m_ready,
    output wire signed [INSTANCE_COUNT*OUT_LANES*ACC_W-1:0] acc_o
);
    initial begin
        if (INSTANCE_COUNT < 1) begin
            $error("INSTANCE_COUNT must be >= 1");
        end
    end

    genvar inst;
    generate
        for (inst = 0; inst < INSTANCE_COUNT; inst = inst + 1) begin : g_accum
            (* dont_touch = "yes" *)
            span_w8a10_packed_group_accum_engine #(
                .OUT_LANES(OUT_LANES),
                .TAP_LANES(TAP_LANES),
                .ACC_W(ACC_W),
                .PIPELINE(PIPELINE)
            ) u_accum (
                .clk(clk),
                .rst(rst),
                .s_valid(s_valid),
                .s_ready(s_ready[inst]),
                .act_i(act_i),
                .acc_i(acc_i),
                .weight_i(weight_i),
                .m_valid(m_valid[inst]),
                .m_ready(m_ready[inst]),
                .acc_o(acc_o[inst*OUT_LANES*ACC_W +: OUT_LANES*ACC_W])
            );
        end
    endgenerate
endmodule
