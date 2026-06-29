`timescale 1ns/1ps
`include "../generated/official_span_model_config.vh"
`include "../generated/official_span_layers.vh"

// 瀹樻柟 SPAN 閮ㄧ讲鏉冮噸閾惰銆?//
// 灏嗗鍑虹殑 44 涓?.mem 寮犻噺鏁寸悊鎴愮粺涓€鐨?Verilog 璇绘帴鍙ｏ細
//   layer_id 閫夋嫨鍗风Н灞傦紱
//   weight_addr 閫夋嫨璇ュ眰灞曞紑鍚庣殑鏉冮噸鍏冪礌锛?//   bias_addr 閫夋嫨璇ュ眰杈撳嚭閫氶亾 bias銆?//
// layer_id 绾﹀畾锛?//   0  conv_1.eval_conv
//   1  block_1.c1_r.eval_conv
//   2  block_1.c2_r.eval_conv
//   3  block_1.c3_r.eval_conv
//   ...
//   18 block_6.c3_r.eval_conv
//   19 conv_2.eval_conv
//   20 conv_cat
//   21 upsampler.0
module span_official_weight_bank #(
    parameter integer CH = `OFFICIAL_SPAN_FEATURE_CHANNELS,
    parameter integer SCALE = `OFFICIAL_SPAN_MODEL_SCALE,
    parameter integer SYNC_READ = 0
) (
    input  wire        clk,
    input  wire [4:0]  layer_id,
    input  wire [15:0] weight_addr,
    input  wire [7:0]  bias_addr,
    output reg signed [7:0] weight_o,
    output reg signed [7:0] bias_o
);
    localparam integer CONV1_WEIGHT_COUNT = CH * 3 * 9;
    localparam integer CONV_WEIGHT_COUNT  = CH * CH * 9;
    localparam integer CAT_WEIGHT_COUNT   = CH * CH * 4;
    localparam integer UP_OUT_CH          = 3 * SCALE * SCALE;
    localparam integer UP_WEIGHT_COUNT    = UP_OUT_CH * CH * 9;

    (* rom_style = "block" *) reg signed [7:0] conv1_w [0:CONV1_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] conv1_b [0:CH-1];

    (* rom_style = "block" *) reg signed [7:0] b1_c1_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b1_c1_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b1_c2_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b1_c2_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b1_c3_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b1_c3_b [0:CH-1];

    (* rom_style = "block" *) reg signed [7:0] b2_c1_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b2_c1_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b2_c2_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b2_c2_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b2_c3_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b2_c3_b [0:CH-1];

    (* rom_style = "block" *) reg signed [7:0] b3_c1_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b3_c1_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b3_c2_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b3_c2_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b3_c3_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b3_c3_b [0:CH-1];

    (* rom_style = "block" *) reg signed [7:0] b4_c1_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b4_c1_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b4_c2_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b4_c2_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b4_c3_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b4_c3_b [0:CH-1];

    (* rom_style = "block" *) reg signed [7:0] b5_c1_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b5_c1_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b5_c2_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b5_c2_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b5_c3_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b5_c3_b [0:CH-1];

    (* rom_style = "block" *) reg signed [7:0] b6_c1_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b6_c1_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b6_c2_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b6_c2_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] b6_c3_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] b6_c3_b [0:CH-1];

    (* rom_style = "block" *) reg signed [7:0] conv2_w [0:CONV_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] conv2_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] cat_w [0:CAT_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] cat_b [0:CH-1];
    (* rom_style = "block" *) reg signed [7:0] up_w [0:UP_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [7:0] up_b [0:UP_OUT_CH-1];

    integer i;
    initial begin
        for (i = 0; i < CONV1_WEIGHT_COUNT; i = i + 1) conv1_w[i] = 8'sd0;
        for (i = 0; i < CH; i = i + 1) conv1_b[i] = 8'sd0;

        for (i = 0; i < CONV_WEIGHT_COUNT; i = i + 1) begin
            b1_c1_w[i] = 8'sd0; b1_c2_w[i] = 8'sd0; b1_c3_w[i] = 8'sd0;
            b2_c1_w[i] = 8'sd0; b2_c2_w[i] = 8'sd0; b2_c3_w[i] = 8'sd0;
            b3_c1_w[i] = 8'sd0; b3_c2_w[i] = 8'sd0; b3_c3_w[i] = 8'sd0;
            b4_c1_w[i] = 8'sd0; b4_c2_w[i] = 8'sd0; b4_c3_w[i] = 8'sd0;
            b5_c1_w[i] = 8'sd0; b5_c2_w[i] = 8'sd0; b5_c3_w[i] = 8'sd0;
            b6_c1_w[i] = 8'sd0; b6_c2_w[i] = 8'sd0; b6_c3_w[i] = 8'sd0;
            conv2_w[i] = 8'sd0;
        end
        for (i = 0; i < CH; i = i + 1) begin
            b1_c1_b[i] = 8'sd0; b1_c2_b[i] = 8'sd0; b1_c3_b[i] = 8'sd0;
            b2_c1_b[i] = 8'sd0; b2_c2_b[i] = 8'sd0; b2_c3_b[i] = 8'sd0;
            b3_c1_b[i] = 8'sd0; b3_c2_b[i] = 8'sd0; b3_c3_b[i] = 8'sd0;
            b4_c1_b[i] = 8'sd0; b4_c2_b[i] = 8'sd0; b4_c3_b[i] = 8'sd0;
            b5_c1_b[i] = 8'sd0; b5_c2_b[i] = 8'sd0; b5_c3_b[i] = 8'sd0;
            b6_c1_b[i] = 8'sd0; b6_c2_b[i] = 8'sd0; b6_c3_b[i] = 8'sd0;
            conv2_b[i] = 8'sd0; cat_b[i] = 8'sd0;
        end
        for (i = 0; i < CAT_WEIGHT_COUNT; i = i + 1) cat_w[i] = 8'sd0;
        for (i = 0; i < UP_WEIGHT_COUNT; i = i + 1) up_w[i] = 8'sd0;
        for (i = 0; i < UP_OUT_CH; i = i + 1) up_b[i] = 8'sd0;

        $readmemh(`OFFICIAL_SPAN_LAYER_0_FILE, conv1_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_1_FILE, conv1_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_2_FILE, b1_c1_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_3_FILE, b1_c1_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_4_FILE, b1_c2_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_5_FILE, b1_c2_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_6_FILE, b1_c3_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_7_FILE, b1_c3_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_8_FILE, b2_c1_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_9_FILE, b2_c1_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_10_FILE, b2_c2_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_11_FILE, b2_c2_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_12_FILE, b2_c3_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_13_FILE, b2_c3_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_14_FILE, b3_c1_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_15_FILE, b3_c1_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_16_FILE, b3_c2_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_17_FILE, b3_c2_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_18_FILE, b3_c3_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_19_FILE, b3_c3_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_20_FILE, b4_c1_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_21_FILE, b4_c1_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_22_FILE, b4_c2_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_23_FILE, b4_c2_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_24_FILE, b4_c3_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_25_FILE, b4_c3_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_26_FILE, b5_c1_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_27_FILE, b5_c1_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_28_FILE, b5_c2_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_29_FILE, b5_c2_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_30_FILE, b5_c3_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_31_FILE, b5_c3_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_32_FILE, b6_c1_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_33_FILE, b6_c1_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_34_FILE, b6_c2_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_35_FILE, b6_c2_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_36_FILE, b6_c3_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_37_FILE, b6_c3_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_40_FILE, conv2_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_41_FILE, conv2_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_38_FILE, cat_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_39_FILE, cat_b);
        $readmemh(`OFFICIAL_SPAN_LAYER_42_FILE, up_w);
        $readmemh(`OFFICIAL_SPAN_LAYER_43_FILE, up_b);
    end

    generate
        if (SYNC_READ != 0) begin : g_sync_weight_read
            reg signed [7:0] conv1_w_q;
            reg signed [7:0] b1_c1_w_q;
            reg signed [7:0] b1_c2_w_q;
            reg signed [7:0] b1_c3_w_q;
            reg signed [7:0] b2_c1_w_q;
            reg signed [7:0] b2_c2_w_q;
            reg signed [7:0] b2_c3_w_q;
            reg signed [7:0] b3_c1_w_q;
            reg signed [7:0] b3_c2_w_q;
            reg signed [7:0] b3_c3_w_q;
            reg signed [7:0] b4_c1_w_q;
            reg signed [7:0] b4_c2_w_q;
            reg signed [7:0] b4_c3_w_q;
            reg signed [7:0] b5_c1_w_q;
            reg signed [7:0] b5_c2_w_q;
            reg signed [7:0] b5_c3_w_q;
            reg signed [7:0] b6_c1_w_q;
            reg signed [7:0] b6_c2_w_q;
            reg signed [7:0] b6_c3_w_q;
            reg signed [7:0] conv2_w_q;
            reg signed [7:0] cat_w_q;
            reg signed [7:0] up_w_q;

            always @(posedge clk) begin
                conv1_w_q <= (weight_addr < CONV1_WEIGHT_COUNT) ? conv1_w[weight_addr] : 8'sd0;

                b1_c1_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b1_c1_w[weight_addr] : 8'sd0;
                b1_c2_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b1_c2_w[weight_addr] : 8'sd0;
                b1_c3_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b1_c3_w[weight_addr] : 8'sd0;
                b2_c1_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b2_c1_w[weight_addr] : 8'sd0;
                b2_c2_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b2_c2_w[weight_addr] : 8'sd0;
                b2_c3_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b2_c3_w[weight_addr] : 8'sd0;
                b3_c1_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b3_c1_w[weight_addr] : 8'sd0;
                b3_c2_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b3_c2_w[weight_addr] : 8'sd0;
                b3_c3_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b3_c3_w[weight_addr] : 8'sd0;
                b4_c1_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b4_c1_w[weight_addr] : 8'sd0;
                b4_c2_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b4_c2_w[weight_addr] : 8'sd0;
                b4_c3_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b4_c3_w[weight_addr] : 8'sd0;
                b5_c1_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b5_c1_w[weight_addr] : 8'sd0;
                b5_c2_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b5_c2_w[weight_addr] : 8'sd0;
                b5_c3_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b5_c3_w[weight_addr] : 8'sd0;
                b6_c1_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b6_c1_w[weight_addr] : 8'sd0;
                b6_c2_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b6_c2_w[weight_addr] : 8'sd0;
                b6_c3_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? b6_c3_w[weight_addr] : 8'sd0;
                conv2_w_q <= (weight_addr < CONV_WEIGHT_COUNT) ? conv2_w[weight_addr] : 8'sd0;
                cat_w_q <= (weight_addr < CAT_WEIGHT_COUNT) ? cat_w[weight_addr] : 8'sd0;
                up_w_q <= (weight_addr < UP_WEIGHT_COUNT) ? up_w[weight_addr] : 8'sd0;
            end

            always @(*) begin
                weight_o = 8'sd0;
                case (layer_id)
                    5'd0:  weight_o = conv1_w_q;
                    5'd1:  weight_o = b1_c1_w_q;
                    5'd2:  weight_o = b1_c2_w_q;
                    5'd3:  weight_o = b1_c3_w_q;
                    5'd4:  weight_o = b2_c1_w_q;
                    5'd5:  weight_o = b2_c2_w_q;
                    5'd6:  weight_o = b2_c3_w_q;
                    5'd7:  weight_o = b3_c1_w_q;
                    5'd8:  weight_o = b3_c2_w_q;
                    5'd9:  weight_o = b3_c3_w_q;
                    5'd10: weight_o = b4_c1_w_q;
                    5'd11: weight_o = b4_c2_w_q;
                    5'd12: weight_o = b4_c3_w_q;
                    5'd13: weight_o = b5_c1_w_q;
                    5'd14: weight_o = b5_c2_w_q;
                    5'd15: weight_o = b5_c3_w_q;
                    5'd16: weight_o = b6_c1_w_q;
                    5'd17: weight_o = b6_c2_w_q;
                    5'd18: weight_o = b6_c3_w_q;
                    5'd19: weight_o = conv2_w_q;
                    5'd20: weight_o = cat_w_q;
                    5'd21: weight_o = up_w_q;
                    default: weight_o = 8'sd0;
                endcase
            end
        end else begin : g_comb_weight_read
            always @(*) begin
                weight_o = 8'sd0;
                case (layer_id)
                    5'd0:  if (weight_addr < CONV1_WEIGHT_COUNT) weight_o = conv1_w[weight_addr];
                    5'd1:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b1_c1_w[weight_addr];
                    5'd2:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b1_c2_w[weight_addr];
                    5'd3:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b1_c3_w[weight_addr];
                    5'd4:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b2_c1_w[weight_addr];
                    5'd5:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b2_c2_w[weight_addr];
                    5'd6:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b2_c3_w[weight_addr];
                    5'd7:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b3_c1_w[weight_addr];
                    5'd8:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b3_c2_w[weight_addr];
                    5'd9:  if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b3_c3_w[weight_addr];
                    5'd10: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b4_c1_w[weight_addr];
                    5'd11: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b4_c2_w[weight_addr];
                    5'd12: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b4_c3_w[weight_addr];
                    5'd13: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b5_c1_w[weight_addr];
                    5'd14: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b5_c2_w[weight_addr];
                    5'd15: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b5_c3_w[weight_addr];
                    5'd16: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b6_c1_w[weight_addr];
                    5'd17: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b6_c2_w[weight_addr];
                    5'd18: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = b6_c3_w[weight_addr];
                    5'd19: if (weight_addr < CONV_WEIGHT_COUNT) weight_o = conv2_w[weight_addr];
                    5'd20: if (weight_addr < CAT_WEIGHT_COUNT) weight_o = cat_w[weight_addr];
                    5'd21: if (weight_addr < UP_WEIGHT_COUNT) weight_o = up_w[weight_addr];
                    default: weight_o = 8'sd0;
                endcase
            end
        end
    endgenerate

    always @(*) begin
        bias_o = 8'sd0;
        case (layer_id)
            5'd0:  if (bias_addr < CH) bias_o = conv1_b[bias_addr];
            5'd1:  if (bias_addr < CH) bias_o = b1_c1_b[bias_addr];
            5'd2:  if (bias_addr < CH) bias_o = b1_c2_b[bias_addr];
            5'd3:  if (bias_addr < CH) bias_o = b1_c3_b[bias_addr];
            5'd4:  if (bias_addr < CH) bias_o = b2_c1_b[bias_addr];
            5'd5:  if (bias_addr < CH) bias_o = b2_c2_b[bias_addr];
            5'd6:  if (bias_addr < CH) bias_o = b2_c3_b[bias_addr];
            5'd7:  if (bias_addr < CH) bias_o = b3_c1_b[bias_addr];
            5'd8:  if (bias_addr < CH) bias_o = b3_c2_b[bias_addr];
            5'd9:  if (bias_addr < CH) bias_o = b3_c3_b[bias_addr];
            5'd10: if (bias_addr < CH) bias_o = b4_c1_b[bias_addr];
            5'd11: if (bias_addr < CH) bias_o = b4_c2_b[bias_addr];
            5'd12: if (bias_addr < CH) bias_o = b4_c3_b[bias_addr];
            5'd13: if (bias_addr < CH) bias_o = b5_c1_b[bias_addr];
            5'd14: if (bias_addr < CH) bias_o = b5_c2_b[bias_addr];
            5'd15: if (bias_addr < CH) bias_o = b5_c3_b[bias_addr];
            5'd16: if (bias_addr < CH) bias_o = b6_c1_b[bias_addr];
            5'd17: if (bias_addr < CH) bias_o = b6_c2_b[bias_addr];
            5'd18: if (bias_addr < CH) bias_o = b6_c3_b[bias_addr];
            5'd19: if (bias_addr < CH) bias_o = conv2_b[bias_addr];
            5'd20: if (bias_addr < CH) bias_o = cat_b[bias_addr];
            5'd21: if (bias_addr < UP_OUT_CH) bias_o = up_b[bias_addr];
            default: bias_o = 8'sd0;
        endcase
    end
endmodule
