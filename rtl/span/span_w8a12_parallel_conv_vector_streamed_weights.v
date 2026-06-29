`timescale 1ns/1ps

// Parallel vector convolution scheduler with external streamed weight groups.
//
// This module removes the large internal multi-read weight ROM from
// span_w8a12_parallel_conv_vector_layer. A future banked ROM/BRAM block should
// respond to weight_req_* with one OUT_LANES x TAP_LANES group.
module span_w8a12_parallel_conv_vector_streamed_weights #(
    parameter integer IN_CH = 3,
    parameter integer OUT_CH = 48,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = ""
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,

    output reg                                   weight_req_valid,
    input  wire                                  weight_req_ready,
    output wire [31:0]                           weight_req_out_group,
    output wire [31:0]                           weight_req_tap_group,
    input  wire signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] weight_group_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg signed [OUT_CH*ACT_W-1:0]         feat_o
);
    localparam integer TAP_COUNT = IN_CH * KERNEL_TAPS;
    localparam integer OUT_GROUP_COUNT = (OUT_CH + OUT_LANES - 1) / OUT_LANES;
    localparam integer TAP_GROUP_COUNT = (TAP_COUNT + TAP_LANES - 1) / TAP_LANES;
    localparam integer OUT_GROUP_W = (OUT_GROUP_COUNT <= 2) ? 1 : $clog2(OUT_GROUP_COUNT);
    localparam integer TAP_GROUP_W = (TAP_GROUP_COUNT <= 2) ? 1 : $clog2(TAP_GROUP_COUNT);
    localparam integer OUT_LANE_W = (OUT_LANES <= 2) ? 1 : $clog2(OUT_LANES);

    localparam [2:0] ST_IDLE          = 3'd0;
    localparam [2:0] ST_REQ           = 3'd1;
    localparam [2:0] ST_ISSUE         = 3'd2;
    localparam [2:0] ST_WAIT          = 3'd3;
    localparam [2:0] ST_REQUANT_LOAD  = 3'd4;
    localparam [2:0] ST_REQUANT_ISSUE = 3'd5;
    localparam [2:0] ST_REQUANT_WAIT  = 3'd6;

    reg [2:0] state;
    reg [OUT_GROUP_W-1:0] out_group_idx;
    reg [TAP_GROUP_W-1:0] tap_group_idx;
    reg [OUT_LANE_W-1:0] requant_lane_idx;
    reg signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_q;
    reg signed [TAP_LANES*ACT_W-1:0] group_act;
    reg signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] group_weight_q;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_i;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_q;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_final_q;
    reg signed [ACC_W-1:0] requant_acc_q;
    reg signed [63:0] requant_bias_q;
    reg signed [31:0] requant_q31_q;
    reg [7:0] requant_shift_q;
    reg [31:0] requant_out_ch_q;
    reg requant_group_last_q;
    reg requant_lane_last_q;

    wire group_s_ready;
    wire group_m_valid;
    wire signed [OUT_LANES*ACC_W-1:0] group_acc_o;
    wire requant_m_valid;
    wire signed [ACT_W-1:0] requant_q;

    (* rom_style = "block" *) reg signed [63:0] bias_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg signed [31:0] requant_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg [7:0] shift_mem [0:OUT_CH-1];

    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < OUT_CH; init_idx = init_idx + 1) begin
            bias_mem[init_idx] = 64'sd0;
            requant_mem[init_idx] = 32'sd0;
            shift_mem[init_idx] = 8'd31;
        end

        if (BIAS_I64_FILE != "")
            $readmemh(BIAS_I64_FILE, bias_mem);
        if (REQUANT_Q31_FILE != "")
            $readmemh(REQUANT_Q31_FILE, requant_mem);
        if (REQUANT_SHIFT_FILE != "")
            $readmemh(REQUANT_SHIFT_FILE, shift_mem);
    end

    integer tap_lane_idx;
    integer global_tap;
    integer global_out;

    assign weight_req_out_group = out_group_idx;
    assign weight_req_tap_group = tap_group_idx;

    always @(*) begin
        group_act = {TAP_LANES*ACT_W{1'b0}};
        group_acc_i = {OUT_LANES*ACC_W{1'b0}};

        for (tap_lane_idx = 0; tap_lane_idx < TAP_LANES; tap_lane_idx = tap_lane_idx + 1) begin
            global_tap = tap_group_idx * TAP_LANES + tap_lane_idx;
            if (global_tap < TAP_COUNT)
                group_act[tap_lane_idx*ACT_W +: ACT_W] = window_q[global_tap*ACT_W +: ACT_W];
        end

        if (tap_group_idx == {TAP_GROUP_W{1'b0}})
            group_acc_i = {OUT_LANES*ACC_W{1'b0}};
        else
            group_acc_i = group_acc_q;
    end

    span_w8a12_parallel_group_accum_engine #(
        .ACT_W(ACT_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES)
    ) u_group_accum (
        .clk(clk),
        .rst(rst),
        .s_valid(state == ST_ISSUE),
        .s_ready(group_s_ready),
        .s_first(tap_group_idx == {TAP_GROUP_W{1'b0}}),
        .s_last(tap_group_idx == TAP_GROUP_COUNT - 1),
        .act_i(group_act),
        .acc_i(group_acc_i),
        .weight_i(group_weight_q),
        .m_valid(group_m_valid),
        .m_ready(1'b1),
        .acc_o(group_acc_o)
    );

    wire [31:0] requant_out_ch = out_group_idx * OUT_LANES + requant_lane_idx;
    wire signed [63:0] requant_bias_i64 = (requant_out_ch < OUT_CH) ? bias_mem[requant_out_ch] : 64'sd0;
    wire signed [31:0] requant_q31 = (requant_out_ch < OUT_CH) ? requant_mem[requant_out_ch] : 32'sd0;
    wire [7:0] requant_shift = (requant_out_ch < OUT_CH) ? shift_mem[requant_out_ch] : 8'd31;

    span_w8a12_requant_pipe #(
        .ACC_W(ACC_W),
        .ACT_W(ACT_W)
    ) u_requant (
        .clk(clk),
        .rst(rst),
        .s_valid(state == ST_REQUANT_ISSUE),
        .acc_i(requant_acc_q),
        .bias_i64(requant_bias_q),
        .requant_q31_i(requant_q31_q),
        .requant_shift_i(requant_shift_q),
        .m_valid(requant_m_valid),
        .q_o(requant_q)
    );

    assign s_ready = (state == ST_IDLE) && (!m_valid || m_ready);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            out_group_idx <= {OUT_GROUP_W{1'b0}};
            tap_group_idx <= {TAP_GROUP_W{1'b0}};
            requant_lane_idx <= {OUT_LANE_W{1'b0}};
            window_q <= {IN_CH*KERNEL_TAPS*ACT_W{1'b0}};
            group_weight_q <= {OUT_LANES*TAP_LANES*WEIGHT_W{1'b0}};
            group_acc_q <= {OUT_LANES*ACC_W{1'b0}};
            group_acc_final_q <= {OUT_LANES*ACC_W{1'b0}};
            requant_acc_q <= {ACC_W{1'b0}};
            requant_bias_q <= 64'sd0;
            requant_q31_q <= 32'sd0;
            requant_shift_q <= 8'd31;
            requant_out_ch_q <= 32'd0;
            requant_group_last_q <= 1'b0;
            requant_lane_last_q <= 1'b0;
            weight_req_valid <= 1'b0;
            m_valid <= 1'b0;
            feat_o <= {OUT_CH*ACT_W{1'b0}};
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    weight_req_valid <= 1'b0;
                    if (s_valid && (!m_valid || m_ready)) begin
                        window_q <= window_i;
                        out_group_idx <= {OUT_GROUP_W{1'b0}};
                        tap_group_idx <= {TAP_GROUP_W{1'b0}};
                        requant_lane_idx <= {OUT_LANE_W{1'b0}};
                        group_acc_q <= {OUT_LANES*ACC_W{1'b0}};
                        group_acc_final_q <= {OUT_LANES*ACC_W{1'b0}};
                        m_valid <= 1'b0;
                        state <= ST_REQ;
                    end
                end

                ST_REQ: begin
                    weight_req_valid <= 1'b1;
                    if (weight_req_ready) begin
                        group_weight_q <= weight_group_i;
                        weight_req_valid <= 1'b0;
                        state <= ST_ISSUE;
                    end
                end

                ST_ISSUE: begin
                    if (group_s_ready)
                        state <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (tap_group_idx != TAP_GROUP_COUNT - 1) begin
                        if (group_s_ready) begin
                            tap_group_idx <= tap_group_idx + 1'b1;
                            state <= ST_REQ;
                        end
                    end else if (group_m_valid) begin
                        group_acc_q <= group_acc_o;
                        group_acc_final_q <= group_acc_o;
                        requant_lane_idx <= {OUT_LANE_W{1'b0}};
                        state <= ST_REQUANT_LOAD;
                    end
                end

                ST_REQUANT_LOAD: begin
                    global_out = out_group_idx * OUT_LANES + requant_lane_idx;
                    requant_acc_q <= group_acc_final_q[requant_lane_idx*ACC_W +: ACC_W];
                    requant_bias_q <= requant_bias_i64;
                    requant_q31_q <= requant_q31;
                    requant_shift_q <= requant_shift;
                    requant_out_ch_q <= global_out;
                    requant_lane_last_q <= (requant_lane_idx == OUT_LANES - 1) || (global_out == OUT_CH - 1);
                    requant_group_last_q <= (out_group_idx == OUT_GROUP_COUNT - 1);
                    state <= ST_REQUANT_ISSUE;
                end

                ST_REQUANT_ISSUE: begin
                    state <= ST_REQUANT_WAIT;
                end

                ST_REQUANT_WAIT: begin
                    if (requant_m_valid) begin
                        if (requant_out_ch_q < OUT_CH)
                            feat_o[requant_out_ch_q*ACT_W +: ACT_W] <= requant_q;

                        if (requant_lane_last_q) begin
                            requant_lane_idx <= {OUT_LANE_W{1'b0}};
                            tap_group_idx <= {TAP_GROUP_W{1'b0}};
                            group_acc_q <= {OUT_LANES*ACC_W{1'b0}};
                            group_acc_final_q <= {OUT_LANES*ACC_W{1'b0}};
                            if (requant_group_last_q) begin
                                m_valid <= 1'b1;
                                state <= ST_IDLE;
                            end else begin
                                out_group_idx <= out_group_idx + 1'b1;
                                state <= ST_REQ;
                            end
                        end else begin
                            requant_lane_idx <= requant_lane_idx + 1'b1;
                            state <= ST_REQUANT_LOAD;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
