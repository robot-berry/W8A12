`ifndef SPAN_W8A12_GENERATED_SELECT_VH
`define SPAN_W8A12_GENERATED_SELECT_VH

// Select the generated REDS SPAN constants used by the reusable W8A12-named
// streamed RTL. W8A10 export keeps the same macro names but points them at
// activation-10 scales, LUTs, and weight memories.
`ifdef REDS_SPAN_USE_W8A10_GENERATED
`include "../generated/reds_span_x4_f48_w8a10/span_w8a12_layers.vh"
`include "../generated/reds_span_x4_f48_w8a10/span_w8a12_rgb_norm.vh"
`include "../generated/reds_span_x4_f48_w8a10/postprocess/span_w8a12_postprocess.vh"
`define REDS_SPAN_ACTIVE_CONV_1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/conv_1_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_CONV_2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/conv_2_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_CONV_CAT_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/conv_cat_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_UPSAMPLER_0_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/upsampler_0_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_1_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_1_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_1_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_1_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_1_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_1_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_2_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_2_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_2_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_2_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_2_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_2_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_3_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_3_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_3_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_3_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_3_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_3_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_4_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_4_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_4_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_4_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_4_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_4_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_5_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_5_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_5_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_5_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_5_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_5_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_6_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_6_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_6_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_6_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_6_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a10/mem/block_6_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_CONV_CAT_FEAT0_Q31 64'sd2147483936
`define REDS_SPAN_ACTIVE_CONV_CAT_B6CONV_Q31 64'sd68961795
`define REDS_SPAN_ACTIVE_CONV_CAT_B1_Q31 64'sd1001432226
`define REDS_SPAN_ACTIVE_CONV_CAT_B6_ACT1_Q31 64'sd80517660
`else
`include "../generated/reds_span_x4_f48_w8a12/span_w8a12_layers.vh"
`include "../generated/reds_span_x4_f48_w8a12/span_w8a12_rgb_norm.vh"
`include "../generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess.vh"
`define REDS_SPAN_ACTIVE_CONV_1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/conv_1_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_CONV_2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/conv_2_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_CONV_CAT_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/conv_cat_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_UPSAMPLER_0_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/upsampler_0_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_1_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_1_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_1_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_1_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_1_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_1_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_2_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_2_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_2_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_2_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_2_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_2_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_3_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_3_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_3_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_3_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_3_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_3_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_4_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_4_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_4_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_4_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_4_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_4_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_5_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_5_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_5_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_5_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_5_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_5_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_6_C1_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_6_c1_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_6_C2_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_6_c2_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_BLOCK_6_C3_WEIGHT_GROUP_FILE "G:/UESTC/feitengspan1/rtl/generated/reds_span_x4_f48_w8a12/mem/block_6_c3_r_w_i8_group_ol8_tl16.mem"
`define REDS_SPAN_ACTIVE_CONV_CAT_FEAT0_Q31 64'sd2147483648
`define REDS_SPAN_ACTIVE_CONV_CAT_B6CONV_Q31 64'sd69288640
`define REDS_SPAN_ACTIVE_CONV_CAT_B1_Q31 64'sd1002444872
`define REDS_SPAN_ACTIVE_CONV_CAT_B6_ACT1_Q31 64'sd80461022
`endif

`endif
