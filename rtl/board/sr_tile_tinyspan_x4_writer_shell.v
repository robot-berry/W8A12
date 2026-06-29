`timescale 1ns/1ps

// Full-frame hardware-side TinySPAN X4 tile writer shell.
//
// This is the next integration step after the proven 32x32 TinySPAN board
// smoke. It keeps tiling on the board side: a scheduler enumerates one complete
// LR frame, the fetch shell reads each LR tile from the frame buffer and pads
// edge tiles in hardware, the TinySPAN 32x32 X4 core emits a fixed 128x128 SR
// tile, the dynamic cropper drops padded edge pixels, and the output writer
// writes the valid SR region back to the full-frame output buffer.
module sr_tile_tinyspan_x4_writer_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 32,
    parameter integer TILE_H = 32,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer SCALE = 4,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer USE_SERIAL_BASE = 0,
    parameter integer HR_TILE_W = TILE_W * SCALE,
    parameter integer HR_TILE_H = TILE_H * SCALE
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  start,
    input  wire [COORD_W-1:0]    image_w,
    input  wire [COORD_W-1:0]    image_h,
    input  wire [ADDR_W-1:0]     input_base,
    input  wire [ADDR_W-1:0]     output_base,

    output wire                  rd_req_valid,
    input  wire                  rd_req_ready,
    output wire [ADDR_W-1:0]     rd_req_addr,
    input  wire                  rd_resp_valid,
    input  wire [DATA_W-1:0]     rd_resp_data,

    output wire                  wr_valid,
    input  wire                  wr_ready,
    output wire [ADDR_W-1:0]     wr_addr,
    output wire [DATA_W-1:0]     wr_data,

    output reg                   busy,
    output reg                   done,
    output reg                   error,
    output reg  [31:0]           tiles_done,
    output reg  [63:0]           frame_cycles
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WAIT_TILE  = 3'd1;
    localparam [2:0] ST_START_TILE = 3'd2;
    localparam [2:0] ST_RUN_TILE   = 3'd3;
    localparam [2:0] ST_DONE       = 3'd4;

    localparam [COORD_W-1:0] TILE_W_C = TILE_W;
    localparam [COORD_W-1:0] TILE_H_C = TILE_H;
    localparam [COORD_W-1:0] SCALE_C = SCALE;

    reg [2:0] state;
    reg sched_start;
    wire sched_busy;
    wire sched_done;
    wire sched_error;
    wire sched_tile_valid;
    wire sched_tile_ready;
    wire [COORD_W-1:0] sched_tile_x;
    wire [COORD_W-1:0] sched_tile_y;
    wire [COORD_W-1:0] sched_valid_w;
    wire [COORD_W-1:0] sched_valid_h;
    wire [31:0] sched_tile_index;
    wire sched_tile_last;
    wire [ADDR_W-1:0] sched_tile_input_addr;
    wire [ADDR_W-1:0] sched_tile_output_addr;

    reg [COORD_W-1:0] tile_x_q;
    reg [COORD_W-1:0] tile_y_q;
    reg [COORD_W-1:0] valid_w_q;
    reg [COORD_W-1:0] valid_h_q;
    reg tile_last_q;
    reg [ADDR_W-1:0] tile_input_addr_q;

    reg fetch_cmd_valid;
    wire fetch_cmd_ready;
    wire fetch_m_valid;
    wire fetch_m_ready;
    wire [DATA_W-1:0] fetch_m_data;
    wire fetch_m_pixel_valid;
    wire fetch_m_user;
    wire fetch_m_last;
    wire fetch_busy;
    wire fetch_done;
    wire fetch_error;

    wire core_m_valid;
    wire core_m_ready;
    wire [DATA_W-1:0] core_m_data;
    wire core_m_user;
    wire core_m_last;

    reg crop_start;
    wire crop_m_valid;
    wire crop_m_ready;
    wire [DATA_W-1:0] crop_m_data;
    wire crop_m_user;
    wire crop_m_last;
    wire crop_busy;
    wire crop_done;
    wire crop_error;
    wire [COORD_W-1:0] crop_valid_w = valid_w_q * SCALE_C;
    wire [COORD_W-1:0] crop_valid_h = valid_h_q * SCALE_C;

    reg writer_cmd_valid;
    wire writer_cmd_ready;
    wire writer_busy;
    wire writer_done;
    wire writer_error;
    reg fetch_done_seen;
    reg crop_done_seen;
    reg writer_done_seen;

    assign sched_tile_ready = (state == ST_WAIT_TILE);

    sr_tile_scheduler #(
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .SCALE(SCALE),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_scheduler (
        .clk(clk),
        .rst(rst),
        .start(sched_start),
        .image_w(image_w),
        .image_h(image_h),
        .tile_w(TILE_W_C),
        .tile_h(TILE_H_C),
        .stride_x(TILE_W_C),
        .stride_y(TILE_H_C),
        .input_base(input_base),
        .output_base(output_base),
        .busy(sched_busy),
        .done(sched_done),
        .error(sched_error),
        .tile_valid(sched_tile_valid),
        .tile_ready(sched_tile_ready),
        .tile_x(sched_tile_x),
        .tile_y(sched_tile_y),
        .tile_valid_w(sched_valid_w),
        .tile_valid_h(sched_valid_h),
        .tile_index(sched_tile_index),
        .tile_last(sched_tile_last),
        .tile_input_addr(sched_tile_input_addr),
        .tile_output_addr(sched_tile_output_addr)
    );

    sr_tile_fetch_stream_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_fetch (
        .clk(clk),
        .rst(rst),
        .cmd_valid(fetch_cmd_valid),
        .cmd_ready(fetch_cmd_ready),
        .cmd_image_w(image_w),
        .cmd_valid_w(valid_w_q),
        .cmd_valid_h(valid_h_q),
        .cmd_input_addr(tile_input_addr_q),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .m_valid(fetch_m_valid),
        .m_ready(fetch_m_ready),
        .m_data(fetch_m_data),
        .m_pixel_valid(fetch_m_pixel_valid),
        .m_user(fetch_m_user),
        .m_last(fetch_m_last),
        .busy(fetch_busy),
        .done(fetch_done),
        .error(fetch_error)
    );

    span_tinyspan_w8a8_full_streamed_rgb888_base_equiv #(
        .DATA_W(DATA_W),
        .IMG_W(TILE_W),
        .IMG_H(TILE_H),
        .USE_SERIAL_BASE(USE_SERIAL_BASE)
    ) u_tinyspan (
        .clk(clk),
        .rst(rst),
        .s_valid(fetch_m_valid),
        .s_ready(fetch_m_ready),
        .s_data(fetch_m_data),
        .s_user(fetch_m_user),
        .s_last(fetch_m_last),
        .m_valid(core_m_valid),
        .m_ready(core_m_ready),
        .m_data(core_m_data),
        .m_user(core_m_user),
        .m_last(core_m_last)
    );

    sr_stream_dynamic_cropper #(
        .DATA_W(DATA_W),
        .IN_W(HR_TILE_W),
        .IN_H(HR_TILE_H),
        .COORD_W(COORD_W)
    ) u_crop (
        .clk(clk),
        .rst(rst),
        .start(crop_start),
        .valid_w_i(crop_valid_w),
        .valid_h_i(crop_valid_h),
        .s_valid(core_m_valid),
        .s_ready(core_m_ready),
        .s_data(core_m_data),
        .s_user(core_m_user),
        .s_last(core_m_last),
        .m_valid(crop_m_valid),
        .m_ready(crop_m_ready),
        .m_data(crop_m_data),
        .m_user(crop_m_user),
        .m_last(crop_m_last),
        .busy(crop_busy),
        .done(crop_done),
        .error(crop_error)
    );

    sr_tile_output_writer #(
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .SCALE(SCALE),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_writer (
        .clk(clk),
        .rst(rst),
        .cmd_valid(writer_cmd_valid),
        .cmd_ready(writer_cmd_ready),
        .cmd_image_w(image_w),
        .cmd_tile_x(tile_x_q),
        .cmd_tile_y(tile_y_q),
        .cmd_valid_w(valid_w_q),
        .cmd_valid_h(valid_h_q),
        .cmd_output_base(output_base),
        .s_valid(crop_m_valid),
        .s_ready(crop_m_ready),
        .s_data(crop_m_data),
        .s_user(crop_m_user),
        .s_last(crop_m_last),
        .wr_valid(wr_valid),
        .wr_ready(wr_ready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(writer_busy),
        .done(writer_done),
        .error(writer_error)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            sched_start <= 1'b0;
            fetch_cmd_valid <= 1'b0;
            crop_start <= 1'b0;
            writer_cmd_valid <= 1'b0;
            fetch_done_seen <= 1'b0;
            crop_done_seen <= 1'b0;
            writer_done_seen <= 1'b0;
            tile_x_q <= {COORD_W{1'b0}};
            tile_y_q <= {COORD_W{1'b0}};
            valid_w_q <= {COORD_W{1'b0}};
            valid_h_q <= {COORD_W{1'b0}};
            tile_last_q <= 1'b0;
            tile_input_addr_q <= {ADDR_W{1'b0}};
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            tiles_done <= 32'd0;
            frame_cycles <= 64'd0;
        end else begin
            sched_start <= 1'b0;
            crop_start <= 1'b0;
            done <= 1'b0;

            if (state != ST_IDLE && state != ST_DONE)
                frame_cycles <= frame_cycles + 64'd1;

            if (fetch_cmd_valid && fetch_cmd_ready)
                fetch_cmd_valid <= 1'b0;
            if (writer_cmd_valid && writer_cmd_ready)
                writer_cmd_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        error <= 1'b0;
                        tiles_done <= 32'd0;
                        frame_cycles <= 64'd0;
                        fetch_done_seen <= 1'b0;
                        crop_done_seen <= 1'b0;
                        writer_done_seen <= 1'b0;
                        sched_start <= 1'b1;
                        state <= ST_WAIT_TILE;
                    end
                end

                ST_WAIT_TILE: begin
                    busy <= 1'b1;
                    if (sched_error) begin
                        error <= 1'b1;
                        state <= ST_DONE;
                    end else if (sched_tile_valid && sched_tile_ready) begin
                        tile_x_q <= sched_tile_x;
                        tile_y_q <= sched_tile_y;
                        valid_w_q <= sched_valid_w;
                        valid_h_q <= sched_valid_h;
                        tile_last_q <= sched_tile_last;
                        tile_input_addr_q <= sched_tile_input_addr;
                        state <= ST_START_TILE;
                    end
                end

                ST_START_TILE: begin
                    busy <= 1'b1;
                    fetch_cmd_valid <= 1'b1;
                    writer_cmd_valid <= 1'b1;
                    crop_start <= 1'b1;
                    fetch_done_seen <= 1'b0;
                    crop_done_seen <= 1'b0;
                    writer_done_seen <= 1'b0;
                    state <= ST_RUN_TILE;
                end

                ST_RUN_TILE: begin
                    busy <= 1'b1;
                    if (fetch_done)
                        fetch_done_seen <= 1'b1;
                    if (crop_done)
                        crop_done_seen <= 1'b1;
                    if (writer_done)
                        writer_done_seen <= 1'b1;

                    if (fetch_error || crop_error || writer_error) begin
                        error <= 1'b1;
                        state <= ST_DONE;
                    end else if ((fetch_done_seen || fetch_done) &&
                                 (crop_done_seen || crop_done) &&
                                 (writer_done_seen || writer_done)) begin
                        tiles_done <= tiles_done + 32'd1;
                        if (tile_last_q)
                            state <= ST_DONE;
                        else
                            state <= ST_WAIT_TILE;
                    end
                end

                ST_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    wire unused_sched_busy = sched_busy;
    wire unused_sched_done = sched_done;
    wire unused_tile_index = |sched_tile_index;
    wire unused_tile_output_addr = |sched_tile_output_addr;
    wire unused_blocks_busy = fetch_busy ^ crop_busy ^ writer_busy;
    wire unused_fetch_pixel_valid = fetch_m_pixel_valid;
endmodule
