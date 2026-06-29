`timescale 1ns/1ps

// Raster RGB888 3x3 window generator with one-pixel padding.
//
// This is the video-shaped counterpart to span_rgb_frame_window3x3. It consumes
// only real image pixels, internally injects the padded border samples, and
// emits one 3x3 window for each original pixel once the bottom/right context is
// available. window_valid_mask_o marks real taps so the W8A12 normalizer can
// produce feature-domain zero for padding.
module span_rgb_line_window3x3 #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W  = 64,
    parameter integer IMG_H  = 64
) (
    input  wire              clk,
    input  wire              rst,

    input  wire              s_valid,
    output wire              s_ready,
    input  wire [DATA_W-1:0] s_data,
    input  wire              s_pixel_valid,
    input  wire              s_user,
    input  wire              s_last,

    output reg               m_valid,
    input  wire              m_ready,
    output reg  [3*9*8-1:0]  window_o,
    output reg  [8:0]        window_valid_mask_o,
    output reg               m_user,
    output reg               m_last
);
    localparam integer PAD_W = IMG_W + 2;
    localparam integer PAD_H = IMG_H + 2;
    localparam integer X_W = (PAD_W <= 2) ? 1 : $clog2(PAD_W);
    localparam integer Y_W = (PAD_H <= 2) ? 1 : $clog2(PAD_H);

    reg [X_W-1:0] pad_x;
    reg [Y_W-1:0] pad_y;
    reg [DATA_W-1:0] line_prev1 [0:PAD_W-1];
    reg [DATA_W-1:0] line_prev2 [0:PAD_W-1];
    reg              valid_prev1 [0:PAD_W-1];
    reg              valid_prev2 [0:PAD_W-1];

    reg [DATA_W-1:0] top_left;
    reg [DATA_W-1:0] top_mid;
    reg [DATA_W-1:0] mid_left;
    reg [DATA_W-1:0] mid_mid;
    reg [DATA_W-1:0] bot_left;
    reg [DATA_W-1:0] bot_mid;
    reg top_valid_left;
    reg top_valid_mid;
    reg mid_valid_left;
    reg mid_valid_mid;
    reg bot_valid_left;
    reg bot_valid_mid;

    wire output_free = !m_valid || m_ready;
    wire need_input = (pad_x != {X_W{1'b0}}) && (pad_x != PAD_W - 1) &&
                      (pad_y != {Y_W{1'b0}}) && (pad_y != PAD_H - 1);
    wire can_step = output_free && (!need_input || s_valid);
    wire [DATA_W-1:0] sample_pix = need_input ? s_data : {DATA_W{1'b0}};
    wire sample_valid = need_input && s_pixel_valid;
    wire emit_window = (pad_x >= 2) && (pad_y >= 2);
    wire emit_user = (pad_x == 2) && (pad_y == 2);
    wire emit_last = (pad_x == PAD_W - 1);

    assign s_ready = output_free && need_input;

    integer init_idx;

    task automatic pack_tap;
        input integer tap;
        input [DATA_W-1:0] pix;
        input valid;
        begin
            window_o[(0*9 + tap)*8 +: 8] <= pix[23:16];
            window_o[(1*9 + tap)*8 +: 8] <= pix[15:8];
            window_o[(2*9 + tap)*8 +: 8] <= pix[7:0];
            window_valid_mask_o[tap] <= valid;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            pad_x <= {X_W{1'b0}};
            pad_y <= {Y_W{1'b0}};
            top_left <= {DATA_W{1'b0}};
            top_mid <= {DATA_W{1'b0}};
            mid_left <= {DATA_W{1'b0}};
            mid_mid <= {DATA_W{1'b0}};
            bot_left <= {DATA_W{1'b0}};
            bot_mid <= {DATA_W{1'b0}};
            top_valid_left <= 1'b0;
            top_valid_mid <= 1'b0;
            mid_valid_left <= 1'b0;
            mid_valid_mid <= 1'b0;
            bot_valid_left <= 1'b0;
            bot_valid_mid <= 1'b0;
            m_valid <= 1'b0;
            m_user <= 1'b0;
            m_last <= 1'b0;
            window_o <= {3*9*8{1'b0}};
            window_valid_mask_o <= 9'b0;
            for (init_idx = 0; init_idx < PAD_W; init_idx = init_idx + 1) begin
                line_prev1[init_idx] <= {DATA_W{1'b0}};
                line_prev2[init_idx] <= {DATA_W{1'b0}};
                valid_prev1[init_idx] <= 1'b0;
                valid_prev2[init_idx] <= 1'b0;
            end
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            if (can_step) begin
                if (emit_window) begin
                    pack_tap(0, top_left, top_valid_left);
                    pack_tap(1, top_mid, top_valid_mid);
                    pack_tap(2, line_prev2[pad_x], valid_prev2[pad_x]);
                    pack_tap(3, mid_left, mid_valid_left);
                    pack_tap(4, mid_mid, mid_valid_mid);
                    pack_tap(5, line_prev1[pad_x], valid_prev1[pad_x]);
                    pack_tap(6, bot_left, bot_valid_left);
                    pack_tap(7, bot_mid, bot_valid_mid);
                    pack_tap(8, sample_pix, sample_valid);
                    m_valid <= 1'b1;
                    m_user <= emit_user;
                    m_last <= emit_last;
                end

                top_left <= top_mid;
                top_mid <= line_prev2[pad_x];
                mid_left <= mid_mid;
                mid_mid <= line_prev1[pad_x];
                bot_left <= bot_mid;
                bot_mid <= sample_pix;
                top_valid_left <= top_valid_mid;
                top_valid_mid <= valid_prev2[pad_x];
                mid_valid_left <= mid_valid_mid;
                mid_valid_mid <= valid_prev1[pad_x];
                bot_valid_left <= bot_valid_mid;
                bot_valid_mid <= sample_valid;

                line_prev2[pad_x] <= line_prev1[pad_x];
                valid_prev2[pad_x] <= valid_prev1[pad_x];
                line_prev1[pad_x] <= sample_pix;
                valid_prev1[pad_x] <= sample_valid;

                if (pad_x == PAD_W - 1) begin
                    pad_x <= {X_W{1'b0}};
                    if (pad_y == PAD_H - 1)
                        pad_y <= {Y_W{1'b0}};
                    else
                        pad_y <= pad_y + 1'b1;

                    top_left <= {DATA_W{1'b0}};
                    top_mid <= {DATA_W{1'b0}};
                    mid_left <= {DATA_W{1'b0}};
                    mid_mid <= {DATA_W{1'b0}};
                    bot_left <= {DATA_W{1'b0}};
                    bot_mid <= {DATA_W{1'b0}};
                    top_valid_left <= 1'b0;
                    top_valid_mid <= 1'b0;
                    mid_valid_left <= 1'b0;
                    mid_valid_mid <= 1'b0;
                    bot_valid_left <= 1'b0;
                    bot_valid_mid <= 1'b0;
                end else begin
                    pad_x <= pad_x + 1'b1;
                end
            end
        end
    end

    wire unused_input_flags = s_user | s_last;
endmodule
