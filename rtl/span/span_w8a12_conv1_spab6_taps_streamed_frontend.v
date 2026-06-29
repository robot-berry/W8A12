`timescale 1ns/1ps

// Streamed REDS W8A12 trunk with tail skip taps:
//   RGB -> conv_1 -> block_1 -> ... -> block_6
//
// The output handshake is aligned to block_6.out and provides the four
// feature streams needed by the streamed tail:
//   feat0      = conv_1 output
//   block6     = block_6 output
//   b1         = block_1 output
//   b6_act1    = block_6 act1 output
module span_w8a12_conv1_spab6_taps_streamed_frontend #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       s_valid,
    output wire                       s_ready,
    input  wire [DATA_W-1:0]          s_data,
    input  wire                       s_user,
    input  wire                       s_last,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire signed [CH*ACT_W-1:0] m_feat0,
    output wire signed [CH*ACT_W-1:0] m_block6,
    output wire signed [CH*ACT_W-1:0] m_b1,
    output wire signed [CH*ACT_W-1:0] m_b6_act1,
    output wire                       m_user,
    output wire                       m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer PIX_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);

    wire conv1_valid;
    wire conv1_ready;
    wire signed [CH*ACT_W-1:0] conv1_feat;
    wire conv1_user;
    wire conv1_last;

    wire b1_valid;
    wire b1_ready;
    wire signed [CH*ACT_W-1:0] b1_feat;
    wire b1_user;
    wire b1_last;

    wire b2_valid;
    wire b2_ready;
    wire signed [CH*ACT_W-1:0] b2_feat;
    wire b2_user;
    wire b2_last;

    wire b3_valid;
    wire b3_ready;
    wire signed [CH*ACT_W-1:0] b3_feat;
    wire b3_user;
    wire b3_last;

    wire b4_valid;
    wire b4_ready;
    wire signed [CH*ACT_W-1:0] b4_feat;
    wire b4_user;
    wire b4_last;

    wire b5_valid;
    wire b5_ready;
    wire signed [CH*ACT_W-1:0] b5_feat;
    wire b5_user;
    wire b5_last;

    wire b6_act1_valid;
    wire signed [CH*ACT_W-1:0] b6_act1_feat;
    wire block6_valid;
    wire block6_ready;
    wire signed [CH*ACT_W-1:0] block6_feat;
    wire block6_user;
    wire block6_last;

    reg [PIX_W-1:0] feat0_wr_pix;
    reg [PIX_W-1:0] b1_wr_pix;
    reg [PIX_W-1:0] b6_act1_wr_pix;
    reg [PIX_W-1:0] out_rd_pix;
    (* ram_style = "block" *) reg signed [CH*ACT_W-1:0] feat0_mem [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg signed [CH*ACT_W-1:0] b1_mem [0:FRAME_PIXELS-1];
    (* ram_style = "block" *) reg signed [CH*ACT_W-1:0] b6_act1_mem [0:FRAME_PIXELS-1];
    reg out_valid_q;
    reg signed [CH*ACT_W-1:0] feat0_q;
    reg signed [CH*ACT_W-1:0] b1_q;
    reg signed [CH*ACT_W-1:0] b6_act1_q;
    reg signed [CH*ACT_W-1:0] block6_q;
    reg out_user_q;
    reg out_last_q;

    assign block6_ready = !out_valid_q || m_ready;
    wire block6_take = block6_valid && block6_ready;

    span_w8a12_conv1_streamed_frontend #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_conv1 (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_pixel_valid(1'b1),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(conv1_valid),
        .m_ready(conv1_ready),
        .m_feat(conv1_feat),
        .m_user(conv1_user),
        .m_last(conv1_last)
    );

    span_w8a12_block1_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block1 (
        .clk(clk), .rst(rst),
        .s_valid(conv1_valid), .s_ready(conv1_ready), .s_feat(conv1_feat),
        .s_user(conv1_user), .s_last(conv1_last),
        .m_valid(b1_valid), .m_ready(b1_ready), .m_feat(b1_feat),
        .m_user(b1_user), .m_last(b1_last)
    );

    span_w8a12_block2_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block2 (
        .clk(clk), .rst(rst),
        .s_valid(b1_valid), .s_ready(b1_ready), .s_feat(b1_feat),
        .s_user(b1_user), .s_last(b1_last),
        .m_valid(b2_valid), .m_ready(b2_ready), .m_feat(b2_feat),
        .m_user(b2_user), .m_last(b2_last)
    );

    span_w8a12_block3_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block3 (
        .clk(clk), .rst(rst),
        .s_valid(b2_valid), .s_ready(b2_ready), .s_feat(b2_feat),
        .s_user(b2_user), .s_last(b2_last),
        .m_valid(b3_valid), .m_ready(b3_ready), .m_feat(b3_feat),
        .m_user(b3_user), .m_last(b3_last)
    );

    span_w8a12_block4_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block4 (
        .clk(clk), .rst(rst),
        .s_valid(b3_valid), .s_ready(b3_ready), .s_feat(b3_feat),
        .s_user(b3_user), .s_last(b3_last),
        .m_valid(b4_valid), .m_ready(b4_ready), .m_feat(b4_feat),
        .m_user(b4_user), .m_last(b4_last)
    );

    span_w8a12_block5_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block5 (
        .clk(clk), .rst(rst),
        .s_valid(b4_valid), .s_ready(b4_ready), .s_feat(b4_feat),
        .s_user(b4_user), .s_last(b4_last),
        .m_valid(b5_valid), .m_ready(b5_ready), .m_feat(b5_feat),
        .m_user(b5_user), .m_last(b5_last)
    );

    span_w8a12_block6_streamed_frontend #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .ACT_W(ACT_W), .ACC_W(ACC_W),
        .CH(CH), .OUT_LANES(OUT_LANES), .TAP_LANES(TAP_LANES)
    ) u_block6 (
        .clk(clk), .rst(rst),
        .s_valid(b5_valid), .s_ready(b5_ready), .s_feat(b5_feat),
        .s_user(b5_user), .s_last(b5_last),
        .m_valid(block6_valid), .m_ready(block6_ready), .m_feat(block6_feat),
        .m_user(block6_user), .m_last(block6_last),
        .tap_act1_valid(b6_act1_valid),
        .tap_act1_feat(b6_act1_feat),
        .tap_act1_user(),
        .tap_act1_last()
    );

    assign m_valid = out_valid_q;
    assign m_feat0 = feat0_q;
    assign m_b1 = b1_q;
    assign m_b6_act1 = b6_act1_q;
    assign m_block6 = block6_q;
    assign m_user = out_user_q;
    assign m_last = out_last_q;

    always @(posedge clk) begin
        if (rst) begin
            feat0_wr_pix <= {PIX_W{1'b0}};
            b1_wr_pix <= {PIX_W{1'b0}};
            b6_act1_wr_pix <= {PIX_W{1'b0}};
            out_rd_pix <= {PIX_W{1'b0}};
            out_valid_q <= 1'b0;
            feat0_q <= {CH*ACT_W{1'b0}};
            b1_q <= {CH*ACT_W{1'b0}};
            b6_act1_q <= {CH*ACT_W{1'b0}};
            block6_q <= {CH*ACT_W{1'b0}};
            out_user_q <= 1'b0;
            out_last_q <= 1'b0;
        end else begin
            if (out_valid_q && m_ready)
                out_valid_q <= 1'b0;

            if (conv1_valid && conv1_ready) begin
                feat0_mem[feat0_wr_pix] <= conv1_feat;
                if (feat0_wr_pix == FRAME_PIXELS - 1)
                    feat0_wr_pix <= {PIX_W{1'b0}};
                else
                    feat0_wr_pix <= feat0_wr_pix + 1'b1;
            end

            if (b1_valid && b1_ready) begin
                b1_mem[b1_wr_pix] <= b1_feat;
                if (b1_wr_pix == FRAME_PIXELS - 1)
                    b1_wr_pix <= {PIX_W{1'b0}};
                else
                    b1_wr_pix <= b1_wr_pix + 1'b1;
            end

            if (b6_act1_valid) begin
                b6_act1_mem[b6_act1_wr_pix] <= b6_act1_feat;
                if (b6_act1_wr_pix == FRAME_PIXELS - 1)
                    b6_act1_wr_pix <= {PIX_W{1'b0}};
                else
                    b6_act1_wr_pix <= b6_act1_wr_pix + 1'b1;
            end

            if (block6_take) begin
                feat0_q <= feat0_mem[out_rd_pix];
                b1_q <= b1_mem[out_rd_pix];
                b6_act1_q <= b6_act1_mem[out_rd_pix];
                block6_q <= block6_feat;
                out_user_q <= block6_user;
                out_last_q <= block6_last;
                out_valid_q <= 1'b1;

                if (out_rd_pix == FRAME_PIXELS - 1)
                    out_rd_pix <= {PIX_W{1'b0}};
                else
                    out_rd_pix <= out_rd_pix + 1'b1;
            end
        end
    end
endmodule
