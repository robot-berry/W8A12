`timescale 1ns/1ps

// Minimal AXI-Lite register probe for PS-to-PL bring-up.
//
// This module intentionally contains no W8A12 datapath and no DDR master.  It
// isolates whether the PS M_AXI_HPM0_FPD control path can reach a simple PL
// AXI-Lite slave at 0xA0000000.
module sr_axi_lite_register_probe #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter [31:0] MAGIC = 32'h5738_4158,
    parameter [31:0] VERSION = 32'h0001_0000
) (
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output wire                              s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,

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
    localparam [7:0] REG_MAGIC       = 8'h00;
    localparam [7:0] REG_SCRATCH     = 8'h04;
    localparam [7:0] REG_WRITE_COUNT = 8'h08;
    localparam [7:0] REG_READ_COUNT  = 8'h0c;
    localparam [7:0] REG_STATUS      = 8'h10;
    localparam [7:0] REG_LAST_ADDR   = 8'h14;
    localparam [7:0] REG_LAST_DATA   = 8'h18;
    localparam [7:0] REG_VERSION     = 8'h1c;

    reg aw_hold_valid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] aw_hold_addr;
    reg w_hold_valid;
    reg [C_S_AXI_DATA_WIDTH-1:0] w_hold_data;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] w_hold_strb;

    reg [31:0] scratch_q;
    reg [31:0] write_count_q;
    reg [31:0] read_count_q;
    reg [31:0] last_addr_q;
    reg [31:0] last_data_q;

    wire rst = !s_axi_aresetn;
    wire write_fire = aw_hold_valid && w_hold_valid && !s_axi_bvalid;
    wire read_fire = !s_axi_rvalid && s_axi_arvalid;

    assign s_axi_awready = !aw_hold_valid && !s_axi_bvalid;
    assign s_axi_wready = !w_hold_valid && !s_axi_bvalid;
    assign irq = 1'b0;

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0] strobe;
        integer i;
        begin
            apply_wstrb = old_value;
            for (i = 0; i < 4; i = i + 1) begin
                if (strobe[i]) begin
                    apply_wstrb[i*8 +: 8] = new_value[i*8 +: 8];
                end
            end
        end
    endfunction

    always @(posedge s_axi_aclk) begin
        if (rst) begin
            aw_hold_valid <= 1'b0;
            aw_hold_addr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            w_hold_valid <= 1'b0;
            w_hold_data <= {C_S_AXI_DATA_WIDTH{1'b0}};
            w_hold_strb <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
            scratch_q <= 32'd0;
            write_count_q <= 32'd0;
            last_addr_q <= 32'd0;
            last_data_q <= 32'd0;
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
                write_count_q <= write_count_q + 32'd1;
                last_addr_q <= {{(32-C_S_AXI_ADDR_WIDTH){1'b0}}, aw_hold_addr};
                last_data_q <= w_hold_data[31:0];
                case (aw_hold_addr[7:0])
                    REG_SCRATCH:
                        scratch_q <= apply_wstrb(scratch_q, w_hold_data[31:0], w_hold_strb[3:0]);
                    REG_WRITE_COUNT:
                        write_count_q <= 32'd0;
                    default:
                        scratch_q <= scratch_q;
                endcase
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
            read_count_q <= 32'd0;
        end else begin
            s_axi_arready <= 1'b0;
            if (read_fire) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;
                read_count_q <= read_count_q + 32'd1;
                case (s_axi_araddr[7:0])
                    REG_MAGIC:
                        s_axi_rdata <= MAGIC;
                    REG_SCRATCH:
                        s_axi_rdata <= scratch_q;
                    REG_WRITE_COUNT:
                        s_axi_rdata <= write_count_q;
                    REG_READ_COUNT:
                        s_axi_rdata <= read_count_q;
                    REG_STATUS:
                        s_axi_rdata <= 32'h0000_0001;
                    REG_LAST_ADDR:
                        s_axi_rdata <= last_addr_q;
                    REG_LAST_DATA:
                        s_axi_rdata <= last_data_q;
                    REG_VERSION:
                        s_axi_rdata <= VERSION;
                    default:
                        s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    wire unused_inputs = |s_axi_awprot | |s_axi_arprot;

endmodule
