# A3 Tail / PixelShuffle / RGB Python Reference

Status: PASS

## Config

- input shape: `4x4x48`
- scale: `x2`
- output shape: `8x8x3`
- activation_bits: `12`

## Cat Requant Q31

| Source | Multiplier |
| --- | --- |
| `feat0` | `2147483648` |
| `b6conv` | `67832288` |
| `b1` | `268709160` |
| `b6_act1` | `96093968` |

## Hashes

| Name | Value |
| --- | --- |
| `feat0_hash` | `0x47766845` |
| `block_1_output_hash` | `0xECD1EB47` |
| `block_2_output_hash` | `0xD6AB151A` |
| `block_3_output_hash` | `0xBFC9491E` |
| `block_4_output_hash` | `0xABAFDDBD` |
| `block_5_output_hash` | `0xC3CD6915` |
| `block_6_output_hash` | `0x3ED6294C` |
| `conv2_hash` | `0x614DE95E` |
| `cat_input_hash` | `0x4FEA4056` |
| `conv_cat_hash` | `0x070AB9D1` |
| `upsampler_0_hash` | `0x3366C77D` |
| `rgb_q_hash` | `0xBC30F107` |

## Outputs

- `feat0_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\feat0.npy`
- `block_1_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\block_1_output.npy`
- `block_2_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\block_2_output.npy`
- `block_3_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\block_3_output.npy`
- `block_4_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\block_4_output.npy`
- `block_5_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\block_5_output.npy`
- `block_6_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\block_6_output.npy`
- `conv2_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\conv2.npy`
- `cat_input_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\cat_input.npy`
- `conv_cat_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\conv_cat.npy`
- `upsampler_0_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\upsampler_0.npy`
- `rgb_q_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\x2\reference\rgb_q.npy`
