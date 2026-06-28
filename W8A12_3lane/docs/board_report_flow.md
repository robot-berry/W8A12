# 全流程上板汇报流程

本文档定义 W8A12_3lane 每次完成全流程上板后的汇报格式。目的不是只记录“能不能跑”，而是同时记录资源消耗、时序、吞吐、功耗估计和超分效果指标。

## 1. 触发条件

每次满足以下任一条件，都必须生成上板汇报：

- 新 bitstream 首次上板；
- 修改 RTL 计算核心后上板；
- 修改 tile size、halo、scale、clock 后上板；
- 修改 W8A12 quant plan、weights、manifest 后上板；
- 从 32x32 扩展到 64x64、tile-based 720p 或视频序列后上板；
- 准备同步到 GitHub evidence 前。

## 2. 汇报目录

每次上板结果保存到：

```text
W8A12_3lane/evidence/board_reports/<tag>/
```

可先用模板工具生成 `PENDING` 报告骨架：

```powershell
python W8A12_3lane\tools\create_board_report.py --tag a5_32x32 --scale 4 --lr-width 32 --lr-height 32
python W8A12_3lane\tools\create_board_report.py --tag a6_64x64 --scale 4 --lr-width 64 --lr-height 64
python W8A12_3lane\tools\create_board_report.py --tag a7_720p_x4 --scale 4 --lr-width 320 --lr-height 180 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\create_board_report.py --tag x2_720p --scale 2 --lr-width 640 --lr-height 360 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
```

注意：模板状态为 `PENDING`，不能通过交付审计。只有真实上板后填入资源、时序、功耗、性能、PSNR/SSIM 和 bit-exact 结果，并把状态改为 `PASS`，才算有效证据。

真实上板产生 `board_output` 和 `fixed_reference` 后，优先使用自动 finalize 工具。它会从两个 raw RGB 文件自动计算 byte mismatch、bit-exact 和 PSNR，再写入 `summary.json` 并调用 `validate_board_report.py` 生成 `validation.md`：

```powershell
python W8A12_3lane\tools\finalize_board_report_from_outputs.py W8A12_3lane\evidence\board_reports\<tag>\summary.json --board-output <board_output.rgb> --fixed-reference <fixed_reference.rgb> --frame-done true --error false --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --power-w <power> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing>
```

该工具不会伪造最终 PASS：只要输出长度、mismatch、资源门限、时序、FPS、PSNR 或必要文件路径任一项不满足，`summary.json` 和 `validation.md` 都会保持 `FAIL`，不能通过交付审计。

如果需要手动覆盖或补充字段，可继续使用低层 update 工具，然后再使用校验器检查：

```powershell
python W8A12_3lane\tools\update_board_report.py W8A12_3lane\evidence\board_reports\<tag>\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --resource-status PASS --timing-status PASS --wns-ns 0.001 --whs-ns 0.001 --clock-mhz 100 --latency-ms 1.0 --fps 15 --target-fps 15 --power-w 3.0 --psnr-db 28.0 --bitstream <path> --utilization-report <path> --timing-report <path> --fixed-reference <path> --board-output <path>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\<tag>\summary.json --json-out W8A12_3lane\evidence\board_reports\<tag>\validation.json --md-out W8A12_3lane\evidence\board_reports\<tag>\validation.md
```

校验器要求：

```text
Status: PASS
FRAME_DONE=true
ERROR=false
mismatch=0
bit_exact_to_fixed_reference=true
resource_gate.status=PASS
LUT/FF/BRAM/DSP used 字段存在且不超过 XC7Z045/ZC706 门限
timing.status=PASS
WNS/WHS >= 0
clock/latency/fps/target_fps/power/psnr 已填写
fps >= target_fps
x4 psnr_db >= 28，x2 psnr_db >= 30
bitstream/utilization/timing/fixed_reference/board_output 文件路径已填写且文件存在
```

其中 `<tag>` 建议包含：

