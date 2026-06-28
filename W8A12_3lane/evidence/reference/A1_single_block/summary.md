# A1 Single SPAB Block 3-Lane Reference

Status: PASS

## Config

- block: `1`
- shape: `4x4x48`
- lanes: `3 x 16ch`
- activation_bits: `12`
- bit_exact_lane_stitch: `True`

## Hashes

| Name | Value |
| --- | --- |
| `block_input_hash` | `0x47766845` |
| `c1_raw_hash` | `0x080D3C47` |
| `act1_hash` | `0x608EB896` |
| `c2_raw_hash` | `0x0A7D238A` |
| `act2_hash` | `0x17B3C9F8` |
| `c3_raw_hash` | `0x19F8FA9A` |
| `sim_att_hash` | `0x9EBD7351` |
| `block_output_hash` | `0xD12E1B43` |

## Lane Hashes

| Stage | Lane | Value |
| --- | --- | --- |
| `c1_raw` | `lane0_hash` | `0xD21FCF34` |
| `c1_raw` | `lane1_hash` | `0xA25E2E5A` |
| `c1_raw` | `lane2_hash` | `0xE8914DF4` |
| `c2_raw` | `lane0_hash` | `0x5B8DA8F5` |
| `c2_raw` | `lane1_hash` | `0x032C3FF2` |
| `c2_raw` | `lane2_hash` | `0x72DB948A` |
| `c3_raw` | `lane0_hash` | `0x1787A3F4` |
| `c3_raw` | `lane1_hash` | `0x04E8A39A` |
| `c3_raw` | `lane2_hash` | `0xB13C415F` |
| `block_output` | `lane0_hash` | `0xBF95ADDD` |
| `block_output` | `lane1_hash` | `0x3520C3E6` |
| `block_output` | `lane2_hash` | `0xB1849F67` |

## Attention Requant

- `out3_multiplier_q31`: `80193`
- `residual_multiplier_q31`: `1123025`
- `shift`: `31`

## Outputs

- `block_input_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\block_input.npy`
- `c1_raw_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\c1_raw.npy`
- `act1_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\act1.npy`
- `c2_raw_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\c2_raw.npy`
- `act2_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\act2.npy`
- `c3_raw_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\c3_raw.npy`
- `sim_att_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\sim_att.npy`
- `block_output_npy`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\block_output.npy`
- `sv_defines`: `G:\UESTC\feitengspan1\W8A12_3lane\evidence\reference\A1_single_block\a1_3lane_files.vh`
