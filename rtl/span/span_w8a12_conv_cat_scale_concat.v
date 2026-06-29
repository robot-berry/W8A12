`timescale 1ns/1ps

// Scale-bridge and concatenate the four SPAN skip features consumed by conv_cat.
//
// Channel order matches the trained SPAN tail:
//   feat0, conv_2(block6_out), block_1.out, block_6.act1
module span_w8a12_conv_cat_scale_concat #(
    parameter integer ACT_W = 12,
    parameter integer CH = 48,
    parameter integer SCALE_LANES = 2,
    parameter signed [63:0] FEAT0_Q31 = 64'sd2147483648,
    parameter signed [63:0] B6CONV_Q31 = 64'sd69288640,
    parameter signed [63:0] B1_Q31 = 64'sd1002444872,
    parameter signed [63:0] B6_ACT1_Q31 = 64'sd80461022
) (
    input  wire                           clk,
    input  wire                           rst,

    input  wire                           s_valid,
    output wire                           s_ready,
    input  wire signed [CH*ACT_W-1:0]     feat0_i,
    input  wire signed [CH*ACT_W-1:0]     b6conv_i,
    input  wire signed [CH*ACT_W-1:0]     b1_i,
    input  wire signed [CH*ACT_W-1:0]     b6_act1_i,
    input  wire                           s_user,
    input  wire                           s_last,

    output reg                            m_valid,
    input  wire                           m_ready,
    output reg signed [4*CH*ACT_W-1:0]    cat_o,
    output reg                            m_user,
    output reg                            m_last
);
    localparam signed [47:0] ROUND_OFFSET = 48'sd1073741824;
    localparam signed [47:0] SAT_MAX = (48'sd1 <<< (ACT_W - 1)) - 48'sd1;
    localparam signed [47:0] SAT_MIN = -(48'sd1 <<< (ACT_W - 1));
    localparam integer SCALE_TOTAL = 3 * CH;
    localparam integer SCALE_LANES_SAFE = (SCALE_LANES < 1) ? 1 : SCALE_LANES;
    localparam integer SCALE_IDX_W = (SCALE_TOTAL <= 1) ? 1 : $clog2(SCALE_TOTAL + 1);
    localparam integer CAT_CH = 4 * CH;
    localparam integer CAT_IDX_W = (CAT_CH <= 1) ? 1 : $clog2(CAT_CH);

    integer ch;
    integer lane;
    integer issue_channel;

    reg busy;
    reg [SCALE_IDX_W-1:0] issue_idx;
    reg signed [CH*ACT_W-1:0] b6conv_q;
    reg signed [CH*ACT_W-1:0] b1_q;
    reg signed [CH*ACT_W-1:0] b6_act1_q;
    reg user_q;
    reg last_q;
    reg [SCALE_LANES_SAFE-1:0] pipe_valid;
    reg signed [ACT_W-1:0] pipe_x [0:SCALE_LANES_SAFE-1];
    reg signed [31:0] pipe_mult [0:SCALE_LANES_SAFE-1];
    reg [CAT_IDX_W-1:0] pipe_dst [0:SCALE_LANES_SAFE-1];
    reg [SCALE_LANES_SAFE-1:0] prod_valid;
    reg signed [47:0] prod_value [0:SCALE_LANES_SAFE-1];
    reg [CAT_IDX_W-1:0] prod_dst [0:SCALE_LANES_SAFE-1];

    assign s_ready = !busy && (!m_valid || m_ready);

    function automatic signed [ACT_W-1:0] round_product;
        input signed [47:0] product;
        reg signed [47:0] rounded;
        reg signed [47:0] shifted;
        begin
            if (product >= 48'sd0) begin
                rounded = product + ROUND_OFFSET;
                shifted = rounded >>> 31;
            end else begin
                rounded = (-product) + ROUND_OFFSET;
                shifted = -(rounded >>> 31);
            end

            if (shifted > SAT_MAX)
                round_product = SAT_MAX[ACT_W-1:0];
            else if (shifted < SAT_MIN)
                round_product = SAT_MIN[ACT_W-1:0];
            else
                round_product = shifted[ACT_W-1:0];
        end
    endfunction

    function automatic signed [ACT_W-1:0] select_scale_x;
        input integer idx;
        begin
            if (idx < CH)
                select_scale_x = b6conv_q[idx*ACT_W +: ACT_W];
            else if (idx < (2 * CH))
                select_scale_x = b1_q[(idx - CH)*ACT_W +: ACT_W];
            else
                select_scale_x = b6_act1_q[(idx - 2 * CH)*ACT_W +: ACT_W];
        end
    endfunction

    function automatic signed [31:0] select_scale_mult;
        input integer idx;
        begin
            if (idx < CH)
                select_scale_mult = B6CONV_Q31[31:0];
            else if (idx < (2 * CH))
                select_scale_mult = B1_Q31[31:0];
            else
                select_scale_mult = B6_ACT1_Q31[31:0];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            m_valid <= 1'b0;
            cat_o <= {4*CH*ACT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
            busy <= 1'b0;
            issue_idx <= {SCALE_IDX_W{1'b0}};
            b6conv_q <= {CH*ACT_W{1'b0}};
            b1_q <= {CH*ACT_W{1'b0}};
            b6_act1_q <= {CH*ACT_W{1'b0}};
            user_q <= 1'b0;
            last_q <= 1'b0;
            pipe_valid <= {SCALE_LANES_SAFE{1'b0}};
            prod_valid <= {SCALE_LANES_SAFE{1'b0}};
            for (lane = 0; lane < SCALE_LANES_SAFE; lane = lane + 1) begin
                pipe_x[lane] <= {ACT_W{1'b0}};
                pipe_mult[lane] <= 32'sd0;
                pipe_dst[lane] <= {CAT_IDX_W{1'b0}};
                prod_value[lane] <= 48'sd0;
                prod_dst[lane] <= {CAT_IDX_W{1'b0}};
            end
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            for (lane = 0; lane < SCALE_LANES_SAFE; lane = lane + 1) begin
                if (prod_valid[lane])
                    cat_o[prod_dst[lane]*ACT_W +: ACT_W] <= round_product(prod_value[lane]);

                if (pipe_valid[lane]) begin
                    prod_value[lane] <= {{(48-ACT_W){pipe_x[lane][ACT_W-1]}}, pipe_x[lane]} *
                                        {{16{pipe_mult[lane][31]}}, pipe_mult[lane]};
                    prod_dst[lane] <= pipe_dst[lane];
                end else begin
                    prod_value[lane] <= 48'sd0;
                    prod_dst[lane] <= {CAT_IDX_W{1'b0}};
                end
            end
            prod_valid <= pipe_valid;
            pipe_valid <= {SCALE_LANES_SAFE{1'b0}};

            if (s_valid && s_ready) begin
                for (ch = 0; ch < CH; ch = ch + 1) begin
                    cat_o[ch*ACT_W +: ACT_W] <= feat0_i[ch*ACT_W +: ACT_W];
                end
                b6conv_q <= b6conv_i;
                b1_q <= b1_i;
                b6_act1_q <= b6_act1_i;
                user_q <= s_user;
                last_q <= s_last;
                issue_idx <= {SCALE_IDX_W{1'b0}};
                busy <= 1'b1;
            end else if (busy) begin
                for (lane = 0; lane < SCALE_LANES_SAFE; lane = lane + 1) begin
                    issue_channel = issue_idx + lane;
                    if (issue_channel < SCALE_TOTAL) begin
                        pipe_valid[lane] <= 1'b1;
                        pipe_x[lane] <= select_scale_x(issue_channel);
                        pipe_mult[lane] <= select_scale_mult(issue_channel);
                        pipe_dst[lane] <= CH + issue_channel;
                    end
                end

                if (issue_idx >= SCALE_TOTAL && pipe_valid == {SCALE_LANES_SAFE{1'b0}} && prod_valid != {SCALE_LANES_SAFE{1'b0}}) begin
                    busy <= 1'b0;
                    issue_idx <= {SCALE_IDX_W{1'b0}};
                    m_user <= user_q;
                    m_last <= last_q;
                    m_valid <= 1'b1;
                end else if (issue_idx < SCALE_TOTAL) begin
                    if ((issue_idx + SCALE_LANES_SAFE) >= SCALE_TOTAL)
                        issue_idx <= SCALE_TOTAL;
                    else
                        issue_idx <= issue_idx + SCALE_LANES_SAFE;
                end
            end
        end
    end
endmodule
