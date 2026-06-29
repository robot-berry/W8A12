`timescale 1ns/1ps

// Generic tile-local W8A12 one-output-channel engine with runtime block select.
module sr_w8a12_block_group_single_out_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer WINDOW_W = CH * 9 * ACT_W,
    parameter integer OUT_CH_W = (CH <= 2) ? 1 : $clog2(CH),
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
    input  wire signed [WINDOW_W-1:0]   s_window,
    input  wire                         s_user,
    input  wire                         s_last,

    output reg                          m_valid,
    input  wire                         m_ready,
    output reg  signed [FEAT_W-1:0]     m_feat,
    output reg                          m_user,
    output reg                          m_last,

    output reg  [PIX_W-1:0]             input_count,
    output reg  [PIX_W-1:0]             output_count,
    output reg  [31:0]                  lane_output_count,
    output wire [31:0]                  debug_state,
    output wire [31:0]                  debug_lane_state,
    output wire [31:0]                  debug_io_state,
    output reg  [31:0]                  debug_hash_raw,
    output reg  [31:0]                  debug_sample0,
    output reg  [31:0]                  debug_sample1,
    output reg  [31:0]                  debug_sample2,
    output reg  [31:0]                  debug_sample3
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WAIT_INPUT = 3'd1;
    localparam [2:0] ST_START_LANE = 3'd2;
    localparam [2:0] ST_WAIT_LANE  = 3'd3;
    localparam [2:0] ST_EMIT       = 3'd4;

    reg [2:0] state;
    reg [BLOCK_W-1:0] block_q;
    reg signed [WINDOW_W-1:0] window_q;
    reg signed [FEAT_W-1:0] feat_q;
    reg signed [FEAT_W-1:0] raw_feat_q;
    reg [OUT_CH_W-1:0] out_ch_q;
    reg side_user_q;
    reg side_last_q;
    reg [X_W-1:0] input_x;
    reg [X_W-1:0] output_x;
    reg err_input_user_q;
    reg err_input_last_q;
    reg err_output_user_q;
    reg err_output_last_q;
    reg err_start_reentry_q;
    reg err_default_state_q;

    wire lane_s_valid = (state == ST_START_LANE);
    wire lane_s_ready;
    wire lane_m_valid;
    wire lane_m_ready;
    wire signed [ACT_W-1:0] lane_raw;
    wire signed [ACT_W-1:0] lane_act;
    wire [31:0] lane_debug_state;
    wire [5:0] out_ch_dbg;

    wire input_take = s_valid && s_ready;
    wire output_take = m_valid && m_ready;
    wire input_last_pixel = (input_count == PIXELS - 1);
    wire output_last_pixel = (output_count == PIXELS - 1);
    wire input_end_row = (input_x == TILE_W - 1);
    wire output_end_row = (output_x == TILE_W - 1);
    wire last_out_channel = (out_ch_q == CH - 1);
    // Keep the lane kernel's original always-ready contract; debug sampling must not
    // add backpressure to the conv/activation datapath.
    assign lane_m_ready = 1'b1;

    wire [31:0] lane_sample_word = {
        lane_output_count[7:0],
        lane_raw[ACT_W-1:0],
        lane_act[ACT_W-1:0]
    };

    function automatic [4:0] trunc5_x(input [X_W-1:0] value);
        integer bit_i;
        begin
            trunc5_x = 5'd0;
            for (bit_i = 0; bit_i < 5; bit_i = bit_i + 1)
                if (bit_i < X_W)
                    trunc5_x[bit_i] = value[bit_i];
        end
    endfunction

    function automatic [8:0] trunc9_pix(input [PIX_W-1:0] value);
        integer bit_i;
        begin
            trunc9_pix = 9'd0;
            for (bit_i = 0; bit_i < 9; bit_i = bit_i + 1)
                if (bit_i < PIX_W)
                    trunc9_pix[bit_i] = value[bit_i];
        end
    endfunction

    function automatic [5:0] trunc6_pix(input [PIX_W-1:0] value);
        integer bit_i;
        begin
            trunc6_pix = 6'd0;
            for (bit_i = 0; bit_i < 6; bit_i = bit_i + 1)
                if (bit_i < PIX_W)
                    trunc6_pix[bit_i] = value[bit_i];
        end
    endfunction

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

    assign ready = (state == ST_IDLE);
    assign busy = (state != ST_IDLE);
    assign s_ready = (state == ST_WAIT_INPUT) && !m_valid;
    assign debug_state = {
        state,
        out_ch_dbg,
        lane_s_ready,
        lane_m_valid,
        s_valid,
        s_ready,
        m_valid,
        m_ready,
        output_take,
        lane_debug_state[15:0]
    };
    assign debug_lane_state = lane_debug_state;
    assign debug_io_state = {
        state,
        error,
        err_default_state_q,
        err_start_reentry_q,
        err_output_last_q,
        err_output_user_q,
        err_input_last_q,
        err_input_user_q,
        trunc5_x(input_x),
        trunc5_x(output_x),
        side_user_q,
        side_last_q,
        m_user,
        m_last,
        input_take,
        output_take,
        trunc6_pix(output_count)
    };

    generate
        if (OUT_CH_W >= 6) begin : gen_out_ch_dbg_wide
            assign out_ch_dbg = out_ch_q[5:0];
        end else begin : gen_out_ch_dbg_narrow
            assign out_ch_dbg = {{(6-OUT_CH_W){1'b0}}, out_ch_q};
        end
    endgenerate

    generate
        if ((DEBUG_HASHES != 0) || (DEBUG_SAMPLES != 0)) begin : gen_lane_with_raw_debug
            (* keep_hierarchy = "yes", dont_touch = "yes" *)
            span_w8a12_block_group_single_out_conv_act_kernel #(
                .BLOCKS(BLOCKS),
                .BLOCK_W(BLOCK_W),
                .ACT_W(ACT_W),
                .CH(CH),
                .ACC_W(ACC_W),
                .WEIGHT_FILE(WEIGHT_FILE),
                .BIAS_I64_FILE(BIAS_I64_FILE),
                .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
                .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE),
                .APPLY_ACT(APPLY_ACT),
                .ACT_LUT_FILE(ACT_LUT_FILE)
            ) u_lane (
                .clk(clk),
                .rst(rst),
                .s_valid(lane_s_valid),
                .s_ready(lane_s_ready),
                .block_i(block_q),
                .out_ch_i(out_ch_q),
                .window_i(window_q),
                .m_valid(lane_m_valid),
                .m_ready(lane_m_ready),
                .raw_o(lane_raw),
                .act_o(lane_act),
                .debug_state(lane_debug_state)
            );
        end else begin : gen_lane_no_raw_debug
            assign lane_raw = {ACT_W{1'b0}};
            (* keep_hierarchy = "yes", dont_touch = "yes" *)
            span_w8a12_block_group_single_out_conv_act_kernel #(
                .BLOCKS(BLOCKS),
                .BLOCK_W(BLOCK_W),
                .ACT_W(ACT_W),
                .CH(CH),
                .ACC_W(ACC_W),
                .WEIGHT_FILE(WEIGHT_FILE),
                .BIAS_I64_FILE(BIAS_I64_FILE),
                .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
                .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE),
                .APPLY_ACT(APPLY_ACT),
                .ACT_LUT_FILE(ACT_LUT_FILE)
            ) u_lane (
                .clk(clk),
                .rst(rst),
                .s_valid(lane_s_valid),
                .s_ready(lane_s_ready),
                .block_i(block_q),
                .out_ch_i(out_ch_q),
                .window_i(window_q),
                .m_valid(lane_m_valid),
                .m_ready(lane_m_ready),
                .raw_o(),
                .act_o(lane_act),
                .debug_state(lane_debug_state)
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            block_q <= {BLOCK_W{1'b0}};
            window_q <= {WINDOW_W{1'b0}};
            feat_q <= {FEAT_W{1'b0}};
            raw_feat_q <= {FEAT_W{1'b0}};
            out_ch_q <= {OUT_CH_W{1'b0}};
            side_user_q <= 1'b0;
            side_last_q <= 1'b0;
            input_x <= {X_W{1'b0}};
            output_x <= {X_W{1'b0}};
            err_input_user_q <= 1'b0;
            err_input_last_q <= 1'b0;
            err_output_user_q <= 1'b0;
            err_output_last_q <= 1'b0;
            err_start_reentry_q <= 1'b0;
            err_default_state_q <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            m_valid <= 1'b0;
            m_feat <= {FEAT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
            input_count <= {PIX_W{1'b0}};
            output_count <= {PIX_W{1'b0}};
            lane_output_count <= 32'd0;
            debug_hash_raw <= 32'h811C_9DC5;
            debug_sample0 <= 32'd0;
            debug_sample1 <= 32'd0;
            debug_sample2 <= 32'd0;
            debug_sample3 <= 32'd0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    m_valid <= 1'b0;
                    m_user <= 1'b0;
                    m_last <= 1'b0;
                    if (start) begin
                        block_q <= block_i;
                        error <= 1'b0;
                        input_count <= {PIX_W{1'b0}};
                        output_count <= {PIX_W{1'b0}};
                        lane_output_count <= 32'd0;
                        err_input_user_q <= 1'b0;
                        err_input_last_q <= 1'b0;
                        err_output_user_q <= 1'b0;
                        err_output_last_q <= 1'b0;
                        err_start_reentry_q <= 1'b0;
                        err_default_state_q <= 1'b0;
                        debug_hash_raw <= 32'h811C_9DC5;
                        debug_sample0 <= 32'd0;
                        debug_sample1 <= 32'd0;
                        debug_sample2 <= 32'd0;
                        debug_sample3 <= 32'd0;
                        input_x <= {X_W{1'b0}};
                        output_x <= {X_W{1'b0}};
                        state <= ST_WAIT_INPUT;
                    end
                end

                ST_WAIT_INPUT: begin
                    if (input_take) begin
                        if (input_count == {PIX_W{1'b0}} && !s_user) begin
                            error <= 1'b1;
                            err_input_user_q <= 1'b1;
                        end
                        if (s_last != input_end_row) begin
                            error <= 1'b1;
                            err_input_last_q <= 1'b1;
                        end

                        window_q <= s_window;
                        feat_q <= {FEAT_W{1'b0}};
                        raw_feat_q <= {FEAT_W{1'b0}};
                        out_ch_q <= {OUT_CH_W{1'b0}};
                        side_user_q <= s_user;
                        side_last_q <= s_last;

                        if (!input_last_pixel) begin
                            input_count <= input_count + 1'b1;
                            if (input_end_row)
                                input_x <= {X_W{1'b0}};
                            else
                                input_x <= input_x + 1'b1;
                        end
                        state <= ST_START_LANE;
                    end
                end

                ST_START_LANE: begin
                    if (lane_s_ready)
                        state <= ST_WAIT_LANE;
                end

                ST_WAIT_LANE: begin
                    if (lane_m_valid) begin
                        if (DEBUG_SAMPLES != 0) begin
                            if (lane_output_count == 32'd0)
                                debug_sample0 <= lane_sample_word;
                            if (lane_output_count == 32'd1)
                                debug_sample1 <= lane_sample_word;
                            if (lane_output_count == 32'd2)
                                debug_sample2 <= lane_sample_word;
                            if (lane_output_count == 32'd3)
                                debug_sample3 <= lane_sample_word;
                        end
                        lane_output_count <= lane_output_count + 1'b1;
                        if (last_out_channel) begin
                            m_feat <= {lane_act, feat_q[FEAT_W-1:ACT_W]};
                            if (DEBUG_HASHES != 0)
                                debug_hash_raw <= rotl5(debug_hash_raw) ^
                                                  feature_signature({lane_raw, raw_feat_q[FEAT_W-1:ACT_W]});
                            m_user <= side_user_q;
                            m_last <= side_last_q;
                            m_valid <= 1'b1;
                            state <= ST_EMIT;
                        end else begin
                            feat_q <= {lane_act, feat_q[FEAT_W-1:ACT_W]};
                            if (DEBUG_HASHES != 0)
                                raw_feat_q <= {lane_raw, raw_feat_q[FEAT_W-1:ACT_W]};
                            out_ch_q <= out_ch_q + 1'b1;
                            state <= ST_START_LANE;
                        end
                    end
                end

                ST_EMIT: begin
                    if (output_take) begin
                        m_valid <= 1'b0;
                        m_user <= 1'b0;
                        m_last <= 1'b0;

                        if (output_count == {PIX_W{1'b0}} && !m_user) begin
                            error <= 1'b1;
                            err_output_user_q <= 1'b1;
                        end
                        if (m_last != output_end_row) begin
                            error <= 1'b1;
                            err_output_last_q <= 1'b1;
                        end

                        if (output_last_pixel) begin
                            done <= 1'b1;
                            state <= ST_IDLE;
                        end else begin
                            output_count <= output_count + 1'b1;
                            if (output_end_row)
                                output_x <= {X_W{1'b0}};
                            else
                                output_x <= output_x + 1'b1;
                            state <= ST_WAIT_INPUT;
                        end
                    end
                end

                default: begin
                    error <= 1'b1;
                    err_default_state_q <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase

            if (start && state != ST_IDLE) begin
                error <= 1'b1;
                err_start_reentry_q <= 1'b1;
            end
        end
    end
endmodule
