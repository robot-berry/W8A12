`timescale 1ns/1ps

// Tile-local feature buffer and replay streamer.
//
// This is the first feature-domain storage boundary after conv1. It stores one
// fixed-size feature tile from an AXIS-like stream, then replays it with fresh
// user/last sideband for the next scheduled W8A12 stage.
module sr_feature_tile_buffer_streamer #(
    parameter integer DATA_W = 576,
    parameter integer TILE_W = 16,
    parameter integer TILE_H = 16
) (
    input  wire                     clk,
    input  wire                     rst,

    input  wire                     load_start,
    output reg                      load_busy,
    output reg                      load_done,
    output reg                      load_error,

    input  wire                     s_valid,
    output wire                     s_ready,
    input  wire [DATA_W-1:0]        s_feat,
    input  wire                     s_user,
    input  wire                     s_last,

    input  wire                     stream_start,
    output reg                      stream_busy,
    output reg                      stream_done,

    output reg                      m_valid,
    input  wire                     m_ready,
    output reg  [DATA_W-1:0]        m_feat,
    output reg                      m_user,
    output reg                      m_last
);
    localparam integer TILE_PIXELS = TILE_W * TILE_H;
    localparam integer ADDR_W = (TILE_PIXELS <= 2) ? 1 : $clog2(TILE_PIXELS);
    localparam integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W);
    localparam [ADDR_W-1:0] ADDR_ZERO = {ADDR_W{1'b0}};
    localparam [ADDR_W-1:0] ADDR_LAST = TILE_PIXELS - 1;

    (* ram_style = "block" *)
    reg [DATA_W-1:0] mem [0:TILE_PIXELS-1];

    reg [ADDR_W-1:0] wr_addr;
    reg [ADDR_W-1:0] rd_addr;
    reg [ADDR_W-1:0] out_addr;
    reg [X_W-1:0] wr_x;
    reg [X_W-1:0] out_x;
    reg [DATA_W-1:0] rd_data;
    reg [1:0] read_wait;
    reg tile_loaded;

    wire s_take = s_valid && s_ready;
    wire m_take = m_valid && m_ready;
    wire wr_last_addr = (wr_addr == ADDR_LAST);
    wire wr_end_row = (wr_x == TILE_W - 1);
    wire out_last_addr = (out_addr == ADDR_LAST);
    wire out_end_row = (out_x == TILE_W - 1);

    assign s_ready = load_busy && !stream_busy;

    always @(posedge clk) begin
        if (rst) begin
            wr_addr <= ADDR_ZERO;
            rd_addr <= ADDR_ZERO;
            out_addr <= ADDR_ZERO;
            wr_x <= {X_W{1'b0}};
            out_x <= {X_W{1'b0}};
            rd_data <= {DATA_W{1'b0}};
            read_wait <= 2'd0;
            tile_loaded <= 1'b0;
            load_busy <= 1'b0;
            load_done <= 1'b0;
            load_error <= 1'b0;
            stream_busy <= 1'b0;
            stream_done <= 1'b0;
            m_valid <= 1'b0;
            m_feat <= {DATA_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            load_done <= 1'b0;
            stream_done <= 1'b0;
            rd_data <= mem[rd_addr];

            if (load_start && !load_busy && !stream_busy) begin
                load_busy <= 1'b1;
                load_error <= 1'b0;
                tile_loaded <= 1'b0;
                wr_addr <= ADDR_ZERO;
                wr_x <= {X_W{1'b0}};
            end

            if (s_take) begin
                mem[wr_addr] <= s_feat;
                if (wr_addr == ADDR_ZERO && !s_user)
                    load_error <= 1'b1;
                if (wr_end_row != s_last)
                    load_error <= 1'b1;

                if (wr_last_addr) begin
                    load_busy <= 1'b0;
                    load_done <= 1'b1;
                    tile_loaded <= 1'b1;
                    if (!s_last)
                        load_error <= 1'b1;
                end else begin
                    wr_addr <= wr_addr + 1'b1;
                    if (wr_end_row)
                        wr_x <= {X_W{1'b0}};
                    else
                        wr_x <= wr_x + 1'b1;
                end
            end

            if (stream_start && !stream_busy && !load_busy && tile_loaded) begin
                stream_busy <= 1'b1;
                read_wait <= 2'd2;
                rd_addr <= ADDR_ZERO;
                out_addr <= ADDR_ZERO;
                out_x <= {X_W{1'b0}};
                m_valid <= 1'b0;
                m_user <= 1'b0;
                m_last <= 1'b0;
            end else if (read_wait != 2'd0) begin
                read_wait <= read_wait - 1'b1;
                if (read_wait == 2'd1) begin
                    m_valid <= 1'b1;
                    m_feat <= rd_data;
                    m_user <= (out_addr == ADDR_ZERO);
                    m_last <= out_end_row;
                end
            end else if (m_take) begin
                if (out_last_addr) begin
                    stream_busy <= 1'b0;
                    stream_done <= 1'b1;
                    m_valid <= 1'b0;
                    m_user <= 1'b0;
                    m_last <= 1'b0;
                end else begin
                    out_addr <= out_addr + 1'b1;
                    if (out_end_row)
                        out_x <= {X_W{1'b0}};
                    else
                        out_x <= out_x + 1'b1;
                    rd_addr <= out_addr + 1'b1;
                    read_wait <= 2'd2;
                    m_valid <= 1'b0;
                    m_user <= 1'b0;
                    m_last <= 1'b0;
                end
            end
        end
    end
endmodule
