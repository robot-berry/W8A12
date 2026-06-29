`timescale 1ns/1ps

// Tile-local RGB888 buffer and streamer.
//
// A large-image fetcher writes the valid pixels of one tile into this local
// buffer. The streamer emits a fixed TILE_W x TILE_H AXIS-like RGB888 tile to a
// small SR engine. Pixels outside valid_w/valid_h are zero-padded in hardware,
// so edge tiles do not require PC-side pre-cut or pre-padding.
module sr_tile_rgb_buffer_streamer #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 16,
    parameter integer TILE_H = 16,
    parameter integer COORD_W = 8
) (
    input  wire                     clk,
    input  wire                     rst,

    input  wire                     load_start,
    input  wire [COORD_W-1:0]       valid_w_i,
    input  wire [COORD_W-1:0]       valid_h_i,

    input  wire                     wr_valid,
    output wire                     wr_ready,
    input  wire [COORD_W-1:0]       wr_x,
    input  wire [COORD_W-1:0]       wr_y,
    input  wire [DATA_W-1:0]        wr_data,
    input  wire                     wr_pixel_valid,

    input  wire                     stream_start,
    output reg                      stream_busy,
    output reg                      stream_done,

    output reg                      m_valid,
    input  wire                     m_ready,
    output reg  [DATA_W-1:0]        m_data,
    output reg                      m_pixel_valid,
    output reg                      m_user,
    output reg                      m_last
);
    localparam integer TILE_PIXELS = TILE_W * TILE_H;
    localparam integer ADDR_W = (TILE_PIXELS <= 2) ? 1 : $clog2(TILE_PIXELS);
    localparam integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W);
    localparam integer Y_W = (TILE_H <= 2) ? 1 : $clog2(TILE_H);
    localparam [COORD_W-1:0] TILE_W_C = TILE_W[COORD_W-1:0];
    localparam [COORD_W-1:0] TILE_H_C = TILE_H[COORD_W-1:0];
    localparam [ADDR_W-1:0] ADDR_ONE = 1;

    (* ram_style = "block" *)
    reg [DATA_W-1:0] mem [0:TILE_PIXELS-1];
    (* ram_style = "block" *)
    reg valid_mem [0:TILE_PIXELS-1];
    reg [COORD_W-1:0] valid_w;
    reg [COORD_W-1:0] valid_h;
    reg [X_W-1:0] out_x;
    reg [Y_W-1:0] out_y;
    reg [ADDR_W-1:0] out_addr;
    reg [ADDR_W-1:0] rd_addr;
    reg [DATA_W-1:0] rd_data;
    reg rd_valid_data;
    reg [1:0] read_wait;
    reg load_pending;

    wire wr_in_tile = (wr_x < TILE_W_C) && (wr_y < TILE_H_C);
    wire wr_in_valid = (wr_x < valid_w) && (wr_y < valid_h);
    wire [ADDR_W-1:0] wr_addr = (wr_y[Y_W-1:0] * TILE_W) + wr_x[X_W-1:0];
    wire accept_out = m_valid && m_ready;
    wire last_pixel = (out_addr == TILE_PIXELS-1);
    wire end_row = (out_x == TILE_W-1);

    assign wr_ready = !load_pending && !stream_busy;

    always @(posedge clk) begin
        if (rst) begin
            valid_w <= {COORD_W{1'b0}};
            valid_h <= {COORD_W{1'b0}};
            out_x <= {X_W{1'b0}};
            out_y <= {Y_W{1'b0}};
            out_addr <= {ADDR_W{1'b0}};
            rd_addr <= {ADDR_W{1'b0}};
            rd_data <= {DATA_W{1'b0}};
            rd_valid_data <= 1'b0;
            read_wait <= 2'd0;
            load_pending <= 1'b0;
            stream_busy <= 1'b0;
            stream_done <= 1'b0;
            m_valid <= 1'b0;
            m_data <= {DATA_W{1'b0}};
            m_pixel_valid <= 1'b0;
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            stream_done <= 1'b0;
            rd_data <= mem[rd_addr];
            rd_valid_data <= valid_mem[rd_addr];

            if (load_start) begin
                valid_w <= (valid_w_i > TILE_W_C) ? TILE_W_C : valid_w_i;
                valid_h <= (valid_h_i > TILE_H_C) ? TILE_H_C : valid_h_i;
                load_pending <= 1'b1;
                stream_busy <= 1'b0;
                read_wait <= 2'd0;
                rd_addr <= {ADDR_W{1'b0}};
                m_valid <= 1'b0;
            end else if (load_pending) begin
                load_pending <= 1'b0;
            end else if (wr_valid && wr_ready && wr_in_tile && wr_in_valid) begin
                mem[wr_addr] <= wr_data;
                valid_mem[wr_addr] <= wr_pixel_valid;
            end

            if (stream_start && !stream_busy && !load_pending) begin
                stream_busy <= 1'b1;
                read_wait <= 2'd2;
                out_x <= {X_W{1'b0}};
                out_y <= {Y_W{1'b0}};
                out_addr <= {ADDR_W{1'b0}};
                rd_addr <= {ADDR_W{1'b0}};
                m_valid <= 1'b0;
                m_user <= 1'b0;
                m_last <= 1'b0;
                m_pixel_valid <= 1'b0;
            end else if (read_wait != 2'd0) begin
                read_wait <= read_wait - 2'd1;
                if (read_wait == 2'd1) begin
                    m_valid <= 1'b1;
                    m_data <= out_pixel_for(out_x, out_y, rd_data);
                    m_pixel_valid <= out_valid_for(out_x, out_y, rd_valid_data);
                    m_user <= (out_addr == {ADDR_W{1'b0}});
                    m_last <= end_row;
                end
            end else if (accept_out) begin
                if (last_pixel) begin
                    stream_busy <= 1'b0;
                    stream_done <= 1'b1;
                    m_valid <= 1'b0;
                    m_pixel_valid <= 1'b0;
                    m_user <= 1'b0;
                    m_last <= 1'b0;
                end else begin
                    out_addr <= out_addr + ADDR_ONE;
                    if (end_row) begin
                        out_x <= {X_W{1'b0}};
                        out_y <= out_y + {{(Y_W-1){1'b0}}, 1'b1};
                    end else begin
                        out_x <= out_x + {{(X_W-1){1'b0}}, 1'b1};
                    end
                    rd_addr <= out_addr + ADDR_ONE;
                    read_wait <= 2'd2;
                    m_valid <= 1'b0;
                    m_pixel_valid <= 1'b0;
                    m_user <= 1'b0;
                    m_last <= 1'b0;
                end
            end
        end
    end

    function [DATA_W-1:0] out_pixel_for;
        input [X_W-1:0] nx;
        input [Y_W-1:0] ny;
        input [DATA_W-1:0] pixel;
        begin
            if (({{(COORD_W-X_W){1'b0}}, nx} < valid_w) &&
                ({{(COORD_W-Y_W){1'b0}}, ny} < valid_h))
                out_pixel_for = pixel;
            else
                out_pixel_for = {DATA_W{1'b0}};
        end
    endfunction

    function out_valid_for;
        input [X_W-1:0] nx;
        input [Y_W-1:0] ny;
        input pixel_valid;
        begin
            out_valid_for = ({{(COORD_W-X_W){1'b0}}, nx} < valid_w) &&
                            ({{(COORD_W-Y_W){1'b0}}, ny} < valid_h) &&
                            pixel_valid;
        end
    endfunction
endmodule