```text
scale_tile_clock_status_date
```

示例：

```text
x4_tile32_h21_f100_pass_20260625
x2_720p_f150_fail_20260625
```

## 3. 必须保存的文件

```text
summary.md
summary.json
board_run.log
xsct.log
vivado_impl.log
utilization.rpt
timing.rpt
power.rpt                 # 如果 Vivado 已生成
resource_gate.json
input.png 或 input_hash.txt
reference_output.png/rgb
board_output.png/rgb
mismatch.json
preview_compare.png
```

如果没有某个文件，必须在 `summary.md` 中说明原因。

## 4. 汇报字段

每次 `summary.json` 至少包含以下字段。

### 4.1 基本信息

| 字段 | 说明 |
| --- | --- |
| `tag` | 本次 run 标签 |
| `date` | 日期 |
| `git_commit` | 当前 commit，如 dirty 需记录 |
| `dirty_files` | 相关 dirty 文件列表 |
| `board_part` | 本地板卡，例如 `xczu19eg-ffvc1760-2-i` |
| `resource_target` | 资源评估目标，例如 `XC7Z045/ZC706` |
| `scale` | x2 或 x4 |
| `model` | SPAN x2/F48 或 SPAN x4/F48 |
| `quant` | W8A12 |
| `checkpoint` | checkpoint 路径 |
| `rtl_manifest` | manifest 路径 |
| `quant_plan` | quant plan 路径 |

### 4.2 图像和 tile 配置

| 字段 | 说明 |
| --- | --- |
| `input_width` / `input_height` | LR 输入尺寸 |
| `output_width` / `output_height` | SR 输出尺寸 |
| `tile_w` / `tile_h` | tile 尺寸 |
| `halo` | halo 大小 |
| `tiling_mode` | `tile+halo crop-stitch` |
| `downsample_on_ps` | 是否在 PS/软件侧先降采样成 LR |
| `bytes_per_pixel` | 输入或输出像素格式 |
| `input_source` | REDS、会议样例或 synthetic |

### 4.3 上板状态

| 字段 | 说明 |
| --- | --- |
| `frame_done` | 是否完成 |
| `error` | 错误 flag |
| `tiles_done` | 完成 tile 数 |
| `input_bytes` | 输入字节数 |
| `output_bytes` | 输出字节数 |
| `rgb_output_count` | 输出像素数 |
| `mismatch_bytes` | 与 reference 不一致字节数 |
| `max_abs_diff` | 最大绝对误差 |
| `mae` | 平均绝对误差 |
| `pass` | 本次是否通过 |

### 4.4 资源和时序

按 XC7Z045/ZC706 口径汇报：

| 字段 | 说明 |
| --- | --- |
| `lut_used` / `lut_limit` / `lut_pct` | LUT |
| `ff_used` / `ff_limit` / `ff_pct` | FF/REG |
| `bram_used` / `bram_limit` / `bram_pct` | BRAM Tile |
| `dsp_used` / `dsp_limit` / `dsp_pct` | DSP |
| `wns_ns` | WNS |
| `whs_ns` | WHS |
| `timing_pass` | 时序是否通过 |
| `resource_gate_pass` | 资源门限是否通过 |

### 4.5 性能指标

| 字段 | 说明 |
| --- | --- |
| `clock_mhz` | PL 时钟 |
| `latency_cycles` | 处理周期，如可测 |
| `latency_ms` | 单帧延迟 |
| `fps_estimated` | 估计 FPS |
| `fps_measured` | 实测 FPS，如可测 |
| `target_fps` | 当前验收 FPS。初版 15，优化目标 20，冲刺目标 30 |
| `ddr_read_bytes` | DDR 读带宽估计或计数 |
| `ddr_write_bytes` | DDR 写带宽估计或计数 |
| `power_w` | 功耗估计或测量 |
| `energy_per_frame_mj` | 每帧能耗，如可计算 |

