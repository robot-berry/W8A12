`timescale 1ns/1ps

// Single-beat AXI4 pixel memory bridge.
//
// 本模块实现一个简单的 AXI4 Master 桥接，专门用于单像素读写 DDR 帧存储。
// W8A12 tile shell 对外提供按字节地址的 RGB 像素读写请求，
// 而 DDR 路径内部以 XRGB888 格式存储帧数据，每个像素占 32 位。
// 因此所有像素地址天然 32 位对齐，模块只需发起单次 AXI 读/写事务。
module sr_ddr_pixel_axi_master #(
    parameter integer ADDR_W = 32,
    parameter integer DATA_W = 24,
    parameter integer AXI_DATA_W = 32
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  rd_req_valid,
    output wire                  rd_req_ready,
    input  wire [ADDR_W-1:0]     rd_req_addr,
    output reg                   rd_resp_valid,
    output reg  [DATA_W-1:0]     rd_resp_data,

    input  wire                  wr_valid,
    output wire                  wr_ready,
    input  wire [ADDR_W-1:0]     wr_addr,
    input  wire [DATA_W-1:0]     wr_data,

    output wire                  busy,
    output reg                   error,

    output reg  [ADDR_W-1:0]     m_axi_awaddr,
    output wire [7:0]            m_axi_awlen,
    output wire [2:0]            m_axi_awsize,
    output wire [1:0]            m_axi_awburst,
    output wire [3:0]            m_axi_awcache,
    output wire [2:0]            m_axi_awprot,
    output reg                   m_axi_awvalid,
    input  wire                  m_axi_awready,

    output reg  [AXI_DATA_W-1:0] m_axi_wdata,
    output reg  [(AXI_DATA_W/8)-1:0] m_axi_wstrb,
    output reg                   m_axi_wlast,
    output reg                   m_axi_wvalid,
    input  wire                  m_axi_wready,

    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_bvalid,
    output reg                   m_axi_bready,

    output reg  [ADDR_W-1:0]     m_axi_araddr,
    output wire [7:0]            m_axi_arlen,
    output wire [2:0]            m_axi_arsize,
    output wire [1:0]            m_axi_arburst,
    output wire [3:0]            m_axi_arcache,
    output wire [2:0]            m_axi_arprot,
    output reg                   m_axi_arvalid,
    input  wire                  m_axi_arready,

    input  wire [AXI_DATA_W-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rlast,
    input  wire                  m_axi_rvalid,
    output reg                   m_axi_rready
);
    // 状态机状态：
    // ST_IDLE: 空闲，可接受新的读请求或写请求。
    // ST_RADDR: 已发出读地址请求，等待 AXI 读地址通道就绪。
    // ST_RDATA: 已接收读数据，等待有效数据返回。
    // ST_WADDR: 已发出写地址并且写数据，等待写响应。
    // ST_WRESP: 已发出写请求，等待 AXI 写响应返回。
    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_RADDR = 3'd1;
    localparam [2:0] ST_RDATA = 3'd2;
    localparam [2:0] ST_WADDR = 3'd3;
    localparam [2:0] ST_WRESP = 3'd4;

    localparam integer AXI_BYTES = AXI_DATA_W / 8;
    localparam [2:0] AXI_SIZE_32 = 3'd2; // AXI size field for 32-bit beats
    localparam [AXI_BYTES-1:0] WSTRB_RGB = {AXI_BYTES{1'b1}}; // 全字节写使能

    reg [2:0] state;
    reg aw_done;
    reg w_done;

    assign rd_req_ready = (state == ST_IDLE);
    assign wr_ready = (state == ST_IDLE) && !rd_req_valid;
    assign busy = (state != ST_IDLE);

    assign m_axi_awlen = 8'd0;
    assign m_axi_awsize = AXI_SIZE_32;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot = 3'b000;
    assign m_axi_arlen = 8'd0;
    assign m_axi_arsize = AXI_SIZE_32;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot = 3'b000;

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            aw_done <= 1'b0;
            w_done <= 1'b0;
            error <= 1'b0;
            rd_resp_valid <= 1'b0;
            rd_resp_data <= {DATA_W{1'b0}};
            m_axi_awaddr <= {ADDR_W{1'b0}};
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= {AXI_DATA_W{1'b0}};
            m_axi_wstrb <= {AXI_BYTES{1'b0}};
            m_axi_wlast <= 1'b0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b0;
            m_axi_araddr <= {ADDR_W{1'b0}};
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b0;
        end else begin
            rd_resp_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    // 空闲时将所有 AXI 请求信号复位，等待新的请求
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid <= 1'b0;
                    m_axi_wlast <= 1'b0;
                    m_axi_bready <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready <= 1'b0;
                    aw_done <= 1'b0;
                    w_done <= 1'b0;

                    if (rd_req_valid) begin
                        // 读请求：地址按 32 位像素对齐
                        m_axi_araddr <= {rd_req_addr[ADDR_W-1:2], 2'b00};
                        m_axi_arvalid <= 1'b1;
                        state <= ST_RADDR;
                    end else if (wr_valid) begin
                        // 写请求：把 24-bit RGB 数据放到 32-bit AXI 数据总线上，高位补 0
                        m_axi_awaddr <= {wr_addr[ADDR_W-1:2], 2'b00};
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata <= {{(AXI_DATA_W-DATA_W){1'b0}}, wr_data};
                        m_axi_wstrb <= WSTRB_RGB;
                        m_axi_wlast <= 1'b1;
                        m_axi_wvalid <= 1'b1;
                        state <= ST_WADDR;
                    end
                end

                ST_RADDR: begin
                    // 读地址通道握手完成后，启动读数据通道
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready <= 1'b1;
                        state <= ST_RDATA;
                    end
                end

                ST_RDATA: begin
                    // 读取到数据后，将低 24bit 作为像素值返回
                    if (m_axi_rvalid && m_axi_rready) begin
                        rd_resp_valid <= 1'b1;
                        rd_resp_data <= m_axi_rdata[DATA_W-1:0];
                        m_axi_rready <= 1'b0;
                        if (m_axi_rresp != 2'b00 || !m_axi_rlast)
                            error <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                ST_WADDR: begin
                    // 写地址通道与写数据通道可以并行完成，待两者都完成后等待写响应
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        aw_done <= 1'b1;
                    end
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        m_axi_wlast <= 1'b0;
                        w_done <= 1'b1;
                    end
                    if ((aw_done || (m_axi_awvalid && m_axi_awready)) &&
                        (w_done || (m_axi_wvalid && m_axi_wready))) begin
                        m_axi_bready <= 1'b1;
                        state <= ST_WRESP;
                    end
                end

                ST_WRESP: begin
                    // 写响应返回后，检测是否有错误并回到空闲状态
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        if (m_axi_bresp != 2'b00)
                            error <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    error <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
