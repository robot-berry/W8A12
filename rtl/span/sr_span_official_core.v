`timescale 1ns/1ps
`include "../generated/official_span_model_config.vh"
`include "../generated/official_span_layers.vh"

// 官方 SPAN 的 RTL 集成入口。
//
// 官方 SPAN eval/deploy 计算顺序：
//   conv_1.eval_conv
//   -> block_1 ~ block_6，每个 SPAB 包含 c1_r/c2_r/c3_r 三个 fused 3x3 卷积
//   -> conv_2.eval_conv
//   -> conv_cat([out_feature, out_b6_after_conv2, out_b1, out_b5_2])
//   -> upsampler.0
//   -> PixelShuffle 输出超分图像
//
// USE_FRAME_ENGINE：
//   0：保持当前可快速仿真/上板的兼容流式核，同时旁路执行官方 conv_1 诊断链。
//   1：使用完整官方 SPAN 帧级顺序 engine，真正按 44 个官方张量执行全图计算。
module sr_span_official_core #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W  = 64,
    parameter integer SCALE  = `OFFICIAL_SPAN_MODEL_SCALE,
    parameter integer CH     = `OFFICIAL_SPAN_FEATURE_CHANNELS,
    parameter integer BLOCKS = `OFFICIAL_SPAN_MODEL_BLOCKS,
    parameter integer USE_FRAME_ENGINE = 0
) (
    input  wire              clk,
    input  wire              rst,

    input  wire              s_valid,
    output wire              s_ready,
    input  wire [DATA_W-1:0] s_data,
    input  wire              s_user,
    input  wire              s_last,

    output wire              m_valid,
    input  wire              m_ready,
    output wire [DATA_W-1:0] m_data,
    output wire              m_user,
    output wire              m_last
);
    localparam integer FEAT_W = 8;

    generate
        if (USE_FRAME_ENGINE != 0) begin : g_full_official_frame_engine
            wire engine_busy;
            wire engine_done;

            // 完整官方 SPAN 帧级计算路径。
            // 该路径吞吐较低，但计算图完整，适合逐层定点对齐和小图上板功能验证。
            span_official_frame_engine #(
                .DATA_W(DATA_W),
                .IMG_W (IMG_W),
                .IMG_H (IMG_W),
                .CH    (CH),
                .SCALE (SCALE)
            ) u_full_span_engine (
                .clk     (clk),
                .rst     (rst),
                .s_valid (s_valid),
                .s_ready (s_ready),
                .s_data  (s_data),
                .s_user  (s_user),
                .s_last  (s_last),
                .m_valid (m_valid),
                .m_ready (m_ready),
                .m_data  (m_data),
                .m_user  (m_user),
                .m_last  (m_last),
                .busy    (engine_busy),
                .done    (engine_done)
            );

            wire unused_engine_status = engine_busy | engine_done;
        end else begin : g_compatible_stream_path
            wire compat_valid;
            wire compat_ready;
            wire [DATA_W-1:0] compat_data;
            wire compat_user;
            wire compat_last;

            // 当前可运行路径：官方入口 -> 兼容流式超分核。
            // 这样可以继续做 Vivado 仿真、JTAG/SD 上板链路验证和接口调试。
            sr_tinyspan_core #(
                .DATA_W(DATA_W),
                .IMG_W (IMG_W),
                .SCALE (SCALE),
                .BLOCKS(BLOCKS)
            ) u_stream_compatible_core (
                .clk     (clk),
                .rst     (rst),
                .s_valid (s_valid),
                .s_ready (s_ready),
                .s_data  (s_data),
                .s_user  (s_user),
                .s_last  (s_last),
                .m_valid (compat_valid),
                .m_ready (compat_ready),
                .m_data  (compat_data),
                .m_user  (compat_user),
                .m_last  (compat_last)
            );

            // 官方 conv_1.eval_conv 旁路诊断链。
            // 输入像素会被缓存成 RGB 3x3 窗口，并真实送入官方第一层 INT8 卷积。
            wire window_valid;
            wire window_ready;
            wire [3*9*FEAT_W-1:0] rgb_window;
            wire window_user;
            wire window_last;
            wire [8:0] window_valid_mask_unused;
            wire conv1_valid;
            wire conv1_ready;
            wire [CH*FEAT_W-1:0] conv1_feat;

            span_rgb_frame_window3x3 #(
                .DATA_W(DATA_W),
                .IMG_W (IMG_W),
                .IMG_H (IMG_W)
            ) u_conv1_window_source (
                .clk      (clk),
                .rst      (rst),
                .s_valid  (s_valid && s_ready),
                .s_ready  (window_ready),
                .s_data   (s_data),
                .s_user   (s_user),
                .s_last   (s_last),
                .m_valid  (window_valid),
                .m_ready  (conv1_ready),
                .window_o (rgb_window),
                .window_valid_mask_o(window_valid_mask_unused),
                .m_user   (window_user),
                .m_last   (window_last)
            );

            span_int8_conv3x3_layer #(
                .IN_CH(3),
                .OUT_CH(CH),
                .ACC_W(32),
                .SCALE_SHIFT(8),
                .WEIGHT_FILE(`OFFICIAL_SPAN_LAYER_0_FILE),
                .BIAS_FILE(`OFFICIAL_SPAN_LAYER_1_FILE)
            ) u_conv1_eval_diag (
                .clk      (clk),
                .rst      (rst),
                .s_valid  (window_valid),
                .s_ready  (conv1_ready),
                .window_i (rgb_window),
                .m_valid  (conv1_valid),
                .m_ready  (1'b1),
                .feat_o   (conv1_feat)
            );

            // SPAB attention 公式诊断锚点。
            wire spab_valid;
            wire spab_ready;
            wire [CH*FEAT_W-1:0] spab_feat;

            span_spab_int8_block #(
                .CH(CH),
                .FEAT_W(FEAT_W),
                .ACC_W(32)
            ) u_spab_int8_anchor (
                .clk     (clk),
                .rst     (rst),
                .s_valid (1'b0),
                .s_ready (spab_ready),
                .s_feat  ({CH*FEAT_W{1'b0}}),
                .m_valid (spab_valid),
                .m_ready (1'b1),
                .m_feat  (spab_feat)
            );

            // 44 个官方部署张量的统一权重银行诊断锚点。
            wire signed [7:0] official_weight_probe;
            wire signed [7:0] official_bias_probe;

            span_official_weight_bank #(
                .CH(CH),
                .SCALE(SCALE),
                .SYNC_READ(0)
            ) u_official_weight_bank (
                .clk         (clk),
                .layer_id    (5'd0),
                .weight_addr (16'd0),
                .bias_addr   (8'd0),
                .weight_o    (official_weight_probe),
                .bias_o      (official_bias_probe)
            );

            assign compat_ready = m_ready;
            assign m_valid = compat_valid;
            assign m_data  = compat_data;
            assign m_user  = compat_user;
            assign m_last  = compat_last;

            wire unused_diag = window_ready | window_user | window_last |
                               conv1_valid | spab_valid | spab_ready |
                               |conv1_feat | |spab_feat |
                               |official_weight_probe | |official_bias_probe;
        end
    endgenerate
endmodule
