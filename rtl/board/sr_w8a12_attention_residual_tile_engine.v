`timescale 1ns/1ps

// Generic tile-local attention/residual postprocess with one serialized
// channel datapath.
module sr_w8a12_attention_residual_tile_engine #(
    parameter integer TILE_W = 2,
    parameter integer TILE_H = 2,
    parameter integer ACT_W = 12,
    parameter integer CH = 48,
    parameter integer FEAT_W = CH * ACT_W,
    parameter integer CH_W = (CH <= 2) ? 1 : $clog2(CH),
    parameter integer PIXELS = TILE_W * TILE_H,
    parameter integer PIX_W = (PIXELS <= 2) ? 1 : $clog2(PIXELS + 1),
    parameter integer X_W = (TILE_W <= 2) ? 1 : $clog2(TILE_W),
    parameter SIM_ATT_LUT_FILE = "",
    parameter integer ATT_SHIFT = 31,
    parameter signed [31:0] ATT_OUT3_REQUANT_Q31 = 32'sd0,
    parameter signed [31:0] ATT_RESIDUAL_REQUANT_Q31 = 32'sd0
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         start,
    output wire                         ready,
    output wire                         busy,
    output reg                          done,
    output reg                          error,

    input  wire                         s_c3_valid,
    output wire                         s_c3_ready,
    input  wire signed [FEAT_W-1:0]     s_c3_feat,
    input  wire                         s_c3_user,
    input  wire                         s_c3_last,

    input  wire                         s_res_valid,
    output wire                         s_res_ready,
    input  wire signed [FEAT_W-1:0]     s_res_feat,
    input  wire                         s_res_user,
    input  wire                         s_res_last,

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
    localparam [2:0] ST_RUN_CH     = 3'd2;
    localparam [2:0] ST_EMIT       = 3'd3;

    reg [2:0] state;
    reg signed [FEAT_W-1:0] c3_q;
    reg signed [FEAT_W-1:0] residual_q;
    reg signed [FEAT_W-1:0] feat_q;
    reg [CH_W-1:0] out_ch_q;
    reg side_user_q;
    reg side_last_q;
    reg [X_W-1:0] input_x;
    reg [X_W-1:0] output_x;

    reg signed [ACT_W-1:0] c3_ch;
    reg signed [ACT_W-1:0] residual_ch;
    integer sel_i;

    wire input_pair_ready = (state == ST_WAIT_INPUT) && !m_valid;
    wire input_take = s_c3_valid && s_c3_ready && s_res_valid && s_res_ready;
    wire output_take = m_valid && m_ready;
    wire input_last_pixel = (input_count == PIXELS - 1);
    wire output_last_pixel = (output_count == PIXELS - 1);
    wire input_end_row = (input_x == TILE_W - 1);
    wire output_end_row = (output_x == TILE_W - 1);
    wire last_channel = (out_ch_q == CH - 1);

    wire signed [ACT_W-1:0] sim_att_ch;
    wire signed [ACT_W-1:0] att_ch;

    assign ready = (state == ST_IDLE);
    assign busy = (state != ST_IDLE);
    assign s_c3_ready = input_pair_ready && s_res_valid;
    assign s_res_ready = input_pair_ready && s_c3_valid;

    always @(*) begin
        c3_ch = c3_q[0 +: ACT_W];
        residual_ch = residual_q[0 +: ACT_W];
        for (sel_i = 0; sel_i < CH; sel_i = sel_i + 1) begin
            if (out_ch_q == sel_i) begin
                c3_ch = c3_q[sel_i*ACT_W +: ACT_W];
                residual_ch = residual_q[sel_i*ACT_W +: ACT_W];
            end
        end
    end

    (* keep_hierarchy = "yes", dont_touch = "yes" *)
    span_w8a12_unary_lut #(
        .ACT_W(ACT_W),
        .LUT_FILE(SIM_ATT_LUT_FILE)
    ) u_sim_att_lut (
        .x_i(c3_ch),
        .y_o(sim_att_ch)
    );

    (* keep_hierarchy = "yes", dont_touch = "yes" *)
    span_w8a12_attention #(
        .ACT_W(ACT_W),
        .SHIFT(ATT_SHIFT),
        .OUT3_REQUANT_Q31(ATT_OUT3_REQUANT_Q31),
        .RESIDUAL_REQUANT_Q31(ATT_RESIDUAL_REQUANT_Q31)
    ) u_attention (
        .out3_i(c3_ch),
        .residual_i(residual_ch),
        .sim_att_i(sim_att_ch),
        .q_o(att_ch)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            c3_q <= {FEAT_W{1'b0}};
            residual_q <= {FEAT_W{1'b0}};
            feat_q <= {FEAT_W{1'b0}};
            out_ch_q <= {CH_W{1'b0}};
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
                        if (input_count == {PIX_W{1'b0}} && (!s_c3_user || !s_res_user))
                            error <= 1'b1;
                        if (s_c3_user != s_res_user)
                            error <= 1'b1;
                        if (s_c3_last != s_res_last)
                            error <= 1'b1;
                        if (s_c3_last != input_end_row)
                            error <= 1'b1;

                        c3_q <= s_c3_feat;
                        residual_q <= s_res_feat;
                        feat_q <= {FEAT_W{1'b0}};
                        out_ch_q <= {CH_W{1'b0}};
                        side_user_q <= s_c3_user;
                        side_last_q <= s_c3_last;

                        if (!input_last_pixel) begin
                            input_count <= input_count + 1'b1;
                            if (input_end_row)
                                input_x <= {X_W{1'b0}};
                            else
                                input_x <= input_x + 1'b1;
                        end
                        state <= ST_RUN_CH;
                    end
                end

                ST_RUN_CH: begin
                    lane_output_count <= lane_output_count + 1'b1;
                    if (last_channel) begin
                        m_feat <= {att_ch, feat_q[FEAT_W-1:ACT_W]};
                        m_user <= side_user_q;
                        m_last <= side_last_q;
                        m_valid <= 1'b1;
                        state <= ST_EMIT;
                    end else begin
                        feat_q <= {att_ch, feat_q[FEAT_W-1:ACT_W]};
                        out_ch_q <= out_ch_q + 1'b1;
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
