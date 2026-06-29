`timescale 1ns/1ps
`include "span_w8a12_generated_select.vh"

// Video-shaped W8A12 conv_1 frontend:
//   RGB stream -> line-buffer 3x3 window -> RGB normalization
//   -> streamed-weight conv_1 scheduler.
module span_w8a12_conv1_streamed_frontend #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer OUT_CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter WEIGHT_GROUP_FILE = `REDS_SPAN_ACTIVE_CONV_1_WEIGHT_GROUP_FILE
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       s_valid,
    output wire                       s_ready,
    input  wire [DATA_W-1:0]          s_data,
    input  wire                       s_pixel_valid,
    input  wire                       s_user,
    input  wire                       s_last,

    output wire                       m_valid,
    input  wire                       m_ready,
    output wire [OUT_CH*ACT_W-1:0]    m_feat,
    output wire                       m_user,
    output wire                       m_last
);
    wire window_valid;
    wire window_ready;
    wire [3*9*8-1:0] rgb_window;
    wire [8:0] window_valid_mask;
    wire window_user;
    wire window_last;
    wire [3*9*ACT_W-1:0] norm_window;

    wire weight_req_valid;
    wire weight_req_ready;
    wire [31:0] weight_req_out_group;
    wire [31:0] weight_req_tap_group;
    wire signed [OUT_LANES*TAP_LANES*8-1:0] weight_group;
    wire conv_window_ready;
    wire conv_m_valid;
    wire conv_s_valid;
    localparam integer SIDE_DEPTH = 8;
    localparam integer SIDE_PTR_W = 3;
    reg [SIDE_DEPTH-1:0] sideband_user_fifo;
    reg [SIDE_DEPTH-1:0] sideband_last_fifo;
    reg [SIDE_PTR_W-1:0] sideband_rd_ptr;
    reg [SIDE_PTR_W-1:0] sideband_wr_ptr;
    reg [SIDE_PTR_W:0] sideband_count;

    wire sideband_push = window_valid && window_ready;
    wire sideband_pop = conv_m_valid && m_ready;
    wire sideband_full = (sideband_count == SIDE_DEPTH);

    assign window_ready = conv_window_ready && !sideband_full;
    assign conv_s_valid = window_valid && !sideband_full;

    span_rgb_line_window3x3 #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) u_window (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_pixel_valid(s_pixel_valid),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(window_valid),
        .m_ready(window_ready),
        .window_o(rgb_window),
        .window_valid_mask_o(window_valid_mask),
        .m_user(window_user),
        .m_last(window_last)
    );

    span_w8a12_rgb_window_normalize #(
        .ACT_W(ACT_W)
    ) u_normalize (
        .rgb_window_i(rgb_window),
        .valid_mask_i(window_valid_mask),
        .norm_window_o(norm_window)
    );

    span_w8a12_weight_group_rom #(
        .OUT_CH(OUT_CH),
        .TAP_COUNT(3*9),
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
        .IN_CH(3),
        .OUT_CH(OUT_CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .WEIGHT_W(8),
        .ACC_W(ACC_W),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_0_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_0_REQUANT_SHIFT_FILE)
    ) u_conv1 (
        .clk(clk),
        .rst(rst),
        .s_valid(conv_s_valid),
        .s_ready(conv_window_ready),
        .window_i(norm_window),
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
                sideband_user_fifo[sideband_wr_ptr] <= window_user;
                sideband_last_fifo[sideband_wr_ptr] <= window_last;
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
