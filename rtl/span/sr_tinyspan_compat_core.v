`timescale 1ns/1ps
`include "../generated/tinyspan_model_config.vh"

`ifndef TINYSPAN_MODEL_SCALE
`define TINYSPAN_MODEL_SCALE 4
`endif

`ifndef TINYSPAN_MODEL_BLOCKS
`define TINYSPAN_MODEL_BLOCKS 6
`endif

// SPAN/TinySPAN 流式超分核心。
// 对外保持 AXI-Stream 像素流接口，便于接入摄像头、HDMI 或板级演示链路。
//
// 当前状态：
//   1. 训练侧已切换到官方 SPAN，权重由 rtl/generated/official_span_x4 导出；
//   2. 本模块仍是硬件友好的流式近似核心，先保证纯 Verilog 可综合和可上板；
//   3. 下一步可把 tinyspan_pixel 内的近似计算替换为 INT8 卷积阵列，逐层读取官方导出权重。
//
// 数据通路近似对应：
//   head 特征提取 -> SPAB x6 参数免费 attention 近似 -> PixelShuffle/上采样输出。
module sr_tinyspan_core #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W  = 64,
    parameter integer SCALE  = `TINYSPAN_MODEL_SCALE,
    parameter integer BLOCKS = `TINYSPAN_MODEL_BLOCKS
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
    localparam integer CH_W = DATA_W / 3;
    localparam integer X_W  = (IMG_W <= 2) ? 1 : $clog2(IMG_W);

    // 两行缓存提供当前像素左侧、上方和左上角的局部窗口信息。
    reg [DATA_W-1:0] line0 [0:IMG_W-1];
    reg [DATA_W-1:0] line1 [0:IMG_W-1];
    reg [DATA_W-1:0] left0;
    reg [DATA_W-1:0] left1;
    reg [X_W-1:0]    x_pos;
    reg              first_row;
    reg              second_row;

    reg              core_valid;
    wire             core_ready;
    reg [DATA_W-1:0] core_data;
    reg              core_user;
    reg              core_last;

    wire fire = s_valid && s_ready;
    wire border = first_row || second_row || (x_pos == {X_W{1'b0}});

    assign s_ready = !core_valid || core_ready;

    function [CH_W-1:0] clamp_u8;
        input signed [17:0] v;
        begin
            if (v < 0)
                clamp_u8 = {CH_W{1'b0}};
            else if (v > ((1 << CH_W) - 1))
                clamp_u8 = {CH_W{1'b1}};
            else
                clamp_u8 = v[CH_W-1:0];
        end
    endfunction

    function [7:0] hard_sigmoid_gate;
        input signed [17:0] x;
        reg signed [17:0] shifted;
        begin
            // 用移位和截断近似 sigmoid，用于模拟 SPAN 中 parameter-free attention 的门控。
            shifted = (x >>> 1) + 18'sd128;
            hard_sigmoid_gate = clamp_u8(shifted);
        end
    endfunction

    function [DATA_W-1:0] head_extract;
        input [DATA_W-1:0] cur;
        input [DATA_W-1:0] up;
        input [DATA_W-1:0] left;
        input [DATA_W-1:0] up_left;
        input              bypass;
        reg [CH_W-1:0] c;
        reg [CH_W-1:0] u;
        reg [CH_W-1:0] l;
        reg [CH_W-1:0] ul;
        reg signed [17:0] smooth;
        reg signed [17:0] detail;
        reg signed [17:0] value;
        integer i;
        begin
            head_extract = {DATA_W{1'b0}};
            for (i = 0; i < 3; i = i + 1) begin
                c  = cur[i*CH_W +: CH_W];
                u  = up[i*CH_W +: CH_W];
                l  = left[i*CH_W +: CH_W];
                ul = up_left[i*CH_W +: CH_W];
                if (bypass) begin
                    head_extract[i*CH_W +: CH_W] = c;
                end else begin
                    // 轻量 3x3 局部纹理估计：先得到邻域平滑值，再增强当前像素的高频细节。
                    smooth = ($signed({1'b0, u}) + $signed({1'b0, l}) + $signed({1'b0, ul})) / 3;
                    detail = $signed({1'b0, c}) - smooth;
                    value  = $signed({1'b0, c}) + (detail >>> 1);
                    head_extract[i*CH_W +: CH_W] = clamp_u8(value);
                end
            end
        end
    endfunction

    function [DATA_W-1:0] spab_compute;
        input [DATA_W-1:0] feat;
        input integer      block_id;
        reg [CH_W-1:0] f;
        reg signed [17:0] centered;
        reg signed [17:0] residual;
        reg signed [17:0] gated;
        reg [7:0] gate;
        integer i;
        begin
            spab_compute = {DATA_W{1'b0}};
            for (i = 0; i < 3; i = i + 1) begin
                f = feat[i*CH_W +: CH_W];
                centered = $signed({1'b0, f}) - 18'sd128;
                // SPAB 的三层卷积暂以低成本残差近似表达，block_id 引入逐层强度差异。
                residual = centered >>> (1 + (block_id & 1));
                gate = hard_sigmoid_gate(centered);
                gated = ($signed(residual) * $signed({1'b0, gate})) >>> 8;
                spab_compute[i*CH_W +: CH_W] = clamp_u8($signed({1'b0, f}) + gated);
            end
        end
    endfunction

    function [DATA_W-1:0] tinyspan_pixel;
        input [DATA_W-1:0] cur;
        input [DATA_W-1:0] up;
        input [DATA_W-1:0] left;
        input [DATA_W-1:0] up_left;
        input              bypass;
        reg [DATA_W-1:0] feat;
        integer b;
        begin
            feat = head_extract(cur, up, left, up_left, bypass);
            for (b = 0; b < BLOCKS; b = b + 1) begin
                feat = spab_compute(feat, b);
            end
            tinyspan_pixel = feat;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            core_valid <= 1'b0;
            core_data  <= {DATA_W{1'b0}};
            core_user  <= 1'b0;
            core_last  <= 1'b0;
            x_pos      <= {X_W{1'b0}};
            left0      <= {DATA_W{1'b0}};
            left1      <= {DATA_W{1'b0}};
            first_row  <= 1'b1;
            second_row <= 1'b1;
        end else begin
            if (core_ready)
                core_valid <= 1'b0;

            if (fire) begin
                core_valid <= 1'b1;
                core_user  <= s_user;
                core_last  <= s_last;
                core_data  <= tinyspan_pixel(s_data, line0[x_pos], left0, line1[x_pos], border);

                line1[x_pos] <= line0[x_pos];
                line0[x_pos] <= s_data;
                left1        <= line1[x_pos];
                left0        <= s_data;

                if (s_last) begin
                    x_pos <= {X_W{1'b0}};
                    left0 <= {DATA_W{1'b0}};
                    left1 <= {DATA_W{1'b0}};
                    first_row <= 1'b0;
                    if (first_row)
                        second_row <= 1'b1;
                    else
                        second_row <= 1'b0;
                end else begin
                    x_pos <= x_pos + 1'b1;
                end
            end
        end
    end

    // 官方 SPAN 的重建层输出 r^2*C 通道后 PixelShuffle。
    // 当前流式 RTL 使用等价的像素块输出时序表达，便于逐像素实时处理。
    sr_nearest_upsampler #(
        .DATA_W(DATA_W),
        .IMG_W (IMG_W),
        .SCALE (SCALE)
    ) u_pixelshuffle_stream (
        .clk     (clk),
        .rst     (rst),
        .s_valid (core_valid),
        .s_ready (core_ready),
        .s_data  (core_data),
        .s_user  (core_user),
        .s_last  (core_last),
        .m_valid (m_valid),
        .m_ready (m_ready),
        .m_data  (m_data),
        .m_user  (m_user),
        .m_last  (m_last)
    );
endmodule
