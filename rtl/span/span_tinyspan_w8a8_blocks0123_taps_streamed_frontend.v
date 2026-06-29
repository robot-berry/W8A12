`timescale 1ns/1ps
`include "../generated/tinyspan_c32b4_30fps_frozen_w8a8/tinyspan_w8a8_layers.vh"

// TinySPAN W8A8 trunk with tail skip taps.
//
// Input is the quantized head feature stream. Output is aligned to block3 and
// provides the three learned-tail inputs needed before fuse_tail:
//   head, block0, block3
module span_tinyspan_w8a8_blocks0123_taps_streamed_frontend #(
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32,
    parameter integer ACT_W = `TINYSPAN_W8A8_ACT_W,
    parameter integer ACC_W = 48,
    parameter integer CH = `TINYSPAN_W8A8_CHANNELS,
    parameter integer OUT_LANES = `TINYSPAN_W8A8_OUT_LANES,
    parameter integer TAP_LANES = `TINYSPAN_W8A8_TAP_LANES
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [CH*ACT_W-1:0]   m_head,
    output wire signed [CH*ACT_W-1:0]   m_block0,
    output wire signed [CH*ACT_W-1:0]   m_block3,
    output wire                         m_user,
    output wire                         m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer PIX_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);

    wire b0_valid, b0_ready, b0_user, b0_last;
    wire b1_valid, b1_ready, b1_user, b1_last;
    wire b2_valid, b2_ready, b2_user, b2_last;
    wire signed [CH*ACT_W-1:0] b0_feat;
    wire signed [CH*ACT_W-1:0] b1_feat;
    wire signed [CH*ACT_W-1:0] b2_feat;

    reg [PIX_W-1:0] head_wr_pix;
    reg [PIX_W-1:0] b0_wr_pix;
    reg [PIX_W-1:0] out_rd_pix;
    reg signed [CH*ACT_W-1:0] head_mem [0:FRAME_PIXELS-1];
    reg signed [CH*ACT_W-1:0] b0_mem [0:FRAME_PIXELS-1];

    span_tinyspan_w8a8_block0_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W), .CH(CH),
        .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_b0 (
        .clk(clk), .rst(rst), .s_valid(s_valid), .s_ready(s_ready), .s_feat(s_feat),
        .s_user(s_user), .s_last(s_last), .m_valid(b0_valid), .m_ready(b0_ready),
        .m_feat(b0_feat), .m_user(b0_user), .m_last(b0_last)
    );

    span_tinyspan_w8a8_block1_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W), .CH(CH),
        .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_b1 (
        .clk(clk), .rst(rst), .s_valid(b0_valid), .s_ready(b0_ready), .s_feat(b0_feat),
        .s_user(b0_user), .s_last(b0_last), .m_valid(b1_valid), .m_ready(b1_ready),
        .m_feat(b1_feat), .m_user(b1_user), .m_last(b1_last)
    );

    span_tinyspan_w8a8_block2_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W), .CH(CH),
        .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_b2 (
        .clk(clk), .rst(rst), .s_valid(b1_valid), .s_ready(b1_ready), .s_feat(b1_feat),
        .s_user(b1_user), .s_last(b1_last), .m_valid(b2_valid), .m_ready(b2_ready),
        .m_feat(b2_feat), .m_user(b2_user), .m_last(b2_last)
    );

    span_tinyspan_w8a8_block3_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W), .CH(CH),
        .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_b3 (
        .clk(clk), .rst(rst), .s_valid(b2_valid), .s_ready(b2_ready), .s_feat(b2_feat),
        .s_user(b2_user), .s_last(b2_last), .m_valid(m_valid), .m_ready(m_ready),
        .m_feat(m_block3), .m_user(m_user), .m_last(m_last)
    );

    assign m_head = head_mem[out_rd_pix];
    assign m_block0 = b0_mem[out_rd_pix];

    always @(posedge clk) begin
        if (rst) begin
            head_wr_pix <= {PIX_W{1'b0}};
            b0_wr_pix <= {PIX_W{1'b0}};
            out_rd_pix <= {PIX_W{1'b0}};
        end else begin
            if (s_valid && s_ready) begin
                head_mem[head_wr_pix] <= s_feat;
                if (head_wr_pix == FRAME_PIXELS - 1)
                    head_wr_pix <= {PIX_W{1'b0}};
                else
                    head_wr_pix <= head_wr_pix + 1'b1;
            end

            if (b0_valid && b0_ready) begin
                b0_mem[b0_wr_pix] <= b0_feat;
                if (b0_wr_pix == FRAME_PIXELS - 1)
                    b0_wr_pix <= {PIX_W{1'b0}};
                else
                    b0_wr_pix <= b0_wr_pix + 1'b1;
            end

            if (m_valid && m_ready) begin
                if (out_rd_pix == FRAME_PIXELS - 1)
                    out_rd_pix <= {PIX_W{1'b0}};
                else
                    out_rd_pix <= out_rd_pix + 1'b1;
            end
        end
    end
endmodule

