`timescale 1ns/1ps

// 通用顺序式 INT8 3x3 卷积层。
//
// 输入为已经展开好的完整 3x3 滑窗：
//   window_i[(tap*8)+:8], tap = input_channel*9 + kernel_index
// 输出为展开后的输出通道特征向量：
//   feat_o[(out_channel*8)+:8]
//
// 设计取舍：
//   这里先采用顺序 MAC，便于把官方 SPAN 权重接入到可综合纯电路中，
//   资源占用低但吞吐较低。后续要做实时视频超分时，可以通过展开
//   tap_idx/out_idx 增加并行 MAC lane。
module span_int8_conv3x3_layer #(
    parameter integer IN_CH = 48,
    parameter integer OUT_CH = 48,
    parameter integer ACC_W = 32,
    parameter integer SCALE_SHIFT = 8,
    parameter WEIGHT_FILE = "",
    parameter BIAS_FILE = ""
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire [IN_CH*9*8-1:0]         window_i,

    output reg                          m_valid,
    input  wire                         m_ready,
    output reg [OUT_CH*8-1:0]           feat_o
);
    localparam integer TAP_COUNT = IN_CH * 9;
    localparam integer WEIGHT_COUNT = OUT_CH * TAP_COUNT;
    localparam integer TAP_W = (TAP_COUNT <= 2) ? 1 : $clog2(TAP_COUNT);
    localparam integer OUT_W = (OUT_CH <= 2) ? 1 : $clog2(OUT_CH);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_MAC  = 2'd1;
    localparam [1:0] ST_OUT  = 2'd2;

    reg [1:0] state;
    reg [IN_CH*9*8-1:0] window_q;
    reg [TAP_W-1:0] tap_idx;
    reg [OUT_W-1:0] out_idx;
    reg signed [ACC_W-1:0] acc_q;

    reg signed [7:0] weight_mem [0:WEIGHT_COUNT-1];
    reg signed [7:0] bias_mem [0:OUT_CH-1];

    wire signed [7:0] act = window_q[tap_idx*8 +: 8];
    wire signed [7:0] weight = weight_mem[out_idx*TAP_COUNT + tap_idx];
    wire signed [15:0] product = act * weight;
    wire signed [ACC_W-1:0] product_ext = {{(ACC_W-16){product[15]}}, product};
    wire signed [ACC_W-1:0] acc_next = acc_q + product_ext;
    wire signed [ACC_W-1:0] scaled = acc_next >>> SCALE_SHIFT;
    wire signed [7:0] q_next = (scaled > 127) ? 8'sd127 :
                               (scaled < -128) ? 8'sh80 :
                               scaled[7:0];

    // 空闲时接收一个完整滑窗，然后依次完成 OUT_CH 个输出通道的点积。
    assign s_ready = (state == ST_IDLE);

    integer i;
    initial begin
        for (i = 0; i < WEIGHT_COUNT; i = i + 1)
            weight_mem[i] = 8'sd0;
        for (i = 0; i < OUT_CH; i = i + 1)
            bias_mem[i] = 8'sd0;
        if (WEIGHT_FILE != "")
            // 权重文件由 train/export_official_span_to_rtl.py 从官方 checkpoint 导出。
            $readmemh(WEIGHT_FILE, weight_mem);
        if (BIAS_FILE != "")
            $readmemh(BIAS_FILE, bias_mem);
    end

    always @(posedge clk) begin
        if (rst) begin
            state    <= ST_IDLE;
            window_q <= {IN_CH*9*8{1'b0}};
            tap_idx  <= {TAP_W{1'b0}};
            out_idx  <= {OUT_W{1'b0}};
            acc_q    <= {ACC_W{1'b0}};
            m_valid  <= 1'b0;
            feat_o   <= {OUT_CH*8{1'b0}};
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        // 锁存输入滑窗，从第 0 个输出通道开始累加。
                        window_q <= window_i;
                        tap_idx  <= {TAP_W{1'b0}};
                        out_idx  <= {OUT_W{1'b0}};
                        acc_q    <= {{(ACC_W-8){bias_mem[0][7]}}, bias_mem[0]};
                        state    <= ST_MAC;
                    end
                end

                ST_MAC: begin
                    // 每周期计算一个 activation*weight，并累加到当前输出通道。
                    acc_q <= acc_next;
                    if (tap_idx == TAP_COUNT-1) begin
                        // 一个输出通道累加完成后，进行移位重量化和 INT8 饱和。
                        feat_o[out_idx*8 +: 8] <= q_next;
                        tap_idx <= {TAP_W{1'b0}};
                        if (out_idx == OUT_CH-1) begin
                            state   <= ST_OUT;
                            m_valid <= 1'b1;
                        end else begin
                            out_idx <= out_idx + 1'b1;
                            acc_q <= {{(ACC_W-8){bias_mem[out_idx + 1'b1][7]}}, bias_mem[out_idx + 1'b1]};
                        end
                    end else begin
                        tap_idx <= tap_idx + 1'b1;
                    end
                end

                ST_OUT: begin
                    if (!m_valid || m_ready)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
