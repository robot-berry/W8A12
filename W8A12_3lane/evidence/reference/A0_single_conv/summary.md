# A0 Single Conv 3-Lane Reference

Status: PASS

## Config

- layer: `block_1.c1_r`
- shape: `4x4x48`
- lanes: `3 x 16ch`
- activation_bits: `12`
- bit_exact_lane_stitch: `True`

## Hashes

| Name | Value |
| --- | --- |
| `input_hash` | `0x47766845` |
| `lane0_hash` | `0xD21FCF34` |
| `lane1_hash` | `0xA25E2E5A` |
| `lane2_hash` | `0xE8914DF4` |
| `full48_hash` | `0x080D3C47` |
| `stitched_hash` | `0x080D3C47` |

## Outputs

- `input_feature_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\input_feature.npy`
- `full48_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\full48_output.npy`
- `lane0_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane0_output.npy`
- `lane1_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane1_output.npy`
- `lane2_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane2_output.npy`
- `sv_defines`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\a0_3lane_files.vh`

## Lane Mems

- `lane0.weight_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane0_block_1_c1_r_w_i8.mem`
- `lane0.bias_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane0_block_1_c1_r_bias_i64.mem`
- `lane0.requant_q31_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane0_block_1_c1_r_requant_q31.mem`
- `lane0.requant_shift_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane0_block_1_c1_r_requant_shift_u8.mem`
- `lane1.weight_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane1_block_1_c1_r_w_i8.mem`
- `lane1.bias_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane1_block_1_c1_r_bias_i64.mem`
- `lane1.requant_q31_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane1_block_1_c1_r_requant_q31.mem`
- `lane1.requant_shift_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane1_block_1_c1_r_requant_shift_u8.mem`
- `lane2.weight_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane2_block_1_c1_r_w_i8.mem`
- `lane2.bias_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane2_block_1_c1_r_bias_i64.mem`
- `lane2.requant_q31_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane2_block_1_c1_r_requant_q31.mem`
- `lane2.requant_shift_mem`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A0_single_conv\lane_mems\lane2_block_1_c1_r_requant_shift_u8.mem`
