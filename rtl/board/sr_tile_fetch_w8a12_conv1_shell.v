`timescale 1ns/1ps

// Hardware tile fetch -> W8A12 conv_1 integration shell.
//
// This is the first real compute gate for the hardware-side tiling path:
// a tile command reads RGB888 pixels from a large-image buffer, streams a
// fixed-size tile, then feeds the W8A12 conv_1 frontend.
module sr_tile_fetch_w8a12_conv1_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 16,
    parameter integer TILE_H = 16,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       cmd_valid,
    output wire                       cmd_ready,
    input  wire [COORD_W-1:0]         cmd_image_w,
    input  wire [COORD_W-1:0]         cmd_valid_w,
    input  wire [COORD_W-1:0]         cmd_valid_h,
    input  wire [ADDR_W-1:0]          cmd_input_addr,

    output wire                       rd_req_valid,
    input  wire                       rd_req_ready,
    output wire [ADDR_W-1:0]          rd_req_addr,
    input  wire                       rd_resp_valid,
    input  wire [DATA_W-1:0]          rd_resp_data,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire [OUT_CH*ACT_W-1:0]    m_feat,
    output wire                       m_user,
    output wire                       m_last,

    output wire                       fetch_busy,
    output wire                       fetch_done,
    output wire                       fetch_error
);
    wire tile_valid;
    wire tile_ready;
    wire [DATA_W-1:0] tile_data;
    wire tile_pixel_valid;
    wire tile_user;
    wire tile_last;

    sr_tile_fetch_stream_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_fetch (
        .clk(clk),
        .rst(rst),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_image_w(cmd_image_w),
        .cmd_valid_w(cmd_valid_w),
        .cmd_valid_h(cmd_valid_h),
        .cmd_input_addr(cmd_input_addr),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .m_valid(tile_valid),
        .m_ready(tile_ready),
        .m_data(tile_data),
        .m_pixel_valid(tile_pixel_valid),
        .m_user(tile_user),
        .m_last(tile_last),
        .busy(fetch_busy),
        .done(fetch_done),
        .error(fetch_error)
    );

    span_w8a12_conv1_streamed_frontend #(
        .DATA_W(DATA_W),
        .IMG_W(TILE_W),
        .IMG_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(OUT_CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_conv1 (
        .clk(clk),
        .rst(rst),
        .s_valid(tile_valid),
        .s_ready(tile_ready),
        .s_data(tile_data),
        .s_pixel_valid(tile_pixel_valid),
        .s_user(tile_user),
        .s_last(tile_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
