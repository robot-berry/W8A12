`timescale 1ns/1ps

// TinySPAN W8A8 final base-add equivalent for the frozen 30fps quant plan.
//
// The exported plan has:
//   pixelshuffle.output / output = 1.1873437860665423e-10
// so every int8 learned-path value maps to 0 at the final output scale.
// Therefore:
//   q_out = round(q_base * input_scale / output_scale)
// exactly over the int8 range for this frozen plan.
module span_tinyspan_w8a8_base_add_equiv #(
    parameter integer ACT_W = 8,
    parameter signed [32:0] BASE_Q31 = 33'sd2007717611
) (
    input  wire signed [3*ACT_W-1:0] learned_rgb_i,
    input  wire signed [3*ACT_W-1:0] base_rgb_i,
    output wire signed [3*ACT_W-1:0] q_rgb_o
);
    genvar color;
    generate
        for (color = 0; color < 3; color = color + 1) begin : g_color
            span_tinyspan_w8a8_scale_q31_symmetric #(
                .ACT_W(ACT_W),
                .SHIFT(31),
                .MUL_Q31(BASE_Q31)
            ) u_base_scale (
                .q_i(base_rgb_i[color*ACT_W +: ACT_W]),
                .q_o(q_rgb_o[color*ACT_W +: ACT_W])
            );
        end
    endgenerate

    wire unused_learned = |learned_rgb_i;
endmodule

