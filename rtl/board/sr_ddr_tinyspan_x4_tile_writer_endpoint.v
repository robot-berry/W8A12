`timescale 1ns/1ps

// DDR-backed TinySPAN X4 tile-writer endpoint.
//
// This module does not implement a DDR controller or DDR PHY. Board DDR is
// provided by the ZynqMP PS DDR controller IP in Vivado Block Design; this
// module is only AXI user logic connected to the PS HP/HPC DDR port.
//
// Control is AXI-Lite from PS. Image data stays in DDR as XRGB888 words:
// - input_base points to the full LR frame, one 32-bit word per RGB pixel.
// - output_base points to the full HR frame, one 32-bit word per RGB pixel.
// PL performs board-side tile scheduling, TinySPAN X4 inference, valid-region
// cropping, and writeback to the full-frame output buffer.
//
// Register map, 32-bit AXI-Lite:
//   0x00 CONTROL        bit0=start, bit1=clear/soft reset
//   0x04 STATUS         bit0=start_allowed, bit1=busy, bit2=active,
//                       bit3=done, bit4=any_error, bit5=shell_error,
//                       bit6=ddr_error, bit7=ddr_busy
//   0x08 IMG_W          LR frame width
//   0x0c IMG_H          LR frame height
//   0x10 INPUT_BASE     DDR byte address, 32-bit aligned
//   0x14 OUTPUT_BASE    DDR byte address, 32-bit aligned
//   0x18 FRAME_CYCLES_LO
//   0x1c FRAME_CYCLES_HI
//   0x20 TILES_DONE
//   0x24 ERROR          bit0=any_error, bit1=sw_error, bit2=shell_error,
//                       bit3=ddr_error
//   0x28 CONFIG         {8'd0, SCALE, TILE_H, TILE_W}
module sr_ddr_tinyspan_x4_tile_writer_endpoint #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer M_AXI_DATA_WIDTH = 32,
    parameter integer DATA_W = 24,
    parameter integer DEFAULT_IMG_W = 320,
    parameter integer DEFAULT_IMG_H = 180,
    parameter integer DEFAULT_INPUT_BASE = 32'h1000_0000,
    parameter integer DEFAULT_OUTPUT_BASE = 32'h1100_0000,
    parameter integer TILE_W = 32,
    parameter integer TILE_H = 32,
    parameter integer SCALE = 4,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 4,
    parameter integer USE_SERIAL_BASE = 0
) (
    input  wire                                  s_axi_aclk,
    input  wire                                  s_axi_aresetn,
    input  wire                                  m_axi_aclk,
    input  wire                                  m_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         s_axi_awaddr,
    input  wire [2:0]                            s_axi_awprot,
    input  wire                                  s_axi_awvalid,
    output wire                                  s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]         s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb,
    input  wire                                  s_axi_wvalid,
    output wire                                  s_axi_wready,

    output reg  [1:0]                            s_axi_bresp,
    output reg                                   s_axi_bvalid,
    input  wire                                  s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         s_axi_araddr,
    input  wire [2:0]                            s_axi_arprot,
    input  wire                                  s_axi_arvalid,
    output reg                                   s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]         s_axi_rdata,
    output reg  [1:0]                            s_axi_rresp,
    output reg                                   s_axi_rvalid,
    input  wire                                  s_axi_rready,

    output wire [ADDR_W-1:0]                     m_axi_awaddr,
    output wire [7:0]                            m_axi_awlen,
    output wire [2:0]                            m_axi_awsize,
    output wire [1:0]                            m_axi_awburst,
    output wire [3:0]                            m_axi_awcache,
    output wire [2:0]                            m_axi_awprot,
    output wire                                  m_axi_awvalid,
    input  wire                                  m_axi_awready,

    output wire [M_AXI_DATA_WIDTH-1:0]           m_axi_wdata,
    output wire [(M_AXI_DATA_WIDTH/8)-1:0]       m_axi_wstrb,
    output wire                                  m_axi_wlast,
    output wire                                  m_axi_wvalid,
    input  wire                                  m_axi_wready,

    input  wire [1:0]                            m_axi_bresp,
    input  wire                                  m_axi_bvalid,
    output wire                                  m_axi_bready,

    output wire [ADDR_W-1:0]                     m_axi_araddr,
    output wire [7:0]                            m_axi_arlen,
    output wire [2:0]                            m_axi_arsize,
    output wire [1:0]                            m_axi_arburst,
    output wire [3:0]                            m_axi_arcache,
    output wire [2:0]                            m_axi_arprot,
    output wire                                  m_axi_arvalid,
    input  wire                                  m_axi_arready,

    input  wire [M_AXI_DATA_WIDTH-1:0]           m_axi_rdata,
    input  wire [1:0]                            m_axi_rresp,
    input  wire                                  m_axi_rlast,
    input  wire                                  m_axi_rvalid,
    output wire                                  m_axi_rready,

    output wire                                  irq
);
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_CONTROL         = 8'h00;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_STATUS          = 8'h04;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_IMG_W           = 8'h08;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_IMG_H           = 8'h0c;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_INPUT_BASE      = 8'h10;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_OUTPUT_BASE     = 8'h14;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_FRAME_CYCLES_LO = 8'h18;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_FRAME_CYCLES_HI = 8'h1c;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_TILES_DONE      = 8'h20;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_ERROR           = 8'h24;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_CONFIG          = 8'h28;

    localparam [7:0] TILE_W_U8 = TILE_W;
    localparam [7:0] TILE_H_U8 = TILE_H;
    localparam [7:0] SCALE_U8 = SCALE;

    wire rst = !s_axi_aresetn;

    reg [C_S_AXI_ADDR_WIDTH-1:0] aw_hold_addr;
    reg aw_hold_valid;
    reg [C_S_AXI_DATA_WIDTH-1:0] w_hold_data;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] w_hold_strb;
    reg w_hold_valid;
    wire write_fire = aw_hold_valid && w_hold_valid && !s_axi_bvalid;

    reg [COORD_W-1:0] image_w_q;
    reg [COORD_W-1:0] image_h_q;
    reg [ADDR_W-1:0] input_base_q;
    reg [ADDR_W-1:0] output_base_q;
    reg shell_start;
    reg soft_reset_pulse;
    reg frame_active;
    reg frame_done;
    reg sw_error;
    reg [63:0] frame_cycles_latched;

    wire shell_busy;
    wire shell_done;
    wire shell_error;
    wire [31:0] tiles_done;
    wire [63:0] shell_frame_cycles;

    wire ddr_busy;
    wire ddr_error;
    wire any_error = sw_error || shell_error || ddr_error;
    wire start_allowed = !frame_active && !shell_busy && !ddr_busy && !any_error;
    wire bridge_rst = rst || soft_reset_pulse;

    wire rd_req_valid;
    wire rd_req_ready;
    wire [ADDR_W-1:0] rd_req_addr;
    wire rd_resp_valid;
    wire [DATA_W-1:0] rd_resp_data;

    wire wr_valid;
    wire wr_ready;
    wire [ADDR_W-1:0] wr_addr;
    wire [DATA_W-1:0] wr_data;

    assign s_axi_awready = !aw_hold_valid && !s_axi_bvalid;
    assign s_axi_wready = !w_hold_valid && !s_axi_bvalid;
    assign irq = frame_done || any_error;

    sr_tile_tinyspan_x4_writer_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .SCALE(SCALE),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .USE_SERIAL_BASE(USE_SERIAL_BASE)
    ) u_tile_writer (
        .clk(s_axi_aclk),
        .rst(bridge_rst),
        .start(shell_start),
        .image_w(image_w_q),
        .image_h(image_h_q),
        .input_base(input_base_q),
        .output_base(output_base_q),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(shell_busy),
        .done(shell_done),
        .error(shell_error),
        .tiles_done(tiles_done),
        .frame_cycles(shell_frame_cycles)
    );

    sr_ddr_pixel_axi_master #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .AXI_DATA_W(M_AXI_DATA_WIDTH)
    ) u_ddr_master (
        .clk(s_axi_aclk),
        .rst(bridge_rst),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(ddr_busy),
        .error(ddr_error),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            aw_hold_valid <= 1'b0;
            aw_hold_addr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            w_hold_valid <= 1'b0;
            w_hold_data <= {C_S_AXI_DATA_WIDTH{1'b0}};
            w_hold_strb <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
        end else begin
            if (s_axi_awready && s_axi_awvalid) begin
                aw_hold_valid <= 1'b1;
                aw_hold_addr <= s_axi_awaddr;
            end
            if (s_axi_wready && s_axi_wvalid) begin
                w_hold_valid <= 1'b1;
                w_hold_data <= s_axi_wdata;
                w_hold_strb <= s_axi_wstrb;
            end
            if (write_fire) begin
                aw_hold_valid <= 1'b0;
                w_hold_valid <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= 2'b00;
            s_axi_rdata <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else begin
            s_axi_arready <= 1'b0;
            if (!s_axi_rvalid && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;
                case (s_axi_araddr)
                    REG_CONTROL:
                        s_axi_rdata <= 32'd0;
                    REG_STATUS:
                        s_axi_rdata <= {
                            24'd0,
                            ddr_busy,
                            ddr_error,
                            shell_error,
                            any_error,
                            frame_done,
                            frame_active,
                            shell_busy,
                            start_allowed
                        };
                    REG_IMG_W:
                        s_axi_rdata <= image_w_q;
                    REG_IMG_H:
                        s_axi_rdata <= image_h_q;
                    REG_INPUT_BASE:
                        s_axi_rdata <= input_base_q;
                    REG_OUTPUT_BASE:
                        s_axi_rdata <= output_base_q;
                    REG_FRAME_CYCLES_LO:
                        s_axi_rdata <= frame_cycles_latched[31:0];
                    REG_FRAME_CYCLES_HI:
                        s_axi_rdata <= frame_cycles_latched[63:32];
                    REG_TILES_DONE:
                        s_axi_rdata <= tiles_done;
                    REG_ERROR:
                        s_axi_rdata <= {28'd0, ddr_error, shell_error, sw_error, any_error};
                    REG_CONFIG:
                        s_axi_rdata <= {8'd0, SCALE_U8, TILE_H_U8, TILE_W_U8};
                    default:
                        s_axi_rdata <= 32'hbad0_0000 | {{(32-C_S_AXI_ADDR_WIDTH){1'b0}}, s_axi_araddr};
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            image_w_q <= DEFAULT_IMG_W;
            image_h_q <= DEFAULT_IMG_H;
            input_base_q <= DEFAULT_INPUT_BASE;
            output_base_q <= DEFAULT_OUTPUT_BASE;
            shell_start <= 1'b0;
            soft_reset_pulse <= 1'b0;
            frame_active <= 1'b0;
            frame_done <= 1'b0;
            sw_error <= 1'b0;
            frame_cycles_latched <= 64'd0;
        end else begin
            shell_start <= 1'b0;
            soft_reset_pulse <= 1'b0;

            if (write_fire) begin
                case (aw_hold_addr)
                    REG_CONTROL: begin
                        if (w_hold_data[1]) begin
                            soft_reset_pulse <= 1'b1;
                            frame_active <= 1'b0;
                            frame_done <= 1'b0;
                            sw_error <= 1'b0;
                            frame_cycles_latched <= 64'd0;
                        end
                        if (w_hold_data[0]) begin
                            if (start_allowed) begin
                                shell_start <= 1'b1;
                                frame_active <= 1'b1;
                                frame_done <= 1'b0;
                                sw_error <= 1'b0;
                                frame_cycles_latched <= 64'd0;
                            end else begin
                                sw_error <= 1'b1;
                            end
                        end
                    end
                    REG_IMG_W:
                        if (start_allowed)
                            image_w_q <= w_hold_data[COORD_W-1:0];
                    REG_IMG_H:
                        if (start_allowed)
                            image_h_q <= w_hold_data[COORD_W-1:0];
                    REG_INPUT_BASE:
                        if (start_allowed)
                            input_base_q <= {w_hold_data[ADDR_W-1:2], 2'b00};
                    REG_OUTPUT_BASE:
                        if (start_allowed)
                            output_base_q <= {w_hold_data[ADDR_W-1:2], 2'b00};
                    REG_ERROR:
                        if (w_hold_data[0])
                            sw_error <= 1'b0;
                    default: begin
                    end
                endcase
            end

            if (shell_done && frame_active) begin
                frame_active <= 1'b0;
                frame_done <= 1'b1;
                frame_cycles_latched <= shell_frame_cycles;
            end
        end
    end

    wire unused_inputs = |s_axi_awprot | |s_axi_arprot | |w_hold_strb |
                         m_axi_aclk | m_axi_aresetn;
endmodule
