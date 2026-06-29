`timescale 1ns/1ps

// Halo-aware one-tile fetch shell for hardware-side large-image tiling.
//
// The command names the valid output tile origin in the LR image. The shell
// fetches a larger compute patch:
//   (OUT_TILE_W + 2*HALO) x (OUT_TILE_H + 2*HALO)
// centered around that output tile. Pixels outside the source image are written
// as zero in hardware; pixels inside the source image issue read requests into a
// linear RGB888 frame buffer. The output stream is the complete halo patch for a
// later W8A12 tile compute engine, which can crop/emit the valid interior.
module sr_tile_halo_fetch_stream_shell #(
    parameter integer DATA_W = 24,
    parameter integer OUT_TILE_W = 64,
    parameter integer OUT_TILE_H = 64,
    parameter integer HALO = 21,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer COMPUTE_W = OUT_TILE_W + 2 * HALO,
    parameter integer COMPUTE_H = OUT_TILE_H + 2 * HALO
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  cmd_valid,
    output wire                  cmd_ready,
    input  wire [COORD_W-1:0]    cmd_image_w,
    input  wire [COORD_W-1:0]    cmd_image_h,
    input  wire [COORD_W-1:0]    cmd_tile_x,
    input  wire [COORD_W-1:0]    cmd_tile_y,
    input  wire [ADDR_W-1:0]     cmd_input_base,

    output reg                   rd_req_valid,
    input  wire                  rd_req_ready,
    output reg  [ADDR_W-1:0]     rd_req_addr,
    input  wire                  rd_resp_valid,
    input  wire [DATA_W-1:0]     rd_resp_data,

    output wire                  m_valid,
    input  wire                  m_ready,
    output wire [DATA_W-1:0]     m_data,
    output wire                  m_pixel_valid,
    output wire                  m_user,
    output wire                  m_last,

    output reg                   busy,
    output reg                   done,
    output reg                   error
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_CLEAR_WAIT = 3'd1;
    localparam [2:0] ST_SCAN       = 3'd2;
    localparam [2:0] ST_REQ        = 3'd3;
    localparam [2:0] ST_WAIT_RESP  = 3'd4;
    localparam [2:0] ST_WRITE_ZERO = 3'd5;
    localparam [2:0] ST_STREAM_ARM = 3'd6;
    localparam [2:0] ST_STREAM     = 3'd7;

    localparam [COORD_W-1:0] COMPUTE_W_C = COMPUTE_W[COORD_W-1:0];
    localparam [COORD_W-1:0] COMPUTE_H_C = COMPUTE_H[COORD_W-1:0];
    localparam signed [COORD_W:0] HALO_S = HALO;

    reg [2:0] state;
    reg [COORD_W-1:0] image_w;
    reg [COORD_W-1:0] image_h;
    reg [COORD_W-1:0] tile_x;
    reg [COORD_W-1:0] tile_y;
    reg [ADDR_W-1:0] base_addr;
    reg [COORD_W-1:0] patch_x;
    reg [COORD_W-1:0] patch_y;
    reg [COORD_W-1:0] resp_x;
    reg [COORD_W-1:0] resp_y;
    reg saw_buffer_clear;
    reg buf_load_start;
    reg buf_wr_valid;
    wire buf_wr_ready;
    reg [COORD_W-1:0] buf_wr_x;
    reg [COORD_W-1:0] buf_wr_y;
    reg [DATA_W-1:0] buf_wr_data;
    reg buf_wr_pixel_valid;
    reg stream_start;
    wire stream_busy;
    wire stream_done;

    wire command_bad = (cmd_image_w == 0) || (cmd_image_h == 0) ||
                       (cmd_tile_x >= cmd_image_w) || (cmd_tile_y >= cmd_image_h) ||
                       (COMPUTE_W <= 0) || (COMPUTE_H <= 0);
    wire req_fire = rd_req_valid && rd_req_ready;
    wire last_patch = (patch_x == (COMPUTE_W_C - {{(COORD_W-1){1'b0}}, 1'b1})) &&
                      (patch_y == (COMPUTE_H_C - {{(COORD_W-1){1'b0}}, 1'b1}));
    wire end_patch_row = (patch_x == (COMPUTE_W_C - {{(COORD_W-1){1'b0}}, 1'b1}));

    wire signed [COORD_W:0] src_x_s =
        $signed({1'b0, tile_x}) + $signed({1'b0, patch_x}) - HALO_S;
    wire signed [COORD_W:0] src_y_s =
        $signed({1'b0, tile_y}) + $signed({1'b0, patch_y}) - HALO_S;
    wire src_in_bounds = (src_x_s >= 0) && (src_y_s >= 0) &&
                         (src_x_s < $signed({1'b0, image_w})) &&
                         (src_y_s < $signed({1'b0, image_h}));
    wire [COORD_W-1:0] src_x = src_x_s[COORD_W-1:0];
    wire [COORD_W-1:0] src_y = src_y_s[COORD_W-1:0];
    wire [ADDR_W+COORD_W+3:0] pixel_offset =
        (({{(ADDR_W+4){1'b0}}, src_y} * {{(ADDR_W+4){1'b0}}, image_w}) +
         {{(ADDR_W+4){1'b0}}, src_x}) * BYTES_PER_PIXEL;

    assign cmd_ready = (state == ST_IDLE);

    sr_tile_rgb_buffer_streamer #(
        .DATA_W(DATA_W),
        .TILE_W(COMPUTE_W),
        .TILE_H(COMPUTE_H),
        .COORD_W(COORD_W)
    ) u_patch_buffer (
        .clk(clk),
        .rst(rst),
        .load_start(buf_load_start),
        .valid_w_i(COMPUTE_W_C),
        .valid_h_i(COMPUTE_H_C),
        .wr_valid(buf_wr_valid),
        .wr_ready(buf_wr_ready),
        .wr_x(buf_wr_x),
        .wr_y(buf_wr_y),
        .wr_data(buf_wr_data),
        .wr_pixel_valid(buf_wr_pixel_valid),
        .stream_start(stream_start),
        .stream_busy(stream_busy),
        .stream_done(stream_done),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data),
        .m_pixel_valid(m_pixel_valid),
        .m_user(m_user),
        .m_last(m_last)
    );

    task automatic advance_patch;
        begin
            if (end_patch_row) begin
                patch_x <= {COORD_W{1'b0}};
                patch_y <= patch_y + {{(COORD_W-1){1'b0}}, 1'b1};
            end else begin
                patch_x <= patch_x + {{(COORD_W-1){1'b0}}, 1'b1};
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            image_w <= {COORD_W{1'b0}};
            image_h <= {COORD_W{1'b0}};
            tile_x <= {COORD_W{1'b0}};
            tile_y <= {COORD_W{1'b0}};
            base_addr <= {ADDR_W{1'b0}};
            patch_x <= {COORD_W{1'b0}};
            patch_y <= {COORD_W{1'b0}};
            resp_x <= {COORD_W{1'b0}};
            resp_y <= {COORD_W{1'b0}};
            saw_buffer_clear <= 1'b0;
            rd_req_valid <= 1'b0;
            rd_req_addr <= {ADDR_W{1'b0}};
            buf_load_start <= 1'b0;
            buf_wr_valid <= 1'b0;
            buf_wr_x <= {COORD_W{1'b0}};
            buf_wr_y <= {COORD_W{1'b0}};
            buf_wr_data <= {DATA_W{1'b0}};
            buf_wr_pixel_valid <= 1'b0;
            stream_start <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;
            buf_load_start <= 1'b0;
            buf_wr_valid <= 1'b0;
            buf_wr_pixel_valid <= 1'b0;
            stream_start <= 1'b0;

            case (state)
                ST_IDLE: begin
                    rd_req_valid <= 1'b0;
                    busy <= 1'b0;
                    if (cmd_valid) begin
                        error <= command_bad;
                        done <= command_bad;
                        if (!command_bad) begin
                            image_w <= cmd_image_w;
                            image_h <= cmd_image_h;
                            tile_x <= cmd_tile_x;
                            tile_y <= cmd_tile_y;
                            base_addr <= cmd_input_base;
                            patch_x <= {COORD_W{1'b0}};
                            patch_y <= {COORD_W{1'b0}};
                            saw_buffer_clear <= 1'b0;
                            buf_load_start <= 1'b1;
                            busy <= 1'b1;
                            state <= ST_CLEAR_WAIT;
                        end
                    end
                end

                ST_CLEAR_WAIT: begin
                    busy <= 1'b1;
                    if (!buf_wr_ready)
                        saw_buffer_clear <= 1'b1;
                    if (saw_buffer_clear && buf_wr_ready)
                        state <= ST_SCAN;
                end

                ST_SCAN: begin
                    busy <= 1'b1;
                    if (src_in_bounds) begin
                        state <= ST_REQ;
                    end else begin
                        state <= ST_WRITE_ZERO;
                    end
                end

                ST_REQ: begin
                    busy <= 1'b1;
                    rd_req_valid <= 1'b1;
                    rd_req_addr <= base_addr + pixel_offset[ADDR_W-1:0];
                    if (req_fire) begin
                        rd_req_valid <= 1'b0;
                        resp_x <= patch_x;
                        resp_y <= patch_y;
                        state <= ST_WAIT_RESP;
                    end
                end

                ST_WAIT_RESP: begin
                    busy <= 1'b1;
                    if (rd_resp_valid && buf_wr_ready) begin
                        buf_wr_valid <= 1'b1;
                        buf_wr_x <= resp_x;
                        buf_wr_y <= resp_y;
                        buf_wr_data <= rd_resp_data;
                        buf_wr_pixel_valid <= 1'b1;
                        if (last_patch) begin
                            state <= ST_STREAM_ARM;
                        end else begin
                            advance_patch();
                            state <= ST_SCAN;
                        end
                    end
                end

                ST_WRITE_ZERO: begin
                    busy <= 1'b1;
                    if (buf_wr_ready) begin
                        buf_wr_valid <= 1'b1;
                        buf_wr_x <= patch_x;
                        buf_wr_y <= patch_y;
                        buf_wr_data <= {DATA_W{1'b0}};
                        buf_wr_pixel_valid <= 1'b0;
                        if (last_patch) begin
                            state <= ST_STREAM_ARM;
                        end else begin
                            advance_patch();
                            state <= ST_SCAN;
                        end
                    end
                end

                ST_STREAM_ARM: begin
                    busy <= 1'b1;
                    stream_start <= 1'b1;
                    state <= ST_STREAM;
                end

                ST_STREAM: begin
                    busy <= 1'b1;
                    if (stream_done) begin
                        done <= 1'b1;
                        busy <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
