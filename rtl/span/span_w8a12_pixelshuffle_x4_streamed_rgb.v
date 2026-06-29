`timescale 1ns/1ps

// X4 PixelShuffle for SPAN W8A12 tail output.
//
// The input stream is one LR raster pixel with 48 channels:
//   channel = color * 16 + sy * 4 + sx
// The output stream is HR raster RGB, four output rows for each input row.
module span_w8a12_pixelshuffle_x4_streamed_rgb #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer CH = 48
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output reg                          m_valid,
    input  wire                         m_ready,
    output reg signed [3*ACT_W-1:0]     m_rgb,
    output reg                          m_user,
    output reg                          m_last
);
    localparam [1:0] ST_LOAD = 2'd0;
    localparam [1:0] ST_EMIT = 2'd1;

    localparam integer X_W = (IMG_W <= 2) ? 1 : $clog2(IMG_W);
    localparam integer Y_W = (IMG_H <= 2) ? 1 : $clog2(IMG_H);

    reg [1:0] state;
    reg signed [CH*ACT_W-1:0] row_buf [0:IMG_W-1];
    reg [X_W-1:0] load_x;
    reg [Y_W-1:0] load_y;
    reg [X_W-1:0] emit_x;
    reg [1:0] emit_sy;
    reg [1:0] emit_sx;
    reg row_user_q;
    reg emit_frame_first;
    reg emit_row_is_last;

    integer color;
    integer in_ch;

    assign s_ready = (state == ST_LOAD);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_LOAD;
            load_x <= {X_W{1'b0}};
            load_y <= {Y_W{1'b0}};
            emit_x <= {X_W{1'b0}};
            emit_sy <= 2'd0;
            emit_sx <= 2'd0;
            row_user_q <= 1'b0;
            emit_frame_first <= 1'b0;
            emit_row_is_last <= 1'b0;
            m_valid <= 1'b0;
            m_rgb <= {3*ACT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_LOAD: begin
                    if (s_valid && s_ready) begin
                        row_buf[load_x] <= s_feat;
                        if (load_x == {X_W{1'b0}})
                            row_user_q <= s_user;
                        if (load_x == IMG_W - 1) begin
                            state <= ST_EMIT;
                            emit_x <= {X_W{1'b0}};
                            emit_sy <= 2'd0;
                            emit_sx <= 2'd0;
                            emit_frame_first <= (load_x == {X_W{1'b0}}) ? s_user : row_user_q;
                            emit_row_is_last <= (load_y == IMG_H - 1);
                            load_x <= {X_W{1'b0}};
                        end else begin
                            load_x <= load_x + 1'b1;
                        end
                    end
                end

                ST_EMIT: begin
                    if (!m_valid || m_ready) begin
                        for (color = 0; color < 3; color = color + 1) begin
                            in_ch = color * 16 + emit_sy * 4 + emit_sx;
                            m_rgb[color*ACT_W +: ACT_W] <= row_buf[emit_x][in_ch*ACT_W +: ACT_W];
                        end
                        m_user <= emit_frame_first && (emit_sy == 2'd0) && (emit_x == {X_W{1'b0}}) && (emit_sx == 2'd0);
                        m_last <= (emit_x == IMG_W - 1) && (emit_sx == 2'd3);
                        m_valid <= 1'b1;

                        if ((emit_sy == 2'd3) && (emit_x == IMG_W - 1) && (emit_sx == 2'd3)) begin
                            state <= ST_LOAD;
                            emit_sy <= 2'd0;
                            emit_x <= {X_W{1'b0}};
                            emit_sx <= 2'd0;
                            if (emit_row_is_last)
                                load_y <= {Y_W{1'b0}};
                            else
                                load_y <= load_y + 1'b1;
                        end else if ((emit_x == IMG_W - 1) && (emit_sx == 2'd3)) begin
                            emit_x <= {X_W{1'b0}};
                            emit_sx <= 2'd0;
                            emit_sy <= emit_sy + 1'b1;
                        end else if (emit_sx == 2'd3) begin
                            emit_x <= emit_x + 1'b1;
                            emit_sx <= 2'd0;
                        end else begin
                            emit_sx <= emit_sx + 1'b1;
                        end
                    end
                end

                default: begin
                    state <= ST_LOAD;
                end
            endcase
        end
    end

    wire unused_last = s_last;
endmodule
