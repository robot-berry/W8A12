`timescale 1ns/1ps

// Scheduler-facing tile engine around the synthesizable partition-style
// block_1.c1_r frame primitive.
//
// Unlike sr_w8a12_block1_c1_tile_engine, this path reuses
// span_w8a12_block1_c1_frame: it captures the feature tile into BRAM, computes
// c1+activation sequentially, then drains the output BRAM as a feature stream.
module sr_w8a12_block1_c1_frame_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1),
    parameter integer ADDR_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS)
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

    output reg                          m_valid,
    input  wire                         m_ready,
    output reg  signed [FEAT_W-1:0]     m_feat,
    output reg                          m_user,
    output reg                          m_last,

    output reg  [PIX_W-1:0]             input_count,
    output reg  [PIX_W-1:0]             output_count
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_CAPTURE    = 3'd1;
    localparam [2:0] ST_WAIT_FRAME = 3'd2;
    localparam [2:0] ST_RD_ISSUE   = 3'd3;
    localparam [2:0] ST_RD_WAIT    = 3'd4;
    localparam [2:0] ST_OUT        = 3'd5;

    reg [2:0] state;
    reg frame_rst;
    reg out_rd_en;
    reg [ADDR_W-1:0] out_rd_addr;

    wire frame_s_ready;
    wire frame_busy;
    wire frame_done;
    wire [31:0] frame_input_count;
    wire [31:0] frame_output_count;
    wire signed [FEAT_W-1:0] frame_out_feat;

    wire input_take = s_valid && s_ready;
    wire output_take = m_valid && m_ready;
    wire input_last_pixel = (input_count == PIXELS - 1);
    wire output_last_pixel = (output_count == PIXELS - 1);
    wire [ADDR_W-1:0] next_out_rd_addr = output_count + 1'b1;

    assign ready = (state == ST_IDLE);
    assign busy = (state != ST_IDLE);
    assign s_ready = (state == ST_CAPTURE) && frame_s_ready;

    span_w8a12_block1_c1_frame #(
        .IMG_W(TILE_W),
        .IMG_H(TILE_H),
        .ACT_W(ACT_W),
        .CH(CH),
        .ACC_W(ACC_W)
    ) u_c1_frame (
        .clk(clk),
        .rst(rst || frame_rst),
        .s_valid((state == ST_CAPTURE) && s_valid),
        .s_ready(frame_s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .busy(frame_busy),
        .done(frame_done),
        .input_count(frame_input_count),
        .output_count(frame_output_count),
        .out_rd_en(out_rd_en),
        .out_rd_addr(out_rd_addr),
        .out_feat(frame_out_feat)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            frame_rst <= 1'b1;
            out_rd_en <= 1'b0;
            out_rd_addr <= {ADDR_W{1'b0}};
            done <= 1'b0;
            error <= 1'b0;
            m_valid <= 1'b0;
            m_feat <= {FEAT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
            input_count <= {PIX_W{1'b0}};
            output_count <= {PIX_W{1'b0}};
        end else begin
            done <= 1'b0;
            out_rd_en <= 1'b0;

            case (state)
                ST_IDLE: begin
                    frame_rst <= 1'b1;
                    m_valid <= 1'b0;
                    m_user <= 1'b0;
                    m_last <= 1'b0;
                    if (start) begin
                        frame_rst <= 1'b0;
                        error <= 1'b0;
                        input_count <= {PIX_W{1'b0}};
                        output_count <= {PIX_W{1'b0}};
                        out_rd_addr <= {ADDR_W{1'b0}};
                        state <= ST_CAPTURE;
                    end
                end

                ST_CAPTURE: begin
                    frame_rst <= 1'b0;
                    if (start)
                        error <= 1'b1;
                    if (input_take) begin
                        if (input_count == {PIX_W{1'b0}} && !s_user)
                            error <= 1'b1;
                        if (s_last != ((input_count % TILE_W) == TILE_W - 1))
                            error <= 1'b1;

                        if (input_last_pixel) begin
                            state <= ST_WAIT_FRAME;
                        end else begin
                            input_count <= input_count + 1'b1;
                        end
                    end
                end

                ST_WAIT_FRAME: begin
                    frame_rst <= 1'b0;
                    if (frame_done) begin
                        out_rd_addr <= {ADDR_W{1'b0}};
                        out_rd_en <= 1'b1;
                        state <= ST_RD_WAIT;
                    end
                end

                ST_RD_ISSUE: begin
                    out_rd_en <= 1'b1;
                    state <= ST_RD_WAIT;
                end

                ST_RD_WAIT: begin
                    state <= ST_OUT;
                end

                ST_OUT: begin
                    if (!m_valid) begin
                        m_feat <= frame_out_feat;
                        m_user <= (output_count == {PIX_W{1'b0}});
                        m_last <= ((output_count % TILE_W) == TILE_W - 1);
                        m_valid <= 1'b1;
                    end else if (output_take) begin
                        m_valid <= 1'b0;
                        if (output_last_pixel) begin
                            done <= 1'b1;
                            frame_rst <= 1'b1;
                            state <= ST_IDLE;
                        end else begin
                            output_count <= output_count + 1'b1;
                            out_rd_addr <= next_out_rd_addr;
                            state <= ST_RD_ISSUE;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    frame_rst <= 1'b1;
                    error <= 1'b1;
                end
            endcase
        end
    end

    wire unused_frame_status = frame_busy | (|frame_input_count) | (|frame_output_count);
endmodule
