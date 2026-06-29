`timescale 1ns/1ps

// TinySPAN/W8A8 vector MAC tile.
//
// Computes LANES independent signed W8A8 MACs that share one activation:
//
//   acc_o[lane] = acc_i[lane] + act_i * weight_i[lane]
//
// Two lanes are packed into each DSP48E2 through span_w8a8_packed_dual_mac.
// LANES must be even.
module span_w8a8_packed_vector_mac #(
    parameter integer LANES = 16,
    parameter integer ACC_W = 48,
    parameter integer PIPELINE = 1
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [7:0]            act_i,
    input  wire [LANES*8-1:0]           weights_i,
    input  wire [LANES*ACC_W-1:0]       acc_i,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire [LANES*ACC_W-1:0]       acc_o
);
    localparam integer PAIRS = LANES / 2;

    initial begin
        if (LANES < 2 || (LANES % 2) != 0) begin
            $error("LANES must be an even integer >= 2");
        end
    end

    wire [PAIRS-1:0] ready_w;
    wire [PAIRS-1:0] valid_w;

    genvar p;
    generate
        for (p = 0; p < PAIRS; p = p + 1) begin : g_pair
            localparam integer L0 = 2 * p;
            localparam integer L1 = 2 * p + 1;

            span_w8a8_packed_dual_mac #(
                .ACC_W(ACC_W),
                .PIPELINE(PIPELINE)
            ) u_dual_mac (
                .clk(clk),
                .rst(rst),
                .s_valid(s_valid),
                .s_ready(ready_w[p]),
                .act_i(act_i),
                .weight0_i(weights_i[L0*8 +: 8]),
                .weight1_i(weights_i[L1*8 +: 8]),
                .acc0_i(acc_i[L0*ACC_W +: ACC_W]),
                .acc1_i(acc_i[L1*ACC_W +: ACC_W]),
                .m_valid(valid_w[p]),
                .m_ready(m_ready),
                .acc0_o(acc_o[L0*ACC_W +: ACC_W]),
                .acc1_o(acc_o[L1*ACC_W +: ACC_W])
            );
        end
    endgenerate

    assign s_ready = &ready_w;
    assign m_valid = &valid_w;
endmodule
