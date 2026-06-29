`timescale 1ns/1ps

// Halo-aware tile fetch -> W8A12 conv_1 -> valid-interior feature crop.
//
// This shell is the first bridge from hardware-side large-image halo tiling to
// a resource-feasible streamed W8A12 compute primitive. It emits only the
// conv_1 features for the valid interior tile; later stages can buffer these
// features and schedule the remaining SPAN layers.
module sr_tile_halo_fetch_w8a12_conv1_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer HALO = 1,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer COMPUTE_W = TILE_W + 2 * HALO,
    parameter integer COMPUTE_H = TILE_H + 2 * HALO,
    parameter integer FEAT_W = OUT_CH * ACT_W
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       cmd_valid,
    output wire                       cmd_ready,
    input  wire [COORD_W-1:0]         cmd_image_w,
    input  wire [COORD_W-1:0]         cmd_image_h,
    input  wire [COORD_W-1:0]         cmd_tile_x,
    input  wire [COORD_W-1:0]         cmd_tile_y,
    input  wire [ADDR_W-1:0]          cmd_input_base,

    output wire                       rd_req_valid,
    input  wire                       rd_req_ready,
    output wire [ADDR_W-1:0]          rd_req_addr,
    input  wire                       rd_resp_valid,
    input  wire [DATA_W-1:0]          rd_resp_data,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire [FEAT_W-1:0]          m_feat,
    output wire                       m_user,
    output wire                       m_last,

    output wire                       fetch_busy,
    output wire                       fetch_done,
    output wire                       fetch_error
);
    wire halo_valid;
    wire halo_ready;
    wire [DATA_W-1:0] halo_data;
    wire halo_pixel_valid;
    wire halo_user;
    wire halo_last;

    wire conv_valid;
    wire conv_ready;
    wire [FEAT_W-1:0] conv_feat;
    wire conv_user;
    wire conv_last;

    sr_tile_halo_fetch_stream_shell #(
        .DATA_W(DATA_W),
        .OUT_TILE_W(TILE_W),
        .OUT_TILE_H(TILE_H),
        .HALO(HALO),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_halo_fetch (
        .clk(clk),
        .rst(rst),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_image_w(cmd_image_w),
        .cmd_image_h(cmd_image_h),
        .cmd_tile_x(cmd_tile_x),
        .cmd_tile_y(cmd_tile_y),
        .cmd_input_base(cmd_input_base),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .m_valid(halo_valid),
        .m_ready(halo_ready),
        .m_data(halo_data),
        .m_pixel_valid(halo_pixel_valid),
        .m_user(halo_user),
        .m_last(halo_last),
        .busy(fetch_busy),
        .done(fetch_done),
        .error(fetch_error)
    );

    span_w8a12_conv1_streamed_frontend #(
        .DATA_W(DATA_W),
        .IMG_W(COMPUTE_W),
        .IMG_H(COMPUTE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(OUT_CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_conv1 (
        .clk(clk),
        .rst(rst),
        .s_valid(halo_valid),
        .s_ready(halo_ready),
        .s_data(halo_data),
        .s_pixel_valid(halo_pixel_valid),
        .s_user(halo_user),
        .s_last(halo_last),
        .m_valid(conv_valid),
        .m_ready(conv_ready),
        .m_feat(conv_feat),
        .m_user(conv_user),
        .m_last(conv_last)
    );

    sr_stream_cropper #(
        .DATA_W(FEAT_W),
        .IN_W(COMPUTE_W),
        .IN_H(COMPUTE_H),
        .CROP_X(HALO),
        .CROP_Y(HALO),
        .CROP_W(TILE_W),
        .CROP_H(TILE_H)
    ) u_feature_crop (
        .clk(clk),
        .rst(rst),
        .s_valid(conv_valid),
        .s_ready(conv_ready),
        .s_data(conv_feat),
        .s_user(conv_user),
        .s_last(conv_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );
endmodule
