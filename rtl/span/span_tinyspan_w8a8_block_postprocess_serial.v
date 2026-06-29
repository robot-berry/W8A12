`timescale 1ns/1ps

// Lane-serial TinySPAN W8A8 block postprocess. It computes the same per-channel
// function as the parallel form while using one LUT/add/mul lane.
module span_tinyspan_w8a8_block_postprocess_serial #(
    parameter integer ACT_W = 8,
    parameter integer CH = 32,
    parameter SIM_ATT_LUT_FILE = "",
    parameter signed [63:0] SUM_A_Q31 = 64'sd0,
    parameter signed [63:0] SUM_B_Q31 = 64'sd0,
    parameter integer SUM_SHIFT = 31,
    parameter signed [63:0] MUL_Q31 = 64'sd0,
    parameter integer MUL_SHIFT = 31
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_c3_feat,
    input  wire signed [CH*ACT_W-1:0]   s_residual_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output reg                          m_valid,
    input  wire                         m_ready,
    output wire signed [CH*ACT_W-1:0]   m_feat,
    output reg                          m_user,
    output reg                          m_last
);
    localparam integer CH_IDX_W = (CH <= 2) ? 1 : $clog2(CH);

    reg busy;
    reg [CH_IDX_W-1:0] ch_idx;
    reg signed [CH*ACT_W-1:0] c3_reg;
    reg signed [CH*ACT_W-1:0] residual_reg;
    reg signed [CH*ACT_W-1:0] out_reg;
    reg user_reg;
    reg last_reg;

    wire can_accept = !busy && (!m_valid || m_ready);
    assign s_ready = can_accept;
    assign m_feat = out_reg;

    wire signed [ACT_W-1:0] c3_lane = c3_reg[ch_idx*ACT_W +: ACT_W];
    wire signed [ACT_W-1:0] residual_lane = residual_reg[ch_idx*ACT_W +: ACT_W];
    wire signed [ACT_W-1:0] sim_lane;
    wire signed [ACT_W-1:0] sum_lane;
    wire signed [ACT_W-1:0] out_lane;

    span_w8a12_unary_lut #(
        .ACT_W(ACT_W),
        .LUT_FILE(SIM_ATT_LUT_FILE)
    ) u_sim_lut (
        .x_i(c3_lane),
        .y_o(sim_lane)
    );

    span_tinyspan_w8a8_scale_add_q31 #(
        .ACT_W(ACT_W),
        .SHIFT(SUM_SHIFT),
        .A_Q31(SUM_A_Q31),
        .B_Q31(SUM_B_Q31)
    ) u_sum (
        .a_i(c3_lane),
        .b_i(residual_lane),
        .q_o(sum_lane)
    );

    span_tinyspan_w8a8_scale_mul_q31 #(
        .ACT_W(ACT_W),
        .SHIFT(MUL_SHIFT),
        .MUL_Q31(MUL_Q31)
    ) u_mul (
        .a_i(sum_lane),
        .b_i(sim_lane),
        .q_o(out_lane)
    );

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            ch_idx <= {CH_IDX_W{1'b0}};
            c3_reg <= {CH*ACT_W{1'b0}};
            residual_reg <= {CH*ACT_W{1'b0}};
            out_reg <= {CH*ACT_W{1'b0}};
            user_reg <= 1'b0;
            last_reg <= 1'b0;
            m_valid <= 1'b0;
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            if (can_accept && s_valid) begin
                busy <= 1'b1;
                ch_idx <= {CH_IDX_W{1'b0}};
                c3_reg <= s_c3_feat;
                residual_reg <= s_residual_feat;
                user_reg <= s_user;
                last_reg <= s_last;
            end else if (busy) begin
                out_reg[ch_idx*ACT_W +: ACT_W] <= out_lane;
                if (ch_idx == CH - 1) begin
                    busy <= 1'b0;
                    m_valid <= 1'b1;
                    m_user <= user_reg;
                    m_last <= last_reg;
                end else begin
                    ch_idx <= ch_idx + 1'b1;
                end
            end
        end
    end
endmodule
