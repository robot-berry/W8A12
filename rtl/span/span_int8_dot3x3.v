`timescale 1ns/1ps

// 单个 3x3 卷积输出通道的顺序式 INT8 点积单元。
//
// 调用方式：
//   上层每周期送入一个 activation byte 和一个 weight byte；
//   连续 IN_CH*9 个 tap 后，valid 拉高并输出加上 bias 的 INT32 累加值。
//
// 该模块是后续并行卷积阵列的基本 MAC lane。
module span_int8_dot3x3 #(
    parameter integer IN_CH = 48,
    parameter integer ACC_W = 32
) (
    input  wire                   clk,
    input  wire                   rst,

    input  wire                   start,
    input  wire                   sample_valid,
    input  wire signed [7:0]      act_i,
    input  wire signed [7:0]      weight_i,
    input  wire signed [ACC_W-1:0] bias_i,

    output reg                    busy,
    output reg                    valid,
    output reg signed [ACC_W-1:0] acc_o
);
    localparam integer TAP_COUNT = IN_CH * 9;
    localparam integer TAP_W = (TAP_COUNT <= 2) ? 1 : $clog2(TAP_COUNT + 1);

    reg [TAP_W-1:0] tap_count;
    reg signed [ACC_W-1:0] acc_q;
    wire signed [15:0] product = act_i * weight_i;
    wire last_tap = (tap_count == TAP_COUNT-1);

    always @(posedge clk) begin
        if (rst) begin
            busy      <= 1'b0;
            valid     <= 1'b0;
            tap_count <= {TAP_W{1'b0}};
            acc_q     <= {ACC_W{1'b0}};
            acc_o     <= {ACC_W{1'b0}};
        end else begin
            valid <= 1'b0;

            if (start) begin
                // 新输出通道开始，累加器先装入 bias。
                busy      <= 1'b1;
                tap_count <= {TAP_W{1'b0}};
                acc_q     <= bias_i;
            end else if (busy && sample_valid) begin
                // 每个 tap 完成一次 INT8*INT8 乘加。
                acc_q <= acc_q + {{(ACC_W-16){product[15]}}, product};
                if (last_tap) begin
                    busy  <= 1'b0;
                    valid <= 1'b1;
                    acc_o <= acc_q + {{(ACC_W-16){product[15]}}, product};
                end else begin
                    tap_count <= tap_count + 1'b1;
                end
            end
        end
    end
endmodule
