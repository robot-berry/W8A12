`timescale 1ns/1ps

// Hardware tile scheduler for large-image SR.
//
// This module does not cut images on the PC. It enumerates tiles in hardware
// from a large linear RGB888 frame buffer and exposes each tile's source/output
// coordinates and byte offsets. A DMA/SD front end can use these commands to
// fetch one tile into a tile-local buffer, run the SR engine, then write the
// scaled tile back.
module sr_tile_scheduler #(
    parameter integer COORD_W = 16,
    parameter integer ADDR_W  = 32,
    parameter integer SCALE   = 4,
    parameter integer BYTES_PER_PIXEL = 3
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  start,
    input  wire [COORD_W-1:0]    image_w,
    input  wire [COORD_W-1:0]    image_h,
    input  wire [COORD_W-1:0]    tile_w,
    input  wire [COORD_W-1:0]    tile_h,
    input  wire [COORD_W-1:0]    stride_x,
    input  wire [COORD_W-1:0]    stride_y,
    input  wire [ADDR_W-1:0]     input_base,
    input  wire [ADDR_W-1:0]     output_base,

    output reg                   busy,
    output reg                   done,
    output reg                   error,

    output reg                   tile_valid,
    input  wire                  tile_ready,
    output reg  [COORD_W-1:0]    tile_x,
    output reg  [COORD_W-1:0]    tile_y,
    output reg  [COORD_W-1:0]    tile_valid_w,
    output reg  [COORD_W-1:0]    tile_valid_h,
    output reg  [31:0]           tile_index,
    output reg                   tile_last,
    output reg  [ADDR_W-1:0]     tile_input_addr,
    output reg  [ADDR_W-1:0]     tile_output_addr
);
    localparam integer MUL_W = ADDR_W + COORD_W + 4;

    reg [COORD_W-1:0] cfg_image_w;
    reg [COORD_W-1:0] cfg_image_h;
    reg [COORD_W-1:0] cfg_tile_w;
    reg [COORD_W-1:0] cfg_tile_h;
    reg [COORD_W-1:0] cfg_stride_x;
    reg [COORD_W-1:0] cfg_stride_y;
    reg [ADDR_W-1:0]  cfg_input_base;
    reg [ADDR_W-1:0]  cfg_output_base;
    reg [COORD_W-1:0] cur_x;
    reg [COORD_W-1:0] cur_y;

    wire accept_tile = tile_valid && tile_ready;
    wire cfg_bad = (image_w == 0) || (image_h == 0) ||
                   (tile_w == 0) || (tile_h == 0) ||
                   (stride_x == 0) || (stride_y == 0);

    wire [COORD_W:0] cur_x_plus_stride = {1'b0, cur_x} + {1'b0, cfg_stride_x};
    wire [COORD_W:0] cur_y_plus_stride = {1'b0, cur_y} + {1'b0, cfg_stride_y};
    wire next_row = (cur_x_plus_stride >= {1'b0, cfg_image_w});
    wire next_done = next_row && (cur_y_plus_stride >= {1'b0, cfg_image_h});
    wire [COORD_W-1:0] next_x = next_row ? {COORD_W{1'b0}} : cur_x_plus_stride[COORD_W-1:0];
    wire [COORD_W-1:0] next_y = next_row ? cur_y_plus_stride[COORD_W-1:0] : cur_y;

    wire [COORD_W:0] next_remaining_w = {1'b0, cfg_image_w} - {1'b0, next_x};
    wire [COORD_W:0] next_remaining_h = {1'b0, cfg_image_h} - {1'b0, next_y};
    wire [COORD_W-1:0] next_eff_w = (next_remaining_w < {1'b0, cfg_tile_w}) ? next_remaining_w[COORD_W-1:0] : cfg_tile_w;
    wire [COORD_W-1:0] next_eff_h = (next_remaining_h < {1'b0, cfg_tile_h}) ? next_remaining_h[COORD_W-1:0] : cfg_tile_h;
    wire [COORD_W:0] next_x_plus_stride = {1'b0, next_x} + {1'b0, cfg_stride_x};
    wire [COORD_W:0] next_y_plus_stride = {1'b0, next_y} + {1'b0, cfg_stride_y};
    wire next_tile_row = (next_x_plus_stride >= {1'b0, cfg_image_w});
    wire next_tile_last = next_tile_row && (next_y_plus_stride >= {1'b0, cfg_image_h});

    wire [MUL_W-1:0] next_in_pixel_index =
        (({{(MUL_W-COORD_W){1'b0}}, next_y} * {{(MUL_W-COORD_W){1'b0}}, cfg_image_w}) +
         {{(MUL_W-COORD_W){1'b0}}, next_x});
    wire [MUL_W-1:0] next_out_pixel_index =
        (({{(MUL_W-COORD_W){1'b0}}, next_y} * SCALE * {{(MUL_W-COORD_W){1'b0}}, cfg_image_w} * SCALE) +
         ({{(MUL_W-COORD_W){1'b0}}, next_x} * SCALE));
    wire [MUL_W-1:0] next_in_byte_offset = next_in_pixel_index * BYTES_PER_PIXEL;
    wire [MUL_W-1:0] next_out_byte_offset = next_out_pixel_index * BYTES_PER_PIXEL;

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            tile_valid <= 1'b0;
            tile_x <= {COORD_W{1'b0}};
            tile_y <= {COORD_W{1'b0}};
            tile_valid_w <= {COORD_W{1'b0}};
            tile_valid_h <= {COORD_W{1'b0}};
            tile_index <= 32'd0;
            tile_last <= 1'b0;
            tile_input_addr <= {ADDR_W{1'b0}};
            tile_output_addr <= {ADDR_W{1'b0}};
            cfg_image_w <= {COORD_W{1'b0}};
            cfg_image_h <= {COORD_W{1'b0}};
            cfg_tile_w <= {COORD_W{1'b0}};
            cfg_tile_h <= {COORD_W{1'b0}};
            cfg_stride_x <= {COORD_W{1'b0}};
            cfg_stride_y <= {COORD_W{1'b0}};
            cfg_input_base <= {ADDR_W{1'b0}};
            cfg_output_base <= {ADDR_W{1'b0}};
            cur_x <= {COORD_W{1'b0}};
            cur_y <= {COORD_W{1'b0}};
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                error <= cfg_bad;
                done <= cfg_bad;
                busy <= !cfg_bad;
                tile_valid <= !cfg_bad;
                cfg_image_w <= image_w;
                cfg_image_h <= image_h;
                cfg_tile_w <= tile_w;
                cfg_tile_h <= tile_h;
                cfg_stride_x <= stride_x;
                cfg_stride_y <= stride_y;
                cfg_input_base <= input_base;
                cfg_output_base <= output_base;
                cur_x <= {COORD_W{1'b0}};
                cur_y <= {COORD_W{1'b0}};
                tile_index <= 32'd0;
                tile_x <= {COORD_W{1'b0}};
                tile_y <= {COORD_W{1'b0}};
                tile_valid_w <= (image_w < tile_w) ? image_w : tile_w;
                tile_valid_h <= (image_h < tile_h) ? image_h : tile_h;
                tile_last <= (stride_x >= image_w) && (stride_y >= image_h);
                tile_input_addr <= input_base;
                tile_output_addr <= output_base;
            end else if (accept_tile) begin
                if (next_done) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    tile_valid <= 1'b0;
                end else begin
                    cur_x <= next_x;
                    cur_y <= next_y;
                    tile_index <= tile_index + 32'd1;
                    tile_x <= next_x;
                    tile_y <= next_y;
                    tile_valid_w <= next_eff_w;
                    tile_valid_h <= next_eff_h;
                    tile_last <= next_tile_last;
                    tile_input_addr <= cfg_input_base + next_in_byte_offset[ADDR_W-1:0];
                    tile_output_addr <= cfg_output_base + next_out_byte_offset[ADDR_W-1:0];
                end
            end

        end
    end
endmodule
