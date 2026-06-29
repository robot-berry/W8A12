`timescale 1ns/1ps

// Streamed 1x1 W8A12 feature convolution frontend.
//
// This is intended for post-trunk layers such as conv_cat, where the stream
// already carries the full per-pixel feature vector and no spatial line window
// is needed.
module span_w8a12_conv1x1_streamed_frontend #(
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer IN_CH = 192,
    parameter integer OUT_CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter WEIGHT_GROUP_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = ""
) (
    input  wire                              clk,
    input  wire                              rst,

    input  wire                              s_valid,
    output wire                              s_ready,
    input  wire signed [IN_CH*ACT_W-1:0]     s_feat,
    input  wire                              s_user,
    input  wire                              s_last,

    output wire                              m_valid,
    input  wire                              m_ready,
    output wire signed [OUT_CH*ACT_W-1:0]    m_feat,
    output wire                              m_user,
    output wire                              m_last
);
    wire weight_req_valid;
    wire weight_req_ready;
    wire [31:0] weight_req_out_group;
    wire [31:0] weight_req_tap_group;
    wire signed [OUT_LANES*TAP_LANES*8-1:0] weight_group;
    wire conv_s_ready;
    wire conv_s_valid;
    wire conv_m_valid;

    localparam integer SIDE_DEPTH = 8;
    localparam integer SIDE_PTR_W = 3;
    reg [SIDE_DEPTH-1:0] sideband_user_fifo;
    reg [SIDE_DEPTH-1:0] sideband_last_fifo;
    reg [SIDE_PTR_W-1:0] sideband_rd_ptr;
    reg [SIDE_PTR_W-1:0] sideband_wr_ptr;
    reg [SIDE_PTR_W:0] sideband_count;

    wire sideband_full = (sideband_count == SIDE_DEPTH);
    wire sideband_push = s_valid && s_ready;
    wire sideband_pop = conv_m_valid && m_ready;

    assign s_ready = conv_s_ready && !sideband_full;
    assign conv_s_valid = s_valid && !sideband_full;

    span_w8a12_weight_group_rom #(
        .OUT_CH(OUT_CH),
        .TAP_COUNT(IN_CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .WEIGHT_W(8),
        .MEM_FILE(WEIGHT_GROUP_FILE)
    ) u_weight_groups (
        .clk(clk),
        .rst(rst),
        .req_valid(weight_req_valid),
        .req_ready(weight_req_ready),
        .req_out_group(weight_req_out_group),
        .req_tap_group(weight_req_tap_group),
        .weight_group_o(weight_group)
    );

    span_w8a12_parallel_conv_vector_streamed_weights #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH),
        .KERNEL_TAPS(1),
        .ACT_W(ACT_W),
        .WEIGHT_W(8),
        .ACC_W(ACC_W),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .BIAS_I64_FILE(BIAS_I64_FILE),
        .REQUANT_Q31_FILE(REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(REQUANT_SHIFT_FILE)
    ) u_conv (
        .clk(clk),
        .rst(rst),
        .s_valid(conv_s_valid),
        .s_ready(conv_s_ready),
        .window_i(s_feat),
        .weight_req_valid(weight_req_valid),
        .weight_req_ready(weight_req_ready),
        .weight_req_out_group(weight_req_out_group),
        .weight_req_tap_group(weight_req_tap_group),
        .weight_group_i(weight_group),
        .m_valid(conv_m_valid),
        .m_ready(m_ready),
        .feat_o(m_feat)
    );

    assign m_valid = conv_m_valid;
    assign m_user = (sideband_count != 0) ? sideband_user_fifo[sideband_rd_ptr] : 1'b0;
    assign m_last = (sideband_count != 0) ? sideband_last_fifo[sideband_rd_ptr] : 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            sideband_user_fifo <= {SIDE_DEPTH{1'b0}};
            sideband_last_fifo <= {SIDE_DEPTH{1'b0}};
            sideband_rd_ptr <= {SIDE_PTR_W{1'b0}};
            sideband_wr_ptr <= {SIDE_PTR_W{1'b0}};
            sideband_count <= {(SIDE_PTR_W+1){1'b0}};
        end else begin
            if (sideband_push) begin
                sideband_user_fifo[sideband_wr_ptr] <= s_user;
                sideband_last_fifo[sideband_wr_ptr] <= s_last;
                sideband_wr_ptr <= sideband_wr_ptr + 1'b1;
            end

            if (sideband_pop)
                sideband_rd_ptr <= sideband_rd_ptr + 1'b1;

            case ({sideband_push, sideband_pop})
                2'b10: sideband_count <= sideband_count + 1'b1;
                2'b01: sideband_count <= sideband_count - 1'b1;
                default: sideband_count <= sideband_count;
            endcase
        end
    end
endmodule
