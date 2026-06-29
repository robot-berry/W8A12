`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

// TinySPAN W8A8 tail staging without the bicubic base-add path.
//
// This covers the frozen learned tail:
//   fuse_tail(block3) -> concat(head, block0, block3, fuse_tail) -> reconstruct
//   -> PixelShuffle x4
//
// The software reference also adds a bicubic-upsampled RGB base. That base path
// must be added before this module can be used for final board acceptance.
module span_tinyspan_w8a8_tail_streamed_rgb_no_base #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = `TINYSPAN_W8A8_ACT_W,
    parameter integer ACC_W = 48,
    parameter integer CH = `TINYSPAN_W8A8_CHANNELS,
    parameter integer RECON_CH = `TINYSPAN_W8A8_RECONSTRUCT_IN_CH,
    parameter integer OUT_CH = `TINYSPAN_W8A8_RECONSTRUCT_OUT_CH,
    parameter integer OUT_LANES = `TINYSPAN_W8A8_OUT_LANES,
    parameter integer TAP_LANES = `TINYSPAN_W8A8_TAP_LANES
) (
    input  wire                           clk,
    input  wire                           rst,

    input  wire                           s_valid,
    output wire                           s_ready,
    input  wire signed [CH*ACT_W-1:0]     head_i,
    input  wire signed [CH*ACT_W-1:0]     block0_i,
    input  wire signed [CH*ACT_W-1:0]     block3_i,
    input  wire                           s_user,
    input  wire                           s_last,

    output wire                           m_valid,
    input  wire                           m_ready,
    output wire signed [3*ACT_W-1:0]      m_rgb,
    output wire                           m_user,
    output wire                           m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer PIX_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);

    reg signed [CH*ACT_W-1:0] head_mem [0:FRAME_PIXELS-1];
    reg signed [CH*ACT_W-1:0] block0_mem [0:FRAME_PIXELS-1];
    reg signed [CH*ACT_W-1:0] block3_mem [0:FRAME_PIXELS-1];
    reg [PIX_W-1:0] input_pix;
    reg [PIX_W-1:0] fuse_pix;

    wire fuse_valid;
    wire fuse_ready;
    wire signed [CH*ACT_W-1:0] fuse_feat;
    wire fuse_user;
    wire fuse_last;

    wire recon_valid;
    wire recon_ready;
    wire recon_ready_to_up;
    wire signed [RECON_CH*ACT_W-1:0] recon_input;
    wire signed [OUT_CH*ACT_W-1:0] recon_feat;
    wire recon_user;
    wire recon_last;

    span_tinyspan_w8a8_fuse_tail_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_fuse_tail (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(block3_i),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(fuse_valid),
        .m_ready(fuse_ready),
        .m_feat(fuse_feat),
        .m_user(fuse_user),
        .m_last(fuse_last)
    );

    assign fuse_ready = recon_ready;

    span_tinyspan_w8a8_reconstruct_concat_requant #(
        .ACT_W(ACT_W),
        .CH(CH)
    ) u_concat_requant (
        .head_i(head_mem[fuse_pix]),
        .block0_i(block0_mem[fuse_pix]),
        .block3_i(block3_mem[fuse_pix]),
        .fuse_tail_i(fuse_feat),
        .concat_o(recon_input)
    );

    span_tinyspan_w8a8_reconstruct_streamed_frontend #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .IN_CH(RECON_CH),
        .OUT_CH(OUT_CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_reconstruct (
        .clk(clk),
        .rst(rst),
        .s_valid(fuse_valid),
        .s_ready(recon_ready),
        .s_feat(recon_input),
        .s_user(fuse_user),
        .s_last(fuse_last),
        .m_valid(recon_valid),
        .m_ready(recon_ready_to_up),
        .m_feat(recon_feat),
        .m_user(recon_user),
        .m_last(recon_last)
    );

    span_w8a12_pixelshuffle_x4_streamed_rgb #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .CH(OUT_CH)
    ) u_pixelshuffle (
        .clk(clk),
        .rst(rst),
        .s_valid(recon_valid),
        .s_ready(recon_ready_to_up),
        .s_feat(recon_feat),
        .s_user(recon_user),
        .s_last(recon_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_rgb(m_rgb),
        .m_user(m_user),
        .m_last(m_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            input_pix <= {PIX_W{1'b0}};
            fuse_pix <= {PIX_W{1'b0}};
        end else begin
            if (s_valid && s_ready) begin
                head_mem[input_pix] <= head_i;
                block0_mem[input_pix] <= block0_i;
                block3_mem[input_pix] <= block3_i;
                if (input_pix == FRAME_PIXELS - 1)
                    input_pix <= {PIX_W{1'b0}};
                else
                    input_pix <= input_pix + 1'b1;
            end

            if (fuse_valid && fuse_ready) begin
                if (fuse_pix == FRAME_PIXELS - 1)
                    fuse_pix <= {PIX_W{1'b0}};
                else
                    fuse_pix <= fuse_pix + 1'b1;
            end
        end
    end
endmodule
