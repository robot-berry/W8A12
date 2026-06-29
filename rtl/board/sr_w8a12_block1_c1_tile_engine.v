`timescale 1ns/1ps

// Tile-local W8A12 block_1.c1_r compute engine.
//
// This keeps the same scheduler-facing contract as sr_w8a12_block1_tile_engine,
// but wraps only the first feature convolution inside block_1. It is the first
// split primitive for replacing the dummy block acknowledgement with real
// time-multiplexed SPAB compute.
module sr_w8a12_block1_c1_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1)
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    output wire                         ready,
    output wire                         busy,
    output reg                          done,
    output reg                          error,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [FEAT_W-1:0]     s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [FEAT_W-1:0]     m_feat,
    output wire                         m_user,
    output wire                         m_last,

    output reg  [PIX_W-1:0]             input_count,
    output reg  [PIX_W-1:0]             output_count
);
    reg active;
    reg input_done;

    wire c1_s_ready;
    wire c1_s_valid = active && !input_done && s_valid;
    wire input_take = c1_s_valid && c1_s_ready;
    wire output_take = m_valid && m_ready;
    wire input_last_pixel = (input_count == PIXELS - 1);
    wire output_last_pixel = (output_count == PIXELS - 1);

    assign ready = !active;
    assign busy = active;
    assign s_ready = active && !input_done && c1_s_ready;

    span_w8a12_block1_c1_streamed_frontend #(
        .IMG_W(TILE_W),
        .IMG_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_c1 (
        .clk(clk),
        .rst(rst),
        .s_valid(c1_s_valid),
        .s_ready(c1_s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0;
            input_done <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            input_count <= {PIX_W{1'b0}};
            output_count <= {PIX_W{1'b0}};
        end else begin
            done <= 1'b0;

            if (start && ready) begin
                active <= 1'b1;
                input_done <= 1'b0;
                error <= 1'b0;
                input_count <= {PIX_W{1'b0}};
                output_count <= {PIX_W{1'b0}};
            end else if (start && !ready) begin
                error <= 1'b1;
            end

            if (input_take) begin
                if (input_count == {PIX_W{1'b0}} && !s_user)
                    error <= 1'b1;
                if (s_last != ((input_count % TILE_W) == TILE_W - 1))
                    error <= 1'b1;

                if (input_last_pixel) begin
                    input_done <= 1'b1;
                end else begin
                    input_count <= input_count + 1'b1;
                end
            end

            if (output_take) begin
                if (output_count == {PIX_W{1'b0}} && !m_user)
                    error <= 1'b1;
                if (m_last != ((output_count % TILE_W) == TILE_W - 1))
                    error <= 1'b1;

                if (output_last_pixel) begin
                    done <= 1'b1;
                    active <= 1'b0;
                end else begin
                    output_count <= output_count + 1'b1;
                end
            end
        end
    end
endmodule
