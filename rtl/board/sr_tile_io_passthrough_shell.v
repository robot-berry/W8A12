`timescale 1ns/1ps

// Hardware-side tile IO loop for large-image tiling, with passthrough compute.
//
// This shell wires:
//   scheduler -> halo fetch -> interior crop -> output writer
// and exposes external read/write request streams. It intentionally does not
// instantiate W8A12 compute yet; the cropper is fed directly from the fetched
// RGB halo patch so the complete tile IO address/control chain can be verified
// before inserting the time-multiplexed compute engine.
//
// Current integration gate supports full tiles only. Edge tiles with valid_w/h
// smaller than TILE_W/H are rejected so the stream counts stay exact; dynamic
// edge crop/write sizing is the next control refinement.
module sr_tile_io_passthrough_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 4,
    parameter integer TILE_H = 4,
    parameter integer HALO = 1,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer SCALE = 1,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer COMPUTE_W = TILE_W + 2 * HALO,
    parameter integer COMPUTE_H = TILE_H + 2 * HALO
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
    output reg  [31:0]           tiles_done
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WAIT_TILE  = 3'd1;
    localparam [2:0] ST_START_TILE = 3'd2;
    localparam [2:0] ST_RUN_TILE   = 3'd3;
    localparam [2:0] ST_DONE       = 3'd4;

    localparam [COORD_W-1:0] TILE_W_C = TILE_W[COORD_W-1:0];
    localparam [COORD_W-1:0] TILE_H_C = TILE_H[COORD_W-1:0];

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

    reg halo_cmd_valid;
    wire halo_cmd_ready;
    wire halo_m_valid;
    wire halo_m_ready;
    wire [DATA_W-1:0] halo_m_data;
    wire halo_m_pixel_valid;
    wire halo_m_user;
    wire halo_m_last;
    wire halo_busy;
    wire halo_done;
    wire halo_error;

    wire crop_m_valid;
    wire crop_m_ready;
    wire [DATA_W-1:0] crop_m_data;
    wire crop_m_user;
    wire crop_m_last;

    reg writer_cmd_valid;
    wire writer_cmd_ready;
    wire writer_busy;
    wire writer_done;
    wire writer_error;
    reg halo_done_seen;
    reg writer_done_seen;

    wire tile_is_full = (sched_valid_w == TILE_W_C) && (sched_valid_h == TILE_H_C);

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

    sr_tile_halo_fetch_stream_shell #(
        .DATA_W(DATA_W),
        .OUT_TILE_W(TILE_W),
        .OUT_TILE_H(TILE_H),
        .HALO(HALO),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) u_halo_fetch (
        .clk(clk),
        .rst(rst),
        .cmd_valid(halo_cmd_valid),
        .cmd_ready(halo_cmd_ready),
        .cmd_image_w(image_w),
        .cmd_image_h(image_h),
        .cmd_tile_x(tile_x_q),
        .cmd_tile_y(tile_y_q),
        .cmd_input_base(input_base),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .m_valid(halo_m_valid),
        .m_ready(halo_m_ready),
        .m_data(halo_m_data),
        .m_pixel_valid(halo_m_pixel_valid),
        .m_user(halo_m_user),
        .m_last(halo_m_last),
        .busy(halo_busy),
        .done(halo_done),
        .error(halo_error)
    );

    sr_stream_cropper #(
        .DATA_W(DATA_W),
        .IN_W(COMPUTE_W),
        .IN_H(COMPUTE_H),
        .CROP_X(HALO),
        .CROP_Y(HALO),
        .CROP_W(TILE_W),
        .CROP_H(TILE_H)
    ) u_cropper (
        .clk(clk),
        .rst(rst),
        .s_valid(halo_m_valid),
        .s_ready(halo_m_ready),
        .s_data(halo_m_data),
        .s_user(halo_m_user),
        .s_last(halo_m_last),
        .m_valid(crop_m_valid),
        .m_ready(crop_m_ready),
        .m_data(crop_m_data),
        .m_user(crop_m_user),
        .m_last(crop_m_last)
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
            halo_cmd_valid <= 1'b0;
            writer_cmd_valid <= 1'b0;
            halo_done_seen <= 1'b0;
            writer_done_seen <= 1'b0;
            tile_x_q <= {COORD_W{1'b0}};
            tile_y_q <= {COORD_W{1'b0}};
            valid_w_q <= {COORD_W{1'b0}};
            valid_h_q <= {COORD_W{1'b0}};
            tile_last_q <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            tiles_done <= 32'd0;
        end else begin
            sched_start <= 1'b0;
            done <= 1'b0;

            if (halo_cmd_valid && halo_cmd_ready)
                halo_cmd_valid <= 1'b0;
            if (writer_cmd_valid && writer_cmd_ready)
                writer_cmd_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        error <= 1'b0;
                        tiles_done <= 32'd0;
                        halo_done_seen <= 1'b0;
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
                        if (!tile_is_full) begin
                            error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_START_TILE;
                        end
                    end
                end

                ST_START_TILE: begin
                    busy <= 1'b1;
                    halo_cmd_valid <= 1'b1;
                    writer_cmd_valid <= 1'b1;
                    halo_done_seen <= 1'b0;
                    writer_done_seen <= 1'b0;
                    state <= ST_RUN_TILE;
                end

                ST_RUN_TILE: begin
                    busy <= 1'b1;
                    if (halo_done)
                        halo_done_seen <= 1'b1;
                    if (writer_done)
                        writer_done_seen <= 1'b1;
                    if (halo_error || writer_error) begin
                        error <= 1'b1;
                        state <= ST_DONE;
                    end else if ((halo_done_seen || halo_done) && (writer_done_seen || writer_done)) begin
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
    wire unused_tile_addr = |sched_tile_input_addr ^ |sched_tile_output_addr;
    wire unused_blocks_busy = halo_busy ^ writer_busy;
    wire unused_halo_pixel_valid = halo_m_pixel_valid;
endmodule
