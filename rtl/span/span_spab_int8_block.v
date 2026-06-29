`timescale 1ns/1ps

// 官方 SPAN 中 SPAB 的 INT8 控制骨架。
//
// 官方 SPAB 的 eval 计算顺序：
//   out1     = c1_r.eval_conv(x)
//   out1_act = SiLU(out1)
//   out2     = c2_r.eval_conv(out1_act)
//   out2_act = SiLU(out2)
//   out3     = c3_r.eval_conv(out2_act)
//   sim_att  = sigmoid(out3) - 0.5
//   out      = (out3 + x) * sim_att
//
// 当前模块先保留可综合的握手、通道扫描和 parameter-free attention 近似。
// 三个 48x48 fused Conv3XC 卷积接入后，s_feat 将作为 residual_in，
// out3 将来自 c3_r 输出，最终仍复用这里的 attention 门控形式。
module span_spab_int8_block #(
    parameter integer CH = 48,
    parameter integer FEAT_W = 8,
    parameter integer ACC_W = 32
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     s_valid,
    output wire                     s_ready,
    input  wire [CH*FEAT_W-1:0]     s_feat,

    output reg                      m_valid,
    input  wire                     m_ready,
    output reg [CH*FEAT_W-1:0]      m_feat
);
    localparam integer CH_W = (CH <= 2) ? 1 : $clog2(CH);

    reg [CH*FEAT_W-1:0] feat_q;
    reg [CH_W-1:0] ch_idx;
    reg busy;

    wire signed [7:0] residual_ch = feat_q[ch_idx*FEAT_W +: FEAT_W];

    // 占位阶段用 residual_ch 近似 out3，便于先验证 attention 数据格式。
    wire signed [15:0] out3_approx = {{8{residual_ch[7]}}, residual_ch};
    wire signed [15:0] residual_ext = {{8{residual_ch[7]}}, residual_ch};
    wire signed [16:0] sum_out3_residual = out3_approx + residual_ext;

    wire [7:0] sigmoid_u8;
    wire signed [15:0] silu_unused;
    wire signed [15:0] lrelu_unused;
    wire signed [8:0] gate_q8 = $signed({1'b0, sigmoid_u8}) - 9'sd128;
    wire signed [25:0] gated_wide = $signed(sum_out3_residual) * $signed(gate_q8);
    wire signed [15:0] out_ch_wide = gated_wide >>> 8;
    wire signed [7:0] out_ch = (out_ch_wide > 127) ? 8'sd127 :
                               (out_ch_wide < -128) ? 8'sh80 :
                               out_ch_wide[7:0];

    span_int8_activations #(
        .DATA_W(16)
    ) u_att_activation (
        .x          (out3_approx),
        .silu_y     (silu_unused),
        .lrelu_y    (lrelu_unused),
        .sigmoid_u8 (sigmoid_u8)
    );

    assign s_ready = !busy;

    always @(posedge clk) begin
        if (rst) begin
            feat_q  <= {CH*FEAT_W{1'b0}};
            ch_idx  <= {CH_W{1'b0}};
            busy    <= 1'b0;
            m_valid <= 1'b0;
            m_feat  <= {CH*FEAT_W{1'b0}};
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            if (s_valid && s_ready) begin
                // 锁存一组 48 通道特征，并逐通道执行 attention 近似。
                feat_q <= s_feat;
                m_feat <= s_feat;
                ch_idx <= {CH_W{1'b0}};
                busy   <= 1'b1;
            end else if (busy) begin
                m_feat[ch_idx*FEAT_W +: FEAT_W] <= out_ch;
                if (ch_idx == CH-1) begin
                    busy    <= 1'b0;
                    m_valid <= 1'b1;
                end else begin
                    ch_idx <= ch_idx + 1'b1;
                end
            end
        end
    end
endmodule
