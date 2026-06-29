`timescale 1ns/1ps

// Halo tile fetch -> W8A12 conv1 valid feature crop -> feature tile buffer.
//
// This shell turns the current conv1 feature boundary into a schedulable
// feature-tile source. A later SPAB/block scheduler can consume the replayed
// feature stream without refetching the RGB halo tile.
module sr_tile_halo_fetch_w8a12_conv1_buffer_shell #(
    parameter integer DATA_W = 24,
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer HALO = 1,
    parameter integer COORD_W = 16,
    parameter integer ADDR_W = 32,
    parameter integer BYTES_PER_PIXEL = 3,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer FEAT_W = OUT_CH * ACT_W
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       cmd_valid,
    output wire                       cmd_ready,
    input  wire [COORD_W-1:0]         cmd_image_w,
    input  wire [COORD_W-1:0]         cmd_image_h,
    input  wire [COORD_W-1:0]         cmd_tile_x,
    input  wire [COORD_W-1:0]         cmd_tile_y,
    input  wire [ADDR_W-1:0]          cmd_input_base,

    output wire                       rd_req_valid,
    input  wire                       rd_req_ready,
    output wire [ADDR_W-1:0]          rd_req_addr,
    input  wire                       rd_resp_valid,
    input  wire [DATA_W-1:0]          rd_resp_data,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire [FEAT_W-1:0]          m_feat,
    output wire                       m_user,
    output wire                       m_last,

    output wire                       busy,
    output wire                       done,
    output wire                       fetch_busy,
    output wire                       fetch_done,
    output wire                       fetch_error,
    output wire                       buffer_load_busy,
    output wire                       buffer_load_done,
    output wire                       buffer_load_error,
    output wire                       buffer_stream_busy,
    output wire                       buffer_stream_done
);
    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_LOAD = 2'd1;
    localparam [1:0] ST_STREAM_START = 2'd2;
    localparam [1:0] ST_STREAM = 2'd3;

    reg [1:0] state;
    reg inner_cmd_valid;
    reg buffer_load_start;
    reg buffer_stream_start;
    reg done_r;

    wire inner_cmd_ready;
    wire conv_valid;
    wire conv_ready;
    wire [FEAT_W-1:0] conv_feat;
    wire conv_user;
    wire conv_last;
    wire inner_cmd_take = inner_cmd_valid && inner_cmd_ready;

    assign cmd_ready = (state == ST_IDLE) && !inner_cmd_valid;
    assign busy = (state != ST_IDLE) || inner_cmd_valid;
    assign done = done_r;

    sr_tile_halo_fetch_w8a12_conv1_shell #(
        .DATA_W(DATA_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .HALO(HALO),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(OUT_CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_conv1_tile (
        .clk(clk),
        .rst(rst),
        .cmd_valid(inner_cmd_valid),
        .cmd_ready(inner_cmd_ready),
        .cmd_image_w(cmd_image_w),
        .cmd_image_h(cmd_image_h),
        .cmd_tile_x(cmd_tile_x),
        .cmd_tile_y(cmd_tile_y),
        .cmd_input_base(cmd_input_base),
        .rd_req_valid(rd_req_valid),
        .rd_req_ready(rd_req_ready),
        .rd_req_addr(rd_req_addr),
        .rd_resp_valid(rd_resp_valid),
        .rd_resp_data(rd_resp_data),
        .m_valid(conv_valid),
        .m_ready(conv_ready),
        .m_feat(conv_feat),
        .m_user(conv_user),
        .m_last(conv_last),
        .fetch_busy(fetch_busy),
        .fetch_done(fetch_done),
        .fetch_error(fetch_error)
    );

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H)
    ) u_feature_buffer (
        .clk(clk),
        .rst(rst),
        .load_start(buffer_load_start),
        .load_busy(buffer_load_busy),
        .load_done(buffer_load_done),
        .load_error(buffer_load_error),
        .s_valid(conv_valid),
        .s_ready(conv_ready),
        .s_feat(conv_feat),
        .s_user(conv_user),
        .s_last(conv_last),
        .stream_start(buffer_stream_start),
        .stream_busy(buffer_stream_busy),
        .stream_done(buffer_stream_done),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            inner_cmd_valid <= 1'b0;
            buffer_load_start <= 1'b0;
            buffer_stream_start <= 1'b0;
            done_r <= 1'b0;
        end else begin
            buffer_load_start <= 1'b0;
            buffer_stream_start <= 1'b0;
            done_r <= 1'b0;

            if (inner_cmd_take)
                inner_cmd_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (cmd_valid && cmd_ready) begin
                        inner_cmd_valid <= 1'b1;
                        buffer_load_start <= 1'b1;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    if (buffer_load_done)
                        state <= ST_STREAM_START;
                end

                ST_STREAM_START: begin
                    buffer_stream_start <= 1'b1;
                    state <= ST_STREAM;
                end

                ST_STREAM: begin
                    if (buffer_stream_done) begin
                        done_r <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
