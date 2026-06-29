`timescale 1ns/1ps

// INT32 累加结果到 signed INT8 的重量化模块。
//
// 当前 SCALE_SHIFT 是硬件占位参数，用算术右移近似每层量化 scale。
// 后续做 bit-accurate 对齐时，应替换为“每层定点乘法 + 右移 + 饱和”的形式，
// 以匹配训练/量化导出的 scale。
module span_int8_quantize #(
    parameter integer ACC_W = 32,
    parameter integer SCALE_SHIFT = 8
) (
    input  wire signed [ACC_W-1:0] acc_i,
    output wire signed [7:0]       q_o
);
    wire signed [ACC_W-1:0] scaled = acc_i >>> SCALE_SHIFT;

    // 饱和到 INT8 范围，避免卷积累加溢出后回绕。
    assign q_o = (scaled > 127)  ? 8'sd127 :
                 (scaled < -128) ? 8'sh80 :
                 scaled[7:0];
endmodule
