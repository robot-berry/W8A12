`timescale 1ns/1ps

// SD 文件验证用 AXI-Lite 超分加速器。
// 板上 MicroSD 接在 Zynq PS 的 SD1/MIO 上，因此 SD 文件读写由 PS 软件完成；
// 本模块只负责提供一个 AXI-Lite 寄存器窗口，让 PS 把 RGB888 像素逐个送入
// sr_super_resolution_pipeline，并逐个读回放大后的 RGB888 像素。
//
// 该接口重在上板功能验证，吞吐量不如 AXI-DMA/VDMA，但工程简单、容易调通。
// FRAME_CYCLES 统计的是端点实际捕获整帧输出的周期，会反映 AXI-Lite/JTAG
// backpressure；它是保守的端到端板上吞吐证据，不是无背压核心理论吞吐。
module sr_sd_axi_lite_accel #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer DATA_W             = 24,
    parameter integer IMG_W              = 64,
    parameter integer IMG_H              = IMG_W,
    parameter integer SCALE              = 2,
    parameter integer USE_FULL_OFFICIAL_SPAN = 0,
    parameter integer USE_W8A12_FULL_STREAMED = 0,
    parameter integer USE_W8A10_FULL_STREAMED = 0,
    parameter integer USE_TINYSPAN_W8A8_BASE_EQUIV = 0,
    parameter integer USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL = 1,
    parameter integer W8A12_OUT_LANES    = 8,
    parameter integer W8A12_TAP_LANES    = 16,
    parameter integer W8A12_SCALE_LANES  = 2,
    parameter integer VIDEO_GAIN_EN      = 1
) (
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                        s_axi_arprot,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    output wire                              irq
);
    localparam [5:0] REG_STATUS       = 6'h00;
    localparam [5:0] REG_INPUT_FLAGS  = 6'h04;
    localparam [5:0] REG_INPUT_PIXEL  = 6'h08;
    localparam [5:0] REG_OUTPUT_PIXEL = 6'h0c;
    localparam [5:0] REG_OUTPUT_FLAGS = 6'h10;
    localparam [5:0] REG_COUNTER_IN   = 6'h14;
    localparam [5:0] REG_COUNTER_OUT  = 6'h18;
    localparam [5:0] REG_ERROR        = 6'h1c;
    localparam [5:0] REG_FRAME_CYCLES = 6'h20;
    localparam [5:0] REG_FRAME_DONE   = 6'h24;
    localparam [5:0] REG_PERF_CTRL    = 6'h28;
    localparam [5:0] REG_E2E_CYCLES   = 6'h2c;
    localparam integer OUTPUT_PIXELS  = IMG_W * IMG_H * SCALE * SCALE;

    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg;
    reg [C_S_AXI_ADDR_WIDTH-1:0] araddr_reg;

    reg        input_user_reg;
    reg        input_last_reg;
    reg        input_push;
    reg [23:0] input_pixel_reg;

    wire       in_ready;
    wire       out_valid;
    wire [23:0] out_pixel;
    wire       out_user;
    wire       out_last;

    reg        out_hold_valid;
    reg [23:0] out_hold_pixel;
    reg        out_hold_user;
    reg        out_hold_last;
    wire       write_accept;
    wire       read_accept;
    wire       out_pop_now;

    reg [31:0] input_count;
    reg [31:0] output_count;
    reg [31:0] frame_output_count;
    reg [31:0] frame_cycle_count;
    reg [31:0] frame_cycle_latched;
    reg [31:0] e2e_cycle_count;
    reg [31:0] e2e_cycle_latched;
    reg        frame_perf_active;
    reg        frame_output_active;
    reg        frame_perf_done;
    reg        perf_drain_enable;
    reg        input_drop_error;
    reg        output_overrun_error;

    wire rst = !s_axi_aresetn;
    assign write_accept = !s_axi_bvalid && s_axi_awvalid && s_axi_wvalid;
    assign read_accept  = !s_axi_rvalid && s_axi_arvalid;
    assign out_pop_now  = read_accept && (s_axi_araddr[5:0] == REG_OUTPUT_PIXEL) && out_hold_valid;

    wire can_accept_output = perf_drain_enable || !out_hold_valid;

    assign irq = out_hold_valid;

    // AXI-Lite 写通道：单拍接收地址和数据。
    always @(posedge s_axi_aclk) begin
        if (rst) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            awaddr_reg    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;

            if (write_accept) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                awaddr_reg    <= s_axi_awaddr;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // AXI-Lite 读通道：读取状态/输出寄存器。
    always @(posedge s_axi_aclk) begin
        if (rst) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= {C_S_AXI_DATA_WIDTH{1'b0}};
            araddr_reg    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            s_axi_arready <= 1'b0;
            if (read_accept) begin
                s_axi_arready <= 1'b1;
                araddr_reg    <= s_axi_araddr;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;
                case (s_axi_araddr[5:0])
                    REG_STATUS:
                        s_axi_rdata <= {
                            20'd0,
                            output_overrun_error,
                            input_drop_error,
                            out_hold_last,
                            out_hold_user,
                            out_hold_valid,
                            in_ready,
                            6'd0
                        };
                    REG_OUTPUT_PIXEL:
                        s_axi_rdata <= {8'd0, out_hold_pixel};
                    REG_OUTPUT_FLAGS:
                        s_axi_rdata <= {30'd0, out_hold_last, out_hold_user};
                    REG_COUNTER_IN:
                        s_axi_rdata <= input_count;
                    REG_COUNTER_OUT:
                        s_axi_rdata <= output_count;
                    REG_ERROR:
                        s_axi_rdata <= {30'd0, output_overrun_error, input_drop_error};
                    REG_FRAME_CYCLES:
                        s_axi_rdata <= frame_cycle_latched;
                    REG_FRAME_DONE:
                        s_axi_rdata <= {31'd0, frame_perf_done};
                    REG_PERF_CTRL:
                        s_axi_rdata <= {31'd0, perf_drain_enable};
                    REG_E2E_CYCLES:
                        s_axi_rdata <= e2e_cycle_latched;
                    default:
                        s_axi_rdata <= 32'd0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            input_user_reg      <= 1'b0;
            input_last_reg      <= 1'b0;
            input_push          <= 1'b0;
            input_pixel_reg     <= 24'd0;
            input_count         <= 32'd0;
            input_drop_error    <= 1'b0;
            perf_drain_enable   <= 1'b0;
        end else begin
            input_push <= 1'b0;
            if (write_accept) begin
                case (s_axi_awaddr[5:0])
                    REG_INPUT_FLAGS: begin
                        input_user_reg <= s_axi_wdata[0];
                        input_last_reg <= s_axi_wdata[1];
                    end
                    REG_INPUT_PIXEL: begin
                        if (in_ready) begin
                            input_pixel_reg  <= s_axi_wdata[23:0];
                            input_push       <= 1'b1;
                            input_count      <= input_count + 32'd1;
                        end else begin
                            input_drop_error <= 1'b1;
                        end
                    end
                    REG_ERROR: begin
                        if (s_axi_wdata[0])
                            input_drop_error <= 1'b0;
                    end
                    REG_PERF_CTRL: begin
                        perf_drain_enable <= s_axi_wdata[0];
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            out_hold_valid       <= 1'b0;
            out_hold_pixel       <= 24'd0;
            out_hold_user        <= 1'b0;
            out_hold_last        <= 1'b0;
            output_count         <= 32'd0;
            frame_output_count   <= 32'd0;
            frame_cycle_count    <= 32'd0;
            frame_cycle_latched  <= 32'd0;
            e2e_cycle_count      <= 32'd0;
            e2e_cycle_latched    <= 32'd0;
            frame_perf_active    <= 1'b0;
            frame_output_active  <= 1'b0;
            frame_perf_done      <= 1'b0;
            output_overrun_error <= 1'b0;
        end else begin
            if (input_push && input_user_reg) begin
                frame_output_count  <= 32'd0;
                frame_cycle_count   <= 32'd0;
                frame_cycle_latched <= 32'd0;
                e2e_cycle_count     <= 32'd0;
                e2e_cycle_latched   <= 32'd0;
                frame_perf_active   <= 1'b1;
                frame_output_active <= 1'b0;
                frame_perf_done     <= 1'b0;
            end else if (frame_perf_active) begin
                e2e_cycle_count <= e2e_cycle_count + 32'd1;
                if (frame_output_active)
                    frame_cycle_count <= frame_cycle_count + 32'd1;
            end

            if (out_valid && can_accept_output) begin
                if (!perf_drain_enable) begin
                    out_hold_valid <= 1'b1;
                    out_hold_pixel <= out_pixel;
                    out_hold_user  <= out_user;
                    out_hold_last  <= out_last;
                end
                output_count   <= output_count + 32'd1;
                if (frame_perf_active) begin
                    if (!frame_output_active) begin
                        frame_output_active <= 1'b1;
                        frame_cycle_count <= 32'd1;
                    end
                    frame_output_count <= frame_output_count + 32'd1;
                    if ((frame_output_count + 32'd1) >= OUTPUT_PIXELS) begin
                        frame_cycle_latched <= frame_output_active ? (frame_cycle_count + 32'd1) : 32'd1;
                        e2e_cycle_latched <= e2e_cycle_count + 32'd1;
                        frame_perf_active <= 1'b0;
                        frame_output_active <= 1'b0;
                        frame_perf_done <= 1'b1;
                    end
                end
            end else if (out_pop_now) begin
                out_hold_valid <= 1'b0;
            end

            if (write_accept && s_axi_awaddr[5:0] == REG_ERROR && s_axi_wdata[1])
                output_overrun_error <= 1'b0;
        end
    end

    generate
        if (USE_TINYSPAN_W8A8_BASE_EQUIV) begin : g_tinyspan_w8a8_base_equiv_core
            span_tinyspan_w8a8_full_streamed_rgb888_base_equiv #(
                .DATA_W(DATA_W),
                .IMG_W (IMG_W),
                .IMG_H (IMG_H),
                .USE_SERIAL_BASE(USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL)
            ) u_tinyspan_base_equiv (
                .clk     (s_axi_aclk),
                .rst     (rst),
                .s_valid (input_push),
                .s_ready (in_ready),
                .s_data  (input_pixel_reg),
                .s_user  (input_user_reg),
                .s_last  (input_last_reg),
                .m_valid (out_valid),
                .m_ready (can_accept_output),
                .m_data  (out_pixel),
                .m_user  (out_user),
                .m_last  (out_last)
            );
        end else if (USE_W8A10_FULL_STREAMED) begin : g_w8a10_direct_core
            span_w8a10_full_streamed_rgb_axis #(
                .DATA_W(DATA_W),
                .IMG_W (IMG_W),
                .IMG_H (IMG_H),
                .SCALE (4)
            ) u_w8a10_axis (
                .aclk          (s_axi_aclk),
                .aresetn       (s_axi_aresetn),
                .s_axis_tvalid (input_push),
                .s_axis_tready (in_ready),
                .s_axis_tdata  (input_pixel_reg),
                .s_axis_tuser  (input_user_reg),
                .s_axis_tlast  (input_last_reg),
                .m_axis_tvalid (out_valid),
                .m_axis_tready (can_accept_output),
                .m_axis_tdata  (out_pixel),
                .m_axis_tuser  (out_user),
                .m_axis_tlast  (out_last)
            );
        end else if (USE_W8A12_FULL_STREAMED) begin : g_w8a12_direct_core
            span_w8a12_full_streamed_rgb_axis #(
                .DATA_W(DATA_W),
                .IMG_W (IMG_W),
                .IMG_H (IMG_H),
                .OUT_LANES(W8A12_OUT_LANES),
                .TAP_LANES(W8A12_TAP_LANES),
                .SCALE_LANES(W8A12_SCALE_LANES)
            ) u_w8a12_axis (
                .aclk          (s_axi_aclk),
                .aresetn       (s_axi_aresetn),
                .s_axis_tvalid (input_push),
                .s_axis_tready (in_ready),
                .s_axis_tdata  (input_pixel_reg),
                .s_axis_tuser  (input_user_reg),
                .s_axis_tlast  (input_last_reg),
                .m_axis_tvalid (out_valid),
                .m_axis_tready (can_accept_output),
                .m_axis_tdata  (out_pixel),
                .m_axis_tuser  (out_user),
                .m_axis_tlast  (out_last)
            );
        end else begin : g_pipeline_core
            sr_super_resolution_pipeline #(
                .DATA_W(DATA_W),
                .IMG_W (IMG_W),
                .SCALE (SCALE),
                .USE_FULL_OFFICIAL_SPAN(USE_FULL_OFFICIAL_SPAN),
                .USE_W8A12_FULL_STREAMED(USE_W8A12_FULL_STREAMED),
                .VIDEO_GAIN_EN(VIDEO_GAIN_EN)
            ) u_sr_pipeline (
                .aclk          (s_axi_aclk),
                .aresetn       (s_axi_aresetn),
                .s_axis_tvalid (input_push),
                .s_axis_tready (in_ready),
                .s_axis_tdata  (input_pixel_reg),
                .s_axis_tuser  (input_user_reg),
                .s_axis_tlast  (input_last_reg),
                .m_axis_tvalid (out_valid),
                .m_axis_tready (can_accept_output),
                .m_axis_tdata  (out_pixel),
                .m_axis_tuser  (out_user),
                .m_axis_tlast  (out_last)
            );
        end
    endgenerate

    // 未使用的 AXI 保护/字节选通信号保留，避免综合器误报未连接端口语义。
    wire unused_axi = |s_axi_awprot | |s_axi_arprot | |s_axi_wstrb | |araddr_reg;
endmodule
