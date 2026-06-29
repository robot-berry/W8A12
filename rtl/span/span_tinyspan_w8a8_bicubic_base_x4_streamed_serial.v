`timescale 1ns/1ps

// Resource-oriented X4 bicubic base generator for TinySPAN W8A8.
//
// It buffers one LR frame, then emits HR RGB q_base pixels. Each HR pixel is
// accumulated over 16 tap cycles with three color accumulators in parallel.
module span_tinyspan_w8a8_bicubic_base_x4_streamed_serial #(
    parameter integer DATA_W = 24,
    parameter integer ACT_W = 8,
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32
) (
    input  wire                       clk,
    input  wire                       rst,

    input  wire                       s_valid,
    output wire                       s_ready,
    input  wire [DATA_W-1:0]          s_data,
    input  wire                       s_user,
    input  wire                       s_last,

    output reg                        m_valid,
    input  wire                       m_ready,
    output reg signed [3*ACT_W-1:0]   m_rgb,
    output reg                        m_user,
    output reg                        m_last
);
    localparam integer FRAME_PIXELS = IMG_W * IMG_H;
    localparam integer HR_W = IMG_W * 4;
    localparam integer HR_H = IMG_H * 4;
    localparam integer LR_PIX_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS);
    localparam integer HR_X_W = (HR_W <= 2) ? 1 : $clog2(HR_W);
    localparam integer HR_Y_W = (HR_H <= 2) ? 1 : $clog2(HR_H);
    localparam [1:0] ST_LOAD = 2'd0;
    localparam [1:0] ST_TAP = 2'd1;
    localparam [1:0] ST_HOLD = 2'd2;

    reg [1:0] state;
    reg [DATA_W-1:0] frame_mem [0:FRAME_PIXELS-1];
    reg [LR_PIX_W-1:0] load_pix;
    reg [HR_X_W-1:0] emit_x;
    reg [HR_Y_W-1:0] emit_y;
    reg frame_user_q;
    reg [4:0] tap_idx;
    reg signed [63:0] acc_r;
    reg signed [63:0] acc_g;
    reg signed [63:0] acc_b;
    reg frame_done_q;

    integer tx;
    integer ty;
    integer sx_phase;
    integer sy_phase;
    integer src_x_floor;
    integer src_y_floor;
    integer px;
    integer py;
    integer addr;
    reg signed [15:0] wx;
    reg signed [15:0] wy;
    reg signed [31:0] wxy;
    reg [DATA_W-1:0] pix;
    reg signed [63:0] next_r;
    reg signed [63:0] next_g;
    reg signed [63:0] next_b;

    assign s_ready = (state == ST_LOAD);

    function automatic signed [15:0] phase_coeff_q14;
        input integer phase;
        input integer tap;
        begin
            case (phase)
                0: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd1080;
                        1: phase_coeff_q14 =  16'sd6984;
                        2: phase_coeff_q14 =  16'sd12280;
                        default: phase_coeff_q14 = -16'sd1800;
                    endcase
                end
                1: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd168;
                        1: phase_coeff_q14 =  16'sd1880;
                        2: phase_coeff_q14 =  16'sd15848;
                        default: phase_coeff_q14 = -16'sd1176;
                    endcase
                end
                2: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd1176;
                        1: phase_coeff_q14 =  16'sd15848;
                        2: phase_coeff_q14 =  16'sd1880;
                        default: phase_coeff_q14 = -16'sd168;
                    endcase
                end
                default: begin
                    case (tap)
                        0: phase_coeff_q14 = -16'sd1800;
                        1: phase_coeff_q14 =  16'sd12280;
                        2: phase_coeff_q14 =  16'sd6984;
                        default: phase_coeff_q14 = -16'sd1080;
                    endcase
                end
            endcase
        end
    endfunction

    function automatic integer clamp_x;
        input integer x;
        begin
            if (x < 0)
                clamp_x = 0;
            else if (x >= IMG_W)
                clamp_x = IMG_W - 1;
            else
                clamp_x = x;
        end
    endfunction

    function automatic integer clamp_y;
        input integer y;
        begin
            if (y < 0)
                clamp_y = 0;
            else if (y >= IMG_H)
                clamp_y = IMG_H - 1;
            else
                clamp_y = y;
        end
    endfunction

    function automatic [7:0] rounded_div_qbase;
        input signed [63:0] abs_num_i;
        integer k;
        reg [7:0] q;
        reg signed [63:0] threshold;
        begin
            q = 8'd0;
            for (k = 127; k >= 1; k = k - 1) begin
                threshold = (64'sd68451041280 * k) - 64'sd34225520640;
                if ((q == 8'd0) && (abs_num_i >= threshold))
                    q = k;
            end
            rounded_div_qbase = q;
        end
    endfunction

    function automatic signed [ACT_W-1:0] acc_to_qbase;
        input signed [63:0] acc_i;
        reg signed [63:0] num;
        reg signed [63:0] abs_num;
        reg [7:0] q_abs;
        reg signed [63:0] q_signed;
        begin
            num = acc_i * 64'sd127;
            abs_num = (num < 64'sd0) ? -num : num;
            q_abs = rounded_div_qbase(abs_num);
            q_signed = (num < 64'sd0) ? -$signed({1'b0, q_abs}) : $signed({1'b0, q_abs});
            if (q_signed > 64'sd127)
                acc_to_qbase = 8'sd127;
            else if (q_signed < -64'sd128)
                acc_to_qbase = -8'sd128;
            else
                acc_to_qbase = q_signed[ACT_W-1:0];
        end
    endfunction

    task automatic advance_pixel;
        begin
            frame_done_q <= (emit_x == HR_W - 1) && (emit_y == HR_H - 1);
            if ((emit_x == HR_W - 1) && (emit_y == HR_H - 1)) begin
                emit_x <= {HR_X_W{1'b0}};
                emit_y <= {HR_Y_W{1'b0}};
            end else if (emit_x == HR_W - 1) begin
                emit_x <= {HR_X_W{1'b0}};
                emit_y <= emit_y + 1'b1;
            end else begin
                emit_x <= emit_x + 1'b1;
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_LOAD;
            load_pix <= {LR_PIX_W{1'b0}};
            emit_x <= {HR_X_W{1'b0}};
            emit_y <= {HR_Y_W{1'b0}};
            frame_user_q <= 1'b0;
            tap_idx <= 5'd0;
            acc_r <= 64'sd0;
            acc_g <= 64'sd0;
            acc_b <= 64'sd0;
            frame_done_q <= 1'b0;
            m_valid <= 1'b0;
            m_rgb <= {3*ACT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            case (state)
                ST_LOAD: begin
                    m_valid <= 1'b0;
                    if (s_valid && s_ready) begin
                        frame_mem[load_pix] <= s_data;
                        if (load_pix == {LR_PIX_W{1'b0}})
                            frame_user_q <= s_user;

                        if (load_pix == FRAME_PIXELS - 1) begin
                            state <= ST_TAP;
                            load_pix <= {LR_PIX_W{1'b0}};
                            emit_x <= {HR_X_W{1'b0}};
                            emit_y <= {HR_Y_W{1'b0}};
                            tap_idx <= 5'd0;
                            acc_r <= 64'sd0;
                            acc_g <= 64'sd0;
                            acc_b <= 64'sd0;
                            frame_done_q <= 1'b0;
                        end else begin
                            load_pix <= load_pix + 1'b1;
                        end
                    end
                end

                ST_TAP: begin
                    tx = tap_idx[1:0];
                    ty = tap_idx[3:2];
                    sx_phase = emit_x & 3;
                    sy_phase = emit_y & 3;
                    src_x_floor = (emit_x >>> 2) + ((sx_phase < 2) ? -1 : 0);
                    src_y_floor = (emit_y >>> 2) + ((sy_phase < 2) ? -1 : 0);
                    px = clamp_x(src_x_floor - 1 + tx);
                    py = clamp_y(src_y_floor - 1 + ty);
                    wx = phase_coeff_q14(sx_phase, tx);
                    wy = phase_coeff_q14(sy_phase, ty);
                    wxy = wx * wy;
                    addr = py * IMG_W + px;
                    pix = frame_mem[addr];
                    next_r = acc_r + ($signed({1'b0, pix[23:16]}) * wxy);
                    next_g = acc_g + ($signed({1'b0, pix[15:8]}) * wxy);
                    next_b = acc_b + ($signed({1'b0, pix[7:0]}) * wxy);

                    if (tap_idx == 5'd15) begin
                        m_rgb[0*ACT_W +: ACT_W] <= acc_to_qbase(next_r);
                        m_rgb[1*ACT_W +: ACT_W] <= acc_to_qbase(next_g);
                        m_rgb[2*ACT_W +: ACT_W] <= acc_to_qbase(next_b);
                        m_user <= frame_user_q && (emit_x == {HR_X_W{1'b0}}) && (emit_y == {HR_Y_W{1'b0}});
                        m_last <= (emit_x == HR_W - 1);
                        m_valid <= 1'b1;
                        advance_pixel();
                        state <= ST_HOLD;
                    end else begin
                        acc_r <= next_r;
                        acc_g <= next_g;
                        acc_b <= next_b;
                        tap_idx <= tap_idx + 1'b1;
                    end
                end

                ST_HOLD: begin
                    if (m_ready) begin
                        m_valid <= 1'b0;
                        if (frame_done_q) begin
                            state <= ST_LOAD;
                        end else begin
                            state <= ST_TAP;
                            tap_idx <= 5'd0;
                            acc_r <= 64'sd0;
                            acc_g <= 64'sd0;
                            acc_b <= 64'sd0;
                        end
                    end
                end

                default: state <= ST_LOAD;
            endcase
        end
    end

    wire unused_last = s_last;
endmodule

