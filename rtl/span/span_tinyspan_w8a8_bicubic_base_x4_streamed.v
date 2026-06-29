`timescale 1ns/1ps

// BRAM-friendly X4 bicubic base generator for TinySPAN W8A8.
//
// Geometry matches PyTorch interpolate(scale_factor=4, mode="bicubic",
// align_corners=False). Coefficients use the PyTorch cubic alpha -0.75 for the
// four fixed x4 subpixel phases, quantized to Q14.
//
// The 320x180 -> 1280x720 acceptance target is too large for a 16-read
// combinational frame buffer. This implementation mirrors the LR RGB888 frame
// into eight explicit single-read XPM block RAMs and processes two bicubic row
// taps per cycle. The read-data and coefficient pipeline is explicitly aligned
// for synchronous block RAM latency.
module span_tinyspan_w8a8_bicubic_base_x4_streamed #(
    parameter integer DATA_W = 24,
    parameter integer ACT_W = 8,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4
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
    localparam [1:0] ST_RUN  = 2'd1;
    localparam [1:0] ST_DRAIN = 2'd2;
    localparam integer Q_STAGES = 7;
    localparam signed [63:0] Q_DEN = 64'sd68451041280;
    localparam signed [63:0] Q_HALF = 64'sd34225520640;

    reg [1:0] state;

    reg [LR_PIX_W-1:0] load_pix;
    reg [LR_PIX_W-1:0] rd_addr0;
    reg [LR_PIX_W-1:0] rd_addr1;
    reg [LR_PIX_W-1:0] rd_addr2;
    reg [LR_PIX_W-1:0] rd_addr3;
    reg [LR_PIX_W-1:0] rd_addr4;
    reg [LR_PIX_W-1:0] rd_addr5;
    reg [LR_PIX_W-1:0] rd_addr6;
    reg [LR_PIX_W-1:0] rd_addr7;
    wire [DATA_W-1:0] rd_pix0;
    wire [DATA_W-1:0] rd_pix1;
    wire [DATA_W-1:0] rd_pix2;
    wire [DATA_W-1:0] rd_pix3;
    wire [DATA_W-1:0] rd_pix4;
    wire [DATA_W-1:0] rd_pix5;
    wire [DATA_W-1:0] rd_pix6;
    wire [DATA_W-1:0] rd_pix7;

    reg [HR_X_W-1:0] emit_x;
    reg [HR_Y_W-1:0] emit_y;
    reg frame_user_q;
    reg frame_done_q;
    reg [1:0] issue_idx;

    reg pipe_valid_d0;
    reg pipe_valid_d1;
    reg pipe_valid_d2;
    reg pair_idx_d0;
    reg pair_idx_d1;
    reg pair_idx_d2;
    reg pair_user_d0;
    reg pair_user_d1;
    reg pair_user_d2;
    reg pair_last_d0;
    reg pair_last_d1;
    reg pair_last_d2;
    reg pair_frame_done_d0;
    reg pair_frame_done_d1;
    reg pair_frame_done_d2;
    reg signed [15:0] wx0_d0;
    reg signed [15:0] wx1_d0;
    reg signed [15:0] wx2_d0;
    reg signed [15:0] wx3_d0;
    reg signed [15:0] wy0_d0;
    reg signed [15:0] wy1_d0;
    reg signed [15:0] wx0_d1;
    reg signed [15:0] wx1_d1;
    reg signed [15:0] wx2_d1;
    reg signed [15:0] wx3_d1;
    reg signed [15:0] wy0_d1;
    reg signed [15:0] wy1_d1;
    reg signed [15:0] wx0_d2;
    reg signed [15:0] wx1_d2;
    reg signed [15:0] wx2_d2;
    reg signed [15:0] wx3_d2;
    reg signed [15:0] wy0_d2;
    reg signed [15:0] wy1_d2;
    reg signed [31:0] w00_d1;
    reg signed [31:0] w01_d1;
    reg signed [31:0] w02_d1;
    reg signed [31:0] w03_d1;
    reg signed [31:0] w10_d1;
    reg signed [31:0] w11_d1;
    reg signed [31:0] w12_d1;
    reg signed [31:0] w13_d1;
    reg signed [31:0] w00_d2;
    reg signed [31:0] w01_d2;
    reg signed [31:0] w02_d2;
    reg signed [31:0] w03_d2;
    reg signed [31:0] w10_d2;
    reg signed [31:0] w11_d2;
    reg signed [31:0] w12_d2;
    reg signed [31:0] w13_d2;

    reg signed [63:0] acc_r;
    reg signed [63:0] acc_g;
    reg signed [63:0] acc_b;
    reg pair_valid_q;
    reg pair_idx_q;
    reg pair_user_q;
    reg pair_last_q;
    reg pair_frame_done_q;
    reg signed [63:0] pair_r_q;
    reg signed [63:0] pair_g_q;
    reg signed [63:0] pair_b_q;

    reg signed [63:0] row0_r;
    reg signed [63:0] row0_g;
    reg signed [63:0] row0_b;
    reg signed [63:0] row1_r;
    reg signed [63:0] row1_g;
    reg signed [63:0] row1_b;
    reg signed [63:0] pair_r;
    reg signed [63:0] pair_g;
    reg signed [63:0] pair_b;
    reg signed [63:0] next_r;
    reg signed [63:0] next_g;
    reg signed [63:0] next_b;
    reg signed [63:0] num_r;
    reg signed [63:0] num_g;
    reg signed [63:0] num_b;
    reg [Q_STAGES:0] q_valid;
    reg signed [63:0] q_abs_r [0:Q_STAGES];
    reg signed [63:0] q_abs_g [0:Q_STAGES];
    reg signed [63:0] q_abs_b [0:Q_STAGES];
    reg q_sign_r [0:Q_STAGES];
    reg q_sign_g [0:Q_STAGES];
    reg q_sign_b [0:Q_STAGES];
    reg [6:0] q_code_r [0:Q_STAGES];
    reg [6:0] q_code_g [0:Q_STAGES];
    reg [6:0] q_code_b [0:Q_STAGES];
    reg q_user [0:Q_STAGES];
    reg q_last [0:Q_STAGES];
    reg q_frame_done [0:Q_STAGES];
    reg m_frame_done_q;
    integer qi;

    wire frame_wr_en = (state == ST_LOAD) && s_valid && s_ready;
    wire run_ce = !(m_valid && !m_ready);

    assign s_ready = (state == ST_LOAD);

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem0 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr0),
        .rd_data(rd_pix0)
    );

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem1 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr1),
        .rd_data(rd_pix1)
    );

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem2 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr2),
        .rd_data(rd_pix2)
    );

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem3 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr3),
        .rd_data(rd_pix3)
    );

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem4 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr4),
        .rd_data(rd_pix4)
    );

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem5 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr5),
        .rd_data(rd_pix5)
    );

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem6 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr6),
        .rd_data(rd_pix6)
    );

    span_tinyspan_rgb888_frame_xpm_bram #(
        .DATA_W(DATA_W),
        .ADDR_W(LR_PIX_W),
        .DEPTH(FRAME_PIXELS)
    ) u_frame_mem7 (
        .clk(clk),
        .rst(rst),
        .wr_en(frame_wr_en),
        .wr_addr(load_pix),
        .wr_data(s_data),
        .rd_addr(rd_addr7),
        .rd_data(rd_pix7)
    );

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

    function automatic [LR_PIX_W-1:0] pixel_addr;
        input integer y;
        input integer x;
        integer cy;
        integer cx;
        begin
            cy = clamp_y(y);
            cx = clamp_x(x);
            pixel_addr = cy * IMG_W + cx;
        end
    endfunction

    function automatic [6:0] quant_stage_qbase;
        input signed [63:0] abs_num_i;
        input [6:0] q_i;
        input integer bit_i;
        reg [6:0] q_candidate;
        reg signed [63:0] threshold;
        begin
            q_candidate = q_i | (7'd1 << bit_i);
            threshold = (Q_DEN * $signed({1'b0, q_candidate})) - Q_HALF;
            quant_stage_qbase = (abs_num_i >= threshold) ? q_candidate : q_i;
        end
    endfunction

    function automatic signed [ACT_W-1:0] quant_to_qbase;
        input sign_i;
        input [6:0] q_abs_i;
        reg signed [8:0] q_signed;
        begin
            q_signed = sign_i ? -$signed({1'b0, q_abs_i}) : $signed({1'b0, q_abs_i});
            if (q_signed > 9'sd127)
                quant_to_qbase = 8'sd127;
            else if (q_signed < -9'sd128)
                quant_to_qbase = -8'sd128;
            else
                quant_to_qbase = q_signed[ACT_W-1:0];
        end
    endfunction

    task automatic issue_pair_at;
        input integer pair_index;
        input integer out_x;
        input integer out_y;
        integer sx_phase;
        integer sy_phase;
        integer src_x_floor;
        integer src_y_floor;
        integer ty0;
        integer ty1;
        begin
            sx_phase = out_x & 3;
            sy_phase = out_y & 3;
            src_x_floor = (out_x >>> 2) + ((sx_phase < 2) ? -1 : 0);
            src_y_floor = (out_y >>> 2) + ((sy_phase < 2) ? -1 : 0);
            ty0 = pair_index * 2;
            ty1 = ty0 + 1;

            rd_addr0 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor - 1);
            rd_addr1 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor);
            rd_addr2 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor + 1);
            rd_addr3 <= pixel_addr(src_y_floor - 1 + ty0, src_x_floor + 2);
            rd_addr4 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor - 1);
            rd_addr5 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor);
            rd_addr6 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor + 1);
            rd_addr7 <= pixel_addr(src_y_floor - 1 + ty1, src_x_floor + 2);

            wx0_d0 <= phase_coeff_q14(sx_phase, 0);
            wx1_d0 <= phase_coeff_q14(sx_phase, 1);
            wx2_d0 <= phase_coeff_q14(sx_phase, 2);
            wx3_d0 <= phase_coeff_q14(sx_phase, 3);
            wy0_d0 <= phase_coeff_q14(sy_phase, ty0);
            wy1_d0 <= phase_coeff_q14(sy_phase, ty1);
            pair_idx_d0 <= (pair_index == 0) ? 1'b0 : 1'b1;
            pair_user_d0 <= frame_user_q && (out_x == 0) && (out_y == 0);
            pair_last_d0 <= (out_x == HR_W - 1);
            pair_frame_done_d0 <= (out_x == HR_W - 1) && (out_y == HR_H - 1);
            pipe_valid_d0 <= 1'b1;
        end
    endtask

    task automatic begin_pixel_at;
        input integer out_x;
        input integer out_y;
        begin
            acc_r <= 64'sd0;
            acc_g <= 64'sd0;
            acc_b <= 64'sd0;
            issue_idx <= 2'd1;
            pipe_valid_d0 <= 1'b0;
            pipe_valid_d1 <= 1'b0;
            pipe_valid_d2 <= 1'b0;
            pair_idx_d0 <= 1'b0;
            pair_idx_d1 <= 1'b0;
            pair_idx_d2 <= 1'b0;
            issue_pair_at(0, out_x, out_y);
        end
    endtask

    task automatic begin_next_pixel;
        integer nx;
        integer ny;
        begin
            if ((emit_x == HR_W - 1) && (emit_y == HR_H - 1)) begin
                nx = 0;
                ny = 0;
            end else if (emit_x == HR_W - 1) begin
                nx = 0;
                ny = emit_y + 1;
            end else begin
                nx = emit_x + 1;
                ny = emit_y;
            end
            emit_x <= nx[HR_X_W-1:0];
            emit_y <= ny[HR_Y_W-1:0];
            begin_pixel_at(nx, ny);
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_LOAD;
            load_pix <= {LR_PIX_W{1'b0}};
            rd_addr0 <= {LR_PIX_W{1'b0}};
            rd_addr1 <= {LR_PIX_W{1'b0}};
            rd_addr2 <= {LR_PIX_W{1'b0}};
            rd_addr3 <= {LR_PIX_W{1'b0}};
            rd_addr4 <= {LR_PIX_W{1'b0}};
            rd_addr5 <= {LR_PIX_W{1'b0}};
            rd_addr6 <= {LR_PIX_W{1'b0}};
            rd_addr7 <= {LR_PIX_W{1'b0}};
            emit_x <= {HR_X_W{1'b0}};
            emit_y <= {HR_Y_W{1'b0}};
            frame_user_q <= 1'b0;
            frame_done_q <= 1'b0;
            issue_idx <= 2'd0;
            pipe_valid_d0 <= 1'b0;
            pipe_valid_d1 <= 1'b0;
            pipe_valid_d2 <= 1'b0;
            pair_idx_d0 <= 1'b0;
            pair_idx_d1 <= 1'b0;
            pair_idx_d2 <= 1'b0;
            pair_user_d0 <= 1'b0;
            pair_user_d1 <= 1'b0;
            pair_user_d2 <= 1'b0;
            pair_last_d0 <= 1'b0;
            pair_last_d1 <= 1'b0;
            pair_last_d2 <= 1'b0;
            pair_frame_done_d0 <= 1'b0;
            pair_frame_done_d1 <= 1'b0;
            pair_frame_done_d2 <= 1'b0;
            wx0_d0 <= 16'sd0;
            wx1_d0 <= 16'sd0;
            wx2_d0 <= 16'sd0;
            wx3_d0 <= 16'sd0;
            wy0_d0 <= 16'sd0;
            wy1_d0 <= 16'sd0;
            wx0_d1 <= 16'sd0;
            wx1_d1 <= 16'sd0;
            wx2_d1 <= 16'sd0;
            wx3_d1 <= 16'sd0;
            wy0_d1 <= 16'sd0;
            wy1_d1 <= 16'sd0;
            wx0_d2 <= 16'sd0;
            wx1_d2 <= 16'sd0;
            wx2_d2 <= 16'sd0;
            wx3_d2 <= 16'sd0;
            wy0_d2 <= 16'sd0;
            wy1_d2 <= 16'sd0;
            w00_d1 <= 32'sd0;
            w01_d1 <= 32'sd0;
            w02_d1 <= 32'sd0;
            w03_d1 <= 32'sd0;
            w10_d1 <= 32'sd0;
            w11_d1 <= 32'sd0;
            w12_d1 <= 32'sd0;
            w13_d1 <= 32'sd0;
            w00_d2 <= 32'sd0;
            w01_d2 <= 32'sd0;
            w02_d2 <= 32'sd0;
            w03_d2 <= 32'sd0;
            w10_d2 <= 32'sd0;
            w11_d2 <= 32'sd0;
            w12_d2 <= 32'sd0;
            w13_d2 <= 32'sd0;
            acc_r <= 64'sd0;
            acc_g <= 64'sd0;
            acc_b <= 64'sd0;
            pair_valid_q <= 1'b0;
            pair_idx_q <= 1'b0;
            pair_user_q <= 1'b0;
            pair_last_q <= 1'b0;
            pair_frame_done_q <= 1'b0;
            pair_r_q <= 64'sd0;
            pair_g_q <= 64'sd0;
            pair_b_q <= 64'sd0;
            m_valid <= 1'b0;
            m_rgb <= {3*ACT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
            m_frame_done_q <= 1'b0;
            for (qi = 0; qi <= Q_STAGES; qi = qi + 1) begin
                q_valid[qi] <= 1'b0;
                q_abs_r[qi] <= 64'sd0;
                q_abs_g[qi] <= 64'sd0;
                q_abs_b[qi] <= 64'sd0;
                q_sign_r[qi] <= 1'b0;
                q_sign_g[qi] <= 1'b0;
                q_sign_b[qi] <= 1'b0;
                q_code_r[qi] <= 7'd0;
                q_code_g[qi] <= 7'd0;
                q_code_b[qi] <= 7'd0;
                q_user[qi] <= 1'b0;
                q_last[qi] <= 1'b0;
                q_frame_done[qi] <= 1'b0;
            end
        end else if (run_ce) begin
            if (m_valid && m_ready) begin
                m_valid <= 1'b0;
                m_user <= 1'b0;
                m_last <= 1'b0;
                if (m_frame_done_q)
                    state <= ST_LOAD;
                m_frame_done_q <= 1'b0;
            end

            pipe_valid_d2 <= pipe_valid_d1;
            pair_idx_d2 <= pair_idx_d1;
            pair_user_d2 <= pair_user_d1;
            pair_last_d2 <= pair_last_d1;
            pair_frame_done_d2 <= pair_frame_done_d1;
            wx0_d2 <= wx0_d1;
            wx1_d2 <= wx1_d1;
            wx2_d2 <= wx2_d1;
            wx3_d2 <= wx3_d1;
            wy0_d2 <= wy0_d1;
            wy1_d2 <= wy1_d1;
            w00_d2 <= w00_d1;
            w01_d2 <= w01_d1;
            w02_d2 <= w02_d1;
            w03_d2 <= w03_d1;
            w10_d2 <= w10_d1;
            w11_d2 <= w11_d1;
            w12_d2 <= w12_d1;
            w13_d2 <= w13_d1;

            pipe_valid_d1 <= pipe_valid_d0;
            pair_idx_d1 <= pair_idx_d0;
            pair_user_d1 <= pair_user_d0;
            pair_last_d1 <= pair_last_d0;
            pair_frame_done_d1 <= pair_frame_done_d0;
            wx0_d1 <= wx0_d0;
            wx1_d1 <= wx1_d0;
            wx2_d1 <= wx2_d0;
            wx3_d1 <= wx3_d0;
            wy0_d1 <= wy0_d0;
            wy1_d1 <= wy1_d0;
            w00_d1 <= wx0_d0 * wy0_d0;
            w01_d1 <= wx1_d0 * wy0_d0;
            w02_d1 <= wx2_d0 * wy0_d0;
            w03_d1 <= wx3_d0 * wy0_d0;
            w10_d1 <= wx0_d0 * wy1_d0;
            w11_d1 <= wx1_d0 * wy1_d0;
            w12_d1 <= wx2_d0 * wy1_d0;
            w13_d1 <= wx3_d0 * wy1_d0;
            pipe_valid_d0 <= 1'b0;

            pair_valid_q <= 1'b0;
            if (pipe_valid_d2) begin
                row0_r = ($signed({1'b0, rd_pix0[23:16]}) * w00_d2) +
                         ($signed({1'b0, rd_pix1[23:16]}) * w01_d2) +
                         ($signed({1'b0, rd_pix2[23:16]}) * w02_d2) +
                         ($signed({1'b0, rd_pix3[23:16]}) * w03_d2);
                row0_g = ($signed({1'b0, rd_pix0[15:8]}) * w00_d2) +
                         ($signed({1'b0, rd_pix1[15:8]}) * w01_d2) +
                         ($signed({1'b0, rd_pix2[15:8]}) * w02_d2) +
                         ($signed({1'b0, rd_pix3[15:8]}) * w03_d2);
                row0_b = ($signed({1'b0, rd_pix0[7:0]}) * w00_d2) +
                         ($signed({1'b0, rd_pix1[7:0]}) * w01_d2) +
                         ($signed({1'b0, rd_pix2[7:0]}) * w02_d2) +
                         ($signed({1'b0, rd_pix3[7:0]}) * w03_d2);
                row1_r = ($signed({1'b0, rd_pix4[23:16]}) * w10_d2) +
                         ($signed({1'b0, rd_pix5[23:16]}) * w11_d2) +
                         ($signed({1'b0, rd_pix6[23:16]}) * w12_d2) +
                         ($signed({1'b0, rd_pix7[23:16]}) * w13_d2);
                row1_g = ($signed({1'b0, rd_pix4[15:8]}) * w10_d2) +
                         ($signed({1'b0, rd_pix5[15:8]}) * w11_d2) +
                         ($signed({1'b0, rd_pix6[15:8]}) * w12_d2) +
                         ($signed({1'b0, rd_pix7[15:8]}) * w13_d2);
                row1_b = ($signed({1'b0, rd_pix4[7:0]}) * w10_d2) +
                         ($signed({1'b0, rd_pix5[7:0]}) * w11_d2) +
                         ($signed({1'b0, rd_pix6[7:0]}) * w12_d2) +
                         ($signed({1'b0, rd_pix7[7:0]}) * w13_d2);

                pair_r_q <= row0_r + row1_r;
                pair_g_q <= row0_g + row1_g;
                pair_b_q <= row0_b + row1_b;
                pair_idx_q <= pair_idx_d2;
                pair_user_q <= pair_user_d2;
                pair_last_q <= pair_last_d2;
                pair_frame_done_q <= pair_frame_done_d2;
                pair_valid_q <= 1'b1;
            end

            q_valid[0] <= 1'b0;
            for (qi = 0; qi < Q_STAGES; qi = qi + 1) begin
                q_valid[qi+1] <= q_valid[qi];
                q_abs_r[qi+1] <= q_abs_r[qi];
                q_abs_g[qi+1] <= q_abs_g[qi];
                q_abs_b[qi+1] <= q_abs_b[qi];
                q_sign_r[qi+1] <= q_sign_r[qi];
                q_sign_g[qi+1] <= q_sign_g[qi];
                q_sign_b[qi+1] <= q_sign_b[qi];
                q_code_r[qi+1] <= quant_stage_qbase(q_abs_r[qi], q_code_r[qi], Q_STAGES - 1 - qi);
                q_code_g[qi+1] <= quant_stage_qbase(q_abs_g[qi], q_code_g[qi], Q_STAGES - 1 - qi);
                q_code_b[qi+1] <= quant_stage_qbase(q_abs_b[qi], q_code_b[qi], Q_STAGES - 1 - qi);
                q_user[qi+1] <= q_user[qi];
                q_last[qi+1] <= q_last[qi];
                q_frame_done[qi+1] <= q_frame_done[qi];
            end

            case (state)
                ST_LOAD: begin
                    pipe_valid_d0 <= 1'b0;
                    pipe_valid_d1 <= 1'b0;
                    pipe_valid_d2 <= 1'b0;
                    pair_valid_q <= 1'b0;
                    if (s_valid && s_ready) begin
                        if (load_pix == {LR_PIX_W{1'b0}})
                            frame_user_q <= s_user;

                        if (load_pix == FRAME_PIXELS - 1) begin
                            load_pix <= {LR_PIX_W{1'b0}};
                            emit_x <= {HR_X_W{1'b0}};
                            emit_y <= {HR_Y_W{1'b0}};
                            frame_done_q <= 1'b0;
                            begin_pixel_at(0, 0);
                            state <= ST_RUN;
                        end else begin
                            load_pix <= load_pix + 1'b1;
                        end
                    end
                end

                ST_RUN: begin
                    if (issue_idx < 2) begin
                        issue_pair_at(issue_idx, emit_x, emit_y);
                        issue_idx <= issue_idx + 1'b1;
                    end

                    if (pair_valid_q) begin
                        next_r = acc_r + pair_r_q;
                        next_g = acc_g + pair_g_q;
                        next_b = acc_b + pair_b_q;

                        if (pair_idx_q) begin
                            num_r = next_r * 64'sd127;
                            num_g = next_g * 64'sd127;
                            num_b = next_b * 64'sd127;
                            q_valid[0] <= 1'b1;
                            q_abs_r[0] <= (num_r < 64'sd0) ? -num_r : num_r;
                            q_abs_g[0] <= (num_g < 64'sd0) ? -num_g : num_g;
                            q_abs_b[0] <= (num_b < 64'sd0) ? -num_b : num_b;
                            q_sign_r[0] <= (num_r < 64'sd0);
                            q_sign_g[0] <= (num_g < 64'sd0);
                            q_sign_b[0] <= (num_b < 64'sd0);
                            q_code_r[0] <= 7'd0;
                            q_code_g[0] <= 7'd0;
                            q_code_b[0] <= 7'd0;
                            q_user[0] <= pair_user_q;
                            q_last[0] <= pair_last_q;
                            q_frame_done[0] <= pair_frame_done_q;

                            if (pair_frame_done_q) begin
                                issue_idx <= 2'd2;
                                state <= ST_DRAIN;
                            end else begin
                                begin_next_pixel();
                            end
                        end else begin
                            acc_r <= next_r;
                            acc_g <= next_g;
                            acc_b <= next_b;
                        end
                    end
                end

                ST_DRAIN: begin
                    pipe_valid_d0 <= 1'b0;
                end

                default: state <= ST_LOAD;
            endcase

            if (q_valid[Q_STAGES]) begin
                m_rgb[0*ACT_W +: ACT_W] <= quant_to_qbase(q_sign_r[Q_STAGES], q_code_r[Q_STAGES]);
                m_rgb[1*ACT_W +: ACT_W] <= quant_to_qbase(q_sign_g[Q_STAGES], q_code_g[Q_STAGES]);
                m_rgb[2*ACT_W +: ACT_W] <= quant_to_qbase(q_sign_b[Q_STAGES], q_code_b[Q_STAGES]);
                m_user <= q_user[Q_STAGES];
                m_last <= q_last[Q_STAGES];
                m_frame_done_q <= q_frame_done[Q_STAGES];
                m_valid <= 1'b1;
            end
        end
    end

    wire unused_last = s_last;
endmodule

module span_tinyspan_rgb888_frame_xpm_bram #(
    parameter integer DATA_W = 24,
    parameter integer ADDR_W = 16,
    parameter integer DEPTH = 57600
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  wr_en,
    input  wire [ADDR_W-1:0]     wr_addr,
    input  wire [DATA_W-1:0]     wr_data,
    input  wire [ADDR_W-1:0]     rd_addr,
    output wire [DATA_W-1:0]     rd_data
);
    xpm_memory_sdpram #(
        .MEMORY_SIZE(DATA_W * DEPTH),
        .MEMORY_PRIMITIVE("block"),
        .CLOCKING_MODE("common_clock"),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .USE_MEM_INIT(0),
        .WAKEUP_TIME("disable_sleep"),
        .MESSAGE_CONTROL(0),
        .WRITE_DATA_WIDTH_A(DATA_W),
        .BYTE_WRITE_WIDTH_A(DATA_W),
        .ADDR_WIDTH_A(ADDR_W),
        .READ_DATA_WIDTH_B(DATA_W),
        .ADDR_WIDTH_B(ADDR_W),
        .READ_RESET_VALUE_B("0"),
        .READ_LATENCY_B(2),
        .WRITE_MODE_B("read_first")
    ) u_xpm_memory_sdpram (
        .sleep(1'b0),
        .clka(clk),
        .ena(wr_en),
        .wea(wr_en),
        .addra(wr_addr),
        .dina(wr_data),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .clkb(clk),
        .rstb(rst),
        .enb(1'b1),
        .regceb(1'b1),
        .addrb(rd_addr),
        .doutb(rd_data),
        .sbiterrb(),
        .dbiterrb()
    );
endmodule
