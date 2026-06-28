# A3 Tail / PixelShuffle / RGB Python Reference

Status: PASS

## Config

- input shape: `4x4x48`
- scale: `x4`
- output shape: `16x16x3`
- activation_bits: `12`

## Cat Requant Q31

| Source | Multiplier |
| --- | --- |
| `feat0` | `2147483648` |
| `b6conv` | `69288640` |
| `b1` | `1002444872` |
| `b6_act1` | `80461022` |

## Hashes

| Name | Value |
| --- | --- |
| `feat0_hash` | `0x47766845` |
| `block_1_output_hash` | `0xD12E1B43` |
| `block_2_output_hash` | `0x8C609E9C` |
| `block_3_output_hash` | `0xF686415B` |
| `block_4_output_hash` | `0x110F1273` |
| `block_5_output_hash` | `0x0FB25029` |
| `block_6_output_hash` | `0xD2AC6553` |
| `conv2_hash` | `0x7C22A0C6` |
| `cat_input_hash` | `0x731D1CD9` |
| `conv_cat_hash` | `0xE6DF97F6` |
| `upsampler_0_hash` | `0x9630BB9C` |
| `rgb_q_hash` | `0x280F9356` |

## Outputs

- `feat0_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\feat0.npy`
- `block_1_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\block_1_output.npy`
- `block_2_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\block_2_output.npy`
- `block_3_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\block_3_output.npy`
- `block_4_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\block_4_output.npy`
- `block_5_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\block_5_output.npy`
- `block_6_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\block_6_output.npy`
- `conv2_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\conv2.npy`
- `cat_input_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\cat_input.npy`
- `conv_cat_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\conv_cat.npy`
- `upsampler_0_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\upsampler_0.npy`
- `rgb_q_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A3_tail_rgb\rgb_q.npy`
