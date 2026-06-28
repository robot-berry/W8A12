# A0 RTL Simulation Summary

Status: PASS

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_single_conv.ps1
```

## Result

```text
PASS w8a12_3lane_single_conv pixels=16 channels=48
```

## Scope

- Stage: A0 single 3-lane convolution.
- Layer: `block_1.c1_r`.
- Input feature shape: `4x4x48`.
- Lane split: `3 x 16ch`.
- Expected output: `W8A12_3lane/evidence/reference/A0_single_conv/full48_output.txt`.
- RTL wrapper: `W8A12_3lane/rtl/span/w8a12_3lane_conv_layer.v`.
- Testbench: `W8A12_3lane/sim/tb_w8a12_3lane_single_conv.sv`.

## Hashes

| Name | Value |
| --- | --- |
| input_hash | `0x47766845` |
| lane0_hash | `0xD21FCF34` |
| lane1_hash | `0xA25E2E5A` |
| lane2_hash | `0xE8914DF4` |
| full48_hash | `0x080D3C47` |
| stitched_hash | `0x080D3C47` |

## Vivado Log

```text
build/vivado_w8a12_3lane_single_conv_sim/w8a12_3lane_single_conv_sim.sim/sim_1/behav/xsim/simulate.log
```

