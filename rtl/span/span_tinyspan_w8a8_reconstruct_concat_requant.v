`timescale 1ns/1ps

// Requantize TinySPAN learned-tail skip features to reconstruct.input scale
// and concatenate in the frozen software-reference order:
//   head, block0, block3, fuse_tail
module span_tinyspan_w8a8_reconstruct_concat_requant #(
    parameter integer ACT_W = 8,
    parameter integer CH = 32,
    parameter signed [32:0] BLOCK0_Q31 = 33'sd111804200,
    parameter signed [32:0] BLOCK3_Q31 = 33'sd18137780,
    parameter signed [32:0] FUSE_TAIL_Q31 = 33'sd92128473
) (
    input  wire signed [CH*ACT_W-1:0]       head_i,
    input  wire signed [CH*ACT_W-1:0]       block0_i,
    input  wire signed [CH*ACT_W-1:0]       block3_i,
    input  wire signed [CH*ACT_W-1:0]       fuse_tail_i,
    output wire signed [4*CH*ACT_W-1:0]     concat_o
);
    assign concat_o[0*CH*ACT_W +: CH*ACT_W] = head_i;

    genvar ch;
    generate
        for (ch = 0; ch < CH; ch = ch + 1) begin : g_requant
            span_tinyspan_w8a8_scale_q31_symmetric #(
                .ACT_W(ACT_W),
                .SHIFT(31),
                .MUL_Q31(BLOCK0_Q31)
            ) u_block0 (
                .q_i(block0_i[ch*ACT_W +: ACT_W]),
                .q_o(concat_o[1*CH*ACT_W + ch*ACT_W +: ACT_W])
            );

            span_tinyspan_w8a8_scale_q31_symmetric #(
                .ACT_W(ACT_W),
                .SHIFT(31),
                .MUL_Q31(BLOCK3_Q31)
            ) u_block3 (
                .q_i(block3_i[ch*ACT_W +: ACT_W]),
                .q_o(concat_o[2*CH*ACT_W + ch*ACT_W +: ACT_W])
            );

            span_tinyspan_w8a8_scale_q31_symmetric #(
                .ACT_W(ACT_W),
                .SHIFT(31),
                .MUL_Q31(FUSE_TAIL_Q31)
            ) u_fuse_tail (
                .q_i(fuse_tail_i[ch*ACT_W +: ACT_W]),
                .q_o(concat_o[3*CH*ACT_W + ch*ACT_W +: ACT_W])
            );
        end
    endgenerate
endmodule