FPS 和 PSNR 是两个独立指标：`x4 >= 28 dB` 指 PSNR 画质门槛，不是 FPS；FPS 初版按 `target_fps=15` 验收，后续优化到 20 FPS，条件允许再冲 30 FPS。

### 4.6 超分效果指标

至少记录：

| 字段 | 说明 |
| --- | --- |
| `psnr_fp32_vs_hr` | FP32 模型对 HR 的 PSNR，如有 |
| `psnr_fixed_vs_hr` | W8A12 fixed-point 对 HR 的 PSNR |
| `psnr_board_vs_hr` | 板端输出对 HR 的 PSNR |
| `psnr_board_vs_fixed` | 板端输出对 fixed reference 的 PSNR |
| `ssim_fixed_vs_hr` | fixed-point 对 HR 的 SSIM |
| `ssim_board_vs_hr` | board 对 HR 的 SSIM |
| `bit_exact_to_fixed` | 是否与 fixed reference bit-exact |
| `visual_status` | 正常、颜色异常、块状异常、边界异常等 |

如果没有 HR，只能做 board-vs-fixed，则必须说明：

```text
No HR metric: this run is a hardware correctness run only.
```

## 5. PASS 标准

一次上板汇报标为 PASS，必须同时满足：

```text
FRAME_DONE=1
ERROR=0
输出像素数正确
resource_gate_pass=true
timing_pass=true
board output 与 W8A12 fixed-point reference bit-exact
```

若不是 bit-exact，必须降级为 `PARTIAL` 或 `FAIL`，除非已有明确的容差验收规则。

## 6. 指标目标

| 倍率 | 画质目标 | 正确性目标 | 备注 |
| --- | --- | --- | --- |
| x4 | REDS_val PSNR `>= 28 dB` | board 与 fixed reference 一致 | 当前训练证据 `28.3118 dB` |
| x2 | REDS_val PSNR `>= 30 dB` | board 与 fixed reference 一致 | 当前训练证据 `34.4297 dB` |

最终赛题汇报必须区分：

- FP32 模型效果；
- W8A12 fixed-point 效果；
- RTL/board 输出效果；
- board-vs-fixed 正确性。

## 7. `summary.md` 模板

```text
# Board Report: <tag>

## 结论

Status: PASS / PARTIAL / FAIL

一句话结论：

## 配置

- board part:
- resource target:
- scale:
- model:
- quant:
- checkpoint:
- tile:
- halo:
- clock:

## 上板状态

- FRAME_DONE:
- ERROR:
- RGB_OUTPUT_COUNT:
- mismatch_bytes:
- max_abs_diff:
- bit_exact_to_fixed:

## 资源和时序

| Resource | Used | Limit | Percent |
| --- | ---: | ---: | ---: |
| LUT | | 218600 | |
| FF/REG | | 437200 | |
| BRAM Tile | | 545 | |
| DSP | | 900 | |

- WNS:
- WHS:
- timing_pass:
- resource_gate_pass:

## 性能

- clock_mhz:
- latency_cycles:
- latency_ms:
- fps_estimated:
- fps_measured:
- power_w:
- energy_per_frame_mj:

## 超分效果

- psnr_fixed_vs_hr:
- psnr_board_vs_hr:
- psnr_board_vs_fixed:
- ssim_fixed_vs_hr:
- ssim_board_vs_hr:
- visual_status:

## 文件

- bitstream:
- utilization:
- timing:
- power:
- resource_gate:
- input:
- reference_output:
- board_output:
- preview_compare:
```

## 8. 汇报节奏

每次完成全流程上板后，必须在本轮工作结束前做三件事：

1. 生成 `W8A12_3lane/evidence/board_reports/<tag>/summary.md`。
2. 更新 `W8A12_3lane/STATUS.md`。
3. 在最终回复或提交说明中汇报：
   - PASS/PARTIAL/FAIL；
   - 资源消耗；
   - 时序；
   - FPS/延迟；
   - PSNR/SSIM 或 board-vs-fixed 正确性。
