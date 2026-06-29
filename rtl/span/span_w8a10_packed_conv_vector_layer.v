`timescale 1ns/1ps

// Manifest-driven W8A10 packed convolution vector scheduler.
//
// This block is the first layer-shaped user of the W8A10 packed group
// accumulator. It accepts one unfolded convolution window, schedules
// OUT_LANES output channels by TAP_LANES taps at a time, then requantizes the
// accumulated output-channel group with the existing Q31/int64 constants.
module span_w8a10_packed_conv_vector_layer #(
    parameter integer IN_CH = 48,
    parameter integer OUT_CH = 48,
    parameter integer KERNEL_TAPS = 9,
    parameter integer ACT_W = 10,
    parameter integer ACC_W = 48,
    parameter integer OUT_LANES = 16,
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

    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_ISSUE   = 3'd1;
    localparam [2:0] ST_WAIT    = 3'd2;
    localparam [2:0] ST_REQUANT = 3'd3;
    localparam [2:0] ST_OUT     = 3'd4;

    initial begin
        if (ACT_W != 10) begin
            $error("span_w8a10_packed_conv_vector_layer requires ACT_W=10");
        end
        if (OUT_LANES < 2 || (OUT_LANES % 2) != 0) begin
            $error("OUT_LANES must be an even integer >= 2");
        end
    end

    reg [2:0] state;
    reg [OUT_GROUP_W-1:0] out_group_idx;
    reg [TAP_GROUP_W-1:0] tap_group_idx;
    reg [OUT_LANE_W-1:0] requant_lane_idx;
    reg signed [IN_CH*KERNEL_TAPS*ACT_W-1:0] window_q;
    reg signed [TAP_LANES*10-1:0] group_act;
    reg signed [OUT_LANES*TAP_LANES*8-1:0] group_weight;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_i;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_q;
    reg signed [OUT_LANES*ACC_W-1:0] group_acc_final_q;

    (* rom_style = "block" *) reg signed [7:0] weight_mem [0:WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [63:0] bias_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg signed [31:0] requant_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg [7:0] shift_mem [0:OUT_CH-1];

    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < WEIGHT_COUNT; init_idx = init_idx + 1)
            weight_mem[init_idx] = 8'sd0;
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

    wire group_s_ready;
    wire group_m_valid;
    wire signed [OUT_LANES*ACC_W-1:0] group_acc_o;
    wire signed [ACT_W-1:0] requant_q;
    wire [31:0] requant_out_ch = out_group_idx * OUT_LANES + requant_lane_idx;
    wire signed [63:0] requant_bias_i64 = (requant_out_ch < OUT_CH) ? bias_mem[requant_out_ch] : 64'sd0;
    wire signed [31:0] requant_q31 = (requant_out_ch < OUT_CH) ? requant_mem[requant_out_ch] : 32'sd0;
    wire [7:0] requant_shift = (requant_out_ch < OUT_CH) ? shift_mem[requant_out_ch] : 8'd31;

    integer tap_lane_idx;
    integer out_lane_idx;
    integer global_tap;
    integer global_out;
    integer weight_addr;

    always @(*) begin
        group_act = {TAP_LANES*10{1'b0}};
        group_weight = {OUT_LANES*TAP_LANES*8{1'b0}};
        group_acc_i = (tap_group_idx == {TAP_GROUP_W{1'b0}}) ? {OUT_LANES*ACC_W{1'b0}} : group_acc_q;

        for (tap_lane_idx = 0; tap_lane_idx < TAP_LANES; tap_lane_idx = tap_lane_idx + 1) begin
            global_tap = tap_group_idx * TAP_LANES + tap_lane_idx;
            if (global_tap < TAP_COUNT)
                group_act[tap_lane_idx*10 +: 10] = window_q[global_tap*ACT_W +: ACT_W];

            for (out_lane_idx = 0; out_lane_idx < OUT_LANES; out_lane_idx = out_lane_idx + 1) begin
                global_out = out_group_idx * OUT_LANES + out_lane_idx;
                weight_addr = global_out * TAP_COUNT + global_tap;
                if ((global_out < OUT_CH) && (global_tap < TAP_COUNT))
                    group_weight[(out_lane_idx*TAP_LANES + tap_lane_idx)*8 +: 8] =
                        weight_mem[weight_addr];
            end
        end
    end

    span_w8a10_packed_group_accum_engine #(
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .ACC_W(ACC_W),
        .PIPELINE(2)
    ) u_group_accum (
        .clk(clk),
        .rst(rst),
        .s_valid(state == ST_ISSUE),
        .s_ready(group_s_ready),
        .act_i(group_act),
        .acc_i(group_acc_i),
        .weight_i(group_weight),
        .m_valid(group_m_valid),
        .m_ready(1'b1),
        .acc_o(group_acc_o)
    );

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
                        out_group_idx <= {OUT_GROUP_W{1'b0}};
                        tap_group_idx <= {TAP_GROUP_W{1'b0}};
                        requant_lane_idx <= {OUT_LANE_W{1'b0}};
                        window_q <= window_i;
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
                    if (group_m_valid) begin
                        group_acc_q <= group_acc_o;
                        if (tap_group_idx == TAP_GROUP_COUNT - 1) begin
                            group_acc_final_q <= group_acc_o;
                            requant_lane_idx <= {OUT_LANE_W{1'b0}};
                            state <= ST_REQUANT;
                        end else begin
                            tap_group_idx <= tap_group_idx + 1'b1;
                            state <= ST_ISSUE;
                        end
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
                            state <= ST_OUT;
                        end else begin
                            out_group_idx <= out_group_idx + 1'b1;
                            state <= ST_ISSUE;
                        end
                    end else begin
                        requant_lane_idx <= requant_lane_idx + 1'b1;
                    end
                end

                ST_OUT: begin
                    if (!m_valid || m_ready)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
