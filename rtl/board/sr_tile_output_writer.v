`timescale 1ns/1ps

// Output-side tile writer address generator.
//
// Consumes a raster stream for one valid HR output tile and emits linear write
// requests into a large RGB output frame buffer. This is the writeback half of
// hardware-side large-image tiling: after halo compute and interior crop, only
// the valid tile pixels are written to their position in the large output image.
module sr_tile_output_writer #(
    parameter integer DATA_W = 24,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer SCALE = 4,
    parameter integer BYTES_PER_PIXEL = 3
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  cmd_valid,
    output wire                  cmd_ready,
    input  wire [COORD_W-1:0]    cmd_image_w,
    input  wire [COORD_W-1:0]    cmd_tile_x,
    input  wire [COORD_W-1:0]    cmd_tile_y,
    input  wire [COORD_W-1:0]    cmd_valid_w,
    input  wire [COORD_W-1:0]    cmd_valid_h,
    input  wire [ADDR_W-1:0]     cmd_output_base,

    input  wire                  s_valid,
    output wire                  s_ready,
    input  wire [DATA_W-1:0]     s_data,
    input  wire                  s_user,
    input  wire                  s_last,

    output wire                  wr_valid,
    input  wire                  wr_ready,
    output wire [ADDR_W-1:0]     wr_addr,
    output wire [DATA_W-1:0]     wr_data,

    output reg                   busy,
    output reg                   done,
    output reg                   error
);
    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_WRITE = 2'd1;

    localparam [COORD_W-1:0] SCALE_C = SCALE[COORD_W-1:0];
    localparam integer MUL_W = ADDR_W + COORD_W + 8;

    reg [1:0] state;
    reg [COORD_W-1:0] image_w;
    reg [COORD_W-1:0] tile_x;
    reg [COORD_W-1:0] tile_y;
    reg [COORD_W-1:0] valid_w;
    reg [COORD_W-1:0] valid_h;
    reg [ADDR_W-1:0] output_base;
    reg [COORD_W-1:0] out_x;
    reg [COORD_W-1:0] out_y;

    wire [COORD_W-1:0] hr_valid_w = valid_w * SCALE_C;
    wire [COORD_W-1:0] hr_valid_h = valid_h * SCALE_C;
    wire [COORD_W-1:0] hr_image_w = image_w * SCALE_C;
    wire [COORD_W-1:0] hr_tile_x = tile_x * SCALE_C;
    wire [COORD_W-1:0] hr_tile_y = tile_y * SCALE_C;
    wire command_bad = (cmd_image_w == 0) || (cmd_valid_w == 0) || (cmd_valid_h == 0) ||
                       (cmd_tile_x >= cmd_image_w);
    wire write_fire = s_valid && s_ready;
    wire last_pixel = (out_x == (hr_valid_w - {{(COORD_W-1){1'b0}}, 1'b1})) &&
                      (out_y == (hr_valid_h - {{(COORD_W-1){1'b0}}, 1'b1}));
    wire end_row = (out_x == (hr_valid_w - {{(COORD_W-1){1'b0}}, 1'b1}));

    wire [MUL_W-1:0] pixel_index =
        (({{(MUL_W-COORD_W){1'b0}}, (hr_tile_y + out_y)} *
          {{(MUL_W-COORD_W){1'b0}}, hr_image_w}) +
         {{(MUL_W-COORD_W){1'b0}}, (hr_tile_x + out_x)});
    wire [MUL_W-1:0] byte_offset = pixel_index * BYTES_PER_PIXEL;

    assign cmd_ready = (state == ST_IDLE);
    assign s_ready = (state == ST_WRITE) && wr_ready;
    assign wr_valid = (state == ST_WRITE) && s_valid;
    assign wr_addr = output_base + byte_offset[ADDR_W-1:0];
    assign wr_data = s_data;

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            image_w <= {COORD_W{1'b0}};
            tile_x <= {COORD_W{1'b0}};
            tile_y <= {COORD_W{1'b0}};
            valid_w <= {COORD_W{1'b0}};
            valid_h <= {COORD_W{1'b0}};
            output_base <= {ADDR_W{1'b0}};
            out_x <= {COORD_W{1'b0}};
            out_y <= {COORD_W{1'b0}};
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (cmd_valid) begin
                        error <= command_bad;
                        done <= command_bad;
                        if (!command_bad) begin
                            image_w <= cmd_image_w;
                            tile_x <= cmd_tile_x;
                            tile_y <= cmd_tile_y;
                            valid_w <= cmd_valid_w;
                            valid_h <= cmd_valid_h;
                            output_base <= cmd_output_base;
                            out_x <= {COORD_W{1'b0}};
                            out_y <= {COORD_W{1'b0}};
                            busy <= 1'b1;
                            state <= ST_WRITE;
                        end
                    end
                end

                ST_WRITE: begin
                    busy <= 1'b1;
                    if (write_fire) begin
                        if (last_pixel) begin
                            done <= 1'b1;
                            busy <= 1'b0;
                            state <= ST_IDLE;
                        end else if (end_row) begin
                            out_x <= {COORD_W{1'b0}};
                            out_y <= out_y + {{(COORD_W-1){1'b0}}, 1'b1};
                        end else begin
                            out_x <= out_x + {{(COORD_W-1){1'b0}}, 1'b1};
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    wire unused_sideband = s_user ^ s_last;
endmodule
