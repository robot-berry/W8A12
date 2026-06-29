`timescale 1ns/1ps

// Four-bank frame feature storage for W8A12 48-channel feature maps.
// Each bank stores 12 signed 12-bit channels for one pixel.
module span_w8a12_feature_bank4 #(
    parameter integer ACT_W = 12,
    parameter integer CH = 48,
    parameter integer BANKS = 4,
    parameter integer BANK_CH = CH / BANKS,
    parameter integer FRAME_PIXELS = 64,
    parameter integer FRAME_ADDR_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS)
) (
    input  wire                         clk,
    input  wire                         we,
    input  wire [FRAME_ADDR_W-1:0]      waddr,
    input  wire signed [CH*ACT_W-1:0]   wfeat,
    input  wire [FRAME_ADDR_W-1:0]      raddr,
    output wire signed [CH*ACT_W-1:0]   rfeat
);
    genvar bank_i;
    generate
        for (bank_i = 0; bank_i < BANKS; bank_i = bank_i + 1) begin : g_bank
            localparam integer LO = bank_i * BANK_CH * ACT_W;
            wire signed [BANK_CH*ACT_W-1:0] bank_wdata = wfeat[LO +: BANK_CH*ACT_W];
            wire signed [BANK_CH*ACT_W-1:0] bank_rdata;

            span_sync_ram_1r1w #(
                .DATA_W(BANK_CH*ACT_W),
                .DEPTH(FRAME_PIXELS),
                .ADDR_W(FRAME_ADDR_W)
            ) u_ram (
                .clk(clk),
                .we(we),
                .waddr(waddr),
                .wdata(bank_wdata),
                .raddr(raddr),
                .rdata(bank_rdata)
            );

            assign rfeat[LO +: BANK_CH*ACT_W] = bank_rdata;
        end
    endgenerate
endmodule
