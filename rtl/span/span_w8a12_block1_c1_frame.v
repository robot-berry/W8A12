`timescale 1ns/1ps
`include "../generated/reds_span_x4_f48_w8a12/frame_engine/span_w8a12_frame_engine_plan.vh"
`include "../generated/reds_span_x4_f48_w8a12/span_w8a12_layers.vh"
`include "../generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess.vh"

// Single-stage frame engine for block_1.c1_r + act1.
//
// This is the synthesizable sub-boundary used to reduce the full block1 slice
// into a reusable conv/postprocess datapath.
module span_w8a12_block1_c1_frame #(
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = `W8A12_FRAME_ACT_W,
    parameter integer CH = `W8A12_FRAME_CHANNELS,
    parameter integer ACC_W = 48,
    parameter integer FRAME_PIXELS = IMG_W * IMG_H,
    parameter integer FRAME_ADDR_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS)
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output reg                          busy,
    output reg                          done,
    output reg  [31:0]                  input_count,
    output reg  [31:0]                  output_count,

    input  wire                         out_rd_en,
    input  wire [FRAME_ADDR_W-1:0]      out_rd_addr,
    output wire signed [CH*ACT_W-1:0]   out_feat
);
    localparam [3:0] ST_CAPTURE     = 4'd0;
    localparam [3:0] ST_PIX_SETUP   = 4'd1;
    localparam [3:0] ST_GATHER_SET  = 4'd2;
    localparam [3:0] ST_GATHER_LOAD = 4'd3;
    localparam [3:0] ST_CONV_START  = 4'd4;
    localparam [3:0] ST_CONV_WAIT   = 4'd5;
    localparam [3:0] ST_POST_SETUP  = 4'd6;
    localparam [3:0] ST_POST_LOOP   = 4'd7;
    localparam [3:0] ST_WRITE       = 4'd8;
    localparam [3:0] ST_ADVANCE     = 4'd9;
    localparam [3:0] ST_DONE        = 4'd10;

    reg [3:0] state;
    reg [FRAME_ADDR_W-1:0] capture_addr;
    reg [FRAME_ADDR_W-1:0] pix_idx;
    reg [3:0] tap_idx;
    reg [5:0] post_ch;
    reg signed [CH*9*ACT_W-1:0] window_q;
    reg signed [CH*ACT_W-1:0] c1_raw_q;
    reg signed [CH*ACT_W-1:0] act1_q;
    reg c1_s_valid;

    wire c1_ready;
    wire c1_valid;
    wire signed [CH*ACT_W-1:0] c1_feat;

    wire capture_take = s_valid && s_ready;
    assign s_ready = (state == ST_CAPTURE);

    wire signed [CH*ACT_W-1:0] input_rfeat;

    wire [31:0] pix_x = pix_idx % IMG_W;
    wire [31:0] pix_y = pix_idx / IMG_W;
    wire [31:0] tap_x_u = tap_idx % 3;
    wire [31:0] tap_y_u = tap_idx / 3;
    wire signed [31:0] src_x = $signed({1'b0, pix_x}) + $signed({1'b0, tap_x_u}) - 32'sd1;
    wire signed [31:0] src_y = $signed({1'b0, pix_y}) + $signed({1'b0, tap_y_u}) - 32'sd1;
    wire tap_in_bounds = (src_x >= 0) && (src_x < IMG_W) && (src_y >= 0) && (src_y < IMG_H);
    wire [FRAME_ADDR_W-1:0] gather_raddr = tap_in_bounds ? (src_y * IMG_W + src_x) : {FRAME_ADDR_W{1'b0}};
    wire [FRAME_ADDR_W-1:0] input_raddr = (state == ST_GATHER_SET || state == ST_GATHER_LOAD) ? gather_raddr : {FRAME_ADDR_W{1'b0}};
    wire [FRAME_ADDR_W-1:0] out_raddr = out_rd_en ? out_rd_addr : {FRAME_ADDR_W{1'b0}};

    span_w8a12_feature_bank4 #(
        .ACT_W(ACT_W),
        .CH(CH),
        .FRAME_PIXELS(FRAME_PIXELS),
        .FRAME_ADDR_W(FRAME_ADDR_W)
    ) u_input_buf (
        .clk(clk),
        .we(capture_take),
        .waddr(capture_addr),
        .wfeat(s_feat),
        .raddr(input_raddr),
        .rfeat(input_rfeat)
    );

    span_w8a12_feature_bank4 #(
        .ACT_W(ACT_W),
        .CH(CH),
        .FRAME_PIXELS(FRAME_PIXELS),
        .FRAME_ADDR_W(FRAME_ADDR_W)
    ) u_out_buf (
        .clk(clk),
        .we(state == ST_WRITE),
        .waddr(pix_idx),
        .wfeat(act1_q),
        .raddr(out_raddr),
        .rfeat(out_feat)
    );

    span_w8a12_conv_layer #(
        .IN_CH(CH),
        .OUT_CH(CH),
        .KERNEL_TAPS(9),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CONST_SYNC_READ(1),
        .PIPELINE_REQUANT(2),
        .WEIGHT_FILE(`REDS_SPAN_W8A12_LAYER_1_WEIGHT_FILE),
        .BIAS_I64_FILE(`REDS_SPAN_W8A12_LAYER_1_BIAS_I64_FILE),
        .REQUANT_Q31_FILE(`REDS_SPAN_W8A12_LAYER_1_REQUANT_Q31_FILE),
        .REQUANT_SHIFT_FILE(`REDS_SPAN_W8A12_LAYER_1_REQUANT_SHIFT_FILE)
    ) u_c1 (
        .clk(clk),
        .rst(rst),
        .s_valid(c1_s_valid),
        .s_ready(c1_ready),
        .window_i(window_q),
        .m_valid(c1_valid),
        .m_ready(1'b1),
        .feat_o(c1_feat)
    );

    wire signed [ACT_W-1:0] c1_raw_ch = c1_raw_q[post_ch*ACT_W +: ACT_W];
    wire signed [ACT_W-1:0] act1_y;

    span_w8a12_unary_lut #(
        .ACT_W(ACT_W),
        .LUT_FILE(`REDS_SPAN_W8A12_POSTPROCESS_0_FILE)
    ) u_act1_lut (
        .x_i(c1_raw_ch),
        .y_o(act1_y)
    );

    integer ch_i;
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_CAPTURE;
            capture_addr <= {FRAME_ADDR_W{1'b0}};
            pix_idx <= {FRAME_ADDR_W{1'b0}};
            tap_idx <= 4'd0;
            post_ch <= 6'd0;
            window_q <= {CH*9*ACT_W{1'b0}};
            c1_raw_q <= {CH*ACT_W{1'b0}};
            act1_q <= {CH*ACT_W{1'b0}};
            c1_s_valid <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            input_count <= 32'd0;
            output_count <= 32'd0;
        end else begin
            c1_s_valid <= 1'b0;

            case (state)
                ST_CAPTURE: begin
                    if (capture_take) begin
                        busy <= 1'b1;
                        done <= 1'b0;
                        if (s_user) begin
                            capture_addr <= {FRAME_ADDR_W{1'b0}};
                            input_count <= 32'd1;
                            output_count <= 32'd0;
                        end else begin
                            input_count <= input_count + 32'd1;
                        end

                        if ((s_user && (FRAME_PIXELS == 1)) || (!s_user && (capture_addr == FRAME_PIXELS-1))) begin
                            state <= ST_PIX_SETUP;
                            pix_idx <= {FRAME_ADDR_W{1'b0}};
                            capture_addr <= {FRAME_ADDR_W{1'b0}};
                        end else begin
                            capture_addr <= s_user ? {{(FRAME_ADDR_W-1){1'b0}}, 1'b1} : capture_addr + 1'b1;
                        end
                    end
                end

                ST_PIX_SETUP: begin
                    tap_idx <= 4'd0;
                    window_q <= {CH*9*ACT_W{1'b0}};
                    state <= ST_GATHER_SET;
                end

                ST_GATHER_SET: begin
                    state <= ST_GATHER_LOAD;
                end

                ST_GATHER_LOAD: begin
                    for (ch_i = 0; ch_i < CH; ch_i = ch_i + 1) begin
                        if (tap_in_bounds)
                            window_q[(ch_i*9 + tap_idx)*ACT_W +: ACT_W] <= input_rfeat[ch_i*ACT_W +: ACT_W];
                        else
                            window_q[(ch_i*9 + tap_idx)*ACT_W +: ACT_W] <= {ACT_W{1'b0}};
                    end
                    if (tap_idx == 4'd8) begin
                        state <= ST_CONV_START;
                    end else begin
                        tap_idx <= tap_idx + 1'b1;
                        state <= ST_GATHER_SET;
                    end
                end

                ST_CONV_START: begin
                    c1_s_valid <= 1'b1;
                    state <= ST_CONV_WAIT;
                end

                ST_CONV_WAIT: begin
                    if (c1_valid) begin
                        c1_raw_q <= c1_feat;
                        state <= ST_POST_SETUP;
                    end
                end

                ST_POST_SETUP: begin
                    post_ch <= 6'd0;
                    act1_q <= {CH*ACT_W{1'b0}};
                    state <= ST_POST_LOOP;
                end

                ST_POST_LOOP: begin
                    act1_q[post_ch*ACT_W +: ACT_W] <= act1_y;
                    if (post_ch == CH-1)
                        state <= ST_WRITE;
                    else
                        post_ch <= post_ch + 1'b1;
                end

                ST_WRITE: begin
                    output_count <= output_count + 32'd1;
                    state <= ST_ADVANCE;
                end

                ST_ADVANCE: begin
                    if (pix_idx == FRAME_PIXELS-1) begin
                        state <= ST_DONE;
                    end else begin
                        pix_idx <= pix_idx + 1'b1;
                        state <= ST_PIX_SETUP;
                    end
                end

                ST_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end

                default: state <= ST_CAPTURE;
            endcase
        end
    end

    wire unused_ready = c1_ready;
    wire unused_stream = s_last;
endmodule
