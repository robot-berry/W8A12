`timescale 1ns/1ps

// Tile-local W8A12 block_1.c3_r compute engine using one runtime-selected
// output-channel lane. It consumes one 3x3x48 feature window per tile pixel,
// invokes the single-output-channel kernel for out_ch=0..47, then packs the
// 48 raw c3 outputs into one 576-bit feature vector.
module sr_w8a12_block1_c3_single_out_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer WINDOW_W = CH * 9 * ACT_W,
    parameter integer OUT_CH_W = (CH <= 2) ? 1 : $clog2(CH),
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
    output reg  [31:0]                  lane_output_count
);
    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WAIT_INPUT = 3'd1;
    localparam [2:0] ST_START_LANE = 3'd2;
    localparam [2:0] ST_WAIT_LANE  = 3'd3;
    localparam [2:0] ST_EMIT       = 3'd4;

    reg [2:0] state;
    reg signed [WINDOW_W-1:0] window_q;
    reg signed [FEAT_W-1:0] feat_q;
    reg [OUT_CH_W-1:0] out_ch_q;
    reg side_user_q;
    reg side_last_q;
    reg [X_W-1:0] input_x;
    reg [X_W-1:0] output_x;

    wire lane_s_valid = (state == ST_START_LANE);
    wire lane_s_ready;
    wire lane_m_valid;
    wire signed [ACT_W-1:0] lane_feat;

    wire input_take = s_valid && s_ready;
    wire output_take = m_valid && m_ready;
    wire input_last_pixel = (input_count == PIXELS - 1);
    wire output_last_pixel = (output_count == PIXELS - 1);
    wire input_end_row = (input_x == TILE_W - 1);
    wire output_end_row = (output_x == TILE_W - 1);
    wire last_out_channel = (out_ch_q == CH - 1);

    assign ready = (state == ST_IDLE);
    assign busy = (state != ST_IDLE);
    assign s_ready = (state == ST_WAIT_INPUT) && !m_valid;

    (* keep_hierarchy = "yes", dont_touch = "yes" *)
    span_w8a12_block1_c3_single_out_kernel #(
        .ACT_W(ACT_W),
        .CH(CH),
        .ACC_W(ACC_W)
    ) u_lane (
        .clk(clk),
        .rst(rst),
        .s_valid(lane_s_valid),
        .s_ready(lane_s_ready),
        .out_ch_i(out_ch_q),
        .window_i(window_q),
        .m_valid(lane_m_valid),
        .m_ready(1'b1),
        .raw_o(),
        .act_o(lane_feat)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            window_q <= {WINDOW_W{1'b0}};
            feat_q <= {FEAT_W{1'b0}};
            out_ch_q <= {OUT_CH_W{1'b0}};
            side_user_q <= 1'b0;
            side_last_q <= 1'b0;
            input_x <= {X_W{1'b0}};
            output_x <= {X_W{1'b0}};
            done <= 1'b0;
            error <= 1'b0;
            m_valid <= 1'b0;
            m_feat <= {FEAT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
            input_count <= {PIX_W{1'b0}};
            output_count <= {PIX_W{1'b0}};
            lane_output_count <= 32'd0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    m_valid <= 1'b0;
                    m_user <= 1'b0;
                    m_last <= 1'b0;
                    if (start) begin
                        error <= 1'b0;
                        input_count <= {PIX_W{1'b0}};
                        output_count <= {PIX_W{1'b0}};
                        lane_output_count <= 32'd0;
                        input_x <= {X_W{1'b0}};
                        output_x <= {X_W{1'b0}};
                        state <= ST_WAIT_INPUT;
                    end
                end

                ST_WAIT_INPUT: begin
                    if (input_take) begin
                        if (input_count == {PIX_W{1'b0}} && !s_user)
                            error <= 1'b1;
                        if (s_last != input_end_row)
                            error <= 1'b1;

                        window_q <= s_window;
                        feat_q <= {FEAT_W{1'b0}};
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
                        lane_output_count <= lane_output_count + 1'b1;
                        if (last_out_channel) begin
                            m_feat <= {lane_feat, feat_q[FEAT_W-1:ACT_W]};
                            m_user <= side_user_q;
                            m_last <= side_last_q;
                            m_valid <= 1'b1;
                            state <= ST_EMIT;
                        end else begin
                            feat_q <= {lane_feat, feat_q[FEAT_W-1:ACT_W]};
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

                        if (output_count == {PIX_W{1'b0}} && !m_user)
                            error <= 1'b1;
                        if (m_last != output_end_row)
                            error <= 1'b1;

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
                    state <= ST_IDLE;
                end
            endcase

            if (start && state != ST_IDLE)
                error <= 1'b1;
        end
    end
endmodule
