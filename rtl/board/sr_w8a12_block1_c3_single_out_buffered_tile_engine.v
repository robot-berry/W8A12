`timescale 1ns/1ps

// Buffered half-pipeline for W8A12 block_1.c3_r.
//
// Flow:
//   feature tile load -> feature buffer replay -> 3x3 feature window ->
//   single-output-channel c3 tile engine -> 48-channel feature stream.
module sr_w8a12_block1_c3_single_out_buffered_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer WINDOW_W = CH * 9 * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1),
    parameter integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W)
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

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [FEAT_W-1:0]     m_feat,
    output wire                         m_user,
    output wire                         m_last,

    output reg  [PIX_W-1:0]             load_count,
    output wire [PIX_W-1:0]             c3_input_count,
    output wire [PIX_W-1:0]             c3_output_count,
    output wire [31:0]                  lane_output_count
);
    localparam [2:0] ST_IDLE         = 3'd0;
    localparam [2:0] ST_LOAD         = 3'd1;
    localparam [2:0] ST_START_REPLAY = 3'd2;
    localparam [2:0] ST_RUN          = 3'd3;
    localparam [2:0] ST_DONE         = 3'd4;

    reg [2:0] state;
    reg load_start_q;
    reg stream_start_q;
    reg c3_start_q;
    reg stream_done_seen;
    reg [X_W-1:0] load_x;

    wire load_busy;
    wire load_done;
    wire load_error;
    wire replay_busy;
    wire replay_done;
    wire replay_valid;
    wire replay_ready;
    wire [FEAT_W-1:0] replay_feat;
    wire replay_user;
    wire replay_last;

    wire window_rst = rst || (state != ST_RUN);
    wire window_valid;
    wire window_ready;
    wire signed [WINDOW_W-1:0] window_data;
    wire [8:0] window_valid_mask;
    wire window_user;
    wire window_last;

    wire c3_ready;
    wire c3_busy;
    wire c3_done;
    wire c3_error;
    wire load_take = s_valid && s_ready;
    wire load_end_row = (load_x == TILE_W - 1);
    wire load_last_pixel = (load_count == PIXELS - 1);

    assign ready = (state == ST_IDLE);
    assign busy = (state != ST_IDLE);

    sr_feature_tile_buffer_streamer #(
        .DATA_W(FEAT_W),
        .TILE_W(TILE_W),
        .TILE_H(TILE_H)
    ) u_buffer (
        .clk(clk),
        .rst(rst),
        .load_start(load_start_q),
        .load_busy(load_busy),
        .load_done(load_done),
        .load_error(load_error),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_feat(s_feat),
        .s_user(s_user),
        .s_last(s_last),
        .stream_start(stream_start_q),
        .stream_busy(replay_busy),
        .stream_done(replay_done),
        .m_valid(replay_valid),
        .m_ready(replay_ready),
        .m_feat(replay_feat),
        .m_user(replay_user),
        .m_last(replay_last)
    );

    span_w8a12_feature_line_window3x3 #(
        .ACT_W(ACT_W),
        .CH(CH),
        .IMG_W(TILE_W),
        .IMG_H(TILE_H)
    ) u_window (
        .clk(clk),
        .rst(window_rst),
        .s_valid(replay_valid && (state == ST_RUN)),
        .s_ready(replay_ready),
        .s_feat(replay_feat),
        .s_user(replay_user),
        .s_last(replay_last),
        .m_valid(window_valid),
        .m_ready(window_ready),
        .window_o(window_data),
        .window_valid_mask_o(window_valid_mask),
        .m_user(window_user),
        .m_last(window_last)
    );

    sr_w8a12_block1_c3_single_out_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH)
    ) u_c3 (
        .clk(clk),
        .rst(rst),
        .start(c3_start_q),
        .ready(c3_ready),
        .busy(c3_busy),
        .done(c3_done),
        .error(c3_error),
        .s_valid(window_valid),
        .s_ready(window_ready),
        .s_window(window_data),
        .s_user(window_user),
        .s_last(window_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_feat(m_feat),
        .m_user(m_user),
        .m_last(m_last),
        .input_count(c3_input_count),
        .output_count(c3_output_count),
        .lane_output_count(lane_output_count)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            load_start_q <= 1'b0;
            stream_start_q <= 1'b0;
            c3_start_q <= 1'b0;
            stream_done_seen <= 1'b0;
            load_x <= {X_W{1'b0}};
            load_count <= {PIX_W{1'b0}};
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            load_start_q <= 1'b0;
            stream_start_q <= 1'b0;
            c3_start_q <= 1'b0;
            done <= 1'b0;

            if (load_take) begin
                if (load_count == {PIX_W{1'b0}} && !s_user)
                    error <= 1'b1;
                if (s_last != load_end_row)
                    error <= 1'b1;
                if (!load_last_pixel) begin
                    load_count <= load_count + 1'b1;
                    if (load_end_row)
                        load_x <= {X_W{1'b0}};
                    else
                        load_x <= load_x + 1'b1;
                end
            end

            if (replay_done)
                stream_done_seen <= 1'b1;
            if (load_error || c3_error)
                error <= 1'b1;

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        error <= 1'b0;
                        stream_done_seen <= 1'b0;
                        load_count <= {PIX_W{1'b0}};
                        load_x <= {X_W{1'b0}};
                        load_start_q <= 1'b1;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    if (load_done)
                        state <= ST_START_REPLAY;
                end

                ST_START_REPLAY: begin
                    stream_start_q <= 1'b1;
                    c3_start_q <= 1'b1;
                    state <= ST_RUN;
                end

                ST_RUN: begin
                    if (c3_done) begin
                        if (!stream_done_seen && !replay_done)
                            error <= 1'b1;
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    error <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase

            if (start && state != ST_IDLE)
                error <= 1'b1;
        end
    end

    wire unused_replay_busy = replay_busy;
    wire unused_c3_ready = c3_ready;
    wire unused_c3_busy = c3_busy;
    wire unused_window_mask = |window_valid_mask;
endmodule
