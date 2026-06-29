`timescale 1ns/1ps

// Generic buffered SPAB conv stage with runtime block-selected constants.
module sr_w8a12_block_group_single_out_buffered_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer WINDOW_W = CH * 9 * ACT_W,
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1),
    parameter integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W),
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = "",
    parameter integer APPLY_ACT = 1,
    parameter ACT_LUT_FILE = "",
    parameter integer DEBUG_HASHES = 0,
    parameter integer DEBUG_SAMPLES = DEBUG_HASHES
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    output wire                         ready,
    output wire                         busy,
    output reg                          done,
    output reg                          error,
    input  wire [BLOCK_W-1:0]           block_i,

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
    output wire [PIX_W-1:0]             core_input_count,
    output wire [PIX_W-1:0]             core_output_count,
    output wire [31:0]                  lane_output_count,
    output wire [31:0]                  debug_state,
    output wire [31:0]                  debug_core_state,
    output wire [31:0]                  debug_lane_state,
    output wire [31:0]                  debug_core_io_state,
    output reg  [31:0]                  debug_hash_replay,
    output reg  [31:0]                  debug_hash_window,
    output wire [31:0]                  debug_hash_raw,
    output wire [31:0]                  debug_sample0,
    output wire [31:0]                  debug_sample1,
    output wire [31:0]                  debug_sample2,
    output wire [31:0]                  debug_sample3
);
    localparam [2:0] ST_IDLE         = 3'd0;
    localparam [2:0] ST_LOAD         = 3'd1;
    localparam [2:0] ST_START_REPLAY = 3'd2;
    localparam [2:0] ST_RUN          = 3'd3;
    localparam [2:0] ST_DONE         = 3'd4;

    reg [2:0] state;
    reg [BLOCK_W-1:0] block_q;
    reg load_start_q;
    reg stream_start_q;
    reg core_start_q;
    reg window_reset_q;
    reg stream_done_seen;
    reg [X_W-1:0] load_x;
    reg load_user_error_seen;
    reg load_last_error_seen;
    reg load_error_seen;
    reg core_error_seen;
    reg stream_done_error_seen;
    reg start_reentry_error_seen;

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

    wire window_rst = rst || window_reset_q;
    wire window_valid;
    wire window_ready;
    wire signed [WINDOW_W-1:0] window_data;
    wire [8:0] window_valid_mask;
    wire [15:0] window_debug_state;
    wire window_user;
    wire window_last;

    wire core_ready;
    wire core_busy;
    wire core_done;
    wire core_error;
    wire [31:0] core_debug_state;
    wire [31:0] core_lane_debug_state;
    wire [31:0] core_io_debug_state;
    wire [31:0] core_debug_sample0;
    wire [31:0] core_debug_sample1;
    wire [31:0] core_debug_sample2;
    wire [31:0] core_debug_sample3;
    wire load_take = s_valid && s_ready;
    wire replay_take = replay_valid && replay_ready && (state == ST_RUN);
    wire window_take = window_valid && window_ready;
    wire load_end_row = (load_x == TILE_W - 1);
    wire load_last_pixel = (load_count == PIXELS - 1);

    function automatic [31:0] rotl5(input [31:0] value);
        begin
            rotl5 = {value[26:0], value[31:27]};
        end
    endfunction

    function automatic [31:0] feature_signature(input signed [FEAT_W-1:0] feat);
        integer sig_ch;
        reg signed [ACT_W-1:0] sample;
        reg [31:0] acc;
        begin
            acc = 32'h9E37_79B9;
            for (sig_ch = 0; sig_ch < CH; sig_ch = sig_ch + 1) begin
                sample = feat[sig_ch*ACT_W +: ACT_W];
                acc = rotl5(acc) ^
                      {{(32-ACT_W){sample[ACT_W-1]}}, sample} ^
                      (32'h7F4A_7C15 + sig_ch[31:0]);
            end
            feature_signature = acc;
        end
    endfunction

    function automatic [31:0] window_signature(input signed [WINDOW_W-1:0] window);
        integer sig_ch;
        integer sig_tap;
        reg signed [ACT_W-1:0] sample;
        reg [31:0] acc;
        begin
            acc = 32'hD1B5_4A32;
            for (sig_ch = 0; sig_ch < CH; sig_ch = sig_ch + 1) begin
                for (sig_tap = 0; sig_tap < 9; sig_tap = sig_tap + 1) begin
                    sample = window[(sig_ch*9 + sig_tap)*ACT_W +: ACT_W];
                    acc = rotl5(acc) ^
                          {{(32-ACT_W){sample[ACT_W-1]}}, sample} ^
                          (32'h9E37_79B9 + sig_ch[31:0] * 32'd9 + sig_tap[31:0]);
                end
            end
            window_signature = acc;
        end
    endfunction

    assign ready = (state == ST_IDLE);
    assign busy = (state != ST_IDLE);
    assign debug_state = {
        error,
        load_user_error_seen,
        load_last_error_seen,
        load_error_seen,
        core_error_seen,
        stream_done_error_seen,
        start_reentry_error_seen,
        state,
        load_busy,
        load_done,
        replay_busy,
        replay_done,
        replay_valid,
        replay_ready,
        window_valid,
        window_ready,
        core_ready,
        core_busy,
        core_done,
        core_error,
        window_debug_state[9:0]
    };
    assign debug_core_state = core_debug_state;
    assign debug_lane_state = core_lane_debug_state;
    assign debug_core_io_state = core_io_debug_state;
    assign debug_sample0 = {
        window_rst,
        window_reset_q,
        state,
        3'b000,
        window_debug_state,
        replay_valid,
        replay_ready,
        window_valid,
        window_ready,
        core_ready,
        core_busy,
        core_done,
        core_error
    };
    assign debug_sample1 = core_debug_sample0;
    assign debug_sample2 = core_debug_sample1;
    assign debug_sample3 = core_debug_sample2 ^ core_debug_sample3;

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
        .m_last(window_last),
        .debug_state(window_debug_state)
    );

    sr_w8a12_block_group_single_out_tile_engine #(
        .TILE_W(TILE_W),
        .TILE_H(TILE_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .BLOCKS(BLOCKS),
        .BLOCK_W(BLOCK_W),
        .WEIGHT_FILE(WEIGHT_FILE),
        .BIAS_I64_FILE(BIAS_I64_FILE),
        .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE),
        .APPLY_ACT(APPLY_ACT),
        .ACT_LUT_FILE(ACT_LUT_FILE),
        .DEBUG_HASHES(DEBUG_HASHES),
        .DEBUG_SAMPLES(DEBUG_SAMPLES)
    ) u_core (
        .clk(clk),
        .rst(rst),
        .start(core_start_q),
        .ready(core_ready),
        .busy(core_busy),
        .done(core_done),
        .error(core_error),
        .block_i(block_q),
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
        .input_count(core_input_count),
        .output_count(core_output_count),
        .lane_output_count(lane_output_count),
        .debug_state(core_debug_state),
        .debug_lane_state(core_lane_debug_state),
        .debug_io_state(core_io_debug_state),
        .debug_hash_raw(debug_hash_raw),
        .debug_sample0(core_debug_sample0),
        .debug_sample1(core_debug_sample1),
        .debug_sample2(core_debug_sample2),
        .debug_sample3(core_debug_sample3)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            block_q <= {BLOCK_W{1'b0}};
            load_start_q <= 1'b0;
            stream_start_q <= 1'b0;
            core_start_q <= 1'b0;
            window_reset_q <= 1'b1;
            stream_done_seen <= 1'b0;
            load_x <= {X_W{1'b0}};
            load_user_error_seen <= 1'b0;
            load_last_error_seen <= 1'b0;
            load_error_seen <= 1'b0;
            core_error_seen <= 1'b0;
            stream_done_error_seen <= 1'b0;
            start_reentry_error_seen <= 1'b0;
            load_count <= {PIX_W{1'b0}};
            done <= 1'b0;
            error <= 1'b0;
            debug_hash_replay <= 32'h811C_9DC5;
            debug_hash_window <= 32'h811C_9DC5;
        end else begin
            load_start_q <= 1'b0;
            stream_start_q <= 1'b0;
            core_start_q <= 1'b0;
            done <= 1'b0;

            if (load_take) begin
                if (load_count == {PIX_W{1'b0}} && !s_user) begin
                    error <= 1'b1;
                    load_user_error_seen <= 1'b1;
                end
                if (s_last != load_end_row) begin
                    error <= 1'b1;
                    load_last_error_seen <= 1'b1;
                end
                if (!load_last_pixel) begin
                    load_count <= load_count + 1'b1;
                    if (load_end_row)
                        load_x <= {X_W{1'b0}};
                    else
                        load_x <= load_x + 1'b1;
                end
            end

            if (DEBUG_HASHES != 0 && replay_take)
                debug_hash_replay <= rotl5(debug_hash_replay) ^
                                     feature_signature(replay_feat);
            if (DEBUG_HASHES != 0 && window_take)
                debug_hash_window <= rotl5(debug_hash_window) ^
                                     window_signature(window_data);

            if (replay_done)
                stream_done_seen <= 1'b1;
            if (load_error) begin
                error <= 1'b1;
                load_error_seen <= 1'b1;
            end
            if (core_error) begin
                error <= 1'b1;
                core_error_seen <= 1'b1;
            end

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        block_q <= block_i;
                        error <= 1'b0;
                        stream_done_seen <= 1'b0;
                        load_count <= {PIX_W{1'b0}};
                        load_x <= {X_W{1'b0}};
                        load_user_error_seen <= 1'b0;
                        load_last_error_seen <= 1'b0;
                        load_error_seen <= 1'b0;
                        core_error_seen <= 1'b0;
                        stream_done_error_seen <= 1'b0;
                        start_reentry_error_seen <= 1'b0;
                        debug_hash_replay <= 32'h811C_9DC5;
                        debug_hash_window <= 32'h811C_9DC5;
                        window_reset_q <= 1'b1;
                        load_start_q <= 1'b1;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    window_reset_q <= 1'b1;
                    if (load_done)
                        state <= ST_START_REPLAY;
                end

                ST_START_REPLAY: begin
                    window_reset_q <= 1'b0;
                    stream_start_q <= 1'b1;
                    core_start_q <= 1'b1;
                    state <= ST_RUN;
                end

                ST_RUN: begin
                    window_reset_q <= 1'b0;
                    if (core_done) begin
                        if (!stream_done_seen && !replay_done) begin
                            error <= 1'b1;
                            stream_done_error_seen <= 1'b1;
                        end
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    window_reset_q <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    error <= 1'b1;
                    window_reset_q <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase

            if (start && state != ST_IDLE) begin
                error <= 1'b1;
                start_reentry_error_seen <= 1'b1;
            end
        end
    end

    wire unused_replay_busy = replay_busy;
    wire unused_core_ready = core_ready;
    wire unused_core_busy = core_busy;
    wire unused_window_mask = |window_valid_mask;
endmodule
