`timescale 1ns/1ps

// Streaming 3x3 window generator for W8A12 feature maps.
//
// The module consumes one CH-channel feature vector per source pixel and emits
// one zero-padded 3x3 window for each pixel. The output packing matches
// span_w8a12_conv_layer:
//   window_o[(channel*9 + kernel_index)*ACT_W +: ACT_W]
// with kernel_index in row-major 3x3 order.
module span_w8a12_feature_line_window3x3 #(
    parameter integer ACT_W = 12,
    parameter integer CH = 48,
    parameter integer IMG_W = 64,
    parameter integer IMG_H = 64
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output reg                          m_valid,
    input  wire                         m_ready,
    output reg signed [CH*9*ACT_W-1:0]  window_o,
    output reg  [8:0]                   window_valid_mask_o,
    output reg                          m_user,
    output reg                          m_last,
    output wire [15:0]                  debug_state
);
    localparam integer FEAT_W = CH * ACT_W;
    localparam integer PAD_W = IMG_W + 2;
    localparam integer PAD_H = IMG_H + 2;
    localparam integer X_W = (PAD_W <= 2) ? 1 : $clog2(PAD_W);
    localparam integer Y_W = (PAD_H <= 2) ? 1 : $clog2(PAD_H);
    localparam [0:0] ST_ISSUE = 1'b0;
    localparam [0:0] ST_EMIT  = 1'b1;

    reg state;
    reg [X_W-1:0] pad_x;
    reg [Y_W-1:0] pad_y;
    (* ram_style = "block" *) reg signed [FEAT_W-1:0] line_prev1 [0:PAD_W-1];
    (* ram_style = "block" *) reg signed [FEAT_W-1:0] line_prev2 [0:PAD_W-1];
    reg valid_prev1 [0:PAD_W-1];
    reg valid_prev2 [0:PAD_W-1];

    reg [X_W-1:0] req_x;
    reg [Y_W-1:0] req_y;
    reg signed [FEAT_W-1:0] sample_q;
    reg sample_valid_q;
    reg emit_window_q;
    reg emit_user_q;
    reg emit_last_q;
    reg signed [FEAT_W-1:0] prev1_q;
    reg signed [FEAT_W-1:0] prev2_q;
    reg valid1_q;
    reg valid2_q;

    reg signed [FEAT_W-1:0] top_left;
    reg signed [FEAT_W-1:0] top_mid;
    reg signed [FEAT_W-1:0] mid_left;
    reg signed [FEAT_W-1:0] mid_mid;
    reg signed [FEAT_W-1:0] bot_left;
    reg signed [FEAT_W-1:0] bot_mid;
    reg top_valid_left;
    reg top_valid_mid;
    reg mid_valid_left;
    reg mid_valid_mid;
    reg bot_valid_left;
    reg bot_valid_mid;

    wire output_free = !m_valid || m_ready;
    wire need_input = (pad_x != {X_W{1'b0}}) && (pad_x != PAD_W - 1) &&
                      (pad_y != {Y_W{1'b0}}) && (pad_y != PAD_H - 1);
    wire can_issue = (state == ST_ISSUE) && output_free && (!need_input || s_valid);
    wire signed [FEAT_W-1:0] sample_feat = need_input ? s_feat : {FEAT_W{1'b0}};
    wire sample_valid = need_input;
    wire emit_window = (pad_x >= 2) && (pad_y >= 2);
    wire emit_user = (pad_x == 2) && (pad_y == 2);
    wire emit_last = (pad_x == PAD_W - 1);

    assign s_ready = (state == ST_ISSUE) && output_free && need_input;

    integer init_idx;
    integer pack_ch;

    function automatic [4:0] trunc5_x(input [X_W-1:0] value);
        integer bit_i;
        begin
            trunc5_x = 5'd0;
            for (bit_i = 0; bit_i < 5; bit_i = bit_i + 1)
                if (bit_i < X_W)
                    trunc5_x[bit_i] = value[bit_i];
        end
    endfunction

    function automatic [4:0] trunc5_y(input [Y_W-1:0] value);
        integer bit_i;
        begin
            trunc5_y = 5'd0;
            for (bit_i = 0; bit_i < 5; bit_i = bit_i + 1)
                if (bit_i < Y_W)
                    trunc5_y[bit_i] = value[bit_i];
        end
    endfunction

    assign debug_state = {
        state,
        trunc5_y(pad_y),
        trunc5_x(pad_x),
        need_input,
        can_issue,
        output_free,
        s_valid,
        s_ready
    };

    task automatic pack_tap;
        input integer tap;
        input signed [FEAT_W-1:0] feat;
        input valid;
        begin
            window_valid_mask_o[tap] <= valid;
            for (pack_ch = 0; pack_ch < CH; pack_ch = pack_ch + 1) begin
                window_o[(pack_ch*9 + tap)*ACT_W +: ACT_W] <=
                    valid ? feat[pack_ch*ACT_W +: ACT_W] : {ACT_W{1'b0}};
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_ISSUE;
            pad_x <= {X_W{1'b0}};
            pad_y <= {Y_W{1'b0}};
            req_x <= {X_W{1'b0}};
            req_y <= {Y_W{1'b0}};
            sample_q <= {FEAT_W{1'b0}};
            sample_valid_q <= 1'b0;
            emit_window_q <= 1'b0;
            emit_user_q <= 1'b0;
            emit_last_q <= 1'b0;
            prev1_q <= {FEAT_W{1'b0}};
            prev2_q <= {FEAT_W{1'b0}};
            valid1_q <= 1'b0;
            valid2_q <= 1'b0;
            top_left <= {FEAT_W{1'b0}};
            top_mid <= {FEAT_W{1'b0}};
            mid_left <= {FEAT_W{1'b0}};
            mid_mid <= {FEAT_W{1'b0}};
            bot_left <= {FEAT_W{1'b0}};
            bot_mid <= {FEAT_W{1'b0}};
            top_valid_left <= 1'b0;
            top_valid_mid <= 1'b0;
            mid_valid_left <= 1'b0;
            mid_valid_mid <= 1'b0;
            bot_valid_left <= 1'b0;
            bot_valid_mid <= 1'b0;
            m_valid <= 1'b0;
            m_user <= 1'b0;
            m_last <= 1'b0;
            window_o <= {CH*9*ACT_W{1'b0}};
            window_valid_mask_o <= 9'b0;
            for (init_idx = 0; init_idx < PAD_W; init_idx = init_idx + 1) begin
                valid_prev1[init_idx] <= 1'b0;
                valid_prev2[init_idx] <= 1'b0;
            end
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            case (state)
                ST_ISSUE: begin
                    if (can_issue) begin
                        req_x <= pad_x;
                        req_y <= pad_y;
                        sample_q <= sample_feat;
                        sample_valid_q <= sample_valid;
                        emit_window_q <= emit_window;
                        emit_user_q <= emit_user;
                        emit_last_q <= emit_last;
                        prev1_q <= line_prev1[pad_x];
                        prev2_q <= line_prev2[pad_x];
                        valid1_q <= valid_prev1[pad_x];
                        valid2_q <= valid_prev2[pad_x];
                        state <= ST_EMIT;
                    end
                end

                ST_EMIT: begin
                    if (output_free) begin
                        if (emit_window_q) begin
                            pack_tap(0, top_left, top_valid_left);
                            pack_tap(1, top_mid, top_valid_mid);
                            pack_tap(2, prev2_q, valid2_q);
                            pack_tap(3, mid_left, mid_valid_left);
                            pack_tap(4, mid_mid, mid_valid_mid);
                            pack_tap(5, prev1_q, valid1_q);
                            pack_tap(6, bot_left, bot_valid_left);
                            pack_tap(7, bot_mid, bot_valid_mid);
                            pack_tap(8, sample_q, sample_valid_q);
                            m_valid <= 1'b1;
                            m_user <= emit_user_q;
                            m_last <= emit_last_q;
                        end

                        top_left <= top_mid;
                        top_mid <= prev2_q;
                        mid_left <= mid_mid;
                        mid_mid <= prev1_q;
                        bot_left <= bot_mid;
                        bot_mid <= sample_q;
                        top_valid_left <= top_valid_mid;
                        top_valid_mid <= valid2_q;
                        mid_valid_left <= mid_valid_mid;
                        mid_valid_mid <= valid1_q;
                        bot_valid_left <= bot_valid_mid;
                        bot_valid_mid <= sample_valid_q;

                        line_prev2[req_x] <= prev1_q;
                        valid_prev2[req_x] <= valid1_q;
                        line_prev1[req_x] <= sample_q;
                        valid_prev1[req_x] <= sample_valid_q;

                        if (req_x == PAD_W - 1) begin
                            pad_x <= {X_W{1'b0}};
                            if (req_y == PAD_H - 1)
                                pad_y <= {Y_W{1'b0}};
                            else
                                pad_y <= req_y + 1'b1;

                            top_left <= {FEAT_W{1'b0}};
                            top_mid <= {FEAT_W{1'b0}};
                            mid_left <= {FEAT_W{1'b0}};
                            mid_mid <= {FEAT_W{1'b0}};
                            bot_left <= {FEAT_W{1'b0}};
                            bot_mid <= {FEAT_W{1'b0}};
                            top_valid_left <= 1'b0;
                            top_valid_mid <= 1'b0;
                            mid_valid_left <= 1'b0;
                            mid_valid_mid <= 1'b0;
                            bot_valid_left <= 1'b0;
                            bot_valid_mid <= 1'b0;
                        end else begin
                            pad_x <= req_x + 1'b1;
                        end

                        state <= ST_ISSUE;
                    end
                end
            endcase
        end
    end

    wire unused_input_flags = s_user | s_last;
endmodule
