`timescale 1ns/1ps

// RGB888 整帧 3x3 滑窗发生器。
//
// 用途：
//   官方 SPAN 第一层 conv_1.eval_conv 需要输入 3 个颜色通道、每通道 3x3 的窗口。
//   直接流式输入时，当前像素的右侧和下一行像素尚未到达，因此这里先采用整帧缓存方案：
//   先接收一帧低分辨率 RGB 图像，再按行优先顺序输出每个像素对应的零填充 3x3 窗口。
//
// 窗口展开顺序：
//   window_o[(channel*9 + kernel_index)*8 +: 8]
//   channel: 0=R, 1=G, 2=B
//   kernel_index: 0..8，对应从左上到右下的 3x3 顺序。
//
// 设计取舍：
//   该模块适合当前 64x64 JTAG/SD 板级验证和逐层 RTL 对齐；
//   后续实时视频链路可替换为低延迟行缓存版本。
module span_rgb_frame_window3x3 #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W  = 64,
    parameter integer IMG_H  = 64
) (
    input  wire              clk,
    input  wire              rst,

    input  wire              s_valid,
    output wire              s_ready,
    input  wire [DATA_W-1:0] s_data,
    input  wire              s_user,
    input  wire              s_last,

    output reg               m_valid,
    input  wire              m_ready,
    output reg  [3*9*8-1:0]  window_o,
    output reg  [8:0]        window_valid_mask_o,
    output wire              m_user,
    output wire              m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer COUNT_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);
    localparam integer X_W = (IMG_W <= 2) ? 1 : $clog2(IMG_W);
    localparam integer Y_W = (IMG_H <= 2) ? 1 : $clog2(IMG_H);

    localparam [1:0] ST_CAPTURE = 2'd0;
    localparam [1:0] ST_EMIT    = 2'd1;

    reg [1:0] state;
    reg [DATA_W-1:0] frame_mem [0:FRAME_PIXELS-1];
    reg [COUNT_W-1:0] wr_idx;
    reg [COUNT_W-1:0] rd_idx;
    reg [X_W-1:0] out_x;
    reg [Y_W-1:0] out_y;

    wire take_in = s_valid && s_ready;
    wire take_out = m_valid && m_ready;
    wire capture_done = take_in && (wr_idx == FRAME_PIXELS-1);
    wire emit_done = take_out && (rd_idx == FRAME_PIXELS-1);

    assign s_ready = (state == ST_CAPTURE);
    assign m_user = (state == ST_EMIT) &&
                    (rd_idx == {COUNT_W{1'b0}});
    assign m_last = (state == ST_EMIT) &&
                    (out_x == IMG_W-1);

    integer kx;
    integer ky;
    integer ch;
    integer tap;
    integer sx;
    integer sy;
    integer src_idx;
    reg [DATA_W-1:0] src_pix;

    always @(*) begin
        window_o = {3*9*8{1'b0}};
        window_valid_mask_o = 9'b0;
        for (ch = 0; ch < 3; ch = ch + 1) begin
            for (ky = 0; ky < 3; ky = ky + 1) begin
                for (kx = 0; kx < 3; kx = kx + 1) begin
                    sx = out_x + kx - 1;
                    sy = out_y + ky - 1;
                    tap = ky * 3 + kx;
                    if ((sx >= 0) && (sx < IMG_W) && (sy >= 0) && (sy < IMG_H)) begin
                        src_idx = sy * IMG_W + sx;
                        src_pix = frame_mem[src_idx];
                        window_valid_mask_o[tap] = 1'b1;
                        case (ch)
                            0: window_o[(ch*9 + tap)*8 +: 8] = src_pix[23:16];
                            1: window_o[(ch*9 + tap)*8 +: 8] = src_pix[15:8];
                            default: window_o[(ch*9 + tap)*8 +: 8] = src_pix[7:0];
                        endcase
                    end
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state   <= ST_CAPTURE;
            wr_idx  <= {COUNT_W{1'b0}};
            rd_idx  <= {COUNT_W{1'b0}};
            out_x   <= {X_W{1'b0}};
            out_y   <= {Y_W{1'b0}};
            m_valid <= 1'b0;
        end else begin
            case (state)
                ST_CAPTURE: begin
                    m_valid <= 1'b0;
                    if (take_in) begin
                        frame_mem[wr_idx] <= s_data;
                        if (capture_done) begin
                            state   <= ST_EMIT;
                            wr_idx  <= {COUNT_W{1'b0}};
                            rd_idx  <= {COUNT_W{1'b0}};
                            out_x   <= {X_W{1'b0}};
                            out_y   <= {Y_W{1'b0}};
                            m_valid <= 1'b1;
                        end else begin
                            wr_idx <= wr_idx + 1'b1;
                        end
                    end
                end

                ST_EMIT: begin
                    if (take_out) begin
                        if (emit_done) begin
                            state   <= ST_CAPTURE;
                            rd_idx  <= {COUNT_W{1'b0}};
                            out_x   <= {X_W{1'b0}};
                            out_y   <= {Y_W{1'b0}};
                            m_valid <= 1'b0;
                        end else begin
                            rd_idx <= rd_idx + 1'b1;
                            if (out_x == IMG_W-1) begin
                                out_x <= {X_W{1'b0}};
                                out_y <= out_y + 1'b1;
                            end else begin
                                out_x <= out_x + 1'b1;
                            end
                        end
                    end
                end

                default: begin
                    state   <= ST_CAPTURE;
                    m_valid <= 1'b0;
                end
            endcase
        end
    end

    wire unused_input_flags = s_user | s_last;
endmodule
