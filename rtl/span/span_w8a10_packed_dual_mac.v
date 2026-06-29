`timescale 1ns/1ps

// W8A10 two-lane packed MAC prototype.
//
// Computes two signed products that share one signed activation:
//
//   acc0_o = acc0_i + act_i * weight0_i
//   acc1_o = acc1_i + act_i * weight1_i
//
// The implementation performs one unsigned packed multiply using the absolute
// value of the activation, then corrects the two unsigned weight lanes back to
// signed int8 products. This is the small proof point for the full-SPAN W8A10
// realtime branch; the frame engine will need many instances of this pattern.
module span_w8a10_packed_dual_mac #(
    parameter integer ACT_W = 10,
    parameter integer WEIGHT_W = 8,
    parameter integer ACC_W = 48,
    parameter integer PACK_SHIFT = 19,
    parameter integer PIPELINE = 1
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [ACT_W-1:0]      act_i,
    input  wire signed [WEIGHT_W-1:0]   weight0_i,
    input  wire signed [WEIGHT_W-1:0]   weight1_i,
    input  wire signed [ACC_W-1:0]      acc0_i,
    input  wire signed [ACC_W-1:0]      acc1_i,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire signed [ACC_W-1:0]      acc0_o,
    output wire signed [ACC_W-1:0]      acc1_o
);
    localparam integer PACKED_W = PACK_SHIFT + WEIGHT_W;
    localparam integer PROD_MAG_W = ACT_W + PACKED_W;
    localparam integer PROD_SIGNED_W = PROD_MAG_W + 1;
    localparam integer PRODUCT_W = ACT_W + WEIGHT_W;

    initial begin
        if (PACK_SHIFT < PRODUCT_W + 1) begin
            $error("PACK_SHIFT must leave one guard bit between packed products");
        end
        if (PACKED_W > 27) begin
            $error("packed weight operand exceeds DSP48E2 A-port planning width");
        end
    end

    wire [ACT_W-1:0] act_bits_u = act_i[ACT_W-1:0];
    wire [ACT_W-1:0] act_abs_u =
        act_i[ACT_W-1] ? (~act_bits_u + {{(ACT_W-1){1'b0}}, 1'b1}) : act_bits_u;

    wire [WEIGHT_W-1:0] weight0_u = weight0_i[WEIGHT_W-1:0];
    wire [WEIGHT_W-1:0] weight1_u = weight1_i[WEIGHT_W-1:0];
    wire [PACKED_W-1:0] packed_weight_u =
        {weight1_u, {(PACK_SHIFT-WEIGHT_W){1'b0}}, weight0_u};

    wire [PROD_MAG_W-1:0] product_mag_u = act_abs_u * packed_weight_u;
    wire signed [PROD_SIGNED_W-1:0] packed_product_s =
        act_i[ACT_W-1] ? -$signed({1'b0, product_mag_u}) : $signed({1'b0, product_mag_u});

    wire signed [PROD_SIGNED_W-1:0] lane0_unsigned_product_s =
        {{(PROD_SIGNED_W-PACK_SHIFT){packed_product_s[PACK_SHIFT-1]}},
          packed_product_s[PACK_SHIFT-1:0]};
    wire signed [PROD_SIGNED_W-1:0] lane1_unsigned_product_s =
        (packed_product_s - lane0_unsigned_product_s) >>> PACK_SHIFT;

    wire signed [ACC_W-1:0] act_acc_s =
        {{(ACC_W-ACT_W){act_i[ACT_W-1]}}, act_i};
    wire signed [ACC_W-1:0] signed_weight_correction_s = act_acc_s <<< WEIGHT_W;

    wire signed [ACC_W-1:0] lane0_unsigned_product_acc_s =
        {{(ACC_W-PROD_SIGNED_W){lane0_unsigned_product_s[PROD_SIGNED_W-1]}},
          lane0_unsigned_product_s};
    wire signed [ACC_W-1:0] lane1_unsigned_product_acc_s =
        {{(ACC_W-PROD_SIGNED_W){lane1_unsigned_product_s[PROD_SIGNED_W-1]}},
          lane1_unsigned_product_s};

    wire signed [ACC_W-1:0] product0_s =
        lane0_unsigned_product_acc_s -
        (weight0_i[WEIGHT_W-1] ? signed_weight_correction_s : {ACC_W{1'b0}});
    wire signed [ACC_W-1:0] product1_s =
        lane1_unsigned_product_acc_s -
        (weight1_i[WEIGHT_W-1] ? signed_weight_correction_s : {ACC_W{1'b0}});

    wire signed [ACC_W-1:0] acc0_comb = acc0_i + product0_s;
    wire signed [ACC_W-1:0] acc1_comb = acc1_i + product1_s;

    generate
        if (PIPELINE > 1) begin : g_pipe2
            reg valid_s1_q;
            reg valid_s2_q;
            reg signed [PROD_SIGNED_W-1:0] packed_product_q;
            reg signed [ACC_W-1:0] act_acc_q;
            reg weight0_sign_q;
            reg weight1_sign_q;
            reg signed [ACC_W-1:0] acc0_i_q;
            reg signed [ACC_W-1:0] acc1_i_q;
            reg signed [ACC_W-1:0] acc0_q;
            reg signed [ACC_W-1:0] acc1_q;

            wire stage2_ready = !valid_s2_q || m_ready;
            wire stage1_ready = !valid_s1_q || stage2_ready;

            wire signed [PROD_SIGNED_W-1:0] lane0_unsigned_product_q =
                {{(PROD_SIGNED_W-PACK_SHIFT){packed_product_q[PACK_SHIFT-1]}},
                  packed_product_q[PACK_SHIFT-1:0]};
            wire signed [PROD_SIGNED_W-1:0] lane1_unsigned_product_q =
                (packed_product_q - lane0_unsigned_product_q) >>> PACK_SHIFT;
            wire signed [ACC_W-1:0] signed_weight_correction_q = act_acc_q <<< WEIGHT_W;
            wire signed [ACC_W-1:0] lane0_unsigned_product_acc_q =
                {{(ACC_W-PROD_SIGNED_W){lane0_unsigned_product_q[PROD_SIGNED_W-1]}},
                  lane0_unsigned_product_q};
            wire signed [ACC_W-1:0] lane1_unsigned_product_acc_q =
                {{(ACC_W-PROD_SIGNED_W){lane1_unsigned_product_q[PROD_SIGNED_W-1]}},
                  lane1_unsigned_product_q};
            wire signed [ACC_W-1:0] product0_q =
                lane0_unsigned_product_acc_q -
                (weight0_sign_q ? signed_weight_correction_q : {ACC_W{1'b0}});
            wire signed [ACC_W-1:0] product1_q =
                lane1_unsigned_product_acc_q -
                (weight1_sign_q ? signed_weight_correction_q : {ACC_W{1'b0}});

            assign s_ready = stage1_ready;
            assign m_valid = valid_s2_q;
            assign acc0_o = acc0_q;
            assign acc1_o = acc1_q;

            always @(posedge clk) begin
                if (rst) begin
                    valid_s1_q <= 1'b0;
                    valid_s2_q <= 1'b0;
                    packed_product_q <= {PROD_SIGNED_W{1'b0}};
                    act_acc_q <= {ACC_W{1'b0}};
                    weight0_sign_q <= 1'b0;
                    weight1_sign_q <= 1'b0;
                    acc0_i_q <= {ACC_W{1'b0}};
                    acc1_i_q <= {ACC_W{1'b0}};
                    acc0_q <= {ACC_W{1'b0}};
                    acc1_q <= {ACC_W{1'b0}};
                end else begin
                    if (stage2_ready) begin
                        valid_s2_q <= valid_s1_q;
                        if (valid_s1_q) begin
                            acc0_q <= acc0_i_q + product0_q;
                            acc1_q <= acc1_i_q + product1_q;
                        end
                    end

                    if (stage1_ready) begin
                        valid_s1_q <= s_valid;
                        if (s_valid) begin
                            packed_product_q <= packed_product_s;
                            act_acc_q <= act_acc_s;
                            weight0_sign_q <= weight0_i[WEIGHT_W-1];
                            weight1_sign_q <= weight1_i[WEIGHT_W-1];
                            acc0_i_q <= acc0_i;
                            acc1_i_q <= acc1_i;
                        end
                    end
                end
            end
        end else if (PIPELINE != 0) begin : g_pipe
            reg valid_q;
            reg signed [ACC_W-1:0] acc0_q;
            reg signed [ACC_W-1:0] acc1_q;

            assign s_ready = !valid_q || m_ready;
            assign m_valid = valid_q;
            assign acc0_o = acc0_q;
            assign acc1_o = acc1_q;

            always @(posedge clk) begin
                if (rst) begin
                    valid_q <= 1'b0;
                    acc0_q <= {ACC_W{1'b0}};
                    acc1_q <= {ACC_W{1'b0}};
                end else if (s_ready) begin
                    valid_q <= s_valid;
                    if (s_valid) begin
                        acc0_q <= acc0_comb;
                        acc1_q <= acc1_comb;
                    end
                end
            end
        end else begin : g_comb
            assign s_ready = m_ready;
            assign m_valid = s_valid;
            assign acc0_o = acc0_comb;
            assign acc1_o = acc1_comb;
        end
    endgenerate
endmodule
