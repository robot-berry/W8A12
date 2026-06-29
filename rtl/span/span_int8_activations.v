`timescale 1ns/1ps

// SPAN RTL 数据通路使用的硬件友好激活函数近似。
//
// 目的：
//   官方模型里有 SiLU、LeakyReLU 和 sigmoid/attention 门控。为了先保持
//   纯 Verilog 可综合，这里使用移位、截断和小乘法器实现近似版本。
//   等 Python 定点参考模型完全对齐后，可替换为查表或分段线性版本。
module span_int8_activations #(
    parameter integer DATA_W = 16
) (
    input  wire signed [DATA_W-1:0] x,
    output wire signed [DATA_W-1:0] silu_y,
    output wire signed [DATA_W-1:0] lrelu_y,
    output wire        [7:0]        sigmoid_u8
);
    // x>>>4 约等于 0.0625*x，用作低成本 LeakyReLU 负半轴斜率。
    wire signed [DATA_W-1:0] neg_slope = x >>> 4;
    wire signed [DATA_W-1:0] gate_base = (x >>> 1) + {{(DATA_W-8){1'b0}}, 8'd128};

    assign lrelu_y = x[DATA_W-1] ? neg_slope : x;
    assign sigmoid_u8 = (gate_base < 0) ? 8'd0 :
                        (gate_base > 255) ? 8'd255 :
                        gate_base[7:0];

    // SiLU(x)=x*sigmoid(x)。sigmoid_u8 作为 Q8 门控，乘法宽度较小。
    assign silu_y = (x * $signed({1'b0, sigmoid_u8})) >>> 8;
endmodule
