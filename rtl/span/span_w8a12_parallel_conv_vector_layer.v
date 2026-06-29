`timescale 1ns/1ps

// Parallel vector convolution layer using the group-fed W8A12 accumulator.
//
// This is a vector-level prototype for the future video frame engine. It still
// accepts one unfolded input window, but it schedules computation in the same
// shape the video datapath needs: OUT_LANES output channels by TAP_LANES input
// taps per issued group.
module span_w8a12_parallel_conv_vector_layer #(
    parameter integer IN_CH = 3,
    parameter integer OUT_CH = 48,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 12,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = ""
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg signed [OUT_CH*ACT_W-1:0]         feat_o
);
    localparam integer TAP_COUNT = IN_CH * KERNEL_TAPS;
    localparam integer WEIGHT_COUNT = OUT_CH * TAP_COUNT;
    localparam integer OUT_GROUP_COUNT = (OUT_CH + OUT_LANES - 1) / OUT_LANES;
    localparam integer TAP_GROUP_COUNT = (TAP_COUNT + TAP_LANES - 1) / TAP_LANES;
    localparam integer OUT_GROUP_W = (OUT_GROUP_COUNT <= 2) ? 1 : $clog2(OUT_GROUP_COUNT);
    localparam integer TAP_GROUP_W = (TAP_GROUP_COUNT <= 2) ? 1 : $clog2(TAP_GROUP_COUNT);
    localparam integer OUT_LANE_W = (OUT_LANES <= 2) ? 1 : $clog2(OUT_LANES);

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_ISSUE  = 2'd1;
    localparam [1:0] ST_WAIT   = 2'd2;
    localparam [1:0] ST_REQUANT = 2'd3;

    reg [1:0] state;
    reg [OUT_GROUP_W-1:0] out_group_idx;
    reg [TAP_GROUP_W-1:0] tap_group_idx;
    reg [OUT_LANE_W-1:0] requant_lane_idx;
    reg signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_q;
    reg signed [TAP_LANES*ACT_W-1:0] group_act;
    reg signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] group_weight;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_i;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_q;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_final_q;

    wire group_s_ready;
    wire group_m_valid;
    wire signed [OUT_LANES*ACC_W-1:0] group_acc_o;
    wire signed [ACT_W-1:0] requant_q;

    (* rom_style = "block" *) reg signed [WEIGHT_W-1:0] weight_mem [0:WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [63:0] bias_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg signed [31:0] requant_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg [7:0] shift_mem [0:OUT_CH-1];

    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < WEIGHT_COUNT; init_idx = init_idx + 1)
            weight_mem[init_idx] = {WEIGHT_W{1'b0}};
        for (init_idx = 0; init_idx < OUT_CH; init_idx = init_idx + 1) begin
            bias_mem[init_idx] = 64'sd0;
            requant_mem[init_idx] = 32'sd0;
            shift_mem[init_idx] = 8'd31;
        end

        if (WEIGHT_FILE != "")
            $readmemh(WEIGHT_FILE, weight_mem);
        if (BIAS_I64_FILE != "")
            $readmemh(BIAS_I64_FILE, bias_mem);
        if (REQUANT_Q31_FILE != "")
            $readmemh(REQUANT_Q31_FILE, requant_mem);
        if (REQUANT_SHIFT_FILE != "")
            $readmemh(REQUANT_SHIFT_FILE, shift_mem);
    end

    integer tap_lane_idx;
    integer out_lane_idx;
    integer global_tap;
    integer global_out;
    integer weight_addr;

    always @(*) begin
        group_act = {TAP_LANES*ACT_W{1'b0}};
        group_weight = {OUT_LANES*TAP_LANES*WEIGHT_W{1'b0}};
        group_acc_i = {OUT_LANES*ACC_W{1'b0}};

        for (tap_lane_idx = 0; tap_lane_idx < TAP_LANES; tap_lane_idx = tap_lane_idx + 1) begin
            global_tap = tap_group_idx * TAP_LANES + tap_lane_idx;
            if (global_tap < TAP_COUNT)
                group_act[tap_lane_idx*ACT_W +: ACT_W] = window_q[global_tap*ACT_W +: ACT_W];

            for (out_lane_idx = 0; out_lane_idx < OUT_LANES; out_lane_idx = out_lane_idx + 1) begin
                global_out = out_group_idx * OUT_LANES + out_lane_idx;
                weight_addr = global_out * TAP_COUNT + global_tap;
                if ((global_out < OUT_CH) && (global_tap < TAP_COUNT))
                    group_weight[(out_lane_idx*TAP_LANES + tap_lane_idx)*WEIGHT_W +: WEIGHT_W] =
                        weight_mem[weight_addr];
            end
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
        .weight_i(group_weight),
        .m_valid(group_m_valid),
        .m_ready(1'b1),
        .acc_o(group_acc_o)
    );

    wire [31:0] requant_out_ch = out_group_idx * OUT_LANES + requant_lane_idx;
    wire signed [63:0] requant_bias_i64 = (requant_out_ch < OUT_CH) ? bias_mem[requant_out_ch] : 64'sd0;
    wire signed [31:0] requant_q31 = (requant_out_ch < OUT_CH) ? requant_mem[requant_out_ch] : 32'sd0;
    wire [7:0] requant_shift = (requant_out_ch < OUT_CH) ? shift_mem[requant_out_ch] : 8'd31;

    span_w8a12_requant #(
        .ACC_W(ACC_W),
        .ACT_W(ACT_W)
    ) u_requant (
        .acc_i(group_acc_final_q[requant_lane_idx*ACC_W +: ACC_W]),
        .bias_i64(requant_bias_i64),
        .requant_q31_i(requant_q31),
        .requant_shift_i(requant_shift),
        .q_o(requant_q)
    );

    assign s_ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            out_group_idx <= {OUT_GROUP_W{1'b0}};
            tap_group_idx <= {TAP_GROUP_W{1'b0}};
            requant_lane_idx <= {OUT_LANE_W{1'b0}};
            window_q <= {IN_CH*KERNEL_TAPS*ACT_W{1'b0}};
            group_acc_q <= {OUT_LANES*ACC_W{1'b0}};
            group_acc_final_q <= {OUT_LANES*ACC_W{1'b0}};
            m_valid <= 1'b0;
            feat_o <= {OUT_CH*ACT_W{1'b0}};
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (s_valid) begin
                        window_q <= window_i;
                        out_group_idx <= {OUT_GROUP_W{1'b0}};
                        tap_group_idx <= {TAP_GROUP_W{1'b0}};
                        requant_lane_idx <= {OUT_LANE_W{1'b0}};
                        group_acc_q <= {OUT_LANES*ACC_W{1'b0}};
                        group_acc_final_q <= {OUT_LANES*ACC_W{1'b0}};
                        m_valid <= 1'b0;
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
                            state <= ST_ISSUE;
                        end
                    end else if (group_m_valid) begin
                        group_acc_q <= group_acc_o;
                        group_acc_final_q <= group_acc_o;
                        requant_lane_idx <= {OUT_LANE_W{1'b0}};
                        state <= ST_REQUANT;
                    end
                end

                ST_REQUANT: begin
                    global_out = out_group_idx * OUT_LANES + requant_lane_idx;
                    if (global_out < OUT_CH)
                        feat_o[global_out*ACT_W +: ACT_W] <= requant_q;

                    if ((requant_lane_idx == OUT_LANES - 1) || (global_out == OUT_CH - 1)) begin
                        requant_lane_idx <= {OUT_LANE_W{1'b0}};
                        tap_group_idx <= {TAP_GROUP_W{1'b0}};
                        group_acc_q <= {OUT_LANES*ACC_W{1'b0}};
                        group_acc_final_q <= {OUT_LANES*ACC_W{1'b0}};
                        if (out_group_idx == OUT_GROUP_COUNT - 1) begin
                            m_valid <= 1'b1;
                            state <= ST_IDLE;
                        end else begin
                            out_group_idx <= out_group_idx + 1'b1;
                            state <= ST_ISSUE;
                        end
                    end else begin
                        requant_lane_idx <= requant_lane_idx + 1'b1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
